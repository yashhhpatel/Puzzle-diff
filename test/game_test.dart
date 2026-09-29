import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/game/game_controller.dart';
import 'package:sparkle_sort/levels.dart';

void main() {
  test('every level builds a valid, solvable permutation', () {
    for (var lvl = 1; lvl <= pictureCount * 2; lvl++) {
      final d = buildLevel(lvl);
      expect(d.target.length, d.cols * d.rows, reason: 'level $lvl size');
      final want = <String, int>{}, have = <String, int>{};
      for (var i = 0; i < d.target.length; i++) {
        expect(d.target[i] == null, d.initial[i] == null, reason: 'level $lvl cell $i');
        if (d.target[i] != null) want[d.target[i]!] = (want[d.target[i]!] ?? 0) + 1;
        if (d.initial[i] != null) have[d.initial[i]!] = (have[d.initial[i]!] ?? 0) + 1;
      }
      expect(have, want, reason: 'level $lvl colour counts');
      final wrong = List.generate(d.target.length, (i) => i).where((i) => d.initial[i] != d.target[i]).length;
      expect(wrong, greaterThan(0), reason: 'level $lvl already solved');
      expect(solvableGreedy(d.cols, d.rows, d.target, d.initial, kShelfSize), isTrue, reason: 'level $lvl solvable');
    }
  });

  test('tutorial level plays through the six guided steps', () {
    final g = GameController(1, tutorial: true);
    var t = 0.0;
    void settle() {
      for (var k = 0; k < 200; k++) {
        t += 0.05;
        g.tick(t);
      }
    }

    var won = false;
    g.onWin = () => won = true;
    // Step 0 only accepts the red group.
    g.tapCell(0); // green gem: ignored
    expect(g.hasSelection, isFalse);
    g.tapCell(3 * 6 + 2);
    expect(g.selCells.length, 12);
    g.tapShelf(6);
    settle();
    expect(g.shelf.whereType<String>().length, 12);
    g.tapCell(0);
    expect(g.selColor, 'G');
    g.tapCell(3 * 6 + 3);
    settle();
    g.tapShelf(0);
    expect(g.selSlots.length, 12);
    g.tapCell(3);
    settle();
    expect(g.isSolved, isTrue);
    expect(won, isTrue);
    expect(g.tutorial, isNull);
  });

  test('boosters fix gems and keep colour counts', () {
    int wrong(GameController g) => List.generate(g.gems.length, (i) => i).where(g.isWrong).length;
    Map<String, int> counts(GameController g) {
      final m = <String, int>{};
      for (final c in [...g.gems, ...g.shelf].whereType<String>()) {
        m[c] = (m[c] ?? 0) + 1;
      }
      return m;
    }

    for (final use in <bool Function(GameController)>[(g) => g.useWand(), (g) => g.useBroom(), (g) => g.useMagnet()]) {
      final g = GameController(8);
      // Park a group so the magnet has free homes to fill.
      g.tapCell(List.generate(g.gems.length, (i) => i).firstWhere(g.isWrong));
      g.tapShelf(0);
      var t = 0.0;
      for (var k = 0; k < 60; k++) {
        g.tick(t += 0.05);
      }
      final before = wrong(g) + g.shelf.whereType<String>().length;
      final c0 = counts(g);
      expect(use(g), isTrue);
      for (var k = 0; k < 60; k++) {
        g.tick(t += 0.05);
      }
      expect(wrong(g) + g.shelf.whereType<String>().length, lessThan(before));
      expect(counts(g), c0);
      expect(g.busy, isFalse);
    }
  });

  test('wrong colour target is rejected and shelf overflow keeps the rest', () {
    final g = GameController(2);
    var t = 0.0;
    // Red group (stem + base, 12 gems) to shelf.
    final red = List.generate(g.gems.length, (i) => i).firstWhere((i) => g.isWrong(i) && g.gems[i] == 'R');
    g.tapCell(red);
    final n = g.selCells.length;
    expect(n, greaterThan(0));
    g.tapShelf(0);
    for (var k = 0; k < 100; k++) {
      g.tick(t += 0.05);
    }
    expect(g.shelf.whereType<String>().length, n.clamp(0, kShelfSize));
    // Selecting shelf red and tapping an empty maroon cell is refused.
    g.tapShelf(0);
    final maroonEmpty = List.generate(g.gems.length, (i) => i).firstWhere((i) => g.gems[i] == null && g.target[i] == 'M');
    g.tapCell(maroonEmpty);
    expect(g.gems[maroonEmpty], isNull);
  });
}
