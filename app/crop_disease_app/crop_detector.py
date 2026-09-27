#!/usr/bin/env python3
"""Train the crop auto-detection classifier with a 5th "background" class.

The classifier identifies **4 crop species** from leaf photos — Banana, Cacao,
Cassava, Maize — plus a catch-all **background** class so photos of anything
that is NOT one of those crops (tables, walls, hands, soil, other plants, …)
are rejected by the model itself instead of being force-fed into the closest
crop class. This fixes the classic closed-set-softmax failure where a photo of
a wall gets reported as "maize, 92% confident".

Dataset layout (labels come from the TOP-LEVEL folder name):

    raw/
    ├── Banana/...        (any nested structure is fine)
    ├── Cacao/...
    ├── cassava/...
    ├── maize/...
    └── background/       <- the not-a-crop class (name is configurable)

The background folder must contain images that are NOT any of the four crops:
other plants/weeds, soil, wood, tables, walls, hands, sky, buildings, etc.
Include GREEN non-crop objects (green fabric, lawns, other crop species) —
those are the ones the old model confidently mislabelled as maize. See
README_crop_detector.md for guidance on sources and volume.

Important contract with the Flutter app (lib/inference_service.dart):
  * The exported model consumes RAW [0,255] pixels — the MobileNetV2
    preprocess_input normalization is baked INTO the graph via a Rescaling
    layer, exactly like the current shipped models.
  * The output tensor is FLOAT32 softmax probabilities, shape [1, N].
  * crop_labels.txt has one class name per line; "background" goes LAST and
    must match CropPrediction.backgroundLabel in the app (case-insensitive).

Requirements:
    pip install tensorflow pillow

Usage:
    python crop_detector.py                       # train + export + deploy to assets
    python crop_detector.py --epochs 20 --batch-size 64
    python crop_detector.py --predict leaf.jpg
    python crop_detector.py --predict leaf.jpg --model crop_model_output/crop_classifier.tflite
    python crop_detector.py --export-only          # convert saved_model -> tflite, skip training
    python crop_detector.py --background-label background

Output:
    crop_model_output/saved_model/          TensorFlow SavedModel
    crop_model_output/crop_classifier.tflite  float32 TFLite (or int8 if --quantize succeeds)
    crop_model_output/crop_labels.txt         class names, background last
    crop_model_output/dataset_cache.json      image path cache
    assets/models/crop_classifier/            Flutter-ready copies (auto-copied)
"""

import argparse
import json
import os
import random
import shutil
import sys
from pathlib import Path

import numpy as np

# NOTE: tensorflow is imported at the top on purpose — every mode (train,
# predict, export-only) needs it. The script requires: pip install tensorflow pillow
import tensorflow as tf
from tensorflow import keras

IMG_SIZE = 224  # must match InferenceService.inputSize
SEED = 42


def log(msg: str) -> None:
    print(f"[crop_detector] {msg}", flush=True)


# ---------------------------------------------------------------------------
# Dataset
# ---------------------------------------------------------------------------

def find_classes(raw_dir: Path, background_label: str):
    """Discover classes from top-level folders of `raw_dir`.

    Returns (class_names, class_dirs) where class_names has the crop classes
    (sorted, case-insensitive) followed by the background class LAST.
    """
    if not raw_dir.is_dir():
        raise SystemExit(f"raw dir not found: {raw_dir} (run from the project root)")
    dirs = [d for d in raw_dir.iterdir() if d.is_dir()]
    if not dirs:
        raise SystemExit(f"no class folders found under {raw_dir}")
    crops, bg_dirs = [], []
    for d in sorted(dirs, key=lambda p: p.name.lower()):
        if d.name.lower() == background_label.lower():
            bg_dirs.append(d)
        else:
            crops.append(d)

    # The background class is the whole point of this script. Refuse to train
    # a 4-class model silently — that is the exact broken behaviour ("wall →
    # maize") this change exists to fix.
    if not bg_dirs:
        raise SystemExit(
            f"no '{background_label}' folder found under {raw_dir} — refusing to train. "
            "Add raw/background/ with images of everything that is NOT one of the "
            "crops (other plants, soil, tables, walls, hands, green fabric, …). "
            "See README_crop_detector.md → 'The background class — what to collect'."
        )

    class_names = [d.name for d in crops]
    class_names.append(background_label)  # ALWAYS last — the app expects it
    log(f"classes: {class_names} (background last)")
    return class_names, crops + bg_dirs


def collect_images(class_dirs, class_names):
    """Map every image under each class dir to its class index."""
    exts = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
    files, labels = [], []
    for class_dir in class_dirs:
        label = class_names.index(class_dir.name) if class_dir.name in class_names else -1
        if label < 0:
            continue
        hits = sorted(
            p for p in class_dir.rglob("*")
            if p.is_file() and p.suffix.lower() in exts
        )
        log(f"{class_dir.name}: {len(hits)} images")
        files.extend(str(p) for p in hits)
        labels.extend([label] * len(hits))
    if not files:
        raise SystemExit("no images found — check the raw/ layout")
    return np.array(files), np.array(labels, dtype=np.int64)


def stratified_split(files, labels, val_frac=0.15, test_frac=0.15):
    """Per-class 70/15/15 split so rare classes stay represented."""
    rng = random.Random(SEED)
    train_f, train_l, val_f, val_l, test_f, test_l = [], [], [], [], [], []
    for cls in np.unique(labels):
        idx = np.where(labels == cls)[0]
        idx = list(idx)
        rng.shuffle(idx)
        n_val = max(1, int(len(idx) * val_frac))
        n_test = max(1, int(len(idx) * test_frac))
        val_idx, test_idx = idx[:n_val], idx[n_val:n_val + n_test]
        train_idx = idx[n_val + n_test:]
        train_f += list(files[train_idx]); train_l += list(labels[train_idx])
        val_f += list(files[val_idx]);     val_l += list(labels[val_idx])
        test_f += list(files[test_idx]);   test_l += list(labels[test_idx])
    return (np.array(train_f), np.array(train_l, dtype=np.int64),
            np.array(val_f), np.array(val_l, dtype=np.int64),
            np.array(test_f), np.array(test_l, dtype=np.int64))


def class_weights(labels, num_classes):
    """Inverse-frequency weights so the background class (often under- or
    over-represented) doesn't dominate or get ignored."""
    counts = np.bincount(labels, minlength=num_classes).astype(float)
    counts = np.where(counts == 0, 1.0, counts)
    total = counts.sum()
    return {i: total / (num_classes * c) for i, c in enumerate(counts)}


def _decode(path, label):
    img = tf.io.read_file(path)
    img = tf.image.decode_image(img, channels=3, expand_animations=False)
    img = tf.image.resize(img, (IMG_SIZE, IMG_SIZE))
    img = tf.cast(img, tf.float32)  # RAW [0,255] — normalization is in the graph
    return img, label


def _augment(img, label):
    img = tf.image.random_flip_left_right(img)
    img = tf.image.random_flip_up_down(img)
    img = tf.image.random_brightness(img, 0.15)
    img = tf.image.random_contrast(img, 0.8, 1.2)
    img = tf.image.random_saturation(img, 0.8, 1.2)
    return img, label


def build_dataset(files, labels, batch_size, train: bool):
    ds = tf.data.Dataset.from_tensor_slices((files, labels))
    ds = ds.map(_decode, num_parallel_calls=tf.data.AUTOTUNE)
    if train:
        ds = ds.map(_augment, num_parallel_calls=tf.data.AUTOTUNE)
        ds = ds.shuffle(2048, seed=SEED)
    return ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------

def build_model(num_classes):
    """MobileNetV2 transfer learning with preprocess_input BAKED IN.

    The first layer maps raw [0,255] pixels to [-1,1] exactly like
    MobileNetV2's preprocess_input — so the exported TFLite consumes raw
    pixels and the Flutter app can keep feeding it raw bytes.
    """
    base = keras.applications.MobileNetV2(
        input_shape=(IMG_SIZE, IMG_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False

    inputs = keras.Input(shape=(IMG_SIZE, IMG_SIZE, 3))
    x = keras.layers.Rescaling(scale=1.0 / 127.5, offset=-1.0)(inputs)  # preprocess_input
    x = base(x, training=False)
    x = keras.layers.GlobalAveragePooling2D()(x)
    x = keras.layers.Dropout(0.2)(x)
    outputs = keras.layers.Dense(num_classes, activation="softmax")(x)
    return keras.Model(inputs, outputs)


def train(model, train_ds, val_ds, epochs, class_weights_map, lr, callbacks):
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=lr),
        loss=keras.losses.SparseCategoricalCrossentropy(),
        metrics=["accuracy"],
    )
    model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=epochs,
        class_weight=class_weights_map,
        callbacks=callbacks,
        verbose=2,
    )


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------

def export(model, out_dir: Path, class_names, quantize: bool):
    out_dir.mkdir(parents=True, exist_ok=True)
    saved_dir = out_dir / "saved_model"
    model.save(saved_dir)
    log(f"SavedModel -> {saved_dir}")

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize:
        # int8 full-integer quantization; falls back to float16 then float32.
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.uint8
        converter.inference_output_type = tf.uint8
        try:
            tflite = converter.convert()
            log("export: int8 quantized tflite")
        except Exception as e:
            log(f"int8 failed ({e}); trying float16")
            converter = tf.lite.TFLiteConverter.from_keras_model(model)
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            tflite = converter.convert()
            log("export: float16 tflite")
    else:
        tflite = converter.convert()
        log("export: float32 tflite")

    # Belt-and-braces: the Flutter app relies on the background class being the
    # LAST label (CropPrediction.backgroundLabel). Fail loudly if that broke.
    if class_names[-1].lower() != background_label.lower():
        raise SystemExit(
            f"labels would not end with '{background_label}' — refusing to export"
        )

    tflite_path = out_dir / "crop_classifier.tflite"
    tflite_path.write_bytes(tflite)

    (out_dir / "crop_labels.txt").write_text("\n".join(class_names) + "\n", encoding="utf-8")
    log(f"labels -> {out_dir / 'crop_labels.txt'}: {class_names}")
    return tflite_path


def deploy_to_assets(out_dir: Path):
    """Copy model + labels into the Flutter assets folder."""
    assets_dir = Path("assets/models/crop_classifier")
    assets_dir.mkdir(parents=True, exist_ok=True)
    for name in ("crop_classifier.tflite", "crop_labels.txt"):
        src = out_dir / name
        if src.exists():
            shutil.copy2(src, assets_dir / name)
            log(f"deployed -> {assets_dir / name}")


# ---------------------------------------------------------------------------
# Prediction
# ---------------------------------------------------------------------------

def predict_image(model_path: Path, image_path: Path, class_names):
    from PIL import Image

    interp = tf.lite.Interpreter(model_path=str(model_path))
    interp.allocate_tensors()
    in_d = interp.get_input_details()[0]
    out_d = interp.get_output_details()[0]

    img = Image.open(image_path).convert("RGB").resize((IMG_SIZE, IMG_SIZE))
    arr = np.asarray(img, dtype=np.float32)[None, ...]  # raw [0,255]

    if in_d["dtype"] == np.uint8:
        arr = arr.astype(np.uint8)
    interp.set_tensor(in_d["index"], arr)
    interp.invoke()
    out = interp.get_tensor(out_d["index"])[0]

    q = out_d.get("quantization_parameters", {})
    scales, zps = q.get("scales"), q.get("zero_points")
    if out_d["dtype"] in (np.uint8, np.int8) and scales is not None and len(scales):
        scores = [(v - zps[0]) * scales[0] for v in out]
    else:
        scores = [float(v) for v in out]

    order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
    print(f"\n{image_path} ->")
    for i in order[:3]:
        name = class_names[i] if i < len(class_names) else f"#{i}"
        print(f"  {name:<12} {scores[i]:.3f}")
    return scores


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--raw-dir", default="raw", help="dataset root (default: raw)")
    ap.add_argument("--background-label", default="background",
                    help="folder/class name for the not-a-crop class (default: background)")
    ap.add_argument("--epochs", type=int, default=10, help="epochs per phase (default: 10)")
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--out-dir", default="crop_model_output")
    ap.add_argument("--quantize", action="store_true",
                    help="export int8 (fallback float16). Default export is float32 — "
                         "the current app consumes float32.")
    ap.add_argument("--predict", metavar="IMAGE", help="run inference on one image")
    ap.add_argument("--model", default="crop_model_output/crop_classifier.tflite",
                    help="model for --predict")
    ap.add_argument("--export-only", action="store_true",
                    help="re-export the saved_model from a previous run as tflite")
    args = ap.parse_args()

    out_dir = Path(args.out_dir)
    class_names, class_dirs = find_classes(Path(args.raw_dir), args.background_label)
    num_classes = len(class_names)

    if args.export_only:
        saved_dir = out_dir / "saved_model"
        if not saved_dir.exists():
            raise SystemExit(f"{saved_dir} not found — run without --export-only first")
        model = keras.models.load_model(saved_dir)
        export(model, out_dir, class_names, args.quantize)
        deploy_to_assets(out_dir)
        return

    if args.predict:
        predict_image(Path(args.model), Path(args.predict), class_names)
        return

    # --- train ---
    files, labels = collect_images(class_dirs, class_names)
    cache = {"class_names": class_names,
             "files": files.tolist(),
             "labels": labels.tolist()}
    (out_dir / "dataset_cache.json").write_text(json.dumps(cache), encoding="utf-8")

    (train_f, train_l, val_f, val_l, test_f, test_l) = stratified_split(files, labels)
    log(f"split: train={len(train_f)} val={len(val_f)} test={len(test_f)}")

    train_ds = build_dataset(train_f, train_l, args.batch_size, train=True)
    val_ds = build_dataset(val_f, val_l, args.batch_size, train=False)
    test_ds = build_dataset(test_f, test_l, args.batch_size, train=False)
    weights = class_weights(train_l, num_classes)

    callbacks = [
        keras.callbacks.EarlyStopping(patience=4, restore_best_weights=True,
                                      monitor="val_loss"),
        keras.callbacks.ReduceLROnPlateau(patience=2, factor=0.5, monitor="val_loss"),
    ]

    model = build_model(num_classes)
    log("phase 1: training head (backbone frozen), lr=1e-3")
    train(model, train_ds, val_ds, args.epochs, weights, lr=1e-3, callbacks=callbacks)

    log("phase 2: fine-tuning top 30% of backbone, lr=1e-5")
    # Layer order: [InputLayer, Rescaling, MobileNetV2, GlobalAveragePooling2D,
    # Dropout, Dense]. Index 2 is the MobileNetV2 backbone.
    base = model.layers[2]
    for layer in base.layers:
        layer.trainable = False
    for layer in base.layers[-int(0.3 * len(base.layers)):]:
        layer.trainable = True
    train(model, train_ds, val_ds, max(2, args.epochs // 2), weights, lr=1e-5,
          callbacks=callbacks)

    log("evaluating on held-out test set:")
    loss, acc = model.evaluate(test_ds, verbose=0)
    log(f"test loss={loss:.4f} test accuracy={acc:.4f}")

    # Per-class accuracy so the background class is checked explicitly.
    preds = np.argmax(model.predict(test_ds, verbose=0), axis=1)
    for cls in np.unique(test_l):
        mask = test_l == cls
        acc_c = float((preds[mask] == cls).mean())
        log(f"  {class_names[int(cls)]:<12} n={int(mask.sum()):>4} accuracy={acc_c:.3f}")

    export(model, out_dir, class_names, args.quantize)
    deploy_to_assets(out_dir)
    log("done — deploy crop_model_output/crop_classifier.tflite to the app or use the auto-copy above")


if __name__ == "__main__":
    main()
