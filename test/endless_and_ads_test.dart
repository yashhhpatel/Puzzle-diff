import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/ads.dart';
import 'package:sparkle_sort/game/game_controller.dart';
import 'package:sparkle_sort/game/stars.dart';
import 'package:sparkle_sort/levels.dart';

void main() {
  test('levels keep going past 1000: valid, solvable, Master tier', () {
    final levels = [
      for (var l = 1001; l <= 1060; l++) l,
      1500, 2000, 2777, 5000, 10000, 25000, 99999, 250000,
    ];
    for (final level in levels) {
      expect(difficultyOf(level), Difficulty.master);
      final d = buildLevel(level);
      final want = <String, int>{}, have = <String, int>{};
      for (var i = 0; i < d.target.length; i++) {
        expect(d.target[i] == null, d.initial[i] == null);
        if (d.target[i] != null) want[d.target[i]!] = (want[d.target[i]!] ?? 0) + 1;
        if (d.initial[i] != null) have[d.initial[i]!] = (have[d.initial[i]!] ?? 0) + 1;
      }
      expect(have, want, reason: 'level $level colour counts');
      expect(solvableGreedy(d.cols, d.rows, d.target, d.initial, kShelfSize), isTrue, reason: 'level $level');
      final (solved, _) = simulate(d);
      expect(solved, isTrue, reason: 'level $level tap playthrough');
    }
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('difficulty never drops and keeps creeping up after 1000', () {
    double block(int start) {
      var s = 0.0;
      for (var l = start; l < start + 10; l++) {
        s += difficultyCurve(l);
      }
      return s / 10;
    }

    var prev = block(1);
    for (var start = 11; start < 20000; start += 10) {
      final cur = block(start);
      expect(cur, greaterThanOrEqualTo(prev - 1e-9), reason: 'block at $start got easier');
      prev = cur;
    }
    // Single levels follow the 10-level saw-tooth (1001 is a breather after
    // milestone 1000), so compare 10-level blocks.
    expect(block(1001), greaterThanOrEqualTo(block(991)));
    expect(block(5001), greaterThan(block(2001)));
    expect(difficultyCurve(1000000), lessThanOrEqualTo(1.3));
    // Board stays within what fits on screen.
    final spec = specFor(1000000);
    expect(spec.cols, lessThanOrEqualTo(12));
    expect(spec.rows, lessThanOrEqualTo(14));
    expect(spec.colors, lessThanOrEqualTo(6));
    expect(spec.scramble, lessThanOrEqualTo(0.9));
  });

  test('App Open ads: never on the first launch, then on later launches', () {
    expect(Ads.appOpenAllowed(launchCount: 1, adsFree: false), isFalse);
    expect(Ads.appOpenAllowed(launchCount: 2, adsFree: false), isTrue);
    expect(Ads.appOpenAllowed(launchCount: 9, adsFree: false), isTrue);
    expect(Ads.appOpenAllowed(launchCount: 9, adsFree: true), isFalse);
  });
}
