import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Painted plant illustration behind the onboarding hero — emulates the
/// photographic foliage of the design (a leafy plant over a soft, blurred
/// field) without bundling an image asset. Must be placed inside a [Stack],
/// wrapped with [Positioned.fill]:
///
/// ```dart
/// Stack(children: [
///   const FoliageBackdrop(), // self-positions via Positioned.fill
///   ...
/// ])
/// ```
class FoliageBackdrop extends StatelessWidget {
  const FoliageBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(painter: _FoliagePainter()),
    );
  }
}

class _FoliagePainter extends CustomPainter {
  const _FoliagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _paintBokehField(canvas, w, h);
    _paintPlant(canvas, w, h);
  }

  /// Soft out-of-focus field: light blobs + big blurred distant leaves.
  void _paintBokehField(Canvas canvas, double w, double h) {
    void blob(double x, double y, double r, double alpha) {
      canvas.drawCircle(
        Offset(w * x, h * y),
        w * r,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }

    blob(0.16, 0.09, 0.17, 0.055);
    blob(0.86, 0.15, 0.13, 0.050);
    blob(0.70, 0.04, 0.10, 0.040);
    blob(0.07, 0.26, 0.11, 0.035);
    blob(0.94, 0.05, 0.08, 0.045);

    _softLeaf(canvas, Offset(w * 0.10, h * 0.22), w * 0.30, -0.9,
        Colors.white.withValues(alpha: 0.05));
    _softLeaf(canvas, Offset(w * 0.92, h * 0.32), w * 0.36, 2.35,
        Colors.white.withValues(alpha: 0.045));
    _softLeaf(canvas, Offset(w * 0.84, h * 0.07), w * 0.24, 0.55,
        Colors.white.withValues(alpha: 0.04));
    _softLeaf(canvas, Offset(w * 0.06, h * 0.06), w * 0.22, -2.4,
        Colors.white.withValues(alpha: 0.035));
  }

  /// The central plant: stem + layered leaves, back-to-front.
  void _paintPlant(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final baseY = h * 0.50;
    final topY = h * 0.12;

    // Ground shadow under the plant.
    final ground = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, baseY + h * 0.004),
        width: w * 0.42,
        height: h * 0.028,
      ),
      ground,
    );

    // Stem — gentle S-curve.
    canvas.drawPath(
      Path()
        ..moveTo(cx + w * 0.004, baseY)
        ..quadraticBezierTo(cx - w * 0.025, h * 0.33, cx, topY),
      Paint()
        ..color = const Color(0xFF2A6146)
        ..strokeWidth = w * 0.013
        ..strokeCap = StrokeCap.round,
    );

    // Back layer (darkest, behind the stem glow).
    _leaf(canvas, cx, h * 0.42, w * 0.27, -2.60, const Color(0xFF1D4E37), w);
    _leaf(canvas, cx, h * 0.35, w * 0.25, -0.52, const Color(0xFF1A4733), w);
    _leaf(canvas, cx, h * 0.47, w * 0.17, -3.02, const Color(0xFF1F5239), w);
    _leaf(canvas, cx, h * 0.47, w * 0.17, -0.12, const Color(0xFF1F5239), w);

    // Mid layer.
    _leaf(canvas, cx, h * 0.44, w * 0.31, -2.82, const Color(0xFF33815A), w);
    _leaf(canvas, cx, h * 0.38, w * 0.29, -0.30, const Color(0xFF2E7653), w);
    _leaf(canvas, cx, h * 0.30, w * 0.24, -2.72, const Color(0xFF3B9066), w);

    // Top layer (brightest — catches the light).
    _leaf(canvas, cx, h * 0.21, w * 0.23, -1.92, const Color(0xFF4DA271), w);
    _leaf(canvas, cx, h * 0.155, w * 0.20, -1.28, const Color(0xFF58AE7C), w);
  }

  /// One leaf: filled teardrop with a highlight vein and a soft drop shadow.
  /// [angle] in radians — 0 points right, negative rotates upward.
  void _leaf(
    Canvas canvas,
    double ox,
    double oy,
    double len,
    double angle,
    Color color,
    double w,
  ) {
    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(angle);

    final belly = len * 0.30;
    final leafPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(len * 0.5, -belly, len, 0)
      ..quadraticBezierTo(len * 0.5, belly, 0, 0)
      ..close();

    // Drop shadow.
    canvas.save();
    canvas.translate(0, w * 0.014);
    canvas.drawPath(
      leafPath,
      Paint()..color = Colors.black.withValues(alpha: 0.14),
    );
    canvas.restore();

    canvas.drawPath(leafPath, Paint()..color = color);

    // Highlight vein.
    canvas.drawLine(
      Offset(len * 0.08, 0),
      Offset(len * 0.92, 0),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22)
        ..strokeWidth = math.max(1.4, w * 0.005)
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  /// Big blurred background leaf (out-of-focus depth), fill only.
  void _softLeaf(
    Canvas canvas,
    Offset origin,
    double len,
    double angle,
    Color color,
  ) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(angle);
    final belly = len * 0.32;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * 0.5, -belly, len, 0)
        ..quadraticBezierTo(len * 0.5, belly, 0, 0)
        ..close(),
      Paint()..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FoliagePainter oldDelegate) => false;
}
