import 'dart:math';

import 'package:flutter/material.dart';

import 'game/gem_art.dart';
import 'levels.dart';
import 'services.dart';
import 'theme.dart';

/// Lavender gradient with the faint diamond lattice seen on the loading screen.
class PatternBackground extends StatelessWidget {
  final Widget? child;
  const PatternBackground({super.key, this.child});
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _PatternPainter(), child: SizedBox.expand(child: child));
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.loadTop, Color(0xFFD9D9F2), AppColors.loadBottom],
          ).createShader(rect));
    final step = size.width / 11;
    for (var y = 0; y * step < size.height + step; y++) {
      for (var x = 0; x * step < size.width + step; x++) {
        final c = Offset(x * step + (y.isOdd ? step / 2 : 0), y * step * 0.9);
        // Lattice fades out toward the top like the reference.
        final a = (c.dy / size.height).clamp(0.15, 1.0);
        canvas.drawPath(sparklePath(c, step * 0.34), Paint()..color = Colors.white.withAlpha((50 * a).round()));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Outlined, gradient-filled bubble lettering.
class OutlinedText extends StatelessWidget {
  final String text;
  final double size;
  final List<Color> fill;
  final Color stroke;
  final double strokeWidth;
  const OutlinedText(this.text,
      {super.key, required this.size, required this.fill, this.stroke = const Color(0xFF6B2FC7), this.strokeWidth = 0});
  @override
  Widget build(BuildContext context) {
    final sw = strokeWidth > 0 ? strokeWidth : size * 0.16;
    return Stack(children: [
      Transform.translate(
        offset: Offset(0, size * 0.06),
        child: Text(text,
            style: titleStyle(size).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = sw
                  ..strokeJoin = StrokeJoin.round
                  ..color = darken(stroke, 0.12))),
      ),
      Text(text,
          style: titleStyle(size).copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = sw
                ..strokeJoin = StrokeJoin.round
                ..color = stroke)),
      ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: fill).createShader(r),
        child: Text(text, style: titleStyle(size)),
      ),
    ]);
  }
}

/// Title logo in the style of the reference (yellow over blue bubble letters).
class GameLogo extends StatelessWidget {
  final double width;
  const GameLogo({super.key, required this.width});
  @override
  Widget build(BuildContext context) {
    final s = width / 5.2;
    // Each line scales down to fit, so the logo never overflows narrow screens.
    Widget line(String text, double size, List<Color> fill) => SizedBox(
          width: width,
          child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.all(size * 0.1), child: OutlinedText(text, size: size, fill: fill))),
        );
    return SizedBox(
      width: width,
      height: s * 2.55,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          line('JEWEL SORT', s * 1.15, const [Color(0xFFFFF36B), Color(0xFFFFC21C)]),
          Transform.translate(
            offset: Offset(0, -s * 0.12),
            child: line('DIAMOND PIXEL ART', s * 0.72, const [Color(0xFF7FF2FF), Color(0xFF1FA3F5)]),
          ),
        ]),
        Positioned(left: -s * 0.15, top: -s * 0.2, child: _Sparkle(size: s * 0.8)),
        Positioned(right: -s * 0.05, top: s * 1.15, child: _Sparkle(size: s * 0.45)),
        Positioned(left: width * 0.28, top: s * 2.05, child: _Sparkle(size: s * 0.42)),
      ]),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  const _Sparkle({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _SparklePainter()));
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawPath(sparklePath(c, size.width / 2), Paint()..color = const Color(0xFF9EDDFF));
    canvas.drawPath(sparklePath(c, size.width / 2), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.05
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Wraps a widget with a squash-on-press effect and a click sound.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool sound;
  const Pressable({super.key, required this.child, this.onTap, this.sound = true});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.sound) Sfx.I.play('click');
                widget.onTap!();
              },
        child: AnimatedScale(scale: _down ? 0.92 : 1, duration: const Duration(milliseconds: 80), child: widget.child),
      );
}

/// HUD coin counter pill (top-left).
class CoinPill extends StatelessWidget {
  final int coins;
  final double unit;
  final bool plus;
  final VoidCallback? onTap;
  final GlobalKey? coinKey;
  const CoinPill({super.key, required this.coins, required this.unit, this.plus = true, this.onTap, this.coinKey});
  @override
  Widget build(BuildContext context) {
    final coin = unit * 0.07;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        height: coin * 1.1,
        child: Stack(alignment: Alignment.centerLeft, children: [
          Container(
            margin: EdgeInsets.only(left: coin * 0.45),
            padding: EdgeInsets.only(left: coin * 0.75, right: coin * 0.45),
            height: coin * 0.86,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(coin)),
            child: Text('$coins', style: bodyStyle(unit * 0.038, color: AppColors.textDark, weight: 800)),
          ),
          CoinIcon(key: coinKey, size: coin, plus: plus),
        ]),
      ),
    );
  }
}

class GearButton extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const GearButton({super.key, required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      Pressable(onTap: onTap, child: Icon(Icons.settings_rounded, size: size, color: AppColors.lavender));
}

/// 3D pill button (Next, Home, Save progress, OK...).
class ChunkyButton extends StatelessWidget {
  final Widget child;
  final Color color, shade;
  final double width, height;
  final VoidCallback? onTap;
  final bool whiteBorder;
  const ChunkyButton(
      {super.key,
      required this.child,
      required this.color,
      required this.shade,
      required this.width,
      required this.height,
      this.onTap,
      this.whiteBorder = false});
  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height * 0.2);
    return Pressable(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: whiteBorder ? EdgeInsets.all(height * 0.05) : null,
        decoration: BoxDecoration(
          color: whiteBorder ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(height * 0.24),
          boxShadow: whiteBorder ? [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 6, offset: const Offset(0, 3))] : null,
        ),
        child: Container(
          decoration: BoxDecoration(borderRadius: r, color: shade),
          padding: EdgeInsets.only(bottom: height * 0.08),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [lighten(color, 0.06), color]),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Text with the dark drop shadow used on button labels.
Widget buttonLabel(String t, double size) => Text(t,
    textAlign: TextAlign.center,
    style: titleStyle(size, shadows: [Shadow(color: Colors.black.withAlpha(70), offset: Offset(0, size * 0.06))]));

/// Pink-red square close button with a white X.
class CloseX extends StatelessWidget {
  final double size;
  final VoidCallback onTap;
  const CloseX({super.key, required this.size, required this.onTap});
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.08),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.28), boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(35), blurRadius: 3, offset: const Offset(0, 2)),
          ]),
          child: Container(
            decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(size * 0.22)),
            alignment: Alignment.center,
            child: Icon(Icons.close_rounded, color: Colors.white, size: size * 0.7),
          ),
        ),
      );
}

/// Lavender popup card with a tab title and a close button, as in
/// "Exit Level?" and "SAVE PROGRESS".
class PopupCard extends StatelessWidget {
  final String title;
  final double unit;
  final Widget child;
  final VoidCallback onClose;
  final double? height;
  const PopupCard({super.key, required this.title, required this.unit, required this.child, required this.onClose, this.height});
  @override
  Widget build(BuildContext context) {
    final w = unit * 0.89;
    return SizedBox(
      width: w + unit * 0.04,
      height: (height ?? unit * 0.5) + unit * 0.06,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: unit * 0.06,
          child: Container(
            width: w,
            height: height ?? unit * 0.5,
            decoration: BoxDecoration(
              color: AppColors.popupBg,
              borderRadius: BorderRadius.circular(unit * 0.035),
              border: Border.all(color: AppColors.popupBorder, width: unit * 0.012),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(60), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            padding: EdgeInsets.fromLTRB(unit * 0.03, unit * 0.08, unit * 0.03, unit * 0.03),
            child: child,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          width: w,
          child: Center(child: TitleTab(text: title, unit: unit)),
        ),
        Positioned(right: 0, top: unit * 0.026, child: CloseX(size: unit * 0.075, onTap: onClose)),
      ]),
    );
  }
}

class TitleTab extends StatelessWidget {
  final String text;
  final double unit;
  const TitleTab({super.key, required this.text, required this.unit});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _TabPainter(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: unit * 0.09, vertical: unit * 0.018),
          child: buttonLabel(text, unit * 0.056),
        ),
      );
}

class _TabPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height, w = size.width;
    Path shape(double dy) => Path()
      ..moveTo(h * 0.35, dy)
      ..lineTo(w - h * 0.35, dy)
      ..quadraticBezierTo(w - h * 0.1, dy, w, h * 0.5 + dy)
      ..quadraticBezierTo(w - h * 0.1, h + dy, w - h * 0.35, h + dy)
      ..lineTo(h * 0.35, h + dy)
      ..quadraticBezierTo(h * 0.1, h + dy, 0, h * 0.5 + dy)
      ..quadraticBezierTo(h * 0.1, dy, h * 0.35, dy)
      ..close();
    canvas.drawPath(shape(h * 0.1), Paint()..color = AppColors.lavenderDark);
    canvas.drawPath(shape(0), Paint()..color = AppColors.lavender);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// White speech bubble with a downward tail.
class SpeechBubble extends StatelessWidget {
  final String text;
  final double unit;
  final double tailX;
  const SpeechBubble({super.key, required this.text, required this.unit, this.tailX = 0.5});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BubblePainter(tailX, unit * 0.025),
        child: Padding(
          padding: EdgeInsets.fromLTRB(unit * 0.04, unit * 0.02, unit * 0.04, unit * 0.025),
          child: Text(text, textAlign: TextAlign.center, style: bodyStyle(unit * 0.044)),
        ),
      );
}

class _BubblePainter extends CustomPainter {
  final double tailX, tail;
  _BubblePainter(this.tailX, this.tail);
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height * 0.22));
    final tx = size.width * tailX;
    final path = Path()
      ..addRRect(r)
      ..moveTo(tx - tail, size.height - 1)
      ..lineTo(tx, size.height + tail)
      ..lineTo(tx + tail, size.height - 1)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawRRect(r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFD5D5E4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small booster icons (wand, broom, magnet) drawn in code.
class BoosterIcon extends StatelessWidget {
  final String kind;
  final double size;
  const BoosterIcon({super.key, required this.kind, required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _BoosterPainter(kind)));
}

CustomPainter boosterPainter(String kind) => _BoosterPainter(kind);

/// Colour coding for the difficulty tiers.
Color tierColor(Difficulty d) => const [
      Color(0xFF22B35E), // easy
      Color(0xFF1E8FE8), // medium
      Color(0xFFF08A1C), // hard
      Color(0xFFE5394E), // very hard
      Color(0xFF8C3FE0), // master
    ][d.index];

/// Gold rating star; [filled] false draws the empty slot.
class StarIcon extends StatelessWidget {
  final double size;
  final bool filled;
  const StarIcon({super.key, required this.size, this.filled = true});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _StarPainter(filled)));
}

class _StarPainter extends CustomPainter {
  final bool filled;
  _StarPainter(this.filled);
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width * 0.48;
    final c = Offset(size.width / 2, size.height / 2 - r * 0.04);
    final path = starPath(c, r, r * 0.5);
    if (filled) canvas.drawPath(path.shift(Offset(0, r * 0.1)), Paint()..color = const Color(0xFFD98A00));
    canvas.drawPath(path, Paint()..color = filled ? const Color(0xFFFFC925) : const Color(0xFFD9D7EE));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.filled != filled;
}

class _BoosterPainter extends CustomPainter {
  final String kind;
  _BoosterPainter(this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    switch (kind) {
      case 'wand':
        canvas.drawLine(Offset(s * 0.2, s * 0.85), Offset(s * 0.62, s * 0.4),
            Paint()
              ..color = const Color(0xFF2E7BF0)
              ..strokeWidth = s * 0.13
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(starPath(Offset(s * 0.68, s * 0.3), s * 0.28, s * 0.12), Paint()..color = const Color(0xFFFFC925));
        break;
      case 'broom':
        canvas.drawLine(Offset(s * 0.85, s * 0.1), Offset(s * 0.45, s * 0.55),
            Paint()
              ..color = const Color(0xFF93602F)
              ..strokeWidth = s * 0.1
              ..strokeCap = StrokeCap.round);
        final p = Path()
          ..moveTo(s * 0.42, s * 0.45)
          ..lineTo(s * 0.6, s * 0.62)
          ..lineTo(s * 0.3, s * 0.95)
          ..lineTo(s * 0.08, s * 0.72)
          ..close();
        canvas.drawPath(p, Paint()..color = const Color(0xFFFFB12B));
        break;
      default:
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.2
          ..color = const Color(0xFFE8327A);
        canvas.drawArc(Rect.fromLTWH(s * 0.18, s * 0.2, s * 0.64, s * 0.64), 0, pi, false, paint);
        canvas.drawLine(Offset(s * 0.18, s * 0.52), Offset(s * 0.18, s * 0.2), paint);
        canvas.drawLine(Offset(s * 0.82, s * 0.52), Offset(s * 0.82, s * 0.2), paint..color = const Color(0xFF2E7BF0));
        final tip = Paint()..color = const Color(0xFFE6E6F0);
        canvas.drawRect(Rect.fromLTWH(s * 0.08, s * 0.08, s * 0.2, s * 0.14), tip);
        canvas.drawRect(Rect.fromLTWH(s * 0.72, s * 0.08, s * 0.2, s * 0.14), tip);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
