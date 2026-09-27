#!/usr/bin/env python3
"""Probe the bundled crop classifier to ground the CropPrediction thresholds.

Mirrors lib/inference_service.dart exactly:
  - image resized to 224x224 (stretch, as the app does)
  - pixels fed RAW (normalization baked into the graph)
  - quantized uint8 output dequantized as (q - zp) * scale
  - leaf-likeness = fraction of centre-quarter pixels (stride 4) where
    g > r and g > b
  - entropy = -sum(p * ln p) over the dequantized scores

Run from the project root:
  /tmp/tflite_venv/Scripts/python.exe tool/probe_thresholds.py
"""

import math
import numpy as np
from PIL import Image
from ai_edge_litert.interpreter import Interpreter

MODEL = "assets/models/crop_classifier/crop_classifier.tflite"
LABELS = "assets/models/crop_classifier/crop_labels.txt"
SIZE = 224


def leaf_likeness(img):
    """Same as _leafLikeness in inference_service.dart."""
    w, h = img.size
    x0, x1 = w // 4, w - w // 4
    y0, y1 = h // 4, h - h // 4
    arr = np.asarray(img.convert("RGB"))
    region = arr[y0:y1:4, x0:x1:4]  # stride 4
    r, g, b = region[..., 0], region[..., 1], region[..., 2]
    total = r.size
    green = int(((g > r) & (g > b)).sum())
    return green / total if total else 0.0


def entropy(scores):
    h = 0.0
    for s in scores:
        if s <= 0:
            continue
        h -= s * math.log(s)
    if h <= 0:
        return math.log(len(scores))
    return h


def make_solid(rgb):
    return Image.new("RGB", (SIZE, SIZE), tuple(rgb))


def make_noise(rgb_base, amount=60, seed=0):
    rng = np.random.default_rng(seed)
    arr = np.clip(
        np.asarray(rgb_base)[None, None, :] + rng.normal(0, amount, (SIZE, SIZE, 3)),
        0, 255,
    ).astype(np.uint8)
    return Image.fromarray(arr)


def make_gradient(rgb_a, rgb_b, vertical=True):
    t = np.linspace(0, 1, SIZE)[:, None if vertical else None]  # (H,1) or (1,W)
    a = np.asarray(rgb_a, dtype=float)
    b = np.asarray(rgb_b, dtype=float)
    arr = np.clip(a[None, None, :] * (1 - t[..., None]) + b[None, None, :] * t[..., None], 0, 255).astype(np.uint8)
    return Image.fromarray(arr)


# Current Dart thresholds (lib/inference_service.dart CropPrediction). The
# probe mirrors them so each row reports exactly how the app would judge it.
LEAF_LIKENESS_THRESHOLD = 0.05
CONFIDENCE_THRESHOLD = 0.70
ENTROPY_THRESHOLD = 0.80


def main():
    labels = [l.strip() for l in open(LABELS, encoding="utf-8") if l.strip()]
    interp = Interpreter(model_path=MODEL)
    interp.allocate_tensors()
    in_d = interp.get_input_details()[0]
    out_d = interp.get_output_details()[0]

    print(f"INPUT  {in_d['dtype']} shape={in_d['shape']} scale={in_d.get('quantization_parameters', {}).get('scales')} zp={in_d.get('quantization_parameters', {}).get('zero_points')}")
    print(f"OUTPUT {out_d['dtype']} shape={out_d['shape']} scale={out_d.get('quantization_parameters', {}).get('scales')} zp={out_d.get('quantization_parameters', {}).get('zero_points')}")
    print()

    images = {
        # --- surfaces / objects (should be rejected) ---
        "gray wall":        make_solid((128, 128, 128)),
        "white wall":       make_solid((245, 245, 245)),
        "black table":      make_solid((25, 25, 25)),
        "brown wood":       make_noise((120, 78, 48), amount=35, seed=1),
        "blue wall":        make_solid((70, 110, 200)),
        "skin/hand":        make_solid((200, 150, 115)),
        "red object":       make_solid((180, 45, 40)),
        "gray noise":       make_noise((128, 128, 128), amount=90, seed=2),
        "green fabric":     make_solid((90, 140, 70)),  # green but not a leaf
        # --- leaf-like images (should be accepted) ---
        "green leaf":       make_noise((70, 150, 55), amount=25, seed=3),
        "dark green leaf":  make_noise((35, 75, 30), amount=20, seed=4),
        "leaf on soil":     make_gradient((70, 150, 55), (95, 70, 40), vertical=False),
        "yellow blight":    make_noise((170, 165, 60), amount=30, seed=6),  # diseased leaf
        "brown blight":     make_noise((130, 95, 45), amount=30, seed=7),   # heavily diseased
    }

    print(f"{'image':<16} {'leaf':>6} {'conf':>7} {'entropy':>8}   top-2 gap | top prediction | verdict")
    print("-" * 92)
    for name, img in images.items():
        img = img.resize((SIZE, SIZE))
        arr = np.asarray(img.convert("RGB"))

        # App feeds raw pixels: uint8 bytes for quantized, raw [0,255] floats for float32.
        if in_d["dtype"] == np.uint8:
            inp = arr[None, ...].astype(np.uint8)
        else:
            inp = arr[None, ...].astype(np.float32)
        interp.set_tensor(in_d["index"], inp)
        interp.invoke()
        out = interp.get_tensor(out_d["index"])[0]

        # Dequantize exactly like _runAndGetScores.
        q = out_d.get("quantization_parameters", {})
        scales, zps = q.get("scales"), q.get("zero_points")
        if out_d["dtype"] in (np.uint8, np.int8) and scales is not None and len(scales):
            scores = [(v - zps[0]) * scales[0] for v in out]
        else:
            scores = [float(v) for v in out]

        order = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
        conf = scores[order[0]]
        ent = entropy(scores)
        gap = scores[order[0]] - scores[order[1]]
        ll = leaf_likeness(img)
        top = labels[order[0]] if order[0] < len(labels) else f"#{order[0]}"
        not_leaf = ll < LEAF_LIKENESS_THRESHOLD
        uncertain = conf < CONFIDENCE_THRESHOLD or ent > ENTROPY_THRESHOLD
        verdict = "BLOCK(retake)" if not_leaf else ("UNCERTAIN" if uncertain else "OK")
        print(f"{name:<16} {ll:6.2f} {conf:7.3f} {ent:8.3f}   {gap:6.3f}   | {top} {scores[order[0]]:.3f} | {verdict}")


if __name__ == "__main__":
    main()
