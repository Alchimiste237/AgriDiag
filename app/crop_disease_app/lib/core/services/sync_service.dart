import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../config/supabase_config.dart';
import 'settings_service.dart';
import 'storage_service.dart';

/// Pushes locally stored scans to Supabase whenever the phone has
/// connectivity. Each scan's image is uploaded to Supabase Storage first,
/// then the scan row (with `image_url`) is inserted via the REST API.
///
/// Image upload is best-effort: if it fails (e.g. bandwidth saving, bucket
/// not created), the scan is still saved without a photo — the `image_url`
/// column is nullable for this reason.
///
/// Extends ChangeNotifier so the UI can watch sync state (pending count,
/// last error, whether a sync is in progress) and rebuild reactively.
class SyncService extends ChangeNotifier {
  final StorageService storage;
  final SettingsService settings;
  final Dio _dio = Dio();

  Timer? _retryTimer;
  bool _syncing = false;
  String? _lastError;
  int _failedCount = 0;
  int _syncedCount = 0;
  int _totalCount = 0;

  /// True while a sync attempt is in flight.
  bool get isSyncing => _syncing;

  /// Human-readable description of the last sync failure (null when idle/success).
  String? get lastError => _lastError;

  /// Number of scans that failed to upload in the most recent attempt.
  int get failedCount => _failedCount;

  /// Number of scans successfully synced so far in the current batch.
  int get syncedCount => _syncedCount;

  /// Total number of scans in the current sync batch.
  int get totalCount => _totalCount;

  SyncService(this.storage, this.settings) {
    debugPrint('[SyncService] initialized — SupabaseConfig.isConfigured: ${SupabaseConfig.isConfigured}');
    // Retry every 60 seconds if there are pending scans — covers the case
    // where the phone comes online silently (e.g. Wi-Fi reconnects) without
    // a connectivity_plus event firing.
    _retryTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      final pendingCount = storage.getUnsyncedScans().length;
      debugPrint('[SyncService] retry timer fired — $pendingCount unsynced scan(s)');
      if (pendingCount > 0) {
        trySync();
      }
    });
  }

  String get _scansEndpoint => '${SupabaseConfig.url}/rest/v1/scans';
  String get _storageEndpoint => '${SupabaseConfig.url}/storage/v1/object';

  Map<String, String> get _authHeaders => {
        'apikey': SupabaseConfig.anonKey,
        'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
      };

  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      final online = result != ConnectivityResult.none;
      debugPrint('[SyncService] connectivity check: $result → ${online ? 'ONLINE' : 'OFFLINE'}');
      return online;
    } catch (e) {
      debugPrint('[SyncService] connectivity check FAILED: $e');
      return false;
    }
  }

  /// Maximum longest-edge dimension for uploaded images (pixels).
  static const int _maxDimension = 1024;

  /// JPEG quality for uploaded images (0–100).
  static const int _jpegQuality = 80;

  /// Compresses the image on a background isolate: decodes, resizes to
  /// [_maxDimension] on the longest edge, and re-encodes as JPEG at
  /// [_jpegQuality] quality. Returns the compressed bytes.
  static Uint8List _compressImage(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes; // fallback: send original

    final oriented = img.bakeOrientation(decoded);

    // Resize only if the image exceeds the max dimension.
    img.Image resized = oriented;
    final longest = oriented.width > oriented.height
        ? oriented.width
        : oriented.height;
    if (longest > _maxDimension) {
      resized = img.copyResize(
        oriented,
        width: oriented.width >= oriented.height ? _maxDimension : null,
        height: oriented.height >= oriented.width ? _maxDimension : null,
      );
    }

    return Uint8List.fromList(
      img.encodeJpg(resized, quality: _jpegQuality),
    );
  }

  /// Uploads the scan image to Supabase Storage and returns its public URL.
  /// The image is compressed (resized + JPEG) before upload to save bandwidth.
  /// Returns null if the upload fails — callers should treat the scan as
  /// imageless but still proceed with the row insert.
  Future<String?> _uploadImage(File imageFile, String scanId) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;

      // Compress on a background isolate so the UI thread stays responsive.
      final compressedBytes = await compute(_compressImage, originalBytes);
      final compressedSize = compressedBytes.length;
      final ratio = ((1 - compressedSize / originalSize) * 100).toInt();
      debugPrint('[SyncService] image compressed: '
          '${(originalSize / 1024).toStringAsFixed(0)}KB → '
          '${(compressedSize / 1024).toStringAsFixed(0)}KB '
          '(${ratio > 0 ? '-$ratio%' : 'no change'})');

      // Always upload as JPEG regardless of the original format.
      final filename = '$scanId.jpg';
      final uploadUrl = '$_storageEndpoint/scan-images/$filename';
      debugPrint('[SyncService] uploading image → $uploadUrl ($compressedSize bytes)');
      final uploadResponse = await _dio.post(
        uploadUrl,
        options: Options(
          headers: {
            ..._authHeaders,
            'Content-Type': 'image/jpeg',
          },
        ),
        data: Stream.fromIterable([compressedBytes]),
      );
      debugPrint('[SyncService] image upload response: ${uploadResponse.statusCode}');

      final publicUrl =
          '${SupabaseConfig.url}/storage/v1/object/public/scan-images/$filename';
      debugPrint('[SyncService] image uploaded OK: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('[SyncService] image upload failed (scan will be saved without photo): $e');
      return null;
    }
  }

  /// Attempts to sync all pending scans. Safe to call often — it's a no-op
  /// when offline, unconfigured, when there's nothing pending, or when a
  /// sync is already in progress.
  Future<void> trySync() async {
    debugPrint('[SyncService] trySync() called');

    if (!SupabaseConfig.isConfigured) {
      debugPrint('[SyncService] SKIP — SupabaseConfig not configured');
      return;
    }
    if (_syncing) {
      debugPrint('[SyncService] SKIP — sync already in progress');
      return;
    }
    if (!await _isOnline()) {
      debugPrint('[SyncService] SKIP — device is offline');
      return;
    }

    final pending = storage.getUnsyncedScans();
    if (pending.isEmpty) {
      debugPrint('[SyncService] SKIP — no pending scans to sync');
      return;
    }
    debugPrint('[SyncService] found ${pending.length} pending scan(s) to sync');

    _syncing = true;
    _lastError = null;
    _failedCount = 0;
    _syncedCount = 0;
    _totalCount = pending.length;
    notifyListeners();

    // Log farmer profile being sent with each scan
    debugPrint('[SyncService] farmer profile — id: ${settings.farmerId}, '
        'name: ${settings.farmerName}, village: ${settings.village}, '
        'phone: ${settings.phoneNumber}');

    final stopwatch = Stopwatch()..start();

    for (var i = 0; i < pending.length; i++) {
      final scan = pending[i];
      debugPrint('[SyncService] ── scanning ${i + 1}/${pending.length} '
          '(id: ${scan.id}, crop: ${scan.cropSpecies}, '
          'disease: ${scan.diseaseLabel}, confidence: ${scan.confidence})');

      try {
        // Step 1: upload the image (best-effort).
        String? imageUrl;
        final imageFile = File(scan.imagePath);
        if (imageFile.existsSync()) {
          debugPrint('[SyncService] image file exists: ${scan.imagePath} '
              '(${(imageFile.lengthSync() / 1024).toStringAsFixed(0)}KB)');
          imageUrl = await _uploadImage(imageFile, scan.id);
        } else {
          debugPrint('[SyncService] WARNING: image file not found at ${scan.imagePath} — syncing without photo');
        }

        // Step 2: insert the scan row with the image URL.
        final payload = {
          'crop_species': scan.cropSpecies,
          'disease_label': scan.diseaseLabel,
          'confidence': scan.confidence,
          'device_timestamp': scan.timestamp.toIso8601String(),
          'latitude': scan.latitude,
          'longitude': scan.longitude,
          'image_url': imageUrl, // null is fine — column is nullable
          'device_farmer_id': settings.farmerId,
          'farmer_name': settings.farmerName,
          'farmer_village': settings.village,
          'farmer_phone': settings.phoneNumber,
        };
        debugPrint('[SyncService] inserting scan row → $_scansEndpoint');
        debugPrint('[SyncService] payload: $payload');

        final insertResponse = await _dio.post(
          _scansEndpoint,
          options: Options(headers: {
            ..._authHeaders,
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          }),
          data: payload,
        );
        debugPrint('[SyncService] insert response: ${insertResponse.statusCode}');

        await storage.markSynced(scan.id);
        debugPrint('[SyncService] scan ${scan.id} marked as synced ✓');
        _syncedCount++;
        notifyListeners();
      } on DioException catch (e) {
        _failedCount++;
        final statusCode = e.response?.statusCode;
        final body = e.response?.data;
        final uri = e.requestOptions.uri;
        final method = e.requestOptions.method;
        _lastError = 'Upload failed ($statusCode): $body';
        debugPrint('[SyncService] scan ${scan.id} FAILED ✗');
        debugPrint('[SyncService]   method: $method, url: $uri');
        debugPrint('[SyncService]   status: $statusCode');
        debugPrint('[SyncService]   response body: $body');
        debugPrint('[SyncService]   error message: ${e.message}');
        continue;
      } catch (e) {
        _failedCount++;
        _lastError = 'Upload error: $e';
        debugPrint('[SyncService] scan ${scan.id} FAILED ✗ (unexpected)');
        debugPrint('[SyncService]   error: $e');
        continue;
      }
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsedMilliseconds;

    if (_failedCount > 0) {
      debugPrint('[SyncService] ═══ sync batch complete with errors ═══');
      debugPrint('[SyncService]   synced: $_syncedCount, failed: $_failedCount, '
          'total: $_totalCount, time: ${elapsed}ms');
      debugPrint('[SyncService]   last error: $_lastError');
    } else {
      debugPrint('[SyncService] ═══ sync batch complete — ALL GOOD ═══');
      debugPrint('[SyncService]   synced: $_syncedCount, '
          'total: $_totalCount, time: ${elapsed}ms');
    }

    _syncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _dio.close();
    super.dispose();
  }
}
