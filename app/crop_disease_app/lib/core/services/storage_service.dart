import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/scan.dart';

/// Local persistence for scan history. Uses a plain Hive box of Maps —
/// no codegen/type adapters needed, keeps the MVP simple.
/// Extends ChangeNotifier so the history screen can watch() it and
/// rebuild automatically whenever a new scan is saved.
class StorageService extends ChangeNotifier {
  static const String _boxName = 'scans';
  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveScan(Scan scan) async {
    debugPrint('[StorageService] saving scan ${scan.id} — '
        'crop: ${scan.cropSpecies}, disease: ${scan.diseaseLabel}, '
        'confidence: ${scan.confidence}, synced: ${scan.synced}');
    await _box.put(scan.id, scan.toMap());
    debugPrint('[StorageService] scan ${scan.id} saved to Hive box (total: ${_box.length})');
    notifyListeners();
  }

  List<Scan> getAllScans() {
    return _box.values
        .map((raw) => Scan.fromMap(Map<dynamic, dynamic>.from(raw as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
  }

  List<Scan> getUnsyncedScans() {
    final unsynced = getAllScans().where((s) => !s.synced).toList();
    debugPrint('[StorageService] getUnsyncedScans() → ${unsynced.length} unsynced out of ${_box.length} total');
    return unsynced;
  }

  Future<void> markSynced(String scanId) async {
    final raw = _box.get(scanId);
    if (raw == null) {
      debugPrint('[StorageService] markSynced($scanId) — scan not found in Hive!');
      return;
    }
    final scan = Scan.fromMap(Map<dynamic, dynamic>.from(raw as Map));
    scan.synced = true;
    await _box.put(scanId, scan.toMap());
    debugPrint('[StorageService] markSynced($scanId) ✓ — synced flag updated');
  }
}
