import 'package:flutter/material.dart';
import '../core/constants/colors.dart';

class TTIconLogo extends StatelessWidget {
  final double size;
  final bool glow;
  const TTIconLogo({super.key, this.size = 80, this.glow = true});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: const Color(0xFF1A1F2E),
      borderRadius: BorderRadius.circular(size * 0.22),
      boxShadow: glow ? [
        BoxShadow(color: C.orange.withOpacity(0.5), blurRadius: 24, spreadRadius: 2),
        BoxShadow(color: C.blue.withOpacity(0.2),   blurRadius: 16, offset: const Offset(4, 4)),
      ] : null,
    ),
    child: CustomPaint(painter: _TTIconPainter()),
  );
}

class _TTIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final pad = w * 0.13; final bH = h * 0.145; final sW = w * 0.14;
    final bp = Path()
      ..moveTo(pad, pad)..lineTo(w * 0.53, pad)..lineTo(w * 0.53, pad + bH)
      ..lineTo(pad + (w * 0.53 - pad) / 2 + sW / 2, pad + bH)
      ..lineTo(pad + (w * 0.53 - pad) / 2 + sW / 2, h - pad * 0.65)
      ..lineTo(pad + (w * 0.53 - pad) / 2 - sW / 2, h - pad * 0.65)
      ..lineTo(pad + (w * 0.53 - pad) / 2 - sW / 2, pad + bH)
      ..lineTo(pad, pad + bH)..close();
    canvas.drawPath(bp, Paint()..color = C.blue);
    final ox = w * 0.37;
    final yp = Path()
      ..moveTo(ox, pad * 1.7)..lineTo(w - pad, pad * 1.7)..lineTo(w - pad, pad * 1.7 + bH)
      ..lineTo(ox + (w - pad - ox) / 2 + sW / 2, pad * 1.7 + bH)
      ..lineTo(ox + (w - pad - ox) / 2 + sW / 2, h - pad * 0.25)
      ..lineTo(ox + (w - pad - ox) / 2 - sW / 2, h - pad * 0.25)
      ..lineTo(ox + (w - pad - ox) / 2 - sW / 2, pad * 1.7 + bH)
      ..lineTo(ox, pad * 1.7 + bH)..close();
    canvas.drawPath(yp, Paint()..color = C.orange);
  }
  @override bool shouldRepaint(covariant CustomPainter o) => false;
}

class TTTextLogo extends StatelessWidget {
  final double fontSize;
  const TTTextLogo({super.key, this.fontSize = 28});

  @override
  Widget build(BuildContext context) => RichText(
    text: TextSpan(
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, letterSpacing: -0.5),
      children: const [
        TextSpan(text: 'TopTop', style: TextStyle(color: C.blue)),
        TextSpan(text: 'Go',    style: TextStyle(color: C.orange)),
      ],
    ),
  );
}
