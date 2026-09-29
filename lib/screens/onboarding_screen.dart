import 'dart:math';

import 'package:flutter/material.dart';

import '../game/board_painter.dart';
import '../game/gem_art.dart';
import '../levels.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart';

class _Page {
  final String title, body;
  final CustomPainter Function(double t) painter;
  const _Page(this.title, this.body, this.painter);
}

/// First-launch walkthrough: four animated pages, then the Home screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pc = PageController();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  double _page = 0;
  double _clock = 0;
  Duration? _last;

  late final List<_Page> _pages = [
    _Page('Welcome to Diamond Picture Puzzle', 'Sort sparkling diamonds into place and reveal a pixel picture in every level.',
        (t) => _WelcomeArt(t)),
    _Page('Tap, park & place', 'Tap a group of same-colour diamonds, park them on the shelf, then tap the matching cells.',
        (t) => _HowToArt(t)),
    _Page('Levels, stars & rewards', 'Finish in fewer moves to earn up to 3 stars. Every level pays out coins.', (t) => _StarsArt(t)),
    _Page('Daily Challenge & boosters', 'A fresh puzzle every day with a big reward. Unlock boosters as you level up.',
        (t) => _DailyArt(t)),
  ];

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => _page = _pc.page ?? 0));
    // Continuous clock for the looping illustrations.
    _loop.addListener(() {
      final now = _loop.lastElapsedDuration ?? Duration.zero;
      if (_last != null) _clock += (now - _last!).inMicroseconds / 1e6;
      _last = now;
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _finish() {
    Progress.I.onboarded = true;
    Progress.I.save();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _next() {
    final i = _page.round();
    if (i >= _pages.length - 1) {
      _finish();
    } else {
      _pc.animateToPage(i + 1, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width, h = size.height;
    // Scale for small and tall screens alike.
    final u = min(w, h * 0.56);
    final last = _page.round() == _pages.length - 1;
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(children: [
            SizedBox(
              height: u * 0.16,
              child: Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: last,
                    child: Pressable(
                      onTap: _finish,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: u * 0.06, vertical: u * 0.03),
                        child: Text('Skip', style: bodyStyle(u * 0.048, color: AppColors.lavenderDark)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: _pages.length,
                itemBuilder: (_, i) {
                  final d = (i - _page).clamp(-1.0, 1.0);
                  final p = _pages[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: u * 0.08),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      // Illustration drifts and scales with the swipe.
                      Transform.translate(
                        offset: Offset(d * u * 0.25, 0),
                        child: Transform.scale(
                          scale: 1 - d.abs() * 0.15,
                          child: Opacity(
                            opacity: (1 - d.abs()).clamp(0.0, 1.0),
                            child: _ArtCard(size: u * 0.8, painter: p.painter, clock: _loop, time: () => _clock),
                          ),
                        ),
                      ),
                      SizedBox(height: u * 0.08),
                      Opacity(
                        opacity: (1 - d.abs() * 1.5).clamp(0.0, 1.0),
                        child: Column(children: [
                          Text(p.title, textAlign: TextAlign.center, style: titleStyle(u * 0.075, color: AppColors.textDark)),
                          SizedBox(height: u * 0.03),
                          Text(p.body,
                              textAlign: TextAlign.center,
                              style: bodyStyle(u * 0.045, color: AppColors.textDark.withAlpha(190), weight: 600)),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
            _Dots(count: _pages.length, page: _page, unit: u),
            SizedBox(height: u * 0.06),
            ChunkyButton(
              color: AppColors.green,
              shade: AppColors.greenDark,
              width: u * 0.62,
              height: u * 0.16,
              whiteBorder: true,
              onTap: _next,
              child: buttonLabel(last ? 'Get Started' : 'Next', u * 0.07),
            ),
            SizedBox(height: u * 0.08),
          ]),
        ),
      ),
    );
  }
}

class _ArtCard extends StatelessWidget {
  final double size;
  final CustomPainter Function(double t) painter;
  final Listenable clock;
  final double Function() time;
  const _ArtCard({required this.size, required this.painter, required this.clock, required this.time});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(235),
          borderRadius: BorderRadius.circular(size * 0.1),
          border: Border.all(color: AppColors.popupBorder, width: size * 0.012),
          boxShadow: [BoxShadow(color: AppColors.lavenderDark.withAlpha(50), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.1),
          child: AnimatedBuilder(animation: clock, builder: (_, __) => CustomPaint(painter: painter(time()), size: Size.square(size))),
        ),
      );
}

class _Dots extends StatelessWidget {
  final int count;
  final double page, unit;
  const _Dots({required this.count, required this.page, required this.unit});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Builder(builder: (_) {
              final k = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: EdgeInsets.symmetric(horizontal: unit * 0.012),
                width: unit * (0.025 + 0.045 * k),
                height: unit * 0.025,
                decoration: BoxDecoration(
                  color: Color.lerp(const Color(0xFFCBC8EE), AppColors.lavenderDark, k),
                  borderRadius: BorderRadius.circular(unit),
                ),
              );
            }),
        ],
      );
}

// ------------------------------------------------------------------ art

void _paintStar(Canvas canvas, Offset c, double r, {double fill = 1}) {
  final path = starPath(c, r, r * 0.48);
  canvas.drawPath(path.shift(Offset(0, r * 0.1)), Paint()..color = const Color(0xFFD98A00));
  canvas.drawPath(path, Paint()..color = Color.lerp(const Color(0xFFE3E1F5), const Color(0xFFFFC925), fill)!);
  canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.1
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white);
}

void _paintHand(Canvas canvas, Offset tip, double size) {
  final tp = TextPainter(text: TextSpan(text: '\u{1F446}\u{1F3FB}', style: TextStyle(fontSize: size)), textDirection: TextDirection.ltr)
    ..layout();
  canvas.save();
  canvas.translate(tip.dx, tip.dy);
  canvas.rotate(-0.35);
  tp.paint(canvas, Offset(-tp.width * 0.4, -tp.height * 0.05));
  canvas.restore();
}

double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Page 1: a mushroom assembling itself gem by gem.
class _WelcomeArt extends CustomPainter {
  final double t;
  _WelcomeArt(this.t);
  static final _level = buildLevel(2);

  @override
  void paint(Canvas canvas, Size size) {
    final d = _level;
    final cell = size.width * 0.085;
    final origin = Offset((size.width - cell * d.cols) / 2, (size.height - cell * d.rows) / 2 + cell * 0.2);
    final cycle = t % 4.5;
    final cells = [for (var i = 0; i < d.target.length; i++) if (d.target[i] != null) i];
    final gems = List<String?>.filled(d.target.length, null);
    final flying = <int, double>{};
    for (var k = 0; k < cells.length; k++) {
      final start = 0.2 + k * 0.08;
      final p = _seg(cycle, start, start + 0.35);
      if (p >= 1) {
        gems[cells[k]] = d.target[cells[k]];
      } else if (p > 0) {
        flying[cells[k]] = p;
      }
    }
    paintBoardBase(canvas, origin, cell, d.cols, d.target, gems);
    flying.forEach((i, p) {
      final r = Rect.fromLTWH(origin.dx + (i % d.cols) * cell, origin.dy + (i ~/ d.cols) * cell, cell, cell).deflate(cell * 0.04);
      final e = Curves.easeInCubic.transform(p);
      drawGem(canvas, r.shift(Offset(0, -(1 - e) * size.height * 0.5)), gemColor(d.target[i]!), lift: 1 - e, alpha: min(1, p * 3));
    });
    // Celebration sparkles once complete.
    final done = _seg(cycle, 3.1, 4.2);
    if (done > 0) {
      final rnd = Random(3);
      for (var i = 0; i < 8; i++) {
        final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
        final k = sin(done * pi);
        canvas.drawPath(sparklePath(c, size.width * 0.04 * k), Paint()..color = const Color(0xFF9EDDFF));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WelcomeArt old) => old.t != t;
}

/// Page 2: the core loop on a tiny board with a shelf.
class _HowToArt extends CustomPainter {
  final double t;
  _HowToArt(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 4;
    final target = ['R', 'R', 'R', 'R', 'G', 'G', 'G', 'G'];
    final cell = size.width * 0.14;
    final origin = Offset((size.width - cell * cols) / 2, size.height * 0.18);
    final cycle = t % 6.0;
    Rect cellRect(int i) => Rect.fromLTWH(origin.dx + (i % cols) * cell, origin.dy + (i ~/ cols) * cell, cell, cell).deflate(cell * 0.04);
    final slotSize = cell * 0.62;
    final shelf = Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.72), width: slotSize * 5.4, height: slotSize * 1.5);
    Rect slotRect(int s) => Rect.fromCenter(center: Offset(shelf.left + slotSize * (0.9 + s * 1.2), shelf.center.dy), width: slotSize, height: slotSize);

    // Phases: tap reds -> shelf, tap greens -> cells, tap shelf -> cells.
    final liftRed = _seg(cycle, 0.6, 0.8), redToShelf = _seg(cycle, 1.1, 1.7);
    final liftGreen = _seg(cycle, 2.1, 2.3), greenDown = _seg(cycle, 2.6, 3.2);
    final liftShelf = _seg(cycle, 3.6, 3.8), shelfUp = _seg(cycle, 4.1, 4.7);

    final gems = List<String?>.filled(8, null);
    if (greenDown >= 1) {
      for (var i = 4; i < 8; i++) {
        gems[i] = 'G';
      }
    }
    if (shelfUp >= 1) {
      for (var i = 0; i < 4; i++) {
        gems[i] = 'R';
      }
    }
    paintBoardBase(canvas, origin, cell, cols, target, gems);

    canvas.drawRRect(RRect.fromRectAndRadius(shelf, Radius.circular(shelf.height * 0.3)), Paint()..color = const Color(0xFFF0F0F6));
    for (var s = 0; s < 4; s++) {
      canvas.drawRRect(RRect.fromRectAndRadius(slotRect(s), Radius.circular(slotSize * 0.28)), Paint()..color = const Color(0xFFD9D9E2));
    }

    Rect lifted(Rect r, double k) => Rect.fromCenter(center: r.center.translate(0, -r.height * 0.18 * k), width: r.width * (1 + 0.1 * k), height: r.height * (1 + 0.1 * k));
    Rect lerpR(Rect a, Rect b, double k) => Rect.lerp(a, b, Curves.easeInOutCubic.transform(k))!;

    for (var k = 0; k < 4; k++) {
      // Green diamonds start on the top (red) row.
      if (greenDown < 1) {
        final from = lifted(cellRect(k), liftGreen);
        final p = _seg(greenDown, k * 0.1, 0.7 + k * 0.1);
        drawGem(canvas, lerpR(from, cellRect(4 + k), p), gemColor('G'), lift: liftGreen * (1 - p));
      }
      // Red diamonds: bottom row -> shelf -> top row.
      if (shelfUp < 1) {
        Rect r;
        double lift;
        if (redToShelf < 1) {
          final p = _seg(redToShelf, k * 0.1, 0.7 + k * 0.1);
          r = lerpR(lifted(cellRect(4 + k), liftRed), slotRect(k), p);
          lift = liftRed * (1 - p);
        } else {
          final p = _seg(shelfUp, k * 0.1, 0.7 + k * 0.1);
          r = lerpR(lifted(slotRect(k), liftShelf), cellRect(k), p);
          lift = liftShelf;
        }
        drawGem(canvas, r, gemColor('R'), lift: lift);
      }
    }

    // Pointing hand follows the taps.
    final spots = [
      (0.0, cellRect(5).center),
      (0.9, shelf.center),
      (1.9, cellRect(1).center),
      (2.4, cellRect(6).center),
      (3.4, slotRect(1).center),
      (3.9, cellRect(2).center),
      (5.2, cellRect(2).center),
    ];
    // Glide from the previous tap spot to the current one.
    var pos = spots.first.$2;
    for (var i = 1; i < spots.length; i++) {
      if (cycle < spots[i].$1) break;
      final k = Curves.easeInOut.transform(_seg(cycle, spots[i].$1, spots[i].$1 + 0.35));
      pos = Offset.lerp(spots[i - 1].$2, spots[i].$2, k)!;
    }
    final press = (sin(cycle * 9) + 1) / 2;
    _paintHand(canvas, pos.translate(0, cell * 0.1 * press), cell * 0.9);

    if (shelfUp >= 1) {
      final k = _seg(cycle, 4.8, 5.6);
      for (var i = 0; i < 8; i++) {
        final band = (1 - ((i % cols + i ~/ cols) / 4 - k * 1.5 + 0.25).abs() / 0.25).clamp(0.0, 1.0);
        canvas.drawRRect(RRect.fromRectAndRadius(cellRect(i), Radius.circular(cell * 0.2)), Paint()..color = Colors.white.withAlpha((140 * band).round()));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HowToArt old) => old.t != t;
}

/// Page 3: three stars pop in and coins pour into the counter.
class _StarsArt extends CustomPainter {
  final double t;
  _StarsArt(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cycle = t % 4.0;
    // Level chip.
    final chip = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w / 2, h * 0.17), width: w * 0.42, height: h * 0.11), Radius.circular(h));
    canvas.drawRRect(chip.shift(Offset(0, h * 0.012)), Paint()..color = AppColors.lavenderDark);
    canvas.drawRRect(chip, Paint()..color = AppColors.lavender);
    final tp = TextPainter(
        text: TextSpan(text: 'LEVEL 5', style: titleStyle(w * 0.07)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, chip.center - Offset(tp.width / 2, tp.height / 2));

    for (var i = 0; i < 3; i++) {
      final p = _seg(cycle, 0.3 + i * 0.35, 0.75 + i * 0.35);
      final s = p <= 0 ? 0.0 : Curves.elasticOut.transform(p);
      final c = Offset(w * (0.27 + i * 0.23), h * (i == 1 ? 0.42 : 0.47));
      final r = w * (i == 1 ? 0.13 : 0.1);
      _paintStar(canvas, c, r, fill: 0);
      if (s > 0) _paintStar(canvas, c, r * s, fill: 1);
    }

    // Coin counter.
    final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.55, h * 0.8), width: w * 0.36, height: h * 0.1), Radius.circular(h));
    canvas.drawRRect(pill, Paint()..color = const Color(0xFFF0F0F6));
    final arrived = (_seg(cycle, 1.8, 3.0) * 10).floor();
    final tp2 = TextPainter(
        text: TextSpan(text: '${120 + arrived}', style: bodyStyle(w * 0.06)), textDirection: TextDirection.ltr)
      ..layout();
    tp2.paint(canvas, Offset(pill.left + w * 0.13, pill.center.dy - tp2.height / 2));
    final target = Offset(pill.left + w * 0.04, pill.center.dy);
    paintCoin(canvas, target, w * 0.055);
    for (var i = 0; i < 10; i++) {
      final p = _seg(cycle, 1.5 + i * 0.12, 1.95 + i * 0.12);
      if (p <= 0 || p >= 1) continue;
      final from = Offset(w * (0.3 + (i % 5) * 0.1), h * 0.55);
      final ctrl = Offset(from.dx, h * 0.62);
      final e = Curves.easeIn.transform(p);
      final pos = Offset.lerp(Offset.lerp(from, ctrl, e)!, Offset.lerp(ctrl, target, e)!, e)!;
      paintCoin(canvas, pos, w * 0.045);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsArt old) => old.t != t;
}

/// Page 4: today's calendar card, a bouncing gift and orbiting boosters.
class _DailyArt extends CustomPainter {
  final double t;
  _DailyArt(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h * 0.47);
    // Calendar.
    final card = Rect.fromCenter(center: center, width: w * 0.42, height: w * 0.44);
    canvas.drawRRect(RRect.fromRectAndRadius(card.shift(Offset(0, w * 0.015)), Radius.circular(w * 0.05)), Paint()..color = const Color(0xFFCFCBEF));
    canvas.drawRRect(RRect.fromRectAndRadius(card, Radius.circular(w * 0.05)), Paint()..color = Colors.white);
    final head = Rect.fromLTWH(card.left, card.top, card.width, card.height * 0.3);
    canvas.drawRRect(
        RRect.fromRectAndCorners(head, topLeft: Radius.circular(w * 0.05), topRight: Radius.circular(w * 0.05)), Paint()..color = AppColors.red);
    final day = TextPainter(
        text: TextSpan(text: '${DateTime.now().day}', style: titleStyle(w * 0.15, color: AppColors.textDark)),
        textDirection: TextDirection.ltr)
      ..layout();
    day.paint(canvas, Offset(card.center.dx - day.width / 2, head.bottom + (card.bottom - head.bottom - day.height) / 2));
    final label = TextPainter(text: TextSpan(text: 'DAILY', style: titleStyle(w * 0.055)), textDirection: TextDirection.ltr)..layout();
    label.paint(canvas, head.center - Offset(label.width / 2, label.height / 2));

    // Gift bouncing on the corner.
    final bounce = (sin(t * 4) + 1) / 2;
    final g = Offset(card.right - w * 0.02, card.bottom - w * 0.04 - bounce * w * 0.04);
    final gift = Rect.fromCenter(center: g, width: w * 0.16, height: w * 0.14);
    canvas.drawRRect(RRect.fromRectAndRadius(gift, Radius.circular(w * 0.02)), Paint()..color = const Color(0xFFE05BD6));
    canvas.drawRect(Rect.fromCenter(center: g, width: w * 0.03, height: w * 0.14), Paint()..color = const Color(0xFFFFD23F));
    canvas.drawRect(Rect.fromCenter(center: g, width: w * 0.16, height: w * 0.025), Paint()..color = const Color(0xFFFFD23F));
    paintCoin(canvas, g.translate(-w * 0.05, -w * 0.1 - bounce * w * 0.02), w * 0.035);

    // Boosters orbit the card.
    const kinds = ['wand', 'broom', 'magnet'];
    for (var i = 0; i < 3; i++) {
      final a = t * 0.8 + i * 2 * pi / 3;
      final p = center + Offset(cos(a) * w * 0.36, sin(a) * w * 0.3);
      final r = w * 0.075;
      canvas.drawCircle(p, r, Paint()..color = const Color(0xFFF4F4F8));
      canvas.drawCircle(p, r, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.008
        ..color = AppColors.popupBorder);
      canvas.save();
      canvas.translate(p.dx - r * 0.6, p.dy - r * 0.6);
      boosterPainter(kinds[i]).paint(canvas, Size.square(r * 1.2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DailyArt old) => old.t != t;
}
