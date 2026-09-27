import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads diagnosis results aloud using the phone's built-in TTS engine —
/// works fully offline once the OS voice pack is installed (true for
/// English/French on virtually all Android/iOS devices out of the box).
///
/// The language can be switched at runtime (English <-> French) to match
/// the user's preference; each speak() call can pass its own language code.
///
/// For languages the OS TTS engine doesn't support (many Central/West
/// African local languages), this approach won't work at all — that will
/// need pre-recorded audio clips per diagnosis instead, played via a
/// regular audio player rather than this service.
class VoiceService extends ChangeNotifier {
  static const String defaultLanguageCode = 'en-US';

  final FlutterTts _tts = FlutterTts();
  bool isSpeaking = false;
  bool isAvailable = true;
  String _languageCode = defaultLanguageCode;

  Future<void> init() async {
    try {
      await _tts.setLanguage(_languageCode);
      await _tts.setSpeechRate(0.42); // slower than default, for clarity
      await _tts.setPitch(1.0);

      final languages = await _tts.getLanguages;
      // Mark available if either of the app's languages is installed — a
      // French-only device shouldn't lose voice just because init starts in
      // English. setLanguage() re-checks when the user switches language.
      if (languages is List &&
          !languages.contains('en-US') &&
          !languages.contains('fr-FR')) {
        // Language pack not installed on this device — degrade gracefully,
        // the UI hides the voice controls rather than failing silently.
        isAvailable = false;
      }

      _tts.setStartHandler(() {
        isSpeaking = true;
        notifyListeners();
      });
      _tts.setCompletionHandler(() {
        isSpeaking = false;
        notifyListeners();
      });
      _tts.setCancelHandler(() {
        isSpeaking = false;
        notifyListeners();
      });
      _tts.setErrorHandler((_) {
        isSpeaking = false;
        notifyListeners();
      });
    } catch (_) {
      isAvailable = false;
    }
  }

  /// Switches the TTS voice to [code] (e.g. 'fr-FR'). No-op if unchanged or
  /// if the engine is unavailable.
  Future<void> setLanguage(String code) async {
    if (code == _languageCode) return;
    _languageCode = code;
    if (!isAvailable) {
      // Re-check: the new language's voice pack may be installed even if the
      // previous one wasn't.
      try {
        final languages = await _tts.getLanguages;
        if (languages is List && languages.contains(_languageCode)) {
          isAvailable = true;
          notifyListeners();
        }
      } catch (_) {
        return;
      }
    }
    try {
      await _tts.setLanguage(_languageCode);
    } catch (_) {
      // keep current language; speech may sound wrong but won't crash
    }
  }

  Future<void> speak(String text, {String? language}) async {
    if (!isAvailable) return;
    if (language != null && language != _languageCode) {
      await setLanguage(language);
    }
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
