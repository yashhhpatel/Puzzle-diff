import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads.dart';
import '../billing.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Boot screen: logo, "Loading......" and a percentage bar.
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  int _dots = 6;
  Timer? _dotTimer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _dotTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() => _dots = _dots % 6 + 1));
    // Bar runs to 86% while assets load, then finishes.
    _c.animateTo(0.86, duration: const Duration(milliseconds: 1600), curve: Curves.easeOut);
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait([
      Progress.I.load().then((_) => Sfx.I.init()),
      Future.delayed(const Duration(milliseconds: 1900)),
    ]);
    // Store and ads connect in the background; nothing waits on them.
    Billing.I.init();
    Ads.I.init();
    if (!mounted) return;
    await _c.animateTo(1, duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
    await Future.delayed(const Duration(milliseconds: 350));
    // App Open ad on returning launches (never the first one after install).
    await Ads.I.showAppOpenOnLaunch();
    if (!mounted || _ready) return;
    _ready = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => Progress.I.onboarded ? const HomeScreen() : const OnboardingScreen(),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width, h = size.height;
    return Scaffold(
      body: PatternBackground(
        child: Stack(children: [
          Positioned(left: w * 0.1, right: w * 0.1, top: h * 0.29, child: Center(child: GameLogo(width: w * 0.72))),
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.785,
            child: Text('Loading${'.' * _dots}', textAlign: TextAlign.center, style: bodyStyle(w * 0.064, color: const Color(0xFF8C90B8))),
          ),
          Positioned(
            left: w * 0.16,
            right: w * 0.16,
            top: h * 0.845,
            height: w * 0.052,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => _ProgressBar(value: _c.value, unit: w),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: h * 0.94,
            child: Text('v1.0.0', textAlign: TextAlign.center, style: bodyStyle(w * 0.03, color: const Color(0xFFA6A8C8))),
          ),
        ]),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value, unit;
  const _ProgressBar({required this.value, required this.unit});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, box) => ClipRRect(
          borderRadius: BorderRadius.circular(unit * 0.012),
          child: Stack(children: [
            Container(color: AppColors.barTrack),
            Container(width: box.maxWidth * value, color: AppColors.barFill),
            Center(
              child: Text('${(value * 100).round()} %',
                  style: titleStyle(unit * 0.042, shadows: [Shadow(color: Colors.black.withAlpha(50), offset: const Offset(0, 1))])),
            ),
          ]),
        ),
      );
}
