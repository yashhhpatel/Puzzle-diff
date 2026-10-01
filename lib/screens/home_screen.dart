import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../game/autoplay.dart';
import '../game/gem_art.dart';
import '../levels.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'contact_screen.dart';
import 'game_screen.dart';
import 'shop_screen.dart';

/// Hub screen: next level, Daily Challenge, stars, shop and Remove Ads.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    Progress.I.addListener(_refresh);
    // Ticks the "next daily in" countdown.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
    if (kAutoplay) Future.delayed(const Duration(milliseconds: 1500), () => mounted ? _play() : null);
  }

  @override
  void dispose() {
    _clock?.cancel();
    Progress.I.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _play({bool daily = false}) {
    // After level 1000, Play replays a random Very Hard level.
    final replay = !daily && Progress.I.level > kMaxLevel ? 801 + Random().nextInt(kMaxLevel - 800) : null;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => GameScreen(daily: daily, replay: replay),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  Future<void> _shop({String? buy}) async {
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => ShopScreen(autoBuy: buy),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
    _refresh();
  }

  String _untilMidnight() {
    final now = DateTime.now();
    final left = DateTime(now.year, now.month, now.day + 1).difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width, h = size.height;
    final u = min(w, h * 0.56);
    final p = Progress.I;
    final allDone = p.level > kMaxLevel;
    return Scaffold(
      body: PatternBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(w * 0.035, u * 0.035, w * 0.035, 0),
              child: Row(children: [
                CoinPill(coins: p.coins, unit: u, onTap: _shop),
                SizedBox(width: u * 0.03),
                _StarPill(stars: p.totalStars, unit: u),
              ]),
            ),
            SizedBox(height: h * 0.05),
            GameLogo(width: u * 0.66),
            const Spacer(),
            ChunkyButton(
              color: AppColors.green,
              shade: AppColors.greenDark,
              width: u * 0.66,
              height: u * 0.19,
              whiteBorder: true,
              onTap: _play,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                buttonLabel(allDone ? 'Replay' : 'Play', u * 0.085),
                Text(allDone ? 'All $kMaxLevel levels done!' : 'Level ${p.level} · ${difficultyOf(p.level).label}',
                    style: bodyStyle(u * 0.04, color: Colors.white.withAlpha(230))),
              ]),
            ),
            SizedBox(height: u * 0.06),
            _dailyCard(u, p),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ChunkyButton(
                color: AppColors.blue,
                shade: AppColors.blueDark,
                width: u * 0.36,
                height: u * 0.13,
                whiteBorder: true,
                onTap: _shop,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.storefront_rounded, color: Colors.white, size: u * 0.06),
                  SizedBox(width: u * 0.015),
                  buttonLabel('Shop', u * 0.055),
                ]),
              ),
              if (!p.adsFree) ...[
                SizedBox(width: u * 0.04),
                ChunkyButton(
                  color: AppColors.bannerPurple,
                  shade: AppColors.bannerPurpleDark,
                  width: u * 0.36,
                  height: u * 0.13,
                  whiteBorder: true,
                  onTap: () => _shop(buy: StoreConfig.removeAds),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.block_rounded, color: Colors.white, size: u * 0.055),
                    SizedBox(width: u * 0.015),
                    buttonLabel('No Ads', u * 0.055),
                  ]),
                ),
              ],
            ]),
            SizedBox(height: u * 0.05),
            LegalLinks(unit: u),
            SizedBox(height: u * 0.05),
          ]),
        ),
      ),
    );
  }

  Widget _dailyCard(double u, Progress p) {
    final done = p.dailyDoneToday;
    return Container(
      width: u * 0.86,
      padding: EdgeInsets.all(u * 0.035),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(240),
        borderRadius: BorderRadius.circular(u * 0.05),
        border: Border.all(color: AppColors.popupBorder, width: u * 0.008),
        boxShadow: [BoxShadow(color: AppColors.lavenderDark.withAlpha(40), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        _Calendar(size: u * 0.16, day: DateTime.now().day),
        SizedBox(width: u * 0.035),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Daily Challenge', maxLines: 1, style: titleStyle(u * 0.055, color: AppColors.textDark)),
            ),
            SizedBox(height: u * 0.008),
            done
                ? Text('Done! New puzzle in ${_untilMidnight()}', style: bodyStyle(u * 0.036, color: AppColors.textDark.withAlpha(170), weight: 600))
                : Row(children: [
                    Text('Reward: ', style: bodyStyle(u * 0.038, color: AppColors.textDark.withAlpha(190), weight: 600)),
                    CoinIcon(size: u * 0.045),
                    Text(' $kDailyReward', style: bodyStyle(u * 0.04)),
                  ]),
          ]),
        ),
        done
            ? Icon(Icons.check_circle_rounded, color: AppColors.green, size: u * 0.1)
            : ChunkyButton(
                color: const Color(0xFFFF9F2E),
                shade: const Color(0xFFE07B0C),
                width: u * 0.2,
                height: u * 0.11,
                onTap: () => _play(daily: true),
                child: buttonLabel('Play', u * 0.05),
              ),
      ]),
    );
  }
}

class _StarPill extends StatelessWidget {
  final int stars;
  final double unit;
  const _StarPill({required this.stars, required this.unit});
  @override
  Widget build(BuildContext context) {
    final s = unit * 0.07;
    return SizedBox(
      height: s * 1.1,
      child: Stack(alignment: Alignment.centerLeft, children: [
        Container(
          margin: EdgeInsets.only(left: s * 0.45),
          padding: EdgeInsets.only(left: s * 0.75, right: s * 0.45),
          height: s * 0.86,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(s)),
          child: Text('$stars', style: bodyStyle(unit * 0.038)),
        ),
        StarIcon(size: s),
      ]),
    );
  }
}

class _Calendar extends StatelessWidget {
  final double size;
  final int day;
  const _Calendar({required this.size, required this.day});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.18),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            height: size * 0.3,
            color: AppColors.red,
            alignment: Alignment.center,
            child: Text('DAILY', style: titleStyle(size * 0.16)),
          ),
          Expanded(child: Center(child: Text('$day', style: titleStyle(size * 0.4, color: AppColors.textDark)))),
        ]),
      );
}
