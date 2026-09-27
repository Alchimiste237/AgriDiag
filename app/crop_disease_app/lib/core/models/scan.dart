/// A single scan record: one photo, one diagnosis, stored locally and
/// synced to the backend when connectivity allows.
class Scan {
  final String id;
  final String imagePath;
  final String cropSpecies; // hardcoded to 'plantain' until crop ID stage exists
  final String diseaseLabel;
  final double confidence;
  final DateTime timestamp;

  /// GPS position captured with the photo; null if unavailable/denied.
  final double? latitude;
  final double? longitude;

  bool synced;

  Scan({
    required this.id,
    required this.imagePath,
    required this.cropSpecies,
    required this.diseaseLabel,
    required this.confidence,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.synced = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        'cropSpecies': cropSpecies,
        'diseaseLabel': diseaseLabel,
        'confidence': confidence,
        'timestamp': timestamp.toIso8601String(),
        'latitude': latitude,
        'longitude': longitude,
        'synced': synced,
      };

  factory Scan.fromMap(Map<dynamic, dynamic> map) => Scan(
        id: map['id'] as String,
        imagePath: map['imagePath'] as String,
        cropSpecies: map['cropSpecies'] as String,
        diseaseLabel: map['diseaseLabel'] as String,
        confidence: (map['confidence'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        synced: map['synced'] as bool? ?? false,
      );
}
