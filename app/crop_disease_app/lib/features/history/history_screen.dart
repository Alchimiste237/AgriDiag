import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'scan_detail_screen.dart';
import '../../core/config/app_theme.dart';
import '../../core/models/crop_info.dart';
import '../../core/models/scan.dart';
import '../../core/services/storage_service.dart';
import '../../l10n/app_strings.dart';

class HistoryScreen extends StatelessWidget {
  final bool embedded;

  const HistoryScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final scans = storage.getAllScans();
    final strings = AppStrings.of(context);

    final list = scans.isEmpty
        ? _buildEmptyState(strings)
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: scans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => _ScanCard(scan: scans[index]),
          );

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 10),
      child: Row(
        children: [
          // Standalone route (pushed from Home) needs a back button; the
          // embedded tab doesn't.
          if (!embedded && Navigator.of(context).canPop())
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
            ),
          Text(
            strings.historyTitle,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );

    final body = SafeArea(
      child: Column(
        children: [
          header,
          Expanded(child: list),
        ],
      ),
    );

    if (embedded) return body;
    return Scaffold(backgroundColor: AppColors.canvas, body: body);
  }

  Widget _buildEmptyState(AppStrings strings) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.greenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco_outlined,
                size: 48,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Scan a leaf to see your diagnosis history here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.inkFaint,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  final Scan scan;
  const _ScanCard({required this.scan});

  /// Returns a color based on the confidence level.
  Color get _confidenceColor {
    if (scan.confidence >= 0.85) return AppColors.severityHighText;
    if (scan.confidence >= 0.6) return AppColors.severityMediumText;
    return AppColors.severityLowText;
  }

  @override
  Widget build(BuildContext context) {
    final file = File(scan.imagePath);
    final cropInfo = CropInfo.fromName(scan.cropSpecies);
    final strings = AppStrings.of(context);
    final displayName =
        _treatmentDisplayName(context) ?? scan.diseaseLabel;

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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ScanDetailScreen(scan: scan),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: file.existsSync()
                      ? Image.file(
                          file,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 64,
                          height: 64,
                          color: AppColors.canvas,
                          child: const Icon(Icons.image_not_supported,
                              color: AppColors.inkFaint),
                        ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${cropInfo?.iconAsset ?? ''} ${cropInfo?.displayName ?? scan.cropSpecies}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          // Confidence badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _confidenceColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              '${(scan.confidence * 100).toStringAsFixed(0)}% · ${_severityWord(strings)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _confidenceColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(scan.timestamp),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkFaint,
                            ),
                          ),
                          if (scan.latitude != null &&
                              scan.longitude != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.place,
                                size: 13, color: AppColors.inkFaint),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Best-effort friendly name lookup from the treatment data is async
  /// (asset load), so cards use the raw label — same as before the redesign.
  String? _treatmentDisplayName(BuildContext context) => null;

  String _severityWord(AppStrings strings) {
    if (scan.diseaseLabel.toLowerCase().contains('health')) {
      return strings.healthyStatus;
    }
    return strings.severityWord(false, scan.confidence);
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.month}/${local.day}/${local.year}';
  }
}
