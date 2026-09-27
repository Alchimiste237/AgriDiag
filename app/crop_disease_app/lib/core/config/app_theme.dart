import 'package:flutter/material.dart';

/// Design-system for the new AgroDiag look (see newDesign.png).
///
/// Palette:
/// - Deep forest green (onboarding bg, capture header, primary buttons)
/// - Vivid green (accents, active tab, progress)
/// - Off-white canvas
/// - Dark ink text
abstract final class AppColors {
  // Brand greens
  static const Color deepGreen = Color(0xFF0E3B2E); // dark forest green
  static const Color deepGreenDark = Color(0xFF0A2C23); // darker stop
  static const Color deepGreenLight = Color(0xFF155040); // lighter stop
  static const Color green = Color(0xFF2EBD59); // vivid action green
  static const Color greenDark = Color(0xFF24A04A); // pressed/gradient stop
  static const Color greenSoft = Color(0xFFE6F4EA); // soft green chip bg

  // Canvas / surfaces
  static const Color canvas = Color(0xFFF4F6F4); // off-white scaffold bg
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF1B2B24); // near-black green ink
  static const Color inkSoft = Color(0xFF5B6B63); // secondary text
  static const Color inkFaint = Color(0xFF8FA098); // tertiary text / hints
  static const Color hairline = Color(0xFFE3E9E4); // dividers, card borders

  // Severity / status
  static const Color severityHighBg = Color(0xFFFDECEC);
  static const Color severityHighText = Color(0xFFD64541);
  static const Color severityMediumBg = Color(0xFFFEF5E4);
  static const Color severityMediumText = Color(0xFFB97D10);
  static const Color severityLowBg = Color(0xFFE6F4EA);
  static const Color severityLowText = Color(0xFF24A04A);

  static const LinearGradient deepGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepGreenLight, deepGreen, deepGreenDark],
  );

  static const LinearGradient greenButtonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [green, greenDark],
  );
}

/// Rounded corner brackets drawn around the viewfinder area (capture screen)
/// and the logo mark (onboarding hero).
class CornerFramePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double radius;

  const CornerFramePainter({
    required this.color,
    this.strokeWidth = 4,
    this.cornerLength = 34,
    this.radius = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final r = radius;
    final w = size.width;
    final h = size.height;
    final L = cornerLength;

    final path = Path()
      // Top-left
      ..moveTo(0, r + L)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(r + L, 0)
      // Top-right
      ..moveTo(w - r - L, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, r + L)
      // Bottom-right
      ..moveTo(w, h - r - L)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - r - L, h)
      // Bottom-left
      ..moveTo(r + L, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, h - r - L);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CornerFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.cornerLength != cornerLength ||
      oldDelegate.radius != radius;
}

/// The leaf-in-brackets brand mark used on the onboarding hero and splash
/// areas. Pure vector — no image asset needed.
class BrandMark extends StatelessWidget {
  final double size;
  final Color color;
  final double bracketExtent; // 0..1 — how far the brackets wrap the leaf

  const BrandMark({
    super.key,
    this.size = 96,
    this.color = Colors.white,
    this.bracketExtent = 0.62,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          color: color,
          bracketExtent: bracketExtent,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  final Color color;
  final double bracketExtent;

  const _BrandMarkPainter({required this.color, required this.bracketExtent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;

    const r = 6.0;
    final w = size.width;
    final h = size.height;
    final L = w * 0.28 * bracketExtent * 1.6;

    // Corner brackets
    final path = Path()
      ..moveTo(0, r + L)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(r + L, 0)
      ..moveTo(w - r - L, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, r + L)
      ..moveTo(w, h - r - L)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(w - r - L, h)
      ..moveTo(r + L, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, h - r - L);
    canvas.drawPath(path, paint);

    // Leaf: mirrored arcs forming a leaf shape with a center vein.
    final leaf = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = w / 2;
    final cy = h / 2;
    final leafW = w * 0.30;
    final leafH = h * 0.42;

    // Filled body so the leaf reads solid on the photo-like backdrop, with
    // the vein knocked out in the dark backdrop color (matching the design's
    // white leaf with a dark center vein).
    final leafPath = Path()
      ..moveTo(cx, cy - leafH / 2)
      ..quadraticBezierTo(cx + leafW, cy - leafH * 0.1, cx, cy + leafH / 2)
      ..quadraticBezierTo(cx - leafW, cy - leafH * 0.1, cx, cy - leafH / 2)
      ..close();
    canvas.drawPath(leafPath, fill);

    // Knocked-out center vein.
    final vein = Paint()
      ..color = const Color(0xFF12352A) // deep green of the hero backdrop
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(cx, cy + leafH / 2),
      Offset(cx, cy - leafH * 0.30),
      vein,
    );

    // Outline stroke on top for crispness at small sizes.
    canvas.drawPath(leafPath, leaf);
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.bracketExtent != bracketExtent;
}


/// Small rounded severity/confidence pill — the red "Severity: High" chip
/// from the design, plus medium/low variants for reuse elsewhere.
class SeverityPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;
  final IconData icon;
  final double fontSize;

  const SeverityPill({
    super.key,
    required this.label,
    required this.bg,
    required this.textColor,
    this.icon = Icons.priority_high_rounded,
    this.fontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
