import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/ads.dart';
import 'package:sparkle_sort/screens/game_screen.dart';
import 'package:sparkle_sort/services.dart';

void main() {
  setUp(() {
    Progress.I
      ..level = 30 // all three boosters unlocked
      ..boosters = {'wand': 0, 'broom': 2, 'magnet': 2};
  });
  tearDown(() => Ads.debugShowRewarded = null);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
  }

  // The wand is the first booster button; its "+" badge is the only add icon.
  Finder plus() => find.byIcon(Icons.add_rounded);

  testWidgets('empty booster shows +, a watched ad adds 1 usable booster', (tester) async {
    var adsShown = 0;
    Ads.debugShowRewarded = () async {
      adsShown++;
      return true; // watched to the end
    };
    await open(tester);
    expect(plus(), findsOneWidget, reason: 'wand has 0, shows +');

    await tester.tap(plus());
    await tester.pump(const Duration(milliseconds: 300));
    expect(adsShown, 1);
    expect(Progress.I.boosters['wand'], 1, reason: 'reward really added to the booster count');
    expect(plus(), findsNothing);
    expect(find.text('1'), findsWidgets);

    // Using it consumes the rewarded booster through normal gameplay.
    await tester.tap(plus().evaluate().isEmpty ? find.text('1').first : plus());
    await tester.pump(const Duration(seconds: 2));
    expect(Progress.I.boosters['wand'], 0, reason: 'booster was used on the board');
    expect(plus(), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('closing the ad early gives nothing', (tester) async {
    Ads.debugShowRewarded = () async => false;
    await open(tester);
    await tester.tap(plus());
    await tester.pump(const Duration(milliseconds: 300));
    expect(Progress.I.boosters['wand'], 0);
    expect(find.text('Watch the whole video to get the booster.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  });
}
