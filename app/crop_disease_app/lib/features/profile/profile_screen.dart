import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_theme.dart';
import '../../l10n/app_strings.dart';
import '../../core/services/settings_service.dart';

/// Profile tab — the farmer's identity (name, Farmer ID, phone, village),
/// language preference and data-sharing consent, plus a short privacy note.
/// Read-only for now: it reuses [SettingsService] getters, no new logic.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final settings = context.watch<SettingsService>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dark header with avatar + name + Farmer ID
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: AppColors.deepGreenGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        strings.profileTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: AppColors.green,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      settings.farmerName ?? strings.notSet,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${strings.farmerIdLabel}: ${settings.farmerId ?? '—'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Details card
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoCard(
                    title: strings.farmerInfo,
                    rows: [
                      (Icons.person_outline, strings.nameLabel,
                          settings.farmerName ?? strings.notSet),
                      (Icons.phone_outlined, strings.phoneLabel,
                          settings.phoneNumber ?? strings.notSet),
                      (Icons.location_on_outlined, strings.villageLabel,
                          settings.village ?? strings.notSet),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: strings.appLanguage,
                    rows: [
                      (
                        Icons.translate_rounded,
                        strings.languageLabel,
                        settings.language == 'fr'
                            ? strings.frenchName
                            : strings.englishName
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: strings.dataSharing,
                    rows: [
                      (
                        Icons.verified_user_outlined,
                        strings.dataSharing,
                        settings.consent ? strings.granted : strings.notGranted
                      ),
                    ],
                    trailing: settings.consent
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 20)
                        : const Icon(Icons.cancel_outlined,
                            color: AppColors.inkFaint, size: 20),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 15, color: AppColors.inkFaint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          strings.dataNote,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.inkFaint,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<(IconData, String, String)> rows;
  final Widget? trailing;

  const _InfoCard({required this.title, required this.rows, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(r.$1, size: 18, color: AppColors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.$2,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      r.$3,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
