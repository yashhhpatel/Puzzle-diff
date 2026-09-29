import 'game_controller.dart';

/// Debug-only autoplay, enabled with `--dart-define=AUTOPLAY=true`.
const bool kAutoplay = bool.fromEnvironment('AUTOPLAY');

/// Performs the next sensible tap on [g] the way a player would, using only
/// [GameController.tapCell] and [GameController.tapShelf]. Returns false when
/// no move is available.
bool autoplayStep(GameController g) {
  if (g.busy || g.won) return true;
  final n = g.gems.length;
  int? emptyTarget(String c) {
    for (var i = 0; i < n; i++) {
      if (g.gems[i] == null && g.target[i] == c) return i;
    }
    return null;
  }

  // The tutorial only accepts its scripted taps.
  final tut = g.tutorial;
  if (tut != null) {
    int firstWrong(String c) => List.generate(n, (i) => i).firstWhere((i) => g.isWrong(i) && g.gems[i] == c);
    switch (tut.action) {
      case TutorialAction.pickRed:
        g.tapCell(firstWrong('R'));
      case TutorialAction.pickGreen:
        g.tapCell(firstWrong('G'));
      case TutorialAction.toShelf:
      case TutorialAction.fromShelf:
        g.tapShelf(0);
      case TutorialAction.placeGreen:
        g.tapCell(emptyTarget('G')!);
      case TutorialAction.placeRed:
        g.tapCell(emptyTarget('R')!);
    }
    return true;
  }
  // Finish a pending selection first.
  if (g.hasSelection) {
    final dest = emptyTarget(g.selColor!);
    if (dest != null) {
      g.tapCell(dest);
      return true;
    }
    if (g.selCells.isNotEmpty && g.shelf.contains(null)) {
      g.tapShelf(0);
      return true;
    }
    // Drop the selection by tapping it again.
    if (g.selCells.isNotEmpty) {
      g.tapCell(g.selCells.first);
    } else {
      g.tapShelf(g.selSlots.first);
    }
    return true;
  }
  // Shelf gems that have a free home.
  for (var s = 0; s < kShelfSize; s++) {
    final c = g.shelf[s];
    if (c != null && emptyTarget(c) != null) {
      g.tapShelf(s);
      return true;
    }
  }
  // Board gems that have a free home.
  for (var i = 0; i < n; i++) {
    if (g.isWrong(i) && emptyTarget(g.gems[i]!) != null) {
      g.tapCell(i);
      return true;
    }
  }
  // Park a group on the shelf, preferring one that frees cells the shelf needs.
  if (!g.shelf.contains(null)) return false;
  final need = g.shelf.whereType<String>().toSet();
  int? best;
  var bestScore = -1 << 30;
  for (var i = 0; i < n; i++) {
    if (!g.isWrong(i)) continue;
    final score = (need.contains(g.target[i]) ? 1000 : 0) - _groupSize(g, i);
    if (score > bestScore) {
      bestScore = score;
      best = i;
    }
  }
  if (best == null) return false;
  g.tapCell(best);
  return true;
}

int _groupSize(GameController g, int start) {
  final c = g.gems[start];
  final seen = {start};
  final q = [start];
  for (var k = 0; k < q.length; k++) {
    for (final m in g.neighbours(q[k])) {
      if (!seen.contains(m) && g.isWrong(m) && g.gems[m] == c) {
        seen.add(m);
        q.add(m);
      }
    }
  }
  return q.length;
}
