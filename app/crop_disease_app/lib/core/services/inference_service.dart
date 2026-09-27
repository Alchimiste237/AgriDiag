import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/crop_info.dart';
import '../models/crop_prediction.dart';
import '../models/inference_result.dart';
import '../../utils/image_preprocessing.dart';

/// Helper to log a step with a millisecond timestamp.
void _log(String message) {
  final now = DateTime.now();
  final ts = '${now.minute}:${now.second.remainder(60).toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  debugPrint('[InferenceService $ts] $message');
}

/// Wraps the TFLite models used by the app: an automatic crop classifier
/// (recognizes the crop species from a leaf photo) plus per-crop disease
/// models. The caller calls [loadCropClassifier] once for auto-detection,
/// and [loadCrop] before disease prediction.
/// Extends ChangeNotifier so the UI can react to loading state changes.
class InferenceService extends ChangeNotifier {
  static const int inputSize = 224; // must match IMG_SIZE used at training time

  /// Automatic crop recognition model — identifies the crop species first,
  /// so the user doesn't have to pick one manually.
  static const String cropClassifierModelAsset =
      'assets/models/crop_classifier/crop_classifier.tflite';
  static const String cropClassifierLabelsAsset =
      'assets/models/crop_classifier/crop_labels.txt';

  // --- Crop disease model (per-crop) ---
  Interpreter? _interpreter;
  List<String> _labels = [];
  CropInfo? _currentCrop;
  bool _isLoading = false;

  // --- Automatic crop classifier ---
  Interpreter? _cropClassifier;
  List<String> _cropLabels = [];
  bool _isLoadingCropClassifier = false;
  Future<void>? _cropClassifierLoadFuture; // guards concurrent loads

  CropInfo? get currentCrop => _currentCrop;
  bool get isLoaded => _interpreter != null;
  bool get isLoading => _isLoading;
  bool get isCropClassifierLoaded => _cropClassifier != null;
  bool get isLoadingCropClassifier => _isLoadingCropClassifier;

  /// Loads the automatic crop classifier (idempotent — safe to call on every
  /// scan; it skips straight through once the model is already in memory).
  /// Concurrent calls share a single in-flight load instead of double-loading.
  Future<void> loadCropClassifier() {
    if (_cropClassifier != null) {
      _log('loadCropClassifier: already loaded, skipping');
      return Future.value();
    }
    return _cropClassifierLoadFuture ??= _doLoadCropClassifier();
  }

  Future<void> _doLoadCropClassifier() async {
    _log('=== loadCropClassifier ===');
    _isLoadingCropClassifier = true;
    notifyListeners();

    try {
      _log('Loading crop classifier from asset: $cropClassifierModelAsset');
      final sw = Stopwatch()..start();
      _cropClassifier = await Interpreter.fromAsset(cropClassifierModelAsset);
      sw.stop();
      _log('Crop classifier loaded in ${sw.elapsedMilliseconds}ms');

      _log('Loading labels from asset: $cropClassifierLabelsAsset');
      final labelsText = await rootBundle.loadString(cropClassifierLabelsAsset);
      _cropLabels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      _log('Crop classifier labels loaded: $_cropLabels');
    } catch (e, stack) {
      _log('loadCropClassifier ERROR: $e');
      _log('STACK: $stack');
      _cropClassifier?.close();
      _cropClassifier = null;
      _cropClassifierLoadFuture = null; // allow a later retry
      rethrow;
    } finally {
      _isLoadingCropClassifier = false;
      notifyListeners();
    }
  }

  /// Runs the crop classifier on a captured photo and returns the detected
  /// crop along with its confidence. Throws if the classifier isn't loaded or
  /// can't map the top prediction to a known crop.
  Future<CropPrediction> predictCrop(File imageFile) async {
    if (_cropClassifier == null) {
      _log('predictCrop ERROR: crop classifier is null — loadCropClassifier() was not called');
      throw StateError('InferenceService.loadCropClassifier() must be called before predictCrop().');
    }

    final overall = Stopwatch()..start();
    _log('=== predictCrop() start ===');
    _log('Image: ${imageFile.path}, exists=${imageFile.existsSync()}, size=${imageFile.lengthSync()} bytes');

    // Read bytes
    var sw = Stopwatch()..start();
    final rawBytes = await imageFile.readAsBytes();
    sw.stop();
    _log('readAsBytes: ${sw.elapsedMilliseconds}ms (${rawBytes.length} bytes)');

    // Decode, resize and build the input buffer on a background isolate so the
    // UI thread stays responsive (this used to block it for ~1.2s per scan).
    sw = Stopwatch()..start();
    final preprocessed = await compute(
      preprocessWorker,
      buildPreprocessRequest(rawBytes, _cropClassifier!, inputSize),
    );
    final input = preprocessed.input;
    final leafLikeness = preprocessed.leafLikeness;
    sw.stop();
    _log('decode+resize+input (background isolate): ${sw.elapsedMilliseconds}ms, leafLikeness=${leafLikeness.toStringAsFixed(2)}');

    // Run inference and convert the output to scores. The crop classifier's
    // output tensor is float32 [1,N] softmax probabilities — N = number of
    // classes in crop_labels.txt (4 today, 5 once retrained with the
    // background class from crop_detector.py). The helper passes them through
    // directly; the dequantization path only kicks in if the model is ever
    // re-exported quantized.
    sw = Stopwatch()..start();
    final scores = _runAndGetScores(_cropClassifier!, input);
    sw.stop();
    _log('Inference + scores: ${sw.elapsedMilliseconds}ms');

    // Process scores
    sw = Stopwatch()..start();
    final ranked = List.generate(scores.length, (i) => MapEntry(_cropLabels[i], scores[i]))
      ..sort((a, b) => b.value.compareTo(a.value));
    sw.stop();
    _log('Score processing: ${sw.elapsedMilliseconds}ms');

    final entropy = softmaxEntropy(scores);

    overall.stop();
    _log('=== predictCrop() END — total ${overall.elapsedMilliseconds}ms ===');
    _log('Top crop: ${ranked.first.key} (${(ranked.first.value * 100).toStringAsFixed(1)}%)');
    _log('Top 3: ${ranked.take(3).map((e) => '${e.key}=${(e.value * 100).toStringAsFixed(1)}%').join(', ')}');
    _log('leafLikeness=${leafLikeness.toStringAsFixed(2)}, entropy=${entropy.toStringAsFixed(2)}');

    final topLabel = ranked.first.key;
    final isBackground =
        topLabel.toLowerCase() == CropPrediction.backgroundLabel;

    // Resolve the CropInfo to display. For a background prediction there is
    // no CropInfo for "not a crop", so fall back to the best-supported real
    // crop — it is only used to pre-select something in the confirm sheet IF
    // the user chooses to "continue anyway" past the retake prompt in the
    // capture flow.
    CropInfo? crop;
    double confidence;
    if (isBackground) {
      CropInfo? fallback;
      for (final entry in ranked.skip(1)) {
        final c = CropInfo.fromName(entry.key);
        if (c != null) {
          fallback = c;
          break;
        }
      }
      final fallbackCrop = fallback ?? CropInfo.all.first;
      confidence = ranked
          .firstWhere((e) => e.key.toLowerCase() == fallbackCrop.name.toLowerCase())
          .value;
      _log('Background (not-a-crop) predicted — fallback crop for '
          'continue-anyway: ${fallbackCrop.name} at '
          '${(confidence * 100).toStringAsFixed(1)}%');
      crop = fallbackCrop;
    } else {
      crop = CropInfo.fromName(topLabel);
      if (crop == null) {
        throw StateError('Crop classifier returned unknown label: $topLabel');
      }
      confidence = ranked.first.value;
    }
    return CropPrediction(
      crop: crop,
      confidence: confidence,
      topPredictions: ranked.take(3).toList(),
      leafLikeness: leafLikeness,
      entropy: entropy,
      isBackground: isBackground,
    );
  }

  /// Load (or switch to) a different crop's disease model. Closes any previously
  /// loaded model first so memory stays bounded.
  Future<void> loadCrop(CropInfo crop) async {
    if (_currentCrop?.name == crop.name && _interpreter != null) {
      _log('loadCrop: ${crop.name} already loaded, skipping');
      return;
    }

    _log('=== loadCrop: ${crop.name} ===');
    _isLoading = true;
    notifyListeners();

    _interpreter?.close();
    _interpreter = null;
    _labels = [];
    _currentCrop = null;

    try {
      _log('Loading model from asset: ${crop.modelAsset}');
      final sw = Stopwatch()..start();
      _interpreter = await Interpreter.fromAsset(crop.modelAsset);
      sw.stop();
      _log('Model loaded in ${sw.elapsedMilliseconds}ms');

      _log('Loading labels from asset: ${crop.labelsAsset}');
      final sw2 = Stopwatch()..start();
      final labelsText = await rootBundle.loadString(crop.labelsAsset);
      _labels = labelsText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      sw2.stop();
      _log('Labels loaded in ${sw2.elapsedMilliseconds}ms: $_labels');

      _currentCrop = crop;
      _log('loadCrop: ${crop.name} completed successfully');
    } catch (e, stack) {
      _log('loadCrop ERROR: $e');
      _log('STACK: $stack');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unload the current crop model and free its memory.
  void unload() {
    _log('unload: discarding ${_currentCrop?.name ?? 'unknown'} model');
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
    _currentCrop = null;
    notifyListeners();
  }

  /// Runs inference on a captured photo and returns the top prediction
  /// plus the full ranked list (useful for "did you mean X?" fallback UI).
  Future<InferenceResult> predict(File imageFile) async {
    if (_interpreter == null) {
      _log('predict ERROR: interpreter is null — loadCrop() was not called');
      throw StateError('InferenceService.loadCrop() must be called before predict().');
    }

    final overall = Stopwatch()..start();
    _log('=== predict() start ===');
    _log('Image: ${imageFile.path}, exists=${imageFile.existsSync()}, size=${imageFile.lengthSync()} bytes');

    // Read bytes
    var sw = Stopwatch()..start();
    final rawBytes = await imageFile.readAsBytes();
    sw.stop();
    _log('readAsBytes: ${sw.elapsedMilliseconds}ms (${rawBytes.length} bytes)');

    // Decode, resize and build the input buffer on a background isolate so the
    // UI thread stays responsive (this used to block it for ~1.2s per scan).
    sw = Stopwatch()..start();
    final preprocessed = await compute(
      preprocessWorker,
      buildPreprocessRequest(rawBytes, _interpreter!, inputSize),
    );
    final input = preprocessed.input;
    sw.stop();
    _log('decode+resize+input (background isolate): ${sw.elapsedMilliseconds}ms');

    // Run inference and convert the output to scores. All bundled models
    // output float32 softmax probabilities (verified with
    // tool/probe_thresholds.py), but the helper also dequantizes quantized
    // uint8/int8 outputs so a re-exported model keeps working.
    sw = Stopwatch()..start();
    final scores = _runAndGetScores(_interpreter!, input);
    sw.stop();
    _log('Inference + scores: ${sw.elapsedMilliseconds}ms');

    // Process scores
    sw = Stopwatch()..start();
    final ranked = List.generate(scores.length, (i) => MapEntry(_labels[i], scores[i]))
      ..sort((a, b) => b.value.compareTo(a.value));
    sw.stop();
    _log('Score processing: ${sw.elapsedMilliseconds}ms');

    overall.stop();
    _log('=== predict() END — total ${overall.elapsedMilliseconds}ms ===');
    _log('Top: ${ranked.first.key} (${(ranked.first.value * 100).toStringAsFixed(1)}%)');
    _log('Top 3: ${ranked.take(3).map((e) => '${e.key}=${(e.value * 100).toStringAsFixed(1)}%').join(', ')}');

    return InferenceResult(
      label: ranked.first.key,
      confidence: ranked.first.value,
      topPredictions: ranked.take(3).toList(),
    );
  }

  /// Runs [interpreter] on [input] and returns the dequantized scores from its
  /// first output tensor. Quantized uint8/int8 outputs are copied back by
  /// tflite_flutter as raw bytes (ints), so they're read into an int buffer
  /// and dequantized with real = (q - zeroPoint) * scale; float outputs pass
  /// through as plain doubles. All bundled models are float32 today, but this
  /// keeps them working if they're ever re-exported quantized.
  List<double> _runAndGetScores(Interpreter interpreter, List<dynamic> input) {
    final outputTensor = interpreter.getOutputTensor(0);
    final numClasses = outputTensor.shape.last;
    final outputType = outputTensor.type;
    final isQuantizedOutput =
        outputType == TensorType.uint8 || outputType == TensorType.int8;
    _log('  Output tensor: ${outputTensor.shape}, type=$outputType,'
        ' isQuantized=$isQuantizedOutput, numClasses=$numClasses');

    final output = isQuantizedOutput
        ? List<int>.filled(numClasses, 0).reshape([1, numClasses])
        : List.filled(numClasses, 0.0).reshape([1, numClasses]);

    final sw = Stopwatch()..start();
    interpreter.run(input, output);
    sw.stop();
    _log('  run(): ${sw.elapsedMilliseconds}ms');

    if (isQuantizedOutput) {
      final q = output[0] as List<int>;
      final s = outputTensor.params.scale;
      final z = outputTensor.params.zeroPoint;
      return q.map((v) => (v - z) * s).toList();
    }
    return List<double>.from(output[0]);
  }

  @override
  void dispose() {
    _log('dispose called');
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
    _currentCrop = null;
    _cropClassifier?.close();
    _cropClassifier = null;
    _cropLabels = [];
    _cropClassifierLoadFuture = null;
    super.dispose();
  }
}
