import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Loose, raised diamond sitting on top of the board or shelf.
void drawGem(Canvas canvas, Rect r, Color c, {double lift = 0, double alpha = 1}) {
  final s = r.width;
  final radius = Radius.circular(s * 0.24);
  final a = (alpha * 255).round();
  // Drop shadow grows while the gem is lifted.
  if (lift > 0) {
    final sh = RRect.fromRectAndRadius(r.shift(Offset(0, s * (0.08 + lift * 0.14))), radius);
    canvas.drawRRect(sh, Paint()..color = Colors.black.withAlpha((50 * lift * alpha).round())..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08));
  }
  // Thick base (side of the gem).
  final base = RRect.fromRectAndRadius(r.shift(Offset(0, s * 0.07)), radius);
  canvas.drawRRect(base, Paint()..color = darken(c, 0.2).withAlpha(a));
  final body = RRect.fromRectAndRadius(r, radius);
  canvas.save();
  canvas.clipRRect(body);
  _facets(canvas, r, c, a, 0.16, 0.06, -0.06, -0.14);
  // Glossy highlight.
  final hl = Rect.fromLTWH(r.left + s * 0.14, r.top + s * 0.1, s * 0.3, s * 0.16);
  canvas.drawOval(hl, Paint()..color = Colors.white.withAlpha((110 * alpha).round()));
  canvas.restore();
  canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, s * 0.035)
        ..color = darken(c, 0.14).withAlpha(a));
}

/// Gem locked into its correct cell: flat, flush with the board.
void drawPlacedGem(Canvas canvas, Rect cell, Color c) {
  final r = cell.deflate(cell.width * 0.04);
  final body = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.2));
  final base = darken(c, 0.05);
  canvas.save();
  canvas.clipRRect(body);
  _facets(canvas, r, base, 255, 0.07, 0.03, -0.03, -0.07);
  canvas.restore();
  canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.6, r.width * 0.03)
        ..color = darken(c, 0.12));
}

/// Empty socket showing the colour the cell wants.
void drawEmptyCell(Canvas canvas, Rect cell, Color c) {
  final r = cell.deflate(cell.width * 0.12);
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.22));
  canvas.drawRRect(rr, Paint()..color = darken(c, 0.07));
  canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(0.8, cell.width * 0.05)
        ..color = lighten(c, 0.08));
}

void _facets(Canvas canvas, Rect r, Color c, int a, double top, double left, double right, double bottom) {
  final ctr = r.center;
  final inset = r.width * 0.2;
  final t = Rect.fromCenter(center: ctr, width: r.width - inset * 2, height: r.height - inset * 2);
  void tri(Offset p1, Offset p2, Offset p3, Offset p4, double amt) {
    final col = amt >= 0 ? lighten(c, amt) : darken(c, -amt);
    canvas.drawPath(Path()..addPolygon([p1, p2, p3, p4], true), Paint()..color = col.withAlpha(a));
  }

  tri(r.topLeft, r.topRight, t.topRight, t.topLeft, top);
  tri(r.topLeft, t.topLeft, t.bottomLeft, r.bottomLeft, left);
  tri(r.topRight, r.bottomRight, t.bottomRight, t.topRight, right);
  tri(r.bottomLeft, t.bottomLeft, t.bottomRight, r.bottomRight, bottom);
  // Centre table with a soft X like the reference cut.
  canvas.drawRect(t, Paint()..color = c.withAlpha(a));
  final x = Paint()
    ..color = lighten(c, 0.1).withAlpha((a * 0.7).round())
    ..strokeWidth = max(0.6, r.width * 0.035);
  canvas.drawLine(t.topLeft, t.bottomRight, x);
  canvas.drawLine(t.topRight, t.bottomLeft, x);
}

/// Gold coin with a star, used in the HUD, rewards and shop.
class CoinIcon extends StatelessWidget {
  final double size;
  final bool plus;
  const CoinIcon({super.key, required this.size, this.plus = false});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _CoinPainter(plus)));
}

class _CoinPainter extends CustomPainter {
  final bool plus;
  _CoinPainter(this.plus);
  @override
  void paint(Canvas canvas, Size size) {
    paintCoin(canvas, Offset(size.width / 2, size.height / 2), size.width / 2);
    if (plus) {
      final c = Offset(size.width * 0.82, size.height * 0.84);
      final pr = size.width * 0.22;
      canvas.drawCircle(c, pr, Paint()..color = Colors.white);
      canvas.drawCircle(c, pr * 0.78, Paint()..color = const Color(0xFF2FC56A));
      final p = Paint()
        ..color = Colors.white
        ..strokeWidth = pr * 0.34
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c.translate(-pr * 0.42, 0), c.translate(pr * 0.42, 0), p);
      canvas.drawLine(c.translate(0, -pr * 0.42), c.translate(0, pr * 0.42), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void paintCoin(Canvas canvas, Offset c, double r, {double alpha = 1}) {
  final a = (alpha * 255).round();
  canvas.drawCircle(c.translate(0, r * 0.08), r, Paint()..color = const Color(0xFFE07A00).withAlpha(a));
  canvas.drawCircle(c, r, Paint()..color = const Color(0xFFFFA91E).withAlpha(a));
  canvas.drawCircle(c, r * 0.76, Paint()..color = const Color(0xFFFFC53A).withAlpha(a));
  canvas.drawPath(starPath(c, r * 0.5, r * 0.24), Paint()..color = const Color(0xFFF58F0A).withAlpha(a));
  canvas.drawCircle(c.translate(-r * 0.4, -r * 0.42), r * 0.16, Paint()..color = Colors.white.withAlpha((a * 0.55).round()));
}

Path starPath(Offset c, double outer, double inner, {int points = 5}) {
  final p = Path();
  for (var i = 0; i < points * 2; i++) {
    final rad = i.isEven ? outer : inner;
    final ang = -pi / 2 + i * pi / points;
    final pt = c + Offset(cos(ang) * rad, sin(ang) * rad);
    i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
  }
  return p..close();
}

/// Four-point sparkle star.
Path sparklePath(Offset c, double r) {
  final p = Path()..moveTo(c.dx, c.dy - r);
  p.quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy);
  p.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r);
  p.quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy);
  p.quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
  return p..close();
}
