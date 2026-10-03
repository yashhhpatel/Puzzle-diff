// Run with: flutter test --dart-define=AUTOPLAY=true test/daily_interstitial_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/ads.dart';
import 'package:sparkle_sort/game/autoplay.dart';
import 'package:sparkle_sort/screens/game_screen.dart';
import 'package:sparkle_sort/screens/home_screen.dart';
import 'package:sparkle_sort/services.dart';

void main() {
  testWidgets('finishing the Daily Challenge shows an interstitial, then Home', (tester) async {
    if (!kAutoplay) {
      markTestSkipped('needs --dart-define=AUTOPLAY=true');
      return;
    }
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var interstitials = 0;
    var homeWhenAdShown = true;
    Ads.debugShowInterstitial = () async {
      interstitials++;
      homeWhenAdShown = find.byType(HomeScreen).evaluate().isNotEmpty;
    };
    addTearDown(() => Ads.debugShowInterstitial = null);
    Progress.I
      ..level = 12
      ..dailyDone = 0
      ..adsFree = false
      ..coins = 500;

    await tester.pumpWidget(const MaterialApp(home: GameScreen(daily: true)));
    // Autoplay solves the puzzle; the result screen auto-presses Next.
    for (var t = 0; t < 4000 && interstitials == 0; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(interstitials, 1, reason: 'one interstitial after the Daily Challenge');
    expect(homeWhenAdShown, isFalse, reason: 'ad shows after completion, before going Home');
    expect(Progress.I.dailyDoneToday, isTrue);
    expect(Progress.I.coins, 550, reason: 'daily reward paid');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    // Autoplay's Home starts the next game after 1.5s; let that timer run out.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Remove Ads owners get no interstitial after the Daily Challenge', (tester) async {
    if (!kAutoplay) return;
    var interstitials = 0;
    Ads.debugShowInterstitial = () async => interstitials++;
    addTearDown(() => Ads.debugShowInterstitial = null);
    Progress.I.adsFree = true;
    addTearDown(() => Progress.I.adsFree = false);
    await Ads.I.showInterstitial();
    expect(interstitials, 0);
  });
}
