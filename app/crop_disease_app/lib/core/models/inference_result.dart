/// Result of running the on-device model on one photo.
class InferenceResult {
  final String label;
  final double confidence;
  final List<MapEntry<String, double>> topPredictions; // sorted, highest first

  InferenceResult({
    required this.label,
    required this.confidence,
    required this.topPredictions,
  });

  /// Below this, don't confidently claim a diagnosis — show "uncertain" in the UI instead.
  static const double confidenceThreshold = 0.6;

  bool get isConfident => confidence >= confidenceThreshold;
}
