import 'package:flutter/material.dart';
import '../../core/config/app_theme.dart';
import '../../l10n/app_strings.dart';

/// Advice tab — the daily crop-health tips shown as simple, visual cards.
/// The tip content comes from [AppStrings.tips] so it stays localized and
/// rotates daily, exactly like the old home-screen "tip of the day".
class AdviceScreen extends StatelessWidget {
  const AdviceScreen({super.key});

  static const List<IconData> _tipIcons = [
    Icons.bug_report_outlined,
    Icons.grass_outlined,
    Icons.search_rounded,
    Icons.water_drop_outlined,
    Icons.eco_outlined,
    Icons.cleaning_services_rounded,
    Icons.photo_camera_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final tips = strings.tips;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Text(
              strings.adviceTitle,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.adviceSubtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(tips.length, (i) {
              return _AdviceCard(
                icon: _tipIcons[i % _tipIcons.length],
                text: tips[i],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdviceCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: AppColors.green),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
