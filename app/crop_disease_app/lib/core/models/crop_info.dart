/// Describes one crop's model and label assets.
class CropInfo {
  final String name; // machine key, e.g. "Banana"
  final String displayName; // human-readable, e.g. "Banana"
  final String iconAsset; // emoji fallback for now
  final String modelAsset;
  final String labelsAsset;

  const CropInfo({
    required this.name,
    required this.displayName,
    required this.iconAsset,
    required this.modelAsset,
    required this.labelsAsset,
  });

  /// All available crop models bundled with the app.
  static const List<CropInfo> all = [
    CropInfo(
      name: 'Banana',
      displayName: 'Banana',
      iconAsset: '\u{1F34C}',
      modelAsset: 'assets/models/Banana/model.tflite',
      labelsAsset: 'assets/models/Banana/labels.txt',
    ),
    CropInfo(
      name: 'Cacao',
      displayName: 'Cacao',
      iconAsset: '\u{1F36B}',
      modelAsset: 'assets/models/Cacao/model.tflite',
      labelsAsset: 'assets/models/Cacao/labels.txt',
    ),
    CropInfo(
      name: 'Cassava',
      displayName: 'Cassava',
      iconAsset: '\u{1F954}',
      modelAsset: 'assets/models/cassava/model.tflite',
      labelsAsset: 'assets/models/cassava/labels.txt',
    ),
    CropInfo(
      name: 'Maize',
      displayName: 'Maize',
      iconAsset: '\u{1F33D}',
      modelAsset: 'assets/models/maize/model.tflite',
      labelsAsset: 'assets/models/maize/labels.txt',
    ),
  ];

  /// Look up a CropInfo by [name] (case-insensitive).
  static CropInfo? fromName(String name) {
    final lower = name.toLowerCase();
    try {
      return all.firstWhere((c) => c.name.toLowerCase() == lower);
    } catch (_) {
      return null;
    }
  }
}
