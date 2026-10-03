import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'config.dart';
import 'services.dart';

/// All AdMob formats: interstitial (between levels / after the Daily
/// Challenge), App Open, Rewarded (boosters) and the anchored banner.
class Ads {
  static final Ads I = Ads._();
  Ads._();

  /// Test hooks standing in for the ad SDK in widget tests.
  @visibleForTesting
  static Future<bool> Function()? debugShowRewarded;
  @visibleForTesting
  static Future<void> Function()? debugShowInterstitial;

  bool _initialised = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  int _interstitialRetry = 0;

  AppOpenAd? _appOpen;
  DateTime? _appOpenLoadedAt;
  bool _loadingAppOpen = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  /// A full-screen ad is on screen right now.
  bool _showing = false;

  /// Resumes before this moment don't trigger an App Open ad (returning from
  /// an ad, the Play purchase sheet, the mail app...).
  DateTime _resumeQuietUntil = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('ads init failed: $e');
      return;
    }
    _loadInterstitial();
    _loadAppOpen();
    _loadRewarded();
  }

  bool get _noAds => Progress.I.adsFree;

  /// Call before leaving the app on purpose (purchase, browser, email) so
  /// coming back doesn't show an App Open ad.
  void quietNextResume([Duration d = const Duration(minutes: 10)]) => _resumeQuietUntil = DateTime.now().add(d);

  void _afterFullScreen() {
    _showing = false;
    // Closing a full-screen ad resumes the app; that isn't an "app open".
    _resumeQuietUntil = DateTime.now().add(const Duration(seconds: 3));
  }

  // ------------------------------------------------------------------ interstitial

  /// Level [completedLevel] earns an interstitial when it is a multiple of
  /// [AdConfig.levelsPerInterstitial] and the player has not bought Remove Ads.
  static bool isDue(int completedLevel, {required bool adsFree}) =>
      !adsFree && completedLevel > 0 && completedLevel % AdConfig.levelsPerInterstitial == 0;

  void _loadInterstitial() {
    if (_loadingInterstitial || _interstitial != null || _noAds || !_initialised) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.androidInterstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialRetry = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          debugPrint('interstitial failed to load: $err');
          // Back off and try again; the game never waits on this.
          final delay = Duration(seconds: [5, 15, 30, 60][_interstitialRetry.clamp(0, 3)]);
          _interstitialRetry++;
          Timer(delay, _loadInterstitial);
        },
      ),
    );
  }

  /// Shows the interstitial after [completedLevel] if one is due and ready.
  Future<void> afterLevel(int completedLevel) async {
    if (!isDue(completedLevel, adsFree: _noAds)) return;
    await showInterstitial();
  }

  /// Shows an interstitial if one is ready and the player hasn't removed ads.
  /// Completes once it is closed, fails, or was skipped, so callers can
  /// safely continue afterwards.
  Future<void> showInterstitial() async {
    if (_noAds || _showing) return;
    if (debugShowInterstitial != null) return debugShowInterstitial!();
    final ad = _interstitial;
    if (ad == null) {
      // Not ready (offline, no fill...): don't block the player.
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    await _present(ad, (cb) => ad.fullScreenContentCallback = cb, ad.show);
    _loadInterstitial();
  }

  // ------------------------------------------------------------------ app open

  void _loadAppOpen() {
    if (_loadingAppOpen || _appOpen != null || _noAds || !_initialised) return;
    _loadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: AdConfig.androidAppOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingAppOpen = false;
          _appOpen = ad;
          _appOpenLoadedAt = DateTime.now();
        },
        onAdFailedToLoad: (err) {
          _loadingAppOpen = false;
          debugPrint('app open failed to load: $err');
          Timer(const Duration(seconds: 30), _loadAppOpen);
        },
      ),
    );
  }

  /// App Open ads are skipped for the whole first session after install, so a
  /// new player's first impression is the game itself.
  static bool appOpenAllowed({required int launchCount, required bool adsFree}) => !adsFree && launchCount > 1;

  bool get _appOpenFresh =>
      _appOpen != null && _appOpenLoadedAt != null && DateTime.now().difference(_appOpenLoadedAt!) < AdConfig.appOpenMaxAge;

  /// On a cold start: waits briefly for an App Open ad and shows it.
  Future<void> showAppOpenOnLaunch({Duration wait = const Duration(seconds: 3)}) async {
    if (!appOpenAllowed(launchCount: Progress.I.launchCount, adsFree: _noAds)) return;
    final until = DateTime.now().add(wait);
    while (!_appOpenFresh && DateTime.now().isBefore(until)) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
    await _showAppOpen();
  }

  /// When the app comes back from the background.
  Future<void> onAppResumed() async {
    if (!appOpenAllowed(launchCount: Progress.I.launchCount, adsFree: _noAds)) return;
    if (_showing || DateTime.now().isBefore(_resumeQuietUntil)) return;
    await _showAppOpen();
  }

  Future<void> _showAppOpen() async {
    if (_showing) return;
    if (!_appOpenFresh) {
      _appOpen?.dispose();
      _appOpen = null;
      _loadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    await _present(ad, (cb) => ad.fullScreenContentCallback = cb, ad.show);
    _loadAppOpen();
  }

  // ------------------------------------------------------------------ rewarded

  void _loadRewarded() {
    if (_loadingRewarded || _rewarded != null || !_initialised) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.androidRewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewarded = ad;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          debugPrint('rewarded failed to load: $err');
          Timer(const Duration(seconds: 20), _loadRewarded);
        },
      ),
    );
  }

  bool get rewardedReady => debugShowRewarded != null || _rewarded != null;

  void preloadRewarded() => _loadRewarded();

  /// Shows a rewarded ad. Completes with true only if the player watched it
  /// long enough to earn the reward. Rewarded ads are opt-in, so they are
  /// offered even to Remove Ads owners.
  Future<bool> showRewarded() async {
    if (_showing) return false;
    if (debugShowRewarded != null) return debugShowRewarded!();
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    await _present(ad, (cb) => ad.fullScreenContentCallback = cb, () => ad.show(onUserEarnedReward: (_, __) => earned = true));
    _loadRewarded();
    return earned;
  }

  // ------------------------------------------------------------------ shared

  Future<void> _present<T extends Ad>(T ad, void Function(FullScreenContentCallback<T>) setCallback, Future<void> Function() show) async {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    _showing = true;
    setCallback(FullScreenContentCallback<T>(
      onAdShowedFullScreenContent: (_) => Sfx.I.pauseMusic(),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        debugPrint('full-screen ad failed to show: $err');
        a.dispose();
        finish();
      },
    ));
    try {
      await show();
    } catch (e) {
      debugPrint('ad show threw: $e');
      finish();
    }
    await done.future;
    _afterFullScreen();
    Sfx.I.updateMusic();
  }
}

/// Adaptive anchored banner pinned to the bottom edge, full screen width.
/// Collapses to nothing for Remove Ads owners or when no ad is available.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});
  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  int? _width;

  @override
  void initState() {
    super.initState();
    Progress.I.addListener(_onProgress);
  }

  void _onProgress() {
    if (Progress.I.adsFree && _ad != null) {
      _ad!.dispose();
      setState(() {
        _ad = null;
        _loaded = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    if (Progress.I.adsFree || kIsWeb) return;
    final AnchoredAdaptiveBannerAdSize? size;
    try {
      size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    } catch (e) {
      // Ads SDK unavailable: no banner, game unaffected.
      debugPrint('banner size failed: $e');
      return;
    }
    if (size == null || !mounted) return;
    _ad?.dispose();
    final ad = BannerAd(
      adUnitId: AdConfig.androidBanner,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (a, err) {
          debugPrint('banner failed to load: $err');
          a.dispose();
          if (mounted) setState(() => _loaded = false);
          // Try again later; layout simply has no banner meanwhile.
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted && _width == width) _load(width);
          });
        },
      ),
    );
    setState(() {
      _ad = ad;
      _size = size;
      _loaded = false;
    });
    await ad.load();
  }

  @override
  void dispose() {
    Progress.I.removeListener(_onProgress);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad, size = _size;
    // Edge to edge: full width, with the system gesture/nav inset below it.
    final inset = MediaQuery.viewPaddingOf(context).bottom;
    if (Progress.I.adsFree || ad == null || size == null || !_loaded) return SizedBox(height: inset);
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.only(bottom: inset),
      alignment: Alignment.topCenter,
      child: SizedBox(width: size.width.toDouble(), height: size.height.toDouble(), child: AdWidget(ad: ad)),
    );
  }
}
