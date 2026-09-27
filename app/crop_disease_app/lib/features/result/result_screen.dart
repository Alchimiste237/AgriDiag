import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../scan/capture_screen.dart';
import '../main_shell.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/crop_info.dart';
import '../../core/models/inference_result.dart';
import '../../core/models/scan.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/widgets/agro_chrome.dart';
import '../../l10n/app_strings.dart';

class ResultScreen extends StatefulWidget {
  final CropInfo crop;
  final File imageFile;
  final InferenceResult result;

  /// Confidence of the automatic crop recognition (0..1).
  final double cropConfidence;

  /// GPS position captured with the photo (null if unavailable).
  final double? latitude;
  final double? longitude;

  const ResultScreen({
    super.key,
    required this.crop,
    required this.imageFile,
    required this.result,
    this.cropConfidence = 1.0,
    this.latitude,
    this.longitude,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? _treatmentInfo;

  @override
  void initState() {
    super.initState();
    _loadTreatmentInfo();
    _saveScan();
  }

  @override
  void dispose() {
    context.read<VoiceService>().stop();
    super.dispose();
  }

  Future<void> _loadTreatmentInfo() async {
    final isFrench = context.read<SettingsService>().language == 'fr';
    final asset = isFrench
        ? 'assets/data/treatment_data_fr.json'
        : 'assets/data/treatment_data.json';
    final raw = await rootBundle.loadString(asset);
    final data = json.decode(raw) as Map<String, dynamic>;

    final cropTreatments = data[widget.crop.name] as Map<String, dynamic>?;
    if (cropTreatments != null && mounted) {
      setState(() {
        _treatmentInfo = cropTreatments[widget.result.label] as Map<String, dynamic>?;
      });
    }
  }

  void _speakResult() {
    final info = _treatmentInfo;
    if (info == null) return;

    final strings = AppStrings.of(context);
    final result = widget.result;
    final confidenceWord = result.confidence >= 0.85
        ? strings.confident.toLowerCase()
        : result.confidence >= InferenceResult.confidenceThreshold
            ? 'moderate'
            : 'low';

    final spokenText = isFrench
        ? '${info['display_name']} détecté sur ${widget.crop.displayName}. '
            'Confiance $confidenceWord. '
            '${info['description']} '
            'Traitement recommandé : ${info['bio_treatment']}'
        : '${info['display_name']} detected on ${widget.crop.displayName}. '
            '$confidenceWord confidence. '
            '${info['description']} '
            'Recommended treatment: ${info['bio_treatment']}';

    context.read<VoiceService>().speak(spokenText, language: strings.ttsLanguageCode);
  }

  bool get isFrench => context.read<SettingsService>().language == 'fr';

  List<String> _stepsFrom(String text) {
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _saveScan() async {
    final scan = Scan(
      id: const Uuid().v4(),
      imagePath: widget.imageFile.path,
      cropSpecies: widget.crop.name,
      diseaseLabel: widget.result.label,
      confidence: widget.result.confidence,
      timestamp: DateTime.now(),
      latitude: widget.latitude,
      longitude: widget.longitude,
    );

    final storage = context.read<StorageService>();
    final syncService = context.read<SyncService>();
    await storage.saveScan(scan);
    syncService.trySync();
  }

  /// Severity pill colors — red for high, amber for medium, green for low,
  /// as in the design. "Healthy" labels never show a red pill.
  ({Color bg, Color text, IconData icon, String label}) get _severity {
    final strings = AppStrings.of(context);
    final isHealthy = widget.result.label.toLowerCase().contains('health');
    if (isHealthy) {
      return (
        bg: AppColors.severityLowBg,
        text: AppColors.severityLowText,
        icon: Icons.verified_rounded,
        label: strings.severityWord(true, widget.result.confidence),
      );
    }
    final c = widget.result.confidence;
    if (c >= 0.85) {
      return (
        bg: AppColors.severityHighBg,
        text: AppColors.severityHighText,
        icon: Icons.error_rounded,
        label: '${strings.severityLabel}: ${strings.severityWord(false, c)}',
      );
    }
    if (c >= 0.6) {
      return (
        bg: AppColors.severityMediumBg,
        text: AppColors.severityMediumText,
        icon: Icons.warning_amber_rounded,
        label: '${strings.severityLabel}: ${strings.severityWord(false, c)}',
      );
    }
    return (
      bg: AppColors.severityLowBg,
      text: AppColors.severityLowText,
      icon: Icons.info_rounded,
      label: '${strings.severityLabel}: ${strings.severityWord(false, c)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final confidentEnough = result.isConfident;
    final strings = AppStrings.of(context);
    final severity = _severity;
    final displayName =
        _treatmentInfo?['display_name'] ?? result.label;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
          // Dark header — "Analysis result"
          AgroPageHeader(
            title: strings.resultPageTitle,
            onBack: () => Navigator.of(context).maybePop(),
            actionIcon: Icons.ios_share_rounded,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Header card: thumbnail + name + confidence + severity
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Hero(
                            tag: 'scan_image_result',
                            child: Image.file(
                              widget.imageFile,
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.confidencePercent(result.confidence),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SeverityPill(
                                label: severity.label,
                                bg: severity.bg,
                                textColor: severity.text,
                                icon: severity.icon,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (!confidentEnough) _buildLowConfidenceBanner(result, strings),

                  // ---- Description section
                  _sectionTitle(strings.descriptionTitle),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      _treatmentInfo?['description'] ??
                          strings.analyzingLeaf.replaceAll('…', '…'),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Recommendations section
                  _sectionTitle(strings.recommendationsTitle),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: _treatmentInfo != null
                        ? Column(
                            children: _stepsFrom(_treatmentInfo!['bio_treatment'] ?? '')
                                .map((step) => _recommendationRow(step))
                                .toList(),
                          )
                        : const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.green),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // ---- Voice: full-width green "Listen" button (design)
                  _buildListenButton(strings),

                  const SizedBox(height: 16),

                  // ---- Location + timestamp footer
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 15, color: AppColors.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${strings.recordedAt} $resultTimestamp',
                          style: const TextStyle(
                              color: AppColors.inkFaint, fontSize: 12),
                        ),
                      ),
                      if (widget.latitude != null && widget.longitude != null)
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 15, color: AppColors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.latitude!.toStringAsFixed(4)}, '
                              '${widget.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: AppColors.inkFaint, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ---- Secondary actions
                  FilledButton.icon(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const CaptureScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 20),
                    label: Text(strings.scanAnother),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (route) => false,
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.deepGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    child: Text(strings.done),
                  ),
                ],
              ),
            ),
          ),

          // Bottom navigation (design shows it on the result screen too).
          AgroBottomNavBar(
            currentTab: AgroTab.scanner,
            onTabSelected: _onNavTab,
          ),
        ],
      ),
    );
  }

  /// Bottom-nav taps from the result screen land on the shell.
  void _onNavTab(AgroTab tab) {
    if (tab == AgroTab.scanner) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CaptureScreen()),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainShell(initialTab: tab)),
      (route) => false,
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _recommendationRow(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.greenSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppColors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get resultTimestamp =>
      DateTime.now().toLocal().toString().split('.').first;

  Widget _buildLowConfidenceBanner(InferenceResult result, AppStrings strings) {
    final alternatives = result.topPredictions.skip(1).map((e) => e.key).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.severityMediumBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.severityMediumText.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.severityMediumText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              strings.lowConfidenceBanner(alternatives),
              style: const TextStyle(
                  fontSize: 13, color: AppColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenButton(AppStrings strings) {
    return Consumer<VoiceService>(
      builder: (context, voice, _) {
        if (!voice.isAvailable) return const SizedBox.shrink();

        final isSpeaking = voice.isSpeaking;
        return SizedBox(
          height: 54,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.greenButtonGradient,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(27),
                onTap: () => isSpeaking ? voice.stop() : _speakResult(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSpeaking
                          ? Icons.stop_circle_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isSpeaking
                          ? strings.stopListening
                          : strings.listenRecommendation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
