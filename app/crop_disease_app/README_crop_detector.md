# Crop Auto-Detection Script

Trains a deep learning classifier to identify **4 crop species** from leaf images:
**Banana, Cacao, Cassava, and Maize** — plus a catch-all **background** class so
photos that are NOT a supported crop (tables, walls, hands, other plants, soil,
…) are rejected by the model itself instead of being force-fed into the closest
crop class (the old "wall → maize 92%" failure).

## Dataset

All training images are stored under `raw/` with the following layout:

```
raw/
├── Banana/OriginalSet/cordana/        *.jpeg  (~162 images)
│                       healthy/       *.jpeg  (~129 images)
│                       pestalotiopsis/*.jpeg  (~172 images)
│                       sigatoka/      *.jpeg  (~470 images)
├── Cacao/OriginalSet/Fito/            *.jpg   (~105 images + YOLO annotations)
│                       Monilia/       *.jpg   (~105 images)
│                       Sana/          *.jpg   (~100 images)
├── cassava/OriginalSet/Cassava___bacterial_blight/    *.jpg  (hundreds)
│                         Cassava___brown_streak_disease/*.jpg
│                         Cassava___green_mottle/      *.jpg
│                         Cassava___healthy/           *.jpg
│                         Cassava___mosaic_disease/    *.jpg
├── maize/OriginalSet/Blight/          *.jpg   (hundreds)
│                   Common_Rust/        *.jpg
│                   Gray_Leaf_Spot/     *.jpg
│                   Healthy/            *.jpg
└── background/                        *.jpg   (the NOT-a-crop class)
```

The crop label is derived from the **top-level folder name**, regardless of
the disease subfolder. This means the classifier learns to distinguish
crop species by their leaf appearance across all disease states. The
`background/` folder is the fifth class and must NOT contain any of the four
crops.

### The background class — what to collect

The whole point of the fifth class is to teach the model to say "I don't
know". Quality and *diversity* matter more than quantity. Aim for **at least
as many background images as your largest crop class** (ideally 1–2× that),
and include the things that actually fooled the old model:

- **Green non-crop objects** — green fabric, lawns/grass, weeds, other crop
  species (tomato, rice, coffee…), houseplants, green painted walls. These are
  the cases the old 4-class model confidently called "maize".
- **Surfaces** — tables, wooden floors, walls, concrete, metal, tiles.
- **Body parts / everyday scenes** — hands, clothes, furniture, books,
  kitchen items, anything a phone camera points at.
- **Natural but non-crop** — soil, gravel, sky, water, dried vegetation.
- **Near-misses** — other plants whose leaves LOOK like the 4 crops (e.g.
  sugarcane, sorghum, plantain vs banana). These near-misses are the most
  valuable: they push the decision boundary where it matters.

Where to get them: take photos yourself, use existing non-crop images from
your other datasets, or pull from open image sets (e.g. ImageNet "background"
categories, Open Images, or Kaggle "non-plant" collections). Avoid using the
same camera/background for every image — diversity prevents the model from
cheating on backgrounds.

> Balance tip: if `background/` is much larger than the crop classes, the
> model may start rejecting real leaves. The training script applies
> inverse-frequency class weights automatically, but keep the folder roughly
> balanced anyway.

## Requirements

```bash
pip install tensorflow pillow
```

(Optional but recommended: scikit-learn is no longer required — the script
does its own stratified split.)

## Usage

### Train the model

```bash
python crop_detector.py
```

This will:
1. Scan `raw/` and build a dataset cache (5 classes, background last)
2. Split into train / validation / test sets (70/15/15, per class)
3. Build a MobileNetV2 transfer learning model with `preprocess_input`
   **baked into the graph** (the exported model consumes raw [0,255] pixels,
   exactly like the currently shipped models — do NOT pre-normalize)
4. Train the classification head (LR=1e-3), then fine-tune the top 30% of the
   backbone (LR=1e-5)
5. Evaluate on the test set, including **per-class accuracy for background**
6. Export to SavedModel + TFLite (float32 by default; `--quantize` tries
   int8 → float16 fallback) and copy everything to `assets/models/crop_classifier/`

Output goes to `crop_model_output/` and is also copied to
`assets/models/crop_classifier/` for Flutter app integration.

### Predict on a single image

```bash
python crop_detector.py --predict path/to/leaf.jpg
```

Optionally specify a model:
```bash
python crop_detector.py --predict leaf.jpg --model crop_model_output/crop_classifier.tflite
```

### Just export (skip training)

```bash
python crop_detector.py --export-only
```

### Configure training

```bash
python crop_detector.py --epochs 20 --batch-size 64
```

### Background folder name

```bash
python crop_detector.py --background-label background
```

## Model Architecture

- **Backbone**: MobileNetV2 (ImageNet pretrained)
- **Head**: GlobalAveragePooling → Dropout(0.2) → Dense(5, softmax)
- **Input**: raw [0,255] pixels — MobileNetV2 `preprocess_input` is the first
  graph layer (Rescaling to [-1,1])
- **Training**: Phase 1 (frozen backbone, LR=1e-3) → Phase 2 (fine-tune top 30%, LR=1e-5)
- **Output**: 5-class softmax: [Banana, Cacao, Cassava, Maize, **background**]

## Output Files

| File | Description |
|------|-------------|
| `crop_model_output/saved_model/` | TensorFlow SavedModel |
| `crop_model_output/crop_classifier.tflite` | TFLite model (float32, or int8 with `--quantize`) |
| `crop_model_output/crop_labels.txt` | Class names (one per line, **background last**) |
| `crop_model_output/dataset_cache.json` | Image path cache |
| `assets/models/crop_classifier/` | Flutter-ready copy (auto-copied) |

## Flutter app integration

The app (`lib/inference_service.dart`) already understands the fifth class:

- `crop_labels.txt` gains a `background` line; `CropPrediction` exposes
  `isBackground` and the capture flow turns a background prediction into the
  same "doesn't look like a leaf — retake?" prompt used for non-leaf photos
  (with a Continue-anyway escape hatch for genuinely diseased/discoloured
  leaves).
- Re-tune the gating thresholds afterwards with `tool/probe_thresholds.py`
  (runs the real model on synthetic images). With 5 classes the max softmax
  entropy rises to ln(5) ≈ 1.61, so `entropyThreshold` in particular may need
  another look.
- The script refuses to train if `raw/background` is missing (a silent
  4-class model would reintroduce the exact bug this class fixes).
- If you use `--quantize` (int8/float16), re-probe the exported model with
  `tool/probe_thresholds.py` before shipping — the app's float32 path is the
  verified contract; quantized I/O goes through a separate (unverified)
  dequantization path.
