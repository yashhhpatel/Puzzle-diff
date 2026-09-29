import 'dart:math';

import 'package:flutter/material.dart';

import '../game/autoplay.dart';
import '../game/board_painter.dart';
import '../game/game_controller.dart';
import '../game/gem_art.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

/// "LEVEL COMPLETE!" overlay: confetti, finished picture, reward and Next.
class LevelCompleteView extends StatefulWidget {
  final GameController game;
  final GlobalKey hudCoinKey;
  final VoidCallback onCoin;
  final VoidCallback onDone;
  final int stars, reward;
  final String title;
  const LevelCompleteView(
      {super.key,
      required this.game,
      required this.hudCoinKey,
      required this.onCoin,
      required this.onDone,
      this.stars = 3,
      this.reward = 10,
      this.title = 'LEVEL COMPLETE!'});
  @override
  State<LevelCompleteView> createState() => _LevelCompleteViewState();
}

class _Confetto {
  final double x, speed, drift, spin, size, phase;
  final Color color;
  _Confetto(Random r)
      : x = r.nextDouble(),
        speed = 0.25 + r.nextDouble() * 0.35,
        drift = (r.nextDouble() - 0.5) * 0.25,
        spin = (r.nextDouble() - 0.5) * 14,
        size = 0.012 + r.nextDouble() * 0.012,
        phase = r.nextDouble() * 0.6,
        color = const [
          Color(0xFFFFD23F),
          Color(0xFFFF5C8A),
          Color(0xFF4FC3F7),
          Color(0xFF7CE38B),
          Color(0xFFB38CFF),
          Color(0xFFFF9F43),
        ][r.nextInt(6)];
}

class _LevelCompleteViewState extends State<LevelCompleteView> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward();
  late final AnimationController _coins = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  final _confetti = List.generate(70, (i) => _Confetto(Random(i * 31 + 7)));
  final _rewardKey = GlobalKey();
  bool _collecting = false;
  Offset _from = Offset.zero, _to = Offset.zero;
  int _arrived = 0;
  static const _coinCount = 10;

  @override
  void initState() {
    super.initState();
    if (kAutoplay) Future.delayed(const Duration(milliseconds: 2500), () => mounted ? _next() : null);
    _coins.addListener(() {
      // Count coins that have reached the HUD.
      final t = _coins.value * 1.4;
      var n = 0;
      for (var i = 0; i < _coinCount; i++) {
        if (t >= i * 0.06 + 0.65) n++;
      }
      while (_arrived < n) {
        _arrived++;
        widget.onCoin();
        Sfx.I.play('coin');
      }
    });
    _coins.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _coins.dispose();
    super.dispose();
  }

  Offset _centerOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null) return Offset.zero;
    return me.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _next() {
    if (_collecting) return;
    setState(() {
      _collecting = true;
      _from = _centerOf(_rewardKey);
      _to = _centerOf(widget.hudCoinKey);
    });
    _coins.forward();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width, h = size.height;
    final g = widget.game;
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _coins]),
      builder: (context, _) {
        final t = _intro.value * 3.0;
        final fade = (t / 0.25).clamp(0.0, 1.0);
        final pop = Curves.easeOutBack.transform((t / 0.45).clamp(0.0, 1.0));
        final uiIn = Curves.easeOut.transform(((t - 0.35) / 0.35).clamp(0.0, 1.0));
        return Stack(children: [
          Positioned.fill(child: GestureDetector(onTap: () {}, child: Container(color: AppColors.overlay.withAlpha((0xEE * fade).round())))),
          // Card with the finished picture.
          Positioned(
            left: (w - w * 0.58) / 2,
            top: h * 0.33,
            width: w * 0.58,
            height: w * 0.58,
            child: Transform.scale(
              scale: pop,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFD2D0F4),
                  borderRadius: BorderRadius.circular(w * 0.06),
                ),
                padding: EdgeInsets.fromLTRB(w * 0.018, w * 0.012, w * 0.018, w * 0.03),
                child: Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w * 0.05)),
                  padding: EdgeInsets.fromLTRB(w * 0.05, w * 0.1, w * 0.05, w * 0.06),
                  child: CustomPaint(
                    painter: PicturePainter(g.cols, g.rows, g.target),
                    foregroundPainter: _TwinklePainter(t),
                  ),
                ),
              ),
            ),
          ),
          // Earned stars pop in one after another.
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.28 - w * 0.2,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.01),
                  child: Stack(alignment: Alignment.center, children: [
                    StarIcon(size: w * (i == 1 ? 0.17 : 0.13), filled: false),
                    if (i < widget.stars)
                      Transform.scale(
                        scale: Curves.elasticOut.transform(((t - 0.5 - i * 0.25) / 0.6).clamp(0.0, 1.0)),
                        child: StarIcon(size: w * (i == 1 ? 0.17 : 0.13)),
                      ),
                  ]),
                ),
            ]),
          ),
          // Ribbon banner.
          Positioned(
            left: w * 0.13,
            right: w * 0.13,
            top: h * 0.28,
            child: Transform.scale(scale: pop, child: _Ribbon(unit: w, text: widget.title)),
          ),
          // Reward.
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.595,
            child: Opacity(
              opacity: uiIn,
              child: Column(children: [
                Text('Reward:', style: titleStyle(w * 0.052)),
                SizedBox(height: w * 0.02),
                Opacity(opacity: _collecting ? 0.0 : 1, child: CoinIcon(key: _rewardKey, size: w * 0.13)),
                SizedBox(height: w * 0.01),
                Text('${widget.reward}', style: titleStyle(w * 0.045)),
              ]),
            ),
          ),
          Positioned(
            left: (w - w * 0.53) / 2,
            top: h * 0.74,
            child: Opacity(
              opacity: uiIn,
              child: ChunkyButton(
                color: AppColors.green,
                shade: AppColors.greenDark,
                width: w * 0.53,
                height: w * 0.155,
                whiteBorder: true,
                onTap: _next,
                child: buttonLabel('Next', w * 0.085),
              ),
            ),
          ),
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ConfettiPainter(_confetti, t)))),
          if (_collecting)
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _CoinFlightPainter(_from, _to, _coins.value * 1.4, w)))),
        ]);
      },
    );
  }
}

class _Ribbon extends StatelessWidget {
  final double unit;
  final String text;
  const _Ribbon({required this.unit, required this.text});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: unit * 0.13,
        child: CustomPaint(
          painter: _RibbonPainter(),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: unit * 0.02),
              child: buttonLabel(text, unit * 0.058),
            ),
          ),
        ),
      );
}

class _RibbonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final tail = Paint()..color = AppColors.bannerPurpleDark;
    // Folded tails on both sides.
    canvas.drawPath(
        Path()
          ..moveTo(0, h * 0.3)
          ..lineTo(w * 0.1, h * 0.3)
          ..lineTo(w * 0.1, h * 0.95)
          ..lineTo(w * 0.02, h * 0.95)
          ..lineTo(w * 0.05, h * 0.62)
          ..close(),
        tail);
    canvas.drawPath(
        Path()
          ..moveTo(w, h * 0.3)
          ..lineTo(w * 0.9, h * 0.3)
          ..lineTo(w * 0.9, h * 0.95)
          ..lineTo(w * 0.98, h * 0.95)
          ..lineTo(w * 0.95, h * 0.62)
          ..close(),
        tail);
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.05, 0, w * 0.9, h * 0.8), Radius.circular(h * 0.14));
    canvas.drawRRect(body.shift(Offset(0, h * 0.06)), Paint()..color = AppColors.bannerPurpleDark);
    canvas.drawRRect(body, Paint()..color = AppColors.bannerPurple);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.07, h * 0.05, w * 0.86, h * 0.25), Radius.circular(h * 0.1)),
        Paint()..color = Colors.white.withAlpha(40));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TwinklePainter extends CustomPainter {
  final double t;
  _TwinklePainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(5);
    for (var i = 0; i < 6; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      final k = max(0.0, sin((t * 2.2 + i * 0.37) * pi));
      canvas.drawPath(sparklePath(p, size.width * 0.05 * k), Paint()..color = Colors.white.withAlpha((230 * k).round()));
    }
  }

  @override
  bool shouldRepaint(covariant _TwinklePainter old) => old.t != t;
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetto> items;
  final double t;
  _ConfettiPainter(this.items, this.t);
  @override
  void paint(Canvas canvas, Size size) {
    for (final c in items) {
      final lt = t - c.phase * 0.5;
      if (lt < 0) continue;
      // Burst upward from behind the banner, then flutter down.
      final y = size.height * (0.3 - 0.25 * exp(-lt * 3) + c.speed * lt * 0.5);
      final x = size.width * (c.x + c.drift * lt + 0.02 * sin(lt * 4 + c.phase * 10));
      if (y > size.height * 0.8) continue;
      final alpha = (1 - ((lt - 2.2) / 0.8)).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(c.spin * lt);
      final s = c.size * size.width;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 0.7), Radius.circular(s * 0.3)),
          Paint()..color = c.color.withAlpha((255 * alpha).round()));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

class _CoinFlightPainter extends CustomPainter {
  final Offset from, to;
  final double t, w;
  _CoinFlightPainter(this.from, this.to, this.t, this.w);
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 10; i++) {
      final lt = t - i * 0.06;
      if (lt < 0) {
        paintCoin(canvas, from, w * 0.065);
        continue;
      }
      if (lt > 0.65) continue;
      // Burst out, then home in on the counter.
      final ang = i * 2.4;
      final burst = from + Offset(cos(ang), sin(ang)) * w * 0.14;
      final Offset p;
      if (lt < 0.2) {
        p = Offset.lerp(from, burst, Curves.easeOut.transform(lt / 0.2))!;
      } else {
        final k = Curves.easeIn.transform((lt - 0.2) / 0.45);
        p = Offset.lerp(burst, to, k)!;
      }
      final r = w * 0.065 * (1 - 0.45 * ((lt - 0.2) / 0.45).clamp(0.0, 1.0));
      paintCoin(canvas, p, r);
    }
  }

  @override
  bool shouldRepaint(covariant _CoinFlightPainter old) => true;
}
