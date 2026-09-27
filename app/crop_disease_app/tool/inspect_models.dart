// tool/inspect_models.dart
//
// Pure-Dart TFLite flatbuffer inspector. Dumps the input/output tensor type,
// shape and quantization parameters for every bundled .tflite model without
// needing the tflite_flutter plugin (which only works inside a running app).
//
// Run from the project root:
//   dart run tool/inspect_models.dart
//
// This is useful for verifying the input-buffer logic in
// lib/inference_service.dart (e.g. which models expect raw uint8 pixels vs
// float [-1, 1] vs quantized int8).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// TensorType enum from the TFLite schema (schema.fbs).
const Map<int, String> tensorTypeNames = {
  0: 'FLOAT32',
  1: 'FLOAT16',
  2: 'INT32',
  3: 'UINT8',
  4: 'INT64',
  5: 'STRING',
  6: 'BOOL',
  7: 'INT16',
  8: 'COMPLEX64',
  9: 'INT8',
  10: 'FLOAT64',
  11: 'COMPLEX128',
  12: 'UINT64',
  13: 'RESOURCE',
  14: 'VARIANT',
  15: 'UINT32',
  16: 'UINT16',
};

/// Minimal flatbuffer reader for the subset of the TFLite schema we need.
class FlatBuffer {
  final ByteData data;
  FlatBuffer(this.data);

  int get _base => data.offsetInBytes;

  int _u32(int off) => data.getUint32(off, Endian.little);
  int _u16(int off) => data.getUint16(off, Endian.little);
  int _i32(int off) => data.getInt32(off, Endian.little);
  int _i64(int off) => data.getInt64(off, Endian.little);
  double _f32(int off) => data.getFloat32(off, Endian.little);

  /// Absolute offset of [fieldIndex]'s value inside the table at [tablePos],
  /// or null when the field is absent.
  int? tableField(int tablePos, int fieldIndex) {
    // The vtable offset must be read as a *signed* int32. These exports keep
    // the (deduplicated) vtables at the end of the file, sometimes ~466KB away
    // from the tables, so a 16-bit read truncates the offset and resolves to
    // garbage for any table whose vtable sits beyond +-32KB. int16 reads
    // happen to work for the other tensors only because their vtables are
    // near; int32 handles every case.
    final vtableOffset = data.getInt32(tablePos, Endian.little);
    final vtablePos = tablePos - vtableOffset;
    final vtableSize = _u16(vtablePos);
    final entry = vtablePos + 4 + 2 * fieldIndex;
    if (entry + 2 > vtablePos + vtableSize) return null;
    final fieldOffset = _u16(entry);
    if (fieldOffset == 0) return null;
    return tablePos + fieldOffset;
  }

  /// Offset of the first element of the vector pointed at by [fieldPos].
  int vectorStart(int fieldPos) => fieldPos + _u32(fieldPos);

  int vectorLength(int vecPos) => _u32(vecPos);

  /// Offset of element [index] inside a vector of 4-byte uoffsets.
  int elementPos(int vecPos, int index) => vecPos + 4 + index * 4;

  /// Resolves the table an element uoffset points at.
  int resolveTable(int elemPos) => elemPos + _u32(elemPos);

  /// Throws if a vector with [len] elements of [elemSize] bytes starting at
  /// [start] would run past the end of the buffer (a sign of a corrupt/foreign
  /// table, not a real 2-billion-element vector).
  void _ensureVectorFits(int start, int len, int elemSize) {
    if (start < 0 || len < 0 || start + 4 + len * elemSize > data.lengthInBytes) {
      throw const FormatException('Vector out of bounds');
    }
  }

  String? readString(int fieldPos) {
    final pos = fieldPos + _u32(fieldPos);
    final len = _u32(pos);
    _ensureVectorFits(pos + 4, len, 1);
    final bytes = data.buffer.asUint8List(_base + pos + 4, len);
    return utf8.decode(bytes, allowMalformed: true);
  }

  List<int> readInt32Vector(int fieldPos) {
    final start = vectorStart(fieldPos);
    final len = vectorLength(start);
    _ensureVectorFits(start, len, 4);
    return List.generate(len, (i) => _i32(start + 4 + i * 4));
  }

  List<double> readFloat32Vector(int fieldPos) {
    final start = vectorStart(fieldPos);
    final len = vectorLength(start);
    _ensureVectorFits(start, len, 4);
    return List.generate(len, (i) => _f32(start + 4 + i * 4));
  }

  List<int> readInt64Vector(int fieldPos) {
    final start = vectorStart(fieldPos);
    final len = vectorLength(start);
    _ensureVectorFits(start, len, 8);
    return List.generate(len, (i) => _i64(start + 4 + i * 8));
  }
}

class TensorInfo {
  final int index;
  final String? name;
  final int type;
  final List<int> shape;
  final List<double> scale;
  final List<int> zeroPoint;
  final int bufferIndex;
  final int bufferBytes;

  TensorInfo({
    required this.index,
    required this.name,
    required this.type,
    required this.shape,
    required this.scale,
    required this.zeroPoint,
    required this.bufferIndex,
    required this.bufferBytes,
  });

  /// UINT8 tensors are consumed as raw pixel bytes (0-255): every common
  /// leaf-classifier export (scale=1.0/zp=0 or scale=1/255/zp=0) reduces to
  /// q = raw pixel. See lib/inference_service.dart.
  bool get isRawUint8Pixels => type == 3; // UINT8

  String describe() {
    final typeName = tensorTypeNames[type] ?? 'UNKNOWN($type)';
    final quant = scale.isEmpty
        ? ''
        : ' scale=[${scale.map((s) => _fmtDouble(s)).join(', ')}]'
            ' zero_point=[${zeroPoint.join(', ')}]';
    final shapeStr =
        shape.isEmpty ? '?' : '[${shape.join(', ')}]';
    final sizeStr = bufferBytes < 0 ? 'n/a' : '$bufferBytes bytes';
    return '[${index.toString().padLeft(2)}] ${name ?? '<unnamed>'.padRight(12)}'
        ' $typeName shape=$shapeStr$quant buffer[$bufferIndex]'
        ' $sizeStr';
  }

  static String _fmtDouble(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

class ModelInfo {
  final int version;
  final int numSubgraphs;
  final int numBuffers;
  final List<TensorInfo> tensors;
  final List<int> inputs;
  final List<int> outputs;
  final String? subgraphName;

  ModelInfo({
    required this.version,
    required this.numSubgraphs,
    required this.numBuffers,
    required this.tensors,
    required this.inputs,
    required this.outputs,
    required this.subgraphName,
  });
}

ModelInfo parseModel(Uint8List bytes) {
  final fb = FlatBuffer(ByteData.sublistView(bytes));

  // Root table: the Model at the offset stored in the first 4 bytes.
  final modelPos = fb._u32(0);

  final version = fb.tableField(modelPos, 0) == null
      ? 0
      : fb._u32(fb.tableField(modelPos, 0)!);
  final numBuffers = fb.tableField(modelPos, 4) == null
      ? 0
      : fb.vectorLength(fb.vectorStart(fb.tableField(modelPos, 4)!));

  // Subgraphs (Model field 2) — assume the first subgraph holds the tensors.
  final subgraphsField = fb.tableField(modelPos, 2);
  if (subgraphsField == null) {
    throw const FormatException('Model has no subgraphs');
  }
  final subgraphsVec = fb.vectorStart(subgraphsField);
  final numSubgraphs = fb.vectorLength(subgraphsVec);
  if (numSubgraphs == 0) {
    throw const FormatException('Model has an empty subgraph list');
  }
  final subgraphPos = fb.resolveTable(fb.elementPos(subgraphsVec, 0));

  // Tensors (Subgraph field 0).
  final tensorsField = fb.tableField(subgraphPos, 0);
  final tensorsVec = tensorsField == null ? null : fb.vectorStart(tensorsField);
  final numTensors = tensorsVec == null ? 0 : fb.vectorLength(tensorsVec);

  // Buffer sizes (Model field 4 -> Buffer.data, Buffer field 0). Best-effort:
  // some exporters rewrite the Buffer tables in a way this walk can't follow,
  // so a failed lookup is recorded as -1 and printed as "n/a".
  final bufferSizes = <int>[];
  if (fb.tableField(modelPos, 4) != null) {
    final buffersVec = fb.vectorStart(fb.tableField(modelPos, 4)!);
    final numBuffersEntries = fb.vectorLength(buffersVec);
    for (var i = 0; i < numBuffersEntries; i++) {
      var size = -1;
      try {
        final bufferPos = fb.resolveTable(fb.elementPos(buffersVec, i));
        final dataField = fb.tableField(bufferPos, 0);
        if (dataField != null) {
          size = fb.vectorLength(fb.vectorStart(dataField));
        }
      } catch (_) {
        size = -1;
      }
      bufferSizes.add(size);
    }
  }

  final tensors = <TensorInfo>[];
  for (var i = 0; i < numTensors; i++) {
    try {
      tensors.add(_parseTensor(fb, tensorsVec!, i, bufferSizes));
    } catch (e) {
      // Some tensors in these exports have tables this walk can't follow;
      // keep the rest of the report instead of failing the whole model.
      tensors.add(TensorInfo(
        index: i,
        name: '<unreadable: $e>',
        type: -1,
        shape: const [],
        scale: const [],
        zeroPoint: const [],
        bufferIndex: -1,
        bufferBytes: -1,
      ));
    }
  }

  // inputs (Subgraph field 1), outputs (Subgraph field 2).
  final inputsField = fb.tableField(subgraphPos, 1);
  final outputsField = fb.tableField(subgraphPos, 2);
  final inputs = inputsField == null ? const <int>[] : fb.readInt32Vector(inputsField);
  final outputs = outputsField == null ? const <int>[] : fb.readInt32Vector(outputsField);

  final nameField = fb.tableField(subgraphPos, 4);
  final subgraphName = nameField == null ? null : fb.readString(nameField);

  return ModelInfo(
    version: version,
    numSubgraphs: numSubgraphs,
    numBuffers: numBuffers,
    tensors: tensors,
    inputs: inputs,
    outputs: outputs,
    subgraphName: subgraphName,
  );
}

/// Parses one Tensor table. Field 1 (type) is optional — when absent the
/// runtime falls back to the schema default FLOAT32 (0), which these models
/// rely on. Throws if the table can't be walked.
TensorInfo _parseTensor(
    FlatBuffer fb, int tensorsVec, int index, List<int> bufferSizes) {
  final tensorPos = fb.resolveTable(fb.elementPos(tensorsVec, index));

  // shape (field 0); fall back to shape_signature (field 7) for dynamic shapes.
  List<int> shape = const [];
  final shapeField = fb.tableField(tensorPos, 0);
  if (shapeField != null) {
    shape = fb.readInt32Vector(shapeField);
  } else {
    final signatureField = fb.tableField(tensorPos, 7);
    if (signatureField != null) {
      shape = fb.readInt32Vector(signatureField);
    }
  }

  // type (field 1) — a single enum byte.
  final typeField = fb.tableField(tensorPos, 1);
  final type = typeField == null ? 0 : fb.data.getInt8(typeField);

  // buffer index (field 2) — uint32.
  final bufferField = fb.tableField(tensorPos, 2);
  final bufferIndex = bufferField == null ? -1 : fb._u32(bufferField);

  // name (field 3).
  final nameField = fb.tableField(tensorPos, 3);
  final name = nameField == null ? null : fb.readString(nameField);

  // quantization (field 4) -> scale (field 2), zero_point (field 3).
  List<double> scale = const [];
  List<int> zeroPoint = const [];
  final quantField = fb.tableField(tensorPos, 4);
  if (quantField != null) {
    final quantPos = fb.resolveTable(quantField);
    final scaleField = fb.tableField(quantPos, 2);
    if (scaleField != null) scale = fb.readFloat32Vector(scaleField);
    final zpField = fb.tableField(quantPos, 3);
    if (zpField != null) zeroPoint = fb.readInt64Vector(zpField);
  }

  return TensorInfo(
    index: index,
    name: name,
    type: type,
    shape: shape,
    scale: scale,
    zeroPoint: zeroPoint,
    bufferIndex: bufferIndex,
    bufferBytes: bufferIndex >= 0 && bufferIndex < bufferSizes.length
        ? bufferSizes[bufferIndex]
        : -1,
  );
}

String inputKind(TensorInfo t) {
  if (t.isRawUint8Pixels) {
    return 'raw uint8 pixels (0-255) — normalization baked into graph';
  }
  if (t.type == 0) return 'float [-1, 1]';
  if (t.type == 9) return 'quantized int8: [-1, 1] -> [-128, 127]';
  return 'unhandled dtype — check input-buffer logic';
}

void main() {
  final modelsDir = Directory('assets/models');
  if (!modelsDir.existsSync()) {
    stderr.writeln('No assets/models directory — run from the project root.');
    exit(1);
  }

  final tfliteFiles = modelsDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.tflite'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (tfliteFiles.isEmpty) {
    stderr.writeln('No .tflite models found under assets/models.');
    exit(1);
  }

  final rawPixelInputs = <String>[];
  final otherInputs = <String>[];

  for (final file in tfliteFiles) {
    print('=== ${file.path} (${file.lengthSync()} bytes) ===');
    try {
      final model = parseModel(file.readAsBytesSync());
      print('  version: ${model.version}, subgraphs: ${model.numSubgraphs},'
          ' buffers: ${model.numBuffers}');
      print('  subgraph: ${model.subgraphName ?? '<unnamed>'}');

      for (final idx in model.inputs) {
        final t = model.tensors[idx];
        final kind = inputKind(t);
        print('  INPUT   ${t.describe()}');
        print('          -> $kind');
        if (t.isRawUint8Pixels) {
          rawPixelInputs.add('${file.path} [${t.name ?? 'tensor $idx'}]');
        } else {
          otherInputs.add('${file.path} [${t.name ?? 'tensor $idx'}] ($kind)');
        }
      }
      for (final idx in model.outputs) {
        print('  OUTPUT  ${model.tensors[idx].describe()}');
      }
    } catch (e, st) {
      print('  PARSE ERROR: $e');
      print('  $st');
    }
    print('');
  }

  print('--- Summary ---');
  print('Expects raw uint8 pixel bytes (0-255):');
  if (rawPixelInputs.isEmpty) {
    print('  (none)');
  } else {
    for (final s in rawPixelInputs) {
      print('  - $s');
    }
  }
  print('Everything else:');
  if (otherInputs.isEmpty) {
    print('  (none)');
  } else {
    for (final s in otherInputs) {
      print('  - $s');
    }
  }
}
