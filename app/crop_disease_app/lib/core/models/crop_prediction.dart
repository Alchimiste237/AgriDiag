import 'crop_info.dart';

/// Result of running the crop classifier on one photo.
class CropPrediction {
  final CropInfo crop;
  final double confidence;
  final List<MapEntry<String, double>> topPredictions; // sorted, highest first

  /// How leaf-like the photo looks (0..1): fraction of centre pixels where
  /// green is the dominant channel. Near 0 for tables, walls, hands, floors.
  final double leafLikeness;

  /// Shannon entropy (nats) of the classifier's full softmax output. The
  /// model is "guessing" when this is high (flat distribution).
  final double entropy;

  /// True when the classifier's top prediction is the "background / not a
  /// crop" class — the model itself says this photo is not one of the
  /// supported crops, so no crop disease model should run.
  final bool isBackground;

  /// Label the classifier uses for "none of the supported crops". Must match
  /// the last line of crop_labels.txt from crop_detector.py (case-insensitive).
  static const String backgroundLabel = 'background';

  CropPrediction({
    required this.crop,
    required this.confidence,
    required this.topPredictions,
    required this.leafLikeness,
    required this.entropy,
    this.isBackground = false,
  });

  // Thresholds are grounded empirically with tool/probe_thresholds.py
  // (which runs the actual bundled classifier on synthetic images):
  //   - solid surfaces (wall/table/hand/floor):  leafLikeness = 0.00
  //   - real leaves incl. dark/blighted:          leafLikeness ≥ 0.19
  //   - between-crop ambiguity:                   confidence 0.63–0.70
  //   - confident crop IDs:                       confidence ≥ 0.75
  //   - observed softmax entropy range:           0.12–0.69 (max ln4 ≈ 1.386)

  /// Below this leaf-likeness the photo is almost certainly not a plant at
  /// all — reject it before running any disease model. 0.08 sits in the gap
  /// between non-plant surfaces (~0.00) and real leaves (≥0.19), catching
  /// objects like cars, blackboards, walls, tables, and hands with margin.
  static const double leafLikenessThreshold = 0.08;

  /// Below this top-1 confidence the classifier isn't sure which crop it is.
  /// 0.70 is where the probe data actually splits: the measured ambiguous
  /// band (brown wood 0.632, yellow blight 0.652, noise 0.698) is flagged,
  /// while confident IDs (brown blight 0.745, leaves 0.85–0.98) pass. This is
  /// deliberately stricter than InferenceResult.confidenceThreshold (0.60): a
  /// wrong crop ID poisons the disease model, so crop uncertainty warrants
  /// more caution. Note confidence alone can NOT catch surfaces — the model
  /// is confidently wrong on them (0.86–0.93) — that is leaf-likeness's job;
  /// this threshold only flags between-crop uncertainty.
  static const double confidenceThreshold = 0.70;

  /// Above this softmax entropy (max for 4 classes ≈ 1.386) the model is
  /// effectively guessing — the prediction should not be presented as solid.
  /// 0.80 is a backstop for "confident-looking but spread" distributions the
  /// confidence gate misses, e.g. (0.75, 0.12, 0.08, 0.05) → H ≈ 0.82, which
  /// happens when two crops look similar. It stays above every entropy the
  /// probe measured on leaves AND surfaces (max 0.69), so it never
  /// false-flags measured inputs, but fires on in-distribution ambiguity.
  static const double entropyThreshold = 0.80;

  /// True when the photo looks like a leaf at all ([leafLikeness] high enough).
  bool get isLeafLike => leafLikeness >= leafLikenessThreshold;

  /// True when the crop recognition itself is unreliable (low confidence or
  /// a flat / guessing softmax distribution).
  bool get isUncertain =>
      confidence < confidenceThreshold || entropy > entropyThreshold;
}
