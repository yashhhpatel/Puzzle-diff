import 'dart:math';

import '../levels.dart';
import 'autoplay.dart';
import 'game_controller.dart';

final Map<Object, int> _parCache = {};

/// Moves a straightforward player needs for [data]: the autoplay route.
int parMoves(Object key, LevelData data, {bool tutorial = false}) {
  return _parCache.putIfAbsent(key, () {
    final g = GameController(0, tutorial: tutorial, data: data);
    var t = 0.0;
    for (var step = 0; step < 2000 && !g.isSolved; step++) {
      if (!autoplayStep(g)) break;
      for (var k = 0; k < 60 && (g.busy || k < 1); k++) {
        g.tick(t += 0.05);
      }
    }
    return max(1, g.moves);
  });
}

/// 3 stars at or under par, 2 within 40% over par, otherwise 1.
int starsFor(int moves, int par) {
  if (moves <= par) return 3;
  if (moves <= (par * 1.4).ceil()) return 2;
  return 1;
}
