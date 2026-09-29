import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config.dart';
import 'services.dart';

/// Interstitial ads shown between levels.
class Ads {
  static final Ads I = Ads._();
  Ads._();

  InterstitialAd? _ad;
  bool _loading = false;
  bool _initialised = false;
  int _retry = 0;

  Future<void> init() async {
    if (_initialised || Progress.I.adsFree) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
      _load();
    } catch (e) {
      debugPrint('ads init failed: $e');
    }
  }

  /// Level [completedLevel] earns an interstitial when it is a multiple of
  /// [AdConfig.levelsPerInterstitial] and the player has not bought Remove Ads.
  static bool isDue(int completedLevel, {required bool adsFree}) =>
      !adsFree && completedLevel > 0 && completedLevel % AdConfig.levelsPerInterstitial == 0;

  void _load() {
    if (_loading || _ad != null || Progress.I.adsFree || !_initialised) return;
    _loading = true;
    InterstitialAd.load(
      adUnitId: AdConfig.androidInterstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loading = false;
          _retry = 0;
          _ad = ad;
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          debugPrint('interstitial failed to load: $err');
          // Back off and try again; the game never waits on this.
          final delay = Duration(seconds: [5, 15, 30, 60][_retry.clamp(0, 3)]);
          _retry++;
          Timer(delay, _load);
        },
      ),
    );
  }

  /// Shows the interstitial after [completedLevel] if one is due and ready.
  /// Completes once the ad is closed, fails, or was skipped, so the caller can
  /// safely start the next level afterwards.
  Future<void> afterLevel(int completedLevel) async {
    if (!isDue(completedLevel, adsFree: Progress.I.adsFree)) return;
    final ad = _ad;
    if (ad == null) {
      // Not ready (offline, no fill...): don't block the player.
      _load();
      return;
    }
    _ad = null;
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => Sfx.I.pauseMusic(),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        debugPrint('interstitial failed to show: $err');
        a.dispose();
        finish();
      },
    );
    try {
      await ad.show();
    } catch (e) {
      debugPrint('interstitial show threw: $e');
      finish();
    }
    await done.future;
    Sfx.I.updateMusic();
    _load();
  }
}
