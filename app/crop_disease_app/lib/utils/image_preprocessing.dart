import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Payload handed to the background isolate: raw image bytes plus the model's
/// input tensor metadata. An [Interpreter] itself is native-bound and can't
/// cross isolates, so we extract the cheap metadata here instead.
class PreprocessRequest {
  final Uint8List rawBytes;
  final int inputSize;

  /// When true, the pixel values are fed to the model untouched: raw uint8
  /// bytes for quantized tensors, raw [0,255] doubles for float32 tensors.
  /// All bundled models normalize pixels inside the exported graph
  /// (MobileNetV2 preprocess_input), so the tensor itself always consumes raw
  /// pixels — never an already-normalized value.
  final bool feedRawPixels;
  final bool isQuantized;
  final bool isInt8;
  final double scale;
  final int zeroPoint;

  const PreprocessRequest({
    required this.rawBytes,
    required this.inputSize,
    required this.feedRawPixels,
    required this.isQuantized,
    required this.isInt8,
    required this.scale,
    required this.zeroPoint,
  });
}

/// Runs on a background isolate: decodes the photo, bakes the EXIF
/// orientation, resizes it to the model's input size and builds the input
/// buffer in the shape/dtype the model expects. The bundled models normalize
/// pixels inside the exported graph (MobileNetV2 preprocess_input), so the
/// tensor input is raw pixels — see [feedRawPixels]. Also computes a cheap
/// "is this even a leaf?" score from the same decoded frame. Returns the
/// [1][inputSize][inputSize][3] buffer tflite_flutter expects plus a 0..1
/// leaf-likeness value.
({List<dynamic> input, double leafLikeness}) preprocessWorker(
    PreprocessRequest request) {
  final decoded = img.decodeImage(request.rawBytes);
  if (decoded == null) {
    throw ArgumentError('Could not decode image (unsupported or corrupt data)');
  }

  // Phone photos carry an EXIF orientation tag that decodeImage does NOT
  // apply — bake it so portrait shots are analyzed upright, not rotated.
  final oriented = img.bakeOrientation(decoded);

  final resized = img.copyResize(
    oriented,
    width: request.inputSize,
    height: request.inputSize,
  );

  final minValue = request.isInt8 ? -128 : 0;
  final maxValue = request.isInt8 ? 127 : 255;

  final input = List.generate(
    1,
    (_) => List.generate(
      request.inputSize,
      (y) => List.generate(
        request.inputSize,
        (x) {
          final pixel = resized.getPixel(x, y);
          if (request.feedRawPixels) {
            // Raw pixels: quantized tensors consume the uint8 byte itself
            // (dequantizing to [0,1] for scale=1/255 or [0,255] for
            // scale=1.0); float32 tensors consume raw [0,255] doubles.
            return request.isQuantized
                ? [pixel.r, pixel.g, pixel.b]
                : [pixel.r.toDouble(), pixel.g.toDouble(), pixel.b.toDouble()];
          }

          // Fallback for quantized exports with a non-trivial scale/zeroPoint:
          // assume the tensor encodes pixel/255 ∈ [0,1] and quantize explicitly.
          final r = (pixel.r / 255.0) / request.scale + request.zeroPoint;
          final g = (pixel.g / 255.0) / request.scale + request.zeroPoint;
          final b = (pixel.b / 255.0) / request.scale + request.zeroPoint;
          return [
            r.round().clamp(minValue, maxValue),
            g.round().clamp(minValue, maxValue),
            b.round().clamp(minValue, maxValue),
          ];
        },
      ),
    ),
  );

  // Cheap "is this even a leaf?" signal computed on the already-decoded,
  // already-resized frame: the fraction of centre pixels where green is the
  // dominant colour channel. Closed-set classifiers must pick one of their
  // classes for ANY input, so without this a photo of a table, wall or hand
  // would be force-fed into the most generic crop class (often maize) with
  // high confidence — see CropPrediction.leafLikenessThreshold.
  final leafLikeness = computeLeafLikeness(resized);

  return (input: input, leafLikeness: leafLikeness);
}

/// Fraction of sampled pixels in the centre of [image] where green beats both
/// red and blue. Relative (not an absolute brightness floor) so dark leaves
/// in shade still count; diseased/brown leaves usually retain some green
/// tissue, while a table, wall, hand or floor has almost none.
double computeLeafLikeness(img.Image image) {
  final w = image.width, h = image.height;
  final x0 = w ~/ 4, x1 = w - w ~/ 4;
  final y0 = h ~/ 4, y1 = h - h ~/ 4;
  var green = 0, total = 0;
  const stride = 4;
  for (var y = y0; y < y1; y += stride) {
    for (var x = x0; x < x1; x += stride) {
      final p = image.getPixel(x, y);
      total++;
      if (p.g > p.r && p.g > p.b) green++;
    }
  }
  return total == 0 ? 0.0 : green / total;
}

/// Shannon entropy (nats) of the softmax output. Uniform over N classes gives
/// ln(N); a peaked prediction gives ~0. Out-of-distribution inputs tend to
/// produce flatter distributions, so a high entropy is a sign the model is
/// guessing rather than recognising a crop.
double softmaxEntropy(List<double> scores) {
  var h = 0.0;
  for (final s in scores) {
    if (s <= 0) continue;
    h -= s * math.log(s);
  }
  // Fail safe: if every score was <= 0 (should never happen with a softmax
  // output, but a broken/empty tensor would give entropy 0 — which reads as
  // "maximally confident"). Report a flat, maximally-uncertain distribution
  // (ln(N) for N classes) instead so the prediction is flagged, not trusted.
  if (h <= 0) return math.log(scores.length);
  return h;
}

/// Reads the input tensor's dtype/quantization metadata and bundles it with
/// the raw image bytes so the heavy decode/resize/buffer work can run on a
/// background isolate (an [Interpreter] can't be sent between isolates).
PreprocessRequest buildPreprocessRequest(
    Uint8List rawBytes, Interpreter interpreter, int inputSize) {
  final inputTensor = interpreter.getInputTensor(0);
  final type = inputTensor.type;
  final isInt8 = type == TensorType.int8;
  final isUint8 = type == TensorType.uint8;
  final isQuantized = isInt8 || isUint8;
  final scale = isQuantized ? inputTensor.params.scale : 1.0;
  final zeroPoint = isQuantized ? inputTensor.params.zeroPoint : 0;

  // All bundled models were trained with MobileNetV2 preprocess_input baked
  // INTO the exported graph, so the tensor input is raw pixels. Every model
  // ships float32 today (verified with tool/probe_thresholds.py), consuming
  // raw [0,255] pixels as trained; the quantized branch is a fallback for a
  // future re-export. For quantized tensors the scale check uses a
  // tolerance: the flatbuffer stores float32 1/255, which never equals the
  // Dart double 1/255 exactly — an exact comparison would silently disable
  // this path and feed a contrast-distorted image instead of raw bytes.
  final scaleIsOne = (scale - 1.0).abs() < 1e-6;
  final scaleIsOneOver255 = (scale - 1.0 / 255.0).abs() < 1e-6;
  final feedRawPixels = !isQuantized ||
      (isUint8 && zeroPoint == 0 && (scaleIsOne || scaleIsOneOver255));

  return PreprocessRequest(
    rawBytes: rawBytes,
    inputSize: inputSize,
    feedRawPixels: feedRawPixels,
    isQuantized: isQuantized,
    isInt8: isInt8,
    scale: scale,
    zeroPoint: zeroPoint,
  );
}
