import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/config/app_theme.dart';
import 'features/main_shell.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/services/inference_service.dart';
import 'core/services/settings_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/voice_service.dart';

class CropDiseaseApp extends StatelessWidget {
  const CropDiseaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const _AppBootstrap();
  }
}

/// Handles async initialisation, then wraps the real [MaterialApp] inside
/// [MultiProvider] so that ALL Navigator routes (not just the initial route)
/// can access the services via [Provider.of] / [context.read].
///
/// Widget tree after init:
/// ```
/// MultiProvider  ← service instances live HERE
///   └── MaterialApp
///        └── Navigator
///             ├── Route 0: HomeScreen / OnboardingScreen
///             └── Route N: CaptureScreen, ResultScreen, HistoryScreen, …
/// ```
class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  /// Services are created once and kept alive for the entire app lifecycle.
  late final InferenceService _inferenceService;
  late final StorageService _storageService;
  late final SettingsService _settingsService;
  late final VoiceService _voiceService;
  SyncService? _syncService;

  late final Future<void> _initFuture;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _inferenceService = InferenceService();
    _storageService = StorageService();
    _settingsService = SettingsService();
    _voiceService = VoiceService();
    _initFuture = _init();
  }

  Future<void> _init() async {
    try {
      await _storageService.init();
      await _settingsService.init();
      await _voiceService.init();
      _syncService = SyncService(_storageService, _settingsService);
      _syncService!.trySync(); // opportunistic sync on app start
    } catch (e) {
      _initError = e.toString();
    }
    // Preload the automatic crop classifier so the first scan is instant.
    // Failure is non-fatal: the app still starts and CaptureScreen retries
    // lazily before scanning.
    try {
      await _inferenceService.loadCropClassifier();
    } catch (e) {
      debugPrint('Crop classifier preload failed (will retry on scan): $e');
    }
  }

  @override
  void dispose() {
    _inferenceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        // --- Loading state: show a minimal MaterialApp with no providers ---
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        // --- Error state ---
        if (_initError != null || snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load the app: ${_initError ?? snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        // --- Ready: wrap the REAL MaterialApp inside MultiProvider ---
        return MultiProvider(
          providers: [
            ChangeNotifierProvider<InferenceService>.value(value: _inferenceService),
            ChangeNotifierProvider<StorageService>.value(value: _storageService),
            ChangeNotifierProvider<SettingsService>.value(value: _settingsService),
            ChangeNotifierProvider<SyncService>.value(value: _syncService!),
            ChangeNotifierProvider<VoiceService>.value(value: _voiceService),
          ],
          child: MaterialApp(
            title: 'AgroDiag',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              scaffoldBackgroundColor: AppColors.canvas,
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.green,
                primary: AppColors.green,
                secondary: AppColors.deepGreen,
                surface: AppColors.surface,
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: true,
                titleTextStyle: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              textTheme: ThemeData.light().textTheme.apply(
                    bodyColor: AppColors.ink,
                    displayColor: AppColors.ink,
                  ),
              cardTheme: CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                margin: EdgeInsets.zero,
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            home: const _RootRouter(),
          ),
        );
      },
    );
  }
}

/// Shows the one-time onboarding screen until the farmer profile is set,
/// then the normal home screen — checked reactively so it flips over
/// immediately after the user taps "Get Started", no restart needed.
class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    if (!settings.isOnboarded) {
      return const OnboardingScreen();
    }
    return const MainShell();
  }
}
