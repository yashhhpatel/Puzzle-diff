import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/ads.dart';
import 'package:sparkle_sort/billing.dart';
import 'package:sparkle_sort/config.dart';
import 'package:sparkle_sort/game/game_controller.dart';
import 'package:sparkle_sort/game/stars.dart';
import 'package:sparkle_sort/levels.dart';
import 'package:sparkle_sort/services.dart';

void main() {
  test('interstitial is due after every 2nd completed level only', () {
    final due = [for (var l = 1; l <= 8; l++) Ads.isDue(l, adsFree: false)];
    expect(due, [false, true, false, true, false, true, false, true]);
    for (var l = 1; l <= 8; l++) {
      expect(Ads.isDue(l, adsFree: true), isFalse, reason: 'Remove Ads owner saw an ad at level $l');
    }
  });

  test('purchases are granted once per purchase id', () {
    final p = Progress.I
      ..coins = 100
      ..adsFree = false
      ..grantedPurchases = []
      ..boosters = {'wand': 0, 'broom': 1, 'magnet': 2};
    expect(Billing.grant(StoreConfig.coins550, 'GPA.1', p), isTrue);
    expect(p.coins, 650);
    // The store re-delivering the same purchase must not pay out again.
    expect(Billing.grant(StoreConfig.coins550, 'GPA.1', p), isTrue);
    expect(p.coins, 650);
    expect(Billing.grant(StoreConfig.boosterBundle, 'GPA.2', p), isTrue);
    expect(p.coins, 1550);
    expect(p.boosters, {'wand': 2, 'broom': 3, 'magnet': 4});
    expect(Billing.grant(StoreConfig.removeAds, 'GPA.3', p), isTrue);
    expect(p.adsFree, isTrue);
    expect(Billing.grant('unknown_sku', 'GPA.4', p), isFalse);
    expect(p.coins, 1550);
  });

  test('star thresholds', () {
    expect(starsFor(10, 10), 3);
    expect(starsFor(14, 10), 2);
    expect(starsFor(15, 10), 1);
  });

  test('par is reachable: the autoplay route earns 3 stars on every level', () {
    for (var lvl = 1; lvl <= 17; lvl++) {
      final par = parMoves('t$lvl', buildLevel(lvl), tutorial: lvl == 1);
      expect(par, greaterThan(0));
      expect(starsFor(par, par), 3);
    }
  });

  test('daily challenge: deterministic per day, valid and solvable for 60 days', () {
    final start = DateTime(2026, 9, 1);
    for (var d = 0; d < 60; d++) {
      final day = start.add(Duration(days: d));
      final a = buildDaily(day), b = buildDaily(day);
      expect(a.initial, b.initial, reason: 'same day must give the same puzzle');
      final want = <String, int>{}, have = <String, int>{};
      for (var i = 0; i < a.target.length; i++) {
        if (a.target[i] != null) want[a.target[i]!] = (want[a.target[i]!] ?? 0) + 1;
        if (a.initial[i] != null) have[a.initial[i]!] = (have[a.initial[i]!] ?? 0) + 1;
      }
      expect(have, want);
      expect(solvableGreedy(a.cols, a.rows, a.target, a.initial, kShelfSize), isTrue, reason: '$day');
    }
    expect(buildDaily(DateTime(2026, 9, 1)).initial, isNot(buildDaily(DateTime(2026, 9, 2)).initial));
  });
}
