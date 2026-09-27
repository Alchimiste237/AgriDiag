import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../scan/capture_screen.dart';
import '../history/history_screen.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/settings_service.dart';
import '../../l10n/app_strings.dart';

/// Home dashboard — new design: greeting header, big green scan card,
/// history shortcut. Built for one-handed use in bright sunlight: big cards,
/// high-contrast dark-on-white text.
///
/// Syncing happens silently in the background via [SyncService]'s retry timer.
/// This screen focuses on the farmer's workflow: scan, check history, learn.
class HomeScreen extends StatelessWidget {
  final bool embedded;

  const HomeScreen({super.key, this.embedded = false});

  String _tipOfDay(BuildContext context) {
    final strings = AppStrings.of(context);
    return strings.tips[
        DateTime.now().difference(DateTime(2024)).inDays % strings.tips.length];
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    SettingsService? settings;
    try {
      settings = context.watch<SettingsService>();
    } catch (_) {
      settings = null;
    }

    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          // Greeting + Farmer ID
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${strings.hello}, ${settings?.firstName ?? '…'} 👋',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'AgroDiag',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.tapToScan,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.inkSoft,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (settings?.farmerId != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${strings.farmerIdLabel}: ${settings!.farmerId}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Big scan card (design language: rounded green gradient panel)
          _ScanCard(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CaptureScreen()),
            ),
            scanLabel: strings.scanNewLeaf,
            autoDetectLabel: strings.autoDetectsCrop,
          ),
          const SizedBox(height: 16),

          // History card — full width
          _ActionCard(
            icon: Icons.history_rounded,
            title: strings.myHistory,
            subtitle: strings.recentScans,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          const SizedBox(height: 16),

          // Tip of the day
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.severityMediumBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.severityMediumText.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.severityMediumText.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.lightbulb_outline,
                      color: AppColors.severityMediumText, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.tipTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tipOfDay(context),
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) return body;
    return Scaffold(backgroundColor: AppColors.canvas, body: body);
  }
}

class _ScanCard extends StatelessWidget {
  final VoidCallback onTap;
  final String scanLabel;
  final String autoDetectLabel;

  const _ScanCard({
    required this.onTap,
    required this.scanLabel,
    required this.autoDetectLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: AppColors.deepGreenGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepGreen.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandMark(size: 84),
                  const SizedBox(height: 14),
                  Text(
                    scanLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    autoDetectLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: AppColors.green),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
