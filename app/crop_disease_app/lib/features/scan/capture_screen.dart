import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_theme.dart';
import '../../core/services/inference_service.dart';
import '../../core/services/location_service.dart';
import '../result/result_screen.dart';
import '../../l10n/app_strings.dart';

/// Helper to log a step with a millisecond timestamp.
void _log(String message) {
  final now = DateTime.now();
  final ts = '${now.minute}:${now.second.remainder(60).toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[CaptureScreen $ts] $message');
}

/// Camera capture screen — manual capture only.
///
/// The user frames a leaf inside the guide and taps the big capture button.
/// The app auto-detects the crop species and rejects non-crop photos
/// (objects, non-plant surfaces) without asking the user to confirm.
/// GPS position is captured in the background in parallel with the scan and
/// is mandatory: the scan is blocked until a valid position is obtained.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isProcessing = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _log('initState called');
    _initCamera();
  }

  Future<void> _initCamera() async {
    _log('_initCamera: fetching available cameras...');
    final cameras = await availableCameras();
    _log('_initCamera: found ${cameras.length} camera(s)');
    if (cameras.isEmpty) {
      _log('_initCamera: NO CAMERAS FOUND');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found on this device.')),
        );
      }
      return;
    }

    final backCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    _log('_initCamera: selected ${backCamera.name} (${backCamera.lensDirection.name})');

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _log('_initCamera: CameraController created, calling initialize()...');
    _initFuture = _controller!.initialize();
    if (mounted) setState(() {});
    await _initFuture;
    _log('_initCamera: CameraController initialized successfully');
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null || !_controller!.value.isInitialized || _isProcessing) {
      _log('_captureAndAnalyze: BLOCKED (controller=${_controller != null}, '
          'initialized=${_controller?.value.isInitialized}, processing=$_isProcessing)');
      return;
    }

    final strings = AppStrings.of(context);
    _log('=== CAPTURE START ===');

    setState(() {
      _isProcessing = true;
      _statusMessage = strings.takingPhoto;
    });

    final inferenceService = context.read<InferenceService>();

    // Kick off GPS capture in parallel (it can take a few seconds outdoors).
    final locationFuture = LocationService.capture();

    try {
      _log('Setting focus mode to auto...');
      await _controller!.setFocusMode(FocusMode.auto);
      _log('Setting exposure mode to auto...');
      await _controller!.setExposureMode(ExposureMode.auto);
      _log('Waiting 300ms for auto-focus to lock...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 1: take the photo with a timeout
      _log('Calling takePicture()...');
      final photo = await _controller!
          .takePicture()
          .timeout(const Duration(seconds: 15));
      _log('takePicture() completed, path=${photo.path}, size=${File(photo.path).lengthSync()} bytes');

      final imageFile = File(photo.path);

      if (!mounted) return;
      setState(() => _statusMessage = strings.detectingCrop);

      // Step 2: automatically recognize the crop species.
      _log('Ensuring crop classifier is loaded...');
      await inferenceService
          .loadCropClassifier()
          .timeout(const Duration(seconds: 30));
      _log('Calling predictCrop()...');
      final stopwatch = Stopwatch()..start();
      final prediction = await inferenceService
          .predictCrop(imageFile)
          .timeout(const Duration(seconds: 30));
      stopwatch.stop();
      _log('predictCrop() completed in ${stopwatch.elapsedMilliseconds}ms → '
          '${prediction.crop.name} (${(prediction.confidence * 100).toStringAsFixed(1)}%)');

      if (!mounted) return;

      // Step 2b: reject non-crop photos automatically — no confirmation.
      // The model's own background class and the leaf-likeness check work
      // together to catch objects, surfaces, and non-plant material.
      if (!prediction.isLeafLike || prediction.isBackground) {
        _log('Photo rejected — not a crop leaf '
            '(leafLikeness=${prediction.leafLikeness.toStringAsFixed(2)}, '
            'isBackground=${prediction.isBackground})');
        _showRejectSnackBar(strings, prediction.isBackground);
        return;
      }

      // Step 2c: if the crop classifier is very uncertain, show a brief
      // warning but proceed — the disease model may still give a useful
      // result, and the low-confidence banner on the result screen will
      // alert the user.
      if (prediction.isUncertain) {
        _log('Crop detection uncertain — showing warning, proceeding anyway');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.uncertainCropWarning(prediction.crop.displayName)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      final detectedCrop = prediction.crop;
      setState(() => _statusMessage = strings.loadingModel(detectedCrop.displayName));

      // Step 3: load the matching per-crop disease model
      _log('Calling loadCrop(${detectedCrop.name})...');
      await inferenceService
          .loadCrop(detectedCrop)
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      setState(() => _statusMessage = strings.analyzingLeaf);

      // Step 4: run the disease inference
      _log('Calling predict()...');
      final result = await inferenceService
          .predict(imageFile)
          .timeout(const Duration(seconds: 30));
      _log('Result: label=${result.label}, confidence=${result.confidence.toStringAsFixed(3)}');

      // GPS (started in parallel) should be ready by now; wait briefly.
      // GPS is mandatory — without a fix the scan is blocked and the user
      // is told what to enable, so the result is never saved without
      // coordinates.
      final ({double latitude, double longitude}) location;
      try {
        location = await locationFuture;
      } on LocationException catch (e) {
        _log('GPS FAILED: ${e.failure}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_locationErrorString(strings, e.failure)),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      _log('Navigating to ResultScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            crop: detectedCrop,
            cropConfidence: prediction.confidence,
            imageFile: imageFile,
            result: result,
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        ),
      );
    } on TimeoutException catch (_) {
      _log('TIMEOUT: The operation took too long');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.timeoutAnalyzing)),
      );
    } catch (e, stack) {
      _log('ERROR: $e');
      _log('STACK: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.analyzeError(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
      _log('=== CAPTURE END ===');
    }
  }

  /// Maps a GPS failure to the user-facing message explaining how to fix it.
  String _locationErrorString(AppStrings strings, LocationFailure failure) {
    switch (failure) {
      case LocationFailure.permissionDenied:
      case LocationFailure.permissionDeniedForever:
        return strings.locationPermissionRequired;
      case LocationFailure.serviceDisabled:
        return strings.locationRequired;
      case LocationFailure.noFix:
      case LocationFailure.unavailable:
        return strings.locationNoFix;
    }
  }

  /// Shows a snackbar explaining the photo was rejected.
  void _showRejectSnackBar(AppStrings strings, bool isBackground) {
    final msg = isBackground ? strings.notCropRejected : strings.notLeafRejected;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: strings.retakePhoto,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _log('dispose called');
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: AppColors.deepGreenDark,
      body: Column(
        children: [
          // Flat header: back arrow + title side by side on the plain dark
          // background — no boxed/rounded container around them.
          SafeArea(
            bottom: false,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      strings.scanPageTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Camera area with corner-bracket viewfinder + instruction pill.
          Expanded(
            child: _initFuture == null
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : FutureBuilder<void>(
                    future: _initFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                            child: CircularProgressIndicator(color: Colors.white));
                      }
                      if (snapshot.hasError) {
                        _log('Camera init error: ${snapshot.error}');
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Camera error: ${snapshot.error}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      }
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),

                          // Corner-bracket viewfinder (design).
                          Center(
                            child: CustomPaint(
                              painter: const CornerFramePainter(
                                color: Colors.white,
                                strokeWidth: 3.5,
                                cornerLength: 40,
                                radius: 16,
                              ),
                              child: Container(
                                width: 300,
                                height: 300,
                                margin: const EdgeInsets.all(8),
                              ),
                            ),
                          ),

                          // Instruction pill below the frame (design).
                          Positioned(
                            bottom: 18,
                            left: 40,
                            right: 40,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                strings.placeLeafWellLit,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),

                          // Processing overlay while analyzing.
                          if (_isProcessing)
                            Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                        color: AppColors.green),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _statusMessage,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),

          // Control bar: just the centered shutter.
          Container(
            color: AppColors.deepGreenDark,
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shutter
                  GestureDetector(
                    onTap: _isProcessing ? null : _captureAndAnalyze,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: AppColors.green,
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.35),
                            blurRadius: 14,
                          ),
                        ],
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
