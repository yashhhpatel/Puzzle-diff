import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../ads.dart';
import '../config.dart';
import '../game/autoplay.dart';
import '../game/board_painter.dart';
import '../game/game_controller.dart';
import '../game/stars.dart';
import '../levels.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contact_screen.dart';
import 'home_screen.dart';
import 'level_complete.dart';
import 'shop_screen.dart';

enum _Popup { none, settings, save, deadlock }

const _boosterKinds = ['wand', 'broom', 'magnet'];
const _boosterLevels = [7, 11, 16];

class GameScreen extends StatefulWidget {
  /// Plays today's Daily Challenge instead of the next level.
  final bool daily;

  /// Replays this level (after all levels are done) without advancing.
  final int? replay;
  const GameScreen({super.key, this.daily = false, this.replay});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameController game;
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  _Popup _popup = _Popup.none;
  int _tooltip = -1;
  Timer? _tooltipTimer;
  bool _complete = false;
  bool _loading = false;
  int _shownCoins = Progress.I.coins;
  String? _toast;
  Timer? _toastTimer;
  final _coinKey = GlobalKey();
  Timer? _autoTimer;
  int _par = 1;
  Difficulty? _tierBanner;
  int _stars = 3;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _startLevel();
    if (kAutoplay) {
      _autoTimer = Timer.periodic(const Duration(milliseconds: 380), (_) {
        if (_popup == _Popup.none && !_complete && !_loading) autoplayStep(game);
      });
    }
    _ticker = createTicker((d) {
      game.tick(d.inMicroseconds / 1e6);
      _frame.value++;
    })
      ..start();
  }

  void _startLevel() {
    final now = DateTime.now();
    final lvl = widget.daily ? 0 : (widget.replay ?? Progress.I.level.clamp(1, kMaxLevel));
    // Announce a new difficulty tier on its first level.
    final tier = difficultyOf(lvl);
    if (!widget.daily && widget.replay == null && lvl > 1 && lvl == tier.firstLevel) {
      _tierBanner = tier;
      Future.delayed(const Duration(milliseconds: 2600), () {
        if (mounted) setState(() => _tierBanner = null);
      });
    }
    final tutorial = !widget.daily && lvl == 1;
    final data = widget.daily ? buildDaily(now) : buildLevel(lvl);
    _par = parMoves(widget.daily ? 'D${Progress.dateKey(now)}' : 'L$lvl', data, tutorial: tutorial);
    game = GameController(lvl, tutorial: tutorial, data: data)
      ..onSound = Sfx.I.play
      ..onHaptic = Sfx.I.haptic
      ..onWin = _onWin
      ..onDeadlock = () => Future.delayed(const Duration(milliseconds: 400), () {
            if (kAutoplay) debugPrint('AUTOPLAY deadlock level ${game.level}');
            if (mounted) setState(() => _popup = _Popup.deadlock);
          });
    game.addListener(_onGame);
    if (kAutoplay) debugPrint('AUTOPLAY start level $lvl');
    _complete = false;
    _shownCoins = Progress.I.coins;
  }

  void _onGame() {
    if (mounted) setState(() {});
  }

  void _onWin() {
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      Sfx.I.play('whoosh');
      Sfx.I.play('complete');
      if (kAutoplay) debugPrint('AUTOPLAY complete level ${game.level} moves ${game.moves} par $_par');
      _stars = starsFor(game.moves, _par);
      if (!widget.daily) Progress.I.recordStars(game.level, _stars);
      setState(() => _complete = true);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _autoTimer?.cancel();
    _tooltipTimer?.cancel();
    _toastTimer?.cancel();
    game.removeListener(_onGame);
    super.dispose();
  }

  /// Runs after the reward coins land on the counter.
  void _afterComplete() {
    Progress.I.addCoins(widget.daily ? kDailyReward : kLevelReward);
    _shownCoins = Progress.I.coins;
    if (widget.daily) {
      Progress.I.dailyDone = Progress.dateKey(DateTime.now());
      Progress.I.save();
      _goHome();
    } else if (widget.replay != null || game.level >= kMaxLevel) {
      // Replays don't advance; finishing level 1000 completes the game.
      if (game.level >= kMaxLevel && Progress.I.level <= kMaxLevel) {
        Progress.I.level = kMaxLevel + 1;
        Progress.I.save();
      }
      _finishToHome(game.level);
    } else {
      _nextLevel(game.level);
    }
  }

  Future<void> _finishToHome(int completed) async {
    setState(() {
      _complete = false;
      _loading = true;
    });
    await Ads.I.afterLevel(completed);
    if (mounted) _goHome();
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  Future<void> _nextLevel(int completed) async {
    Progress.I.level++;
    Progress.I.save();
    setState(() {
      _complete = false;
      _loading = true;
    });
    final minLoading = Future.delayed(const Duration(milliseconds: 1400));
    // Generate the next puzzle (and its par) behind the loading screen; both
    // are cached, so _startLevel below is instant.
    await Future.delayed(const Duration(milliseconds: 60));
    final next = Progress.I.level.clamp(1, kMaxLevel);
    parMoves('L$next', buildLevel(next), tutorial: next == 1);
    // Interstitial (every 2nd level, unless Remove Ads) plays over the loading
    // screen; the next level is only built once it has been closed.
    await Ads.I.afterLevel(completed);
    await minLoading;
    if (!mounted) return;
    game.removeListener(_onGame);
    setState(() {
      _startLevel();
      _loading = false;
    });
  }

  void _restart() {
    game.removeListener(_onGame);
    setState(() {
      _popup = _Popup.none;
      _startLevel();
    });
  }

  void _showToast(String t) {
    _toastTimer?.cancel();
    setState(() => _toast = t);
    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _onBooster(int i) {
    if (Progress.I.level < _boosterLevels[i]) {
      _tooltipTimer?.cancel();
      setState(() => _tooltip = i);
      _tooltipTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _tooltip = -1);
      });
      return;
    }
    final kind = _boosterKinds[i];
    final have = Progress.I.boosters[kind]!;
    if (have <= 0) {
      if (Progress.I.coins >= 100) {
        Progress.I.coins -= 100;
        Progress.I.boosters[kind] = 1;
        Progress.I.save();
        setState(() => _shownCoins = Progress.I.coins);
      } else {
        _openShop();
        return;
      }
    }
    final used = switch (kind) { 'wand' => game.useWand(), 'broom' => game.useBroom(), _ => game.useMagnet() };
    if (used) {
      Progress.I.boosters[kind] = Progress.I.boosters[kind]! - 1;
      Progress.I.save();
      Sfx.I.play('sparkle');
      setState(() {});
    }
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const ShopScreen(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    if (mounted) setState(() => _shownCoins = Progress.I.coins);
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        setState(() => _popup = _popup == _Popup.none ? _Popup.settings : _Popup.none);
      },
      child: Scaffold(
        backgroundColor: AppColors.gameBg,
        body: SafeArea(child: LayoutBuilder(builder: (context, box) {
          final size = box.biggest;
          final w = size.width, h = size.height;
          final layout = GameLayout(size, game.cols, game.rows);
          final dim = _popup != _Popup.none || _complete;
          return Stack(children: [
            // Board + shelf canvas with its own hit testing.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _onTap(d.localPosition, layout),
                child: CustomPaint(painter: BoardPainter(game, layout, _frame)),
              ),
            ),
            if (game.tutorial != null) _tutorialBox(w, h),
            _boosters(w, h),
            if (game.tutorial != null && !game.busy) _hand(layout, w),
            _hud(w, h, dimmed: dim),
            if (_tooltip >= 0) _tooltipBubble(w, h),
            if (_tierBanner != null && !_complete) _tierBannerView(w, h, _tierBanner!),
            if (_popup != _Popup.none) ..._popupLayer(w, h),
            if (_complete)
              Positioned.fill(
                child: LevelCompleteView(
                  game: game,
                  hudCoinKey: _coinKey,
                  stars: _stars,
                  reward: widget.daily ? kDailyReward : kLevelReward,
                  title: widget.daily ? 'DAILY COMPLETE!' : 'LEVEL COMPLETE!',
                  onCoin: () => setState(() => _shownCoins += (widget.daily ? kDailyReward : kLevelReward) ~/ 10),
                  onDone: _afterComplete,
                ),
              ),
            if (_complete) _hud(w, h, coinsOnly: true),
            if (_loading) const Positioned.fill(child: LevelLoading()),
            if (_toast != null) _toastView(w, h),
          ]);
        })),
      ),
    );
  }

  void _onTap(Offset p, GameLayout layout) {
    if (_popup != _Popup.none || _complete || _loading) return;
    if (_tooltip >= 0) setState(() => _tooltip = -1);
    final slot = layout.hitShelf(p);
    if (slot > -2) {
      game.tapShelf(slot);
      return;
    }
    final i = layout.hitCell(p, game.target);
    if (i >= 0 || p.dy < layout.shelfRect.top) game.tapCell(i);
  }

  Widget _hud(double w, double h, {bool dimmed = false, bool coinsOnly = false}) {
    final hudY = h * 0.076 - w * 0.035;
    return Stack(children: [
      Positioned(
        left: w * 0.035,
        top: hudY,
        child: Opacity(
          opacity: dimmed && !coinsOnly ? 0.35 : 1,
          child: CoinPill(
            coins: _shownCoins,
            unit: w,
            coinKey: coinsOnly ? _coinKey : null,
            onTap: coinsOnly || dimmed ? null : _openShop,
          ),
        ),
      ),
      if (!coinsOnly && game.tutorial == null)
        Positioned(
          left: 0,
          right: 0,
          top: hudY,
          child: Center(child: Opacity(opacity: dimmed ? 0.35 : 1, child: _movesPill(w))),
        ),
      if (!coinsOnly)
        Positioned(
          right: w * 0.055,
          top: hudY,
          child: Opacity(
            opacity: dimmed ? 0.35 : 1,
            child: GearButton(size: w * 0.075, onTap: () => setState(() => _popup = _Popup.settings)),
          ),
        ),
    ]);
  }

  static const _tierHints = [
    '',
    'Bigger pictures and more colours!',
    'Smaller groups - plan your shelf!',
    'The toughest puzzles. Good luck!',
  ];

  Widget _tierBannerView(double w, double h, Difficulty tier) => Positioned(
        left: w * 0.08,
        right: w * 0.08,
        top: h * 0.17,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: w * 0.03, horizontal: w * 0.04),
              decoration: BoxDecoration(
                color: tierColor(tier),
                borderRadius: BorderRadius.circular(w * 0.05),
                border: Border.all(color: Colors.white, width: w * 0.012),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                buttonLabel('${tier.label.toUpperCase()} LEVELS', w * 0.07),
                SizedBox(height: w * 0.01),
                Text(_tierHints[tier.index], textAlign: TextAlign.center, style: bodyStyle(w * 0.04, color: Colors.white)),
              ]),
            ),
          ),
        ),
      );

  /// Stars the player is currently on track for, plus the move count.
  Widget _movesPill(double w) {
    final projected = starsFor(game.moves, _par);
    return Container(
      height: w * 0.075,
      padding: EdgeInsets.symmetric(horizontal: w * 0.03),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(w)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (widget.daily)
          Text('Daily', style: bodyStyle(w * 0.034, color: AppColors.red))
        else
          Text(difficultyOf(game.level).label, style: bodyStyle(w * 0.034, color: tierColor(difficultyOf(game.level)))),
        SizedBox(width: w * 0.02),
        for (var i = 0; i < 3; i++) StarIcon(size: w * 0.045, filled: i < projected),
        SizedBox(width: w * 0.02),
        Text('Moves ${game.moves}', style: bodyStyle(w * 0.034)),
      ]),
    );
  }

  Widget _tutorialBox(double w, double h) {
    return Positioned(
      left: w * 0.04,
      right: w * 0.04,
      top: h * 0.22,
      height: h * 0.1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(color: const Color(0xFFCFCFDD), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), offset: const Offset(0, 3), blurRadius: 2)],
        ),
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: w * 0.05),
        child: Text(game.tutorial!.text, textAlign: TextAlign.center, style: bodyStyle(w * 0.052)),
      ),
    );
  }

  Offset _handTarget(GameLayout layout) {
    final c = game.cols;
    switch (game.tutorial!.action) {
      case TutorialAction.pickRed:
        return layout.cellCenter(3 * c + 2);
      case TutorialAction.pickGreen:
        return layout.cellCenter(1 * c + 2);
      case TutorialAction.placeGreen:
        return layout.cellCenter(3 * c + 3);
      case TutorialAction.placeRed:
        return layout.cellCenter(0 * c + 3);
      case TutorialAction.toShelf:
      case TutorialAction.fromShelf:
        return layout.slots[6].center;
    }
  }

  Widget _hand(GameLayout layout, double w) {
    final t = _handTarget(layout);
    final s = w * 0.15;
    return Positioned(
      left: t.dx - s * 0.32,
      top: t.dy - s * 0.02,
      child: IgnorePointer(
        child: ValueListenableBuilder(
          valueListenable: _frame,
          builder: (_, __, ___) {
            final k = (sin(game.now * 5) + 1) / 2;
            return Transform.translate(
              offset: Offset(s * 0.04 * k, s * 0.08 * k),
              child: Transform.rotate(angle: -0.35, child: Text('\u{1F446}\u{1F3FB}', style: TextStyle(fontSize: s * 0.8))),
            );
          },
        ),
      ),
    );
  }

  Widget _boosters(double w, double h) {
    return Positioned(
      left: 0,
      right: 0,
      top: h * 0.93 - w * 0.058,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.018),
            child: Pressable(onTap: () => _onBooster(i), child: _boosterButton(i, w)),
          ),
      ]),
    );
  }

  Widget _boosterButton(int i, double w) {
    final unlocked = Progress.I.level >= _boosterLevels[i];
    final bw = w * 0.164, bh = w * 0.116;
    return Container(
      width: bw,
      height: bh,
      decoration: BoxDecoration(
        color: const Color(0xFFC6C7D3),
        borderRadius: BorderRadius.circular(bw * 0.16),
      ),
      padding: EdgeInsets.only(bottom: bh * 0.07),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F8),
          borderRadius: BorderRadius.circular(bw * 0.16),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: unlocked
            ? Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                BoosterIcon(kind: _boosterKinds[i], size: bh * 0.7),
                Positioned(
                  right: -bw * 0.06,
                  bottom: -bh * 0.05,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: bw * 0.08),
                    decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(bh)),
                    child: Text(
                        Progress.I.boosters[_boosterKinds[i]]! > 0 ? '${Progress.I.boosters[_boosterKinds[i]]}' : '+',
                        style: titleStyle(bh * 0.28)),
                  ),
                ),
              ])
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _Lock(size: bh * 0.42),
                SizedBox(height: bh * 0.02),
                Text('Level ${_boosterLevels[i]}', style: bodyStyle(bh * 0.2, color: AppColors.textDark)),
              ]),
      ),
    );
  }

  Widget _tooltipBubble(double w, double h) {
    final bx = w * (0.5 + (_tooltip - 1) * 0.2);
    final bubbleW = w * 0.77;
    final left = (bx - bubbleW / 2).clamp(w * 0.03, w * 0.97 - bubbleW);
    return Positioned(
      left: left,
      width: bubbleW,
      bottom: h - (h * 0.93 - w * 0.07),
      child: IgnorePointer(
        child: SpeechBubble(
          text: "You'll unlock this booster soon.\nKeep playing!",
          unit: w,
          tailX: (bx - left) / bubbleW,
        ),
      ),
    );
  }

  List<Widget> _popupLayer(double w, double h) {
    void close() => setState(() => _popup = _popup == _Popup.save ? _Popup.settings : _Popup.none);
    final Widget card;
    double top = h * 0.3;
    switch (_popup) {
      case _Popup.settings:
        card = PopupCard(
          title: 'Exit Level?',
          unit: w,
          height: w * 0.63,
          onClose: close,
          child: Column(children: [
            Container(
              width: w * 0.66,
              height: w * 0.18,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(w * 0.03),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 3, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _toggle(Icons.volume_up_rounded, Progress.I.sound, w, () => Progress.I.sound = !Progress.I.sound),
                _toggle(Icons.vibration_rounded, Progress.I.vibration, w, () {
                  Progress.I.vibration = !Progress.I.vibration;
                  Sfx.I.haptic();
                }),
                _toggle(Icons.music_note_rounded, Progress.I.music, w, () {
                  Progress.I.music = !Progress.I.music;
                  Sfx.I.updateMusic();
                }),
              ]),
            ),
            SizedBox(height: w * 0.035),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              ChunkyButton(
                color: AppColors.grayBtn,
                shade: AppColors.grayBtnDark,
                width: w * 0.385,
                height: w * 0.14,
                whiteBorder: true,
                onTap: () {
                  Navigator.of(context).pushReplacement(PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const HomeScreen(),
                    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
                  ));
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.home_rounded, color: Colors.white, size: w * 0.075),
                  SizedBox(width: w * 0.01),
                  buttonLabel('Home', w * 0.065),
                ]),
              ),
              ChunkyButton(
                color: AppColors.blue,
                shade: AppColors.blueDark,
                width: w * 0.385,
                height: w * 0.14,
                whiteBorder: true,
                onTap: () => setState(() => _popup = _Popup.save),
                child: buttonLabel('Save\nprogress', w * 0.05),
              ),
            ]),
            SizedBox(height: w * 0.035),
            LegalLinks(unit: w),
          ]),
        );
        break;
      case _Popup.save:
        top = h * 0.16;
        card = PopupCard(
          title: 'SAVE PROGRESS',
          unit: w,
          height: w * 0.56,
          onClose: close,
          child: Column(children: [
            SizedBox(height: w * 0.02),
            Text('Sync your progress across\ndevices', textAlign: TextAlign.center, style: bodyStyle(w * 0.05)),
            SizedBox(height: w * 0.035),
            ChunkyButton(
              color: AppColors.green,
              shade: AppColors.greenDark,
              width: w * 0.74,
              height: w * 0.13,
              whiteBorder: true,
              onTap: () => _showToast("You're offline. Try again later."),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: w * 0.07,
                  height: w * 0.07,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(Icons.person_rounded, color: AppColors.greenDark, size: w * 0.055),
                ),
                SizedBox(width: w * 0.025),
                Text('Sign in to sync', style: bodyStyle(w * 0.048, color: Colors.white)),
              ]),
            ),
          ]),
        );
        break;
      case _Popup.deadlock:
        card = PopupCard(
          title: 'Out of space!',
          unit: w,
          height: w * 0.5,
          onClose: _restart,
          child: Column(children: [
            SizedBox(height: w * 0.02),
            Text('The shelf is full and no\ndiamond can move.', textAlign: TextAlign.center, style: bodyStyle(w * 0.05)),
            SizedBox(height: w * 0.045),
            ChunkyButton(
              color: AppColors.green,
              shade: AppColors.greenDark,
              width: w * 0.5,
              height: w * 0.14,
              whiteBorder: true,
              onTap: _restart,
              child: buttonLabel('Retry', w * 0.07),
            ),
          ]),
        );
        break;
      case _Popup.none:
        return [];
    }
    return [
      Positioned.fill(
        child: GestureDetector(
          onTap: () {},
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 180),
            builder: (_, v, __) => Container(color: AppColors.overlay.withAlpha((0xE6 * v).round())),
          ),
        ),
      ),
      Positioned(
        top: top,
        left: w * 0.03,
        child: TweenAnimationBuilder<double>(
          key: ValueKey(_popup),
          tween: Tween(begin: 0.7, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: card,
        ),
      ),
    ];
  }

  Widget _toggle(IconData icon, bool on, double w, VoidCallback flip) => Pressable(
        onTap: () {
          flip();
          Progress.I.save();
          setState(() {});
        },
        child: Icon(icon, size: w * 0.095, color: on ? AppColors.teal : AppColors.salmon),
      );

  Widget _toastView(double w, double h) => Positioned(
        left: w * 0.05,
        right: w * 0.05,
        bottom: h * 0.05,
        child: IgnorePointer(
          child: Container(
            padding: EdgeInsets.all(w * 0.035),
            decoration: BoxDecoration(color: const Color(0xFF2B2B33), borderRadius: BorderRadius.circular(8)),
            child: Text(_toast!, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ),
      );
}

class _Lock extends StatelessWidget {
  final double size;
  const _Lock({required this.size});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: _LockPainter()));
}

class _LockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final shackle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.13
      ..color = const Color(0xFF9A9BB0);
    canvas.drawArc(Rect.fromLTWH(s * 0.26, s * 0.02, s * 0.48, s * 0.5), pi, pi, false, shackle);
    canvas.drawLine(Offset(s * 0.26, s * 0.27), Offset(s * 0.26, s * 0.45), shackle);
    canvas.drawLine(Offset(s * 0.74, s * 0.27), Offset(s * 0.74, s * 0.45), shackle);
    canvas.drawCircle(Offset(s / 2, s * 0.64), s * 0.36, Paint()..color = const Color(0xFFE5E5EE));
    canvas.drawCircle(
        Offset(s / 2, s * 0.64),
        s * 0.36,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..color = const Color(0xFF9A9BB0));
    canvas.drawCircle(Offset(s / 2, s * 0.6), s * 0.08, Paint()..color = const Color(0xFF6D6E85));
    canvas.drawRect(Rect.fromCenter(center: Offset(s / 2, s * 0.72), width: s * 0.07, height: s * 0.16), Paint()..color = const Color(0xFF6D6E85));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Short "Loading....." interstitial shown between levels.
class LevelLoading extends StatefulWidget {
  const LevelLoading({super.key});
  @override
  State<LevelLoading> createState() => _LevelLoadingState();
}

class _LevelLoadingState extends State<LevelLoading> {
  int _dots = 3;
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 220), (_) => setState(() => _dots = _dots % 6 + 1));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PatternBackground(
      child: Stack(children: [
        Positioned(
          left: 0,
          right: 0,
          top: size.height * 0.88,
          child: Text('Loading${'.' * _dots}', textAlign: TextAlign.center, style: bodyStyle(size.width * 0.045, color: Colors.white)),
        ),
      ]),
    );
  }
}
