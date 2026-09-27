import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device-level settings that aren't tied to a single scan — the farmer
/// profile collected once during onboarding (name, phone, village, language,
/// data-sharing consent) plus an auto-generated Farmer ID and the optional
/// pilot farmer code. Kept separate from StorageService's scan box since
/// this is config, not scan data.
class SettingsService extends ChangeNotifier {
  static const String _boxName = 'settings';
  static const String _farmerIdKey = 'farmer_id';
  static const String _nameKey = 'farmer_name';
  static const String _phoneKey = 'farmer_phone';
  static const String _villageKey = 'farmer_village';
  static const String _languageKey = 'language';
  static const String _consentKey = 'consent';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  // --- Getters ---
  String? get farmerId => _box.get(_farmerIdKey) as String?;
  String? get farmerName => _box.get(_nameKey) as String?;
  String? get phoneNumber => _box.get(_phoneKey) as String?;
  String? get village => _box.get(_villageKey) as String?;

  /// 'en' or 'fr' — the app's UI + voice language.
  String get language => _box.get(_languageKey) as String? ?? 'en';
  bool get consent => _box.get(_consentKey) as bool? ?? false;

  /// First word of the farmer's name, for the greeting ("Hello, Musa").
  String? get firstName => farmerName?.trim().split(RegExp(r'\s+')).first;

  /// Onboarding is complete once a name is stored and consent was given.
  bool get isOnboarded => (farmerName?.isNotEmpty ?? false) && consent;

  // --- Setters ---
  Future<void> setLanguage(String lang) async {
    await _box.put(_languageKey, lang);
    notifyListeners();
  }

  /// Persists the full profile from the onboarding screen and generates the
  /// Farmer ID the first time (it is never regenerated afterwards).
  Future<void> completeOnboarding({
    required String name,
    required String phone,
    required String village,
    required String language,
    required bool consent,
  }) async {
    await _box.put(_nameKey, name.trim());
    await _box.put(_phoneKey, phone.trim());
    await _box.put(_villageKey, village.trim());
    await _box.put(_languageKey, language);
    await _box.put(_consentKey, consent);
    if (_box.get(_farmerIdKey) == null) {
      await _box.put(_farmerIdKey, _generateFarmerId());
    }
    notifyListeners();
  }

  /// Simple, readable, human-shareable ID (e.g. "AGD-4821").
  static String _generateFarmerId() {
    final digits = Random().nextInt(9000) + 1000;
    return 'AGD-$digits';
  }
}
