import 'dart:math';

import 'package:flutter/foundation.dart';

import '../levels.dart';

const int kShelfSize = 12;

/// A position a gem can occupy: a board cell or a shelf slot.
class Loc {
  final bool shelf;
  final int index;
  const Loc.cell(this.index) : shelf = false;
  const Loc.slot(this.index) : shelf = true;
}

class Flight {
  final String color;
  final Loc from, to;
  final double start, dur;
  final bool fromLifted;
  final VoidCallback onLand;
  bool landed = false;
  Flight(this.color, this.from, this.to, this.start, this.dur, this.fromLifted, this.onLand);
}

class Shine {
  final Set<int> cells;
  final double start;
  Shine(this.cells, this.start);
}

enum TutorialAction { pickRed, toShelf, pickGreen, placeGreen, fromShelf, placeRed }

class TutorialStep {
  final String text;
  final TutorialAction action;
  const TutorialStep(this.text, this.action);
}

const kTutorial = [
  TutorialStep('Tap a group of red diamonds', TutorialAction.pickRed),
  TutorialStep('Put them on the shelf', TutorialAction.toShelf),
  TutorialStep('Tap a group of green diamonds', TutorialAction.pickGreen),
  TutorialStep('Put them in the green cells', TutorialAction.placeGreen),
  TutorialStep('Take the red diamonds from the shelf', TutorialAction.fromShelf),
  TutorialStep('Now move the diamonds into their places', TutorialAction.placeRed),
];

/// Board rules and the animation timeline for one level.
class GameController extends ChangeNotifier {
  final int level;
  late final int cols, rows;
  late final List<String?> target;
  late final List<String?> gems;
  final List<String?> shelf = List.filled(kShelfSize, null);

  // Selection: either a group of board cells or a set of shelf slots.
  final Set<int> selCells = {};
  final List<int> selSlots = [];
  String? selColor;
  double selTime = 0;
  double shakeTime = -10;

  final List<Flight> flights = [];
  final Set<int> hiddenCells = {};
  final Set<int> hiddenSlots = {};
  final List<Shine> shines = [];
  final Set<int> landedCells = {};

  double now = 0;
  int tutorialStep = -1;
  bool won = false;
  bool _checkPending = false;

  void Function(String sfx)? onSound;
  VoidCallback? onHaptic;
  VoidCallback? onWin;
  VoidCallback? onDeadlock;

  /// Completed actions (a group parked on the shelf or placed in cells);
  /// drives the star rating. Selections and boosters are free.
  int moves = 0;

  GameController(this.level, {bool tutorial = false, LevelData? data}) {
    final d = data ?? buildLevel(level);
    cols = d.cols;
    rows = d.rows;
    target = d.target;
    gems = List.of(d.initial);
    if (tutorial) tutorialStep = 0;
  }

  bool get busy => flights.isNotEmpty;
  bool get hasSelection => selColor != null;
  bool isCell(int i) => target[i] != null;
  bool isWrong(int i) => gems[i] != null && gems[i] != target[i];
  TutorialStep? get tutorial => tutorialStep >= 0 && tutorialStep < kTutorial.length ? kTutorial[tutorialStep] : null;

  List<int> neighbours(int i) {
    final x = i % cols, y = i ~/ cols;
    return [
      if (x > 0) i - 1,
      if (x < cols - 1) i + 1,
      if (y > 0) i - cols,
      if (y < rows - 1) i + cols,
    ];
  }

  List<int> _flood(int start, bool Function(int) ok) {
    final out = <int>[start];
    final seen = {start};
    for (var k = 0; k < out.length; k++) {
      for (final n in neighbours(out[k])) {
        if (!seen.contains(n) && ok(n)) {
          seen.add(n);
          out.add(n);
        }
      }
    }
    return out;
  }

  void _deselect() {
    selCells.clear();
    selSlots.clear();
    selColor = null;
  }

  void _shake() {
    shakeTime = now;
    onSound?.call('error');
    onHaptic?.call();
    notifyListeners();
  }

  bool _tutorialAllows(TutorialAction a) => tutorial == null || tutorial!.action == a;
  void _advanceTutorial(TutorialAction a) {
    if (tutorial?.action == a) tutorialStep++;
  }

  // ---------------------------------------------------------------- input

  void tapCell(int i) {
    if (busy || won) return;
    if (i < 0 || !isCell(i)) {
      if (tutorial == null) _deselect();
      notifyListeners();
      return;
    }
    final g = gems[i];
    if (g != null && g != target[i]) {
      final action = g == 'R' ? TutorialAction.pickRed : TutorialAction.pickGreen;
      if (!_tutorialAllows(action)) return;
      if (selCells.contains(i)) {
        _deselect();
      } else {
        _deselect();
        selCells.addAll(_flood(i, (n) => isWrong(n) && gems[n] == g));
        selColor = g;
        selTime = now;
        onSound?.call('pick');
        onHaptic?.call();
        _advanceTutorial(action);
      }
      notifyListeners();
      return;
    }
    if (g == null) {
      if (!hasSelection) return;
      if (selColor != target[i]) {
        if (tutorial == null) _shake();
        return;
      }
      final action = selColor == 'G' ? TutorialAction.placeGreen : TutorialAction.placeRed;
      if (!_tutorialAllows(action)) return;
      _placeInto(i);
      _advanceTutorial(action);
      notifyListeners();
      return;
    }
    if (tutorial == null) {
      _deselect();
      notifyListeners();
    }
  }

  void tapShelf(int slot) {
    if (busy || won) return;
    if (selCells.isNotEmpty) {
      if (!_tutorialAllows(TutorialAction.toShelf)) return;
      if (!shelf.contains(null)) {
        _shake();
        return;
      }
      _moveSelectionToShelf();
      _advanceTutorial(TutorialAction.toShelf);
      notifyListeners();
      return;
    }
    if (selSlots.isNotEmpty) {
      if (tutorial != null) return;
      _deselect();
      notifyListeners();
      return;
    }
    if (!_tutorialAllows(TutorialAction.fromShelf)) return;
    String? color = slot >= 0 && slot < kShelfSize ? shelf[slot] : null;
    color ??= shelf.firstWhere((s) => s != null, orElse: () => null);
    if (color == null) return;
    for (var s = 0; s < kShelfSize; s++) {
      if (shelf[s] == color) selSlots.add(s);
    }
    selColor = color;
    selTime = now;
    onSound?.call('pick');
    onHaptic?.call();
    _advanceTutorial(TutorialAction.fromShelf);
    notifyListeners();
  }

  // ---------------------------------------------------------------- moves

  void _moveSelectionToShelf() {
    moves++;
    final free = [for (var s = 0; s < kShelfSize; s++) if (shelf[s] == null) s];
    final cells = selCells.toList()..sort();
    final n = min(free.length, cells.length);
    for (var k = 0; k < n; k++) {
      final cell = cells[k], slot = free[k];
      final color = gems[cell]!;
      gems[cell] = null;
      shelf[slot] = color;
      hiddenSlots.add(slot);
      selCells.remove(cell);
      flights.add(Flight(color, Loc.cell(cell), Loc.slot(slot), now + k * 0.045, 0.38, true, () {
        hiddenSlots.remove(slot);
        onSound?.call('shelf');
      }));
    }
    if (selCells.isEmpty) _deselect();
    _checkPending = true;
  }

  void _placeInto(int tapped) {
    moves++;
    final color = selColor!;
    final region = _flood(tapped, (n) => gems[n] == null && target[n] == color);
    int dist(int a, int b) => (a % cols - b % cols).abs() + (a ~/ cols - b ~/ cols).abs();
    final List<Loc> sources;
    if (selCells.isNotEmpty) {
      final s = selCells.toList()..sort((a, b) => dist(a, tapped).compareTo(dist(b, tapped)));
      sources = [for (final c in s) Loc.cell(c)];
    } else {
      sources = [for (final s in selSlots) Loc.slot(s)];
    }
    final n = min(region.length, sources.length);
    final placed = <int>{};
    var landedCount = 0;
    for (var k = 0; k < n; k++) {
      final dest = region[k], src = sources[k];
      if (src.shelf) {
        shelf[src.index] = null;
        selSlots.remove(src.index);
      } else {
        gems[src.index] = null;
        selCells.remove(src.index);
      }
      gems[dest] = color;
      hiddenCells.add(dest);
      placed.add(dest);
      flights.add(Flight(color, src, Loc.cell(dest), now + k * 0.045, 0.36, true, () {
        hiddenCells.remove(dest);
        landedCells.add(dest);
        onSound?.call('drop');
        landedCount++;
        if (landedCount == n) {
          shines.add(Shine(placed, now));
          onSound?.call('sparkle');
        }
      }));
    }
    if (selCells.isEmpty && selSlots.isEmpty) _deselect();
    _checkPending = true;
  }

  /// Animates a batch of state changes already applied to [gems]/[shelf].
  void _animateMoves(List<(String, Loc, Loc)> moves) {
    final placed = <int>{};
    var landed = 0;
    for (var k = 0; k < moves.length; k++) {
      final (color, from, to) = moves[k];
      if (to.shelf) {
        hiddenSlots.add(to.index);
      } else {
        hiddenCells.add(to.index);
        if (target[to.index] == color) placed.add(to.index);
      }
      flights.add(Flight(color, from, to, now + k * 0.035, 0.42, false, () {
        if (to.shelf) {
          hiddenSlots.remove(to.index);
        } else {
          hiddenCells.remove(to.index);
        }
        onSound?.call('drop');
        landed++;
        if (landed == moves.length && placed.isNotEmpty) {
          shines.add(Shine(placed, now));
          onSound?.call('sparkle');
        }
      }));
    }
    _checkPending = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------- boosters

  /// Swaps up to [limit] misplaced gems (optionally only [only] colour) into
  /// their correct cells.
  bool _fixBySwaps(int limit, {String? only}) {
    final moves = <(String, Loc, Loc)>[];
    final touched = <int>{};
    for (var a = 0; a < gems.length && moves.length < limit * 2; a++) {
      if (!isWrong(a) || touched.contains(a)) continue;
      final c = gems[a]!;
      if (only != null && c != only) continue;
      int? best;
      for (var b = 0; b < gems.length; b++) {
        if (b == a || touched.contains(b) || target[b] != c || gems[b] == c) continue;
        // Prefer a partner that also becomes correct after the swap.
        if (best == null || gems[b] == target[a]) best = b;
        if (gems[b] == target[a]) break;
      }
      if (best == null) continue;
      final other = gems[best];
      gems[best] = c;
      gems[a] = other;
      touched..add(a)..add(best);
      moves.add((c, Loc.cell(a), Loc.cell(best)));
      if (other != null) moves.add((other, Loc.cell(best), Loc.cell(a)));
    }
    if (moves.isEmpty) return false;
    _animateMoves(moves);
    return true;
  }

  /// Magic wand: fixes a handful of gems.
  bool useWand() {
    if (busy || won) return false;
    _deselect();
    return _fixBySwaps(5);
  }

  /// Broom: sweeps every gem of the most scattered colour into place.
  bool useBroom() {
    if (busy || won) return false;
    _deselect();
    final counts = <String, int>{};
    for (var i = 0; i < gems.length; i++) {
      if (isWrong(i)) counts[gems[i]!] = (counts[gems[i]!] ?? 0) + 1;
    }
    if (counts.isEmpty) return false;
    final c = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return _fixBySwaps(999, only: c);
  }

  /// Magnet: pulls every gem that has a free home into it.
  bool useMagnet() {
    if (busy || won) return false;
    _deselect();
    final moves = <(String, Loc, Loc)>[];
    for (var s = 0; s < kShelfSize; s++) {
      final c = shelf[s];
      if (c == null) continue;
      final dest = List.generate(gems.length, (i) => i).where((i) => gems[i] == null && target[i] == c).firstOrNull;
      if (dest == null) continue;
      shelf[s] = null;
      gems[dest] = c;
      moves.add((c, Loc.slot(s), Loc.cell(dest)));
    }
    for (var i = 0; i < gems.length; i++) {
      if (!isWrong(i)) continue;
      final c = gems[i]!;
      final dest = List.generate(gems.length, (j) => j).where((j) => gems[j] == null && target[j] == c).firstOrNull;
      if (dest == null) continue;
      gems[i] = null;
      gems[dest] = c;
      moves.add((c, Loc.cell(i), Loc.cell(dest)));
    }
    if (moves.isEmpty) return false;
    _animateMoves(moves);
    return true;
  }

  // ---------------------------------------------------------------- state

  bool get isSolved {
    for (var i = 0; i < gems.length; i++) {
      if (target[i] != null && gems[i] != target[i]) return false;
    }
    return shelf.every((s) => s == null);
  }

  bool get hasMove {
    final empties = <String>{};
    final loose = <String>{};
    for (var i = 0; i < gems.length; i++) {
      if (target[i] == null) continue;
      if (gems[i] == null) empties.add(target[i]!);
      if (isWrong(i)) loose.add(gems[i]!);
    }
    for (final s in shelf) {
      if (s != null && empties.contains(s)) return true;
    }
    if (loose.any(empties.contains)) return true;
    return loose.isNotEmpty && shelf.contains(null);
  }

  void tick(double t) {
    now = t;
    for (final f in flights) {
      if (!f.landed && t >= f.start + f.dur) {
        f.landed = true;
        f.onLand();
      }
    }
    flights.removeWhere((f) => f.landed);
    shines.removeWhere((s) => t - s.start > 0.9);
    if (flights.isEmpty && _checkPending) {
      _checkPending = false;
      if (isSolved) {
        won = true;
        _deselect();
        final all = <int>{for (var i = 0; i < gems.length; i++) if (isCell(i)) i};
        shines.add(Shine(all, t + 0.25));
        onWin?.call();
      } else if (!hasMove) {
        onDeadlock?.call();
      }
    }
  }
}
