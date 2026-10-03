import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/game/game_controller.dart';
import 'package:sparkle_sort/game/stars.dart';
import 'package:sparkle_sort/levels.dart';

class _Stats {
  int n = 0;
  double cells = 0, colors = 0, wrong = 0, moves = 0;
  void add(double c, double k, double w, double m) {
    n++;
    cells += c;
    colors += k;
    wrong += w;
    moves += m;
  }

  String row(String name) => '$name: levels=$n cells=${(cells / n).toStringAsFixed(1)} '
      'colours=${(colors / n).toStringAsFixed(2)} misplaced=${(wrong / n * 100).toStringAsFixed(0)}% '
      'parMoves=${(moves / n).toStringAsFixed(1)}';
}

void main() {
  test('all 1000 levels are valid, solvable, and get harder tier by tier', () {
    const mainTiers = [Difficulty.easy, Difficulty.medium, Difficulty.hard, Difficulty.veryHard];
    final tiers = {for (final d in mainTiers) d: _Stats()};
    final blocks = List.generate(10, (_) => _Stats());
    final seen = <String>{};
    for (var level = 1; level <= 1000; level++) {
      final d = buildLevel(level);
      expect(d.target.length, d.cols * d.rows, reason: 'level $level size');
      expect(d.cols, lessThanOrEqualTo(12));
      expect(d.rows, lessThanOrEqualTo(14));
      final want = <String, int>{}, have = <String, int>{};
      var cells = 0, wrong = 0;
      for (var i = 0; i < d.target.length; i++) {
        expect(d.target[i] == null, d.initial[i] == null, reason: 'level $level cell $i');
        if (d.target[i] == null) continue;
        cells++;
        if (d.initial[i] != d.target[i]) wrong++;
        want[d.target[i]!] = (want[d.target[i]!] ?? 0) + 1;
        have[d.initial[i]!] = (have[d.initial[i]!] ?? 0) + 1;
      }
      expect(have, want, reason: 'level $level colour counts');
      expect(wrong, greaterThan(0), reason: 'level $level already solved');
      expect(solvableGreedy(d.cols, d.rows, d.target, d.initial, kShelfSize), isTrue, reason: 'level $level');
      // Every level is a different puzzle.
      expect(seen.add(d.target.join() + d.initial.join()), isTrue, reason: 'level $level duplicates another');
      final (solved, par) = simulate(d, tutorial: level == 1);
      expect(solved, isTrue, reason: 'level $level: tap playthrough did not finish');
      tiers[difficultyOf(level)]!.add(cells.toDouble(), want.length.toDouble(), wrong / cells, par.toDouble());
      blocks[(level - 1) ~/ 100].add(cells.toDouble(), want.length.toDouble(), wrong / cells, par.toDouble());
    }
    for (final d in mainTiers) {
      // ignore: avoid_print
      print(tiers[d]!.row(d.label));
    }
    for (var b = 0; b < 10; b++) {
      // ignore: avoid_print
      print(blocks[b].row('levels ${b * 100 + 1}-${b * 100 + 100}'));
    }
    // Each tier is harder than the one before on every measure.
    final t = mainTiers.map((d) => tiers[d]!).toList();
    for (var i = 1; i < t.length; i++) {
      expect(t[i].cells / t[i].n, greaterThan(t[i - 1].cells / t[i - 1].n));
      expect(t[i].colors / t[i].n, greaterThan(t[i - 1].colors / t[i - 1].n));
      expect(t[i].wrong / t[i].n, greaterThan(t[i - 1].wrong / t[i - 1].n));
      expect(t[i].moves / t[i].n, greaterThan(t[i - 1].moves / t[i - 1].n));
    }
    // And the climb is gradual: average moves rise from one 100-level block
    // to the next without big jumps.
    for (var b = 1; b < 10; b++) {
      final prev = blocks[b - 1].moves / blocks[b - 1].n, cur = blocks[b].moves / blocks[b].n;
      expect(cur, greaterThan(prev * 0.97), reason: 'block $b got easier');
      expect(cur, lessThan(prev * 1.8), reason: 'block $b jumps too much');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));

  test('tier boundaries', () {
    expect(difficultyOf(1), Difficulty.easy);
    expect(difficultyOf(200), Difficulty.easy);
    expect(difficultyOf(201), Difficulty.medium);
    expect(difficultyOf(500), Difficulty.medium);
    expect(difficultyOf(501), Difficulty.hard);
    expect(difficultyOf(800), Difficulty.hard);
    expect(difficultyOf(801), Difficulty.veryHard);
    expect(difficultyOf(1000), Difficulty.veryHard);
  });
}
