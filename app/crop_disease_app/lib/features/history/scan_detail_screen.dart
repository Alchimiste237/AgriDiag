import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/crop_info.dart';
import '../../core/models/scan.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/voice_service.dart';
import '../../core/widgets/agro_chrome.dart';
import '../../l10n/app_strings.dart';

/// Displays the full diagnosis result for a previously saved scan,
/// letting the user review it without re-scanning.
class ScanDetailScreen extends StatefulWidget {
  final Scan scan;

  const ScanDetailScreen({super.key, required this.scan});

  @override
  State<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends State<ScanDetailScreen> {
  Map<String, dynamic>? _treatmentInfo;

  @override
  void initState() {
    super.initState();
    _loadTreatmentInfo();
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

    final cropTreatments = data[widget.scan.cropSpecies] as Map<String, dynamic>?;
    if (cropTreatments != null && mounted) {
      setState(() {
        _treatmentInfo = cropTreatments[widget.scan.diseaseLabel] as Map<String, dynamic>?;
      });
    }
  }

  void _speakResult() {
    final info = _treatmentInfo;
    if (info == null) return;

    final strings = AppStrings.of(context);
    final scan = widget.scan;
    final cropInfo = CropInfo.fromName(scan.cropSpecies);
    final confidenceWord = scan.confidence >= 0.85
        ? strings.confident.toLowerCase()
        : scan.confidence >= 0.6
            ? 'moderate'
            : 'low';

    final isFrench = context.read<SettingsService>().language == 'fr';
    final spokenText = isFrench
        ? '${info['display_name']} détecté sur ${cropInfo?.displayName ?? scan.cropSpecies}. '
            'Confiance $confidenceWord. '
            '${info['description']} '
            'Traitement recommandé : ${info['bio_treatment']}'
        : '${info['display_name']} detected on ${cropInfo?.displayName ?? scan.cropSpecies}. '
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

  /// Severity pill data (same rules as ResultScreen).
  ({Color bg, Color text, IconData icon, String label}) get _severity {
    final strings = AppStrings.of(context);
    final isHealthy = widget.scan.diseaseLabel.toLowerCase().contains('health');
    if (isHealthy) {
      return (
        bg: AppColors.severityLowBg,
        text: AppColors.severityLowText,
        icon: Icons.verified_rounded,
        label: strings.healthyStatus,
      );
    }
    final c = widget.scan.confidence;
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
    final scan = widget.scan;
    final file = File(scan.imagePath);
    final cropInfo = CropInfo.fromName(scan.cropSpecies);
    final confidentEnough = scan.confidence >= 0.6;
    final strings = AppStrings.of(context);
    final severity = _severity;
    final displayName = _treatmentInfo?['display_name'] ?? scan.diseaseLabel;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        children: [
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
                  // Header card: thumbnail + name + confidence + severity
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
                            tag: 'scan_image_${scan.id}',
                            child: file.existsSync()
                                ? Image.file(
                                    file,
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 76,
                                    height: 76,
                                    color: AppColors.canvas,
                                    child: const Icon(
                                        Icons.image_not_supported,
                                        color: AppColors.inkFaint),
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
                                '${cropInfo?.iconAsset ?? ''} '
                                '${cropInfo?.displayName ?? scan.cropSpecies} · '
                                '${strings.confidencePercent(scan.confidence)}',
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

                  if (!confidentEnough) _buildLowConfidenceBanner(strings),

                  // Description
                  _sectionTitle(strings.descriptionTitle),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      _treatmentInfo?['description'] ?? '…',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.55,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendations
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
                            children: _stepsFrom(
                                    _treatmentInfo!['bio_treatment'] ?? '')
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

                  // Listen button
                  _buildListenButton(strings),

                  const SizedBox(height: 16),

                  // Location + timestamp
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 15, color: AppColors.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${strings.recordedAt} ${scan.timestamp.toLocal().toString().split('.').first}',
                          style: const TextStyle(
                              color: AppColors.inkFaint, fontSize: 12),
                        ),
                      ),
                      if (scan.latitude != null && scan.longitude != null)
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 15, color: AppColors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${scan.latitude!.toStringAsFixed(4)}, '
                              '${scan.longitude!.toStringAsFixed(4)}',
                              style: const TextStyle(
                                  color: AppColors.inkFaint, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowConfidenceBanner(AppStrings strings) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.severityMediumBg,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.severityMediumText.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline,
              color: AppColors.severityMediumText, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Not fully sure about this one. Consider a local agricultural agent if the leaf still looks off.',
              style: TextStyle(fontSize: 13, color: AppColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
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
