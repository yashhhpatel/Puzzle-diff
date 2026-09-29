import 'dart:math';

import 'package:flutter/material.dart';

import '../levels.dart';
import '../theme.dart';
import 'game_controller.dart';
import 'gem_art.dart';

/// Screen-space geometry of the play field, proportions measured from the
/// reference video (portrait phone).
class GameLayout {
  final Size size;
  late final double cell;
  late final Offset boardOrigin;
  late final Rect shelfRect;
  late final List<Rect> slots;
  final int cols, rows;

  GameLayout(this.size, this.cols, this.rows) {
    final w = size.width, h = size.height;
    var c = w * (cols <= 6 ? 0.058 : 0.054);
    c = min(c, w * 0.86 / cols);
    c = min(c, h * 0.5 / rows);
    cell = c;
    final boardW = cols * c, boardH = rows * c;
    boardOrigin = Offset((w - boardW) / 2, h * 0.47 - boardH / 2);
    final pitch = w * 0.061, slot = w * 0.044;
    final shelfW = pitch * kShelfSize + w * 0.02;
    final shelfH = w * 0.074;
    shelfRect = Rect.fromCenter(center: Offset(w / 2, h * 0.848), width: shelfW, height: shelfH);
    final firstX = w / 2 - pitch * (kShelfSize - 1) / 2;
    slots = List.generate(
        kShelfSize, (i) => Rect.fromCenter(center: Offset(firstX + pitch * i, shelfRect.center.dy), width: slot, height: slot));
  }

  Rect boardRect() => boardOrigin & Size(cols * cell, rows * cell);
  Rect cellRect(int i) => Rect.fromLTWH(boardOrigin.dx + (i % cols) * cell, boardOrigin.dy + (i ~/ cols) * cell, cell, cell);
  Offset cellCenter(int i) => cellRect(i).center;

  /// Board cell under [p], snapping to the nearest cell within half a cell of
  /// the board edge so small cells stay easy to hit.
  int hitCell(Offset p, List<String?> target) {
    final br = boardRect().inflate(cell * 0.5);
    if (!br.contains(p)) return -1;
    final x = ((p.dx - boardOrigin.dx) / cell).floor().clamp(0, cols - 1);
    final y = ((p.dy - boardOrigin.dy) / cell).floor().clamp(0, rows - 1);
    final i = y * cols + x;
    if (target[i] != null) return i;
    // Nearest real cell.
    var best = -1;
    var bd = double.infinity;
    for (var j = 0; j < target.length; j++) {
      if (target[j] == null) continue;
      final d = (cellCenter(j) - p).distance;
      if (d < bd) {
        bd = d;
        best = j;
      }
    }
    return bd < cell * 0.9 ? best : -1;
  }

  /// Shelf slot under [p]; -2 if outside the shelf, -1 if on the shelf but
  /// between slots.
  int hitShelf(Offset p) {
    if (!shelfRect.inflate(shelfRect.height * 0.5).contains(p)) return -2;
    var best = -1;
    var bd = double.infinity;
    for (var i = 0; i < slots.length; i++) {
      final d = (slots[i].center.dx - p.dx).abs();
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    return best;
  }

  Rect locRect(Loc l) => l.shelf ? slots[l.index].inflate(slots[l.index].width * 0.06) : cellRect(l.index).deflate(cell * 0.04);
}

Color gemColor(String k) => kGemColors[k]!;

/// Draws the static picture frame (outline, cell colours, placed gems).
void paintBoardBase(Canvas canvas, Offset origin, double cell, int cols, List<String?> target, List<String?> gems,
    {Set<int> hidden = const {}, bool showLoose = false}) {
  Rect rectOf(int i) => Rect.fromLTWH(origin.dx + (i % cols) * cell, origin.dy + (i ~/ cols) * cell, cell, cell);
  final outline = Paint()..color = const Color(0xFFF7F7FF);
  final shadow = Paint()..color = const Color(0xFFC4C3DA);
  final bw = cell * 0.11;
  for (var i = 0; i < target.length; i++) {
    if (target[i] == null) continue;
    canvas.drawRRect(RRect.fromRectAndRadius(rectOf(i).inflate(bw).shift(Offset(0, bw * 0.6)), Radius.circular(bw * 1.6)), shadow);
  }
  for (var i = 0; i < target.length; i++) {
    if (target[i] == null) continue;
    canvas.drawRRect(RRect.fromRectAndRadius(rectOf(i).inflate(bw), Radius.circular(bw * 1.6)), outline);
  }
  for (var i = 0; i < target.length; i++) {
    final t = target[i];
    if (t == null) continue;
    final r = rectOf(i);
    final c = gemColor(t);
    canvas.drawRect(r.inflate(0.3), Paint()..color = darken(c, 0.02));
    final g = gems[i];
    if (g == null || hidden.contains(i)) {
      drawEmptyCell(canvas, r, c);
    } else if (g == t) {
      drawPlacedGem(canvas, r, c);
    } else {
      drawEmptyCell(canvas, r, c);
      if (showLoose) drawGem(canvas, r.deflate(cell * 0.04), gemColor(g));
    }
  }
}

class BoardPainter extends CustomPainter {
  final GameController game;
  final GameLayout layout;
  BoardPainter(this.game, this.layout, Listenable repaint) : super(repaint: repaint);

  double _ease(double t) => 1 - pow(1 - t.clamp(0.0, 1.0), 3).toDouble();

  Offset _shakeOffset() {
    final t = game.now - game.shakeTime;
    if (t < 0 || t > 0.3) return Offset.zero;
    return Offset(sin(t * 60) * layout.cell * 0.12 * (1 - t / 0.3), 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final g = game;
    final L = layout;
    final cell = L.cell;

    paintBoardBase(canvas, L.boardOrigin, cell, g.cols, g.target, g.gems, hidden: g.hiddenCells);

    // Loose (misplaced) gems that are not selected.
    for (var i = 0; i < g.gems.length; i++) {
      if (!g.isWrong(i) || g.selCells.contains(i) || g.hiddenCells.contains(i)) continue;
      drawGem(canvas, L.cellRect(i).deflate(cell * 0.04), gemColor(g.gems[i]!));
    }

    _paintShines(canvas);
    _paintShelf(canvas);

    // Selected group, lifted above the rest.
    final lift = _ease((g.now - g.selTime) / 0.14);
    final shake = _shakeOffset();
    final sel = g.selCells.toList()..sort();
    for (final i in sel) {
      final r = L.cellRect(i).deflate(cell * 0.04);
      final lr = Rect.fromCenter(center: r.center.translate(0, -cell * 0.16 * lift) + shake, width: r.width * (1 + 0.1 * lift), height: r.height * (1 + 0.1 * lift));
      drawGem(canvas, lr, gemColor(g.gems[i]!), lift: lift);
    }

    // Flights.
    for (final f in g.flights) {
      final t = (g.now - f.start) / f.dur;
      final a = L.locRect(f.from), b = L.locRect(f.to);
      if (t < 0) {
        // Still waiting in its source position.
        final r = f.fromLifted
            ? Rect.fromCenter(center: a.center.translate(0, -cell * 0.16), width: a.width * 1.1, height: a.height * 1.1)
            : a;
        drawGem(canvas, r, gemColor(f.color), lift: f.fromLifted ? 1 : 0);
        continue;
      }
      final e = Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));
      final start = f.fromLifted ? a.center.translate(0, -cell * 0.16) : a.center;
      final end = b.center;
      final dist = (end - start).distance;
      // Gentle sideways bow, like the gem stream in the reference.
      final ctrl = Offset((start.dx + end.dx) / 2 + dist * 0.15, (start.dy + end.dy) / 2 - dist * 0.05);
      final p = _bezier(start, ctrl, end, e);
      final sz = a.width + (b.width - a.width) * e;
      drawGem(canvas, Rect.fromCenter(center: p, width: sz * (1 + 0.12 * sin(pi * e)), height: sz * (1 + 0.12 * sin(pi * e))), gemColor(f.color),
          lift: 1 - e);
    }
  }

  Offset _bezier(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return a * (u * u) + c * (2 * u * t) + b * (t * t);
  }

  void _paintShines(Canvas canvas) {
    final g = game;
    final L = layout;
    for (final s in g.shines) {
      final t = (g.now - s.start) / 0.75;
      if (t < 0 || t > 1) continue;
      // Diagonal band sweeping from top-left to bottom-right.
      var minD = double.infinity, maxD = -double.infinity;
      for (final i in s.cells) {
        final d = (i % g.cols + i ~/ g.cols).toDouble();
        minD = min(minD, d);
        maxD = max(maxD, d);
      }
      final span = max(1.0, maxD - minD);
      final pos = -0.25 + t * 1.5;
      for (final i in s.cells) {
        if (g.hiddenCells.contains(i)) continue;
        final d = ((i % g.cols + i ~/ g.cols) - minD) / span;
        final k = (1 - ((d - pos).abs() / 0.22)).clamp(0.0, 1.0);
        if (k <= 0) continue;
        final r = L.cellRect(i);
        canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(L.cell * 0.05), Radius.circular(L.cell * 0.2)),
            Paint()..color = Colors.white.withAlpha((150 * k).round()));
        if (k > 0.85 && (i * 7) % 5 == 0) {
          canvas.drawPath(sparklePath(r.center.translate(L.cell * 0.2, -L.cell * 0.2), L.cell * 0.35 * k), Paint()..color = Colors.white);
        }
      }
    }
  }

  void _paintShelf(Canvas canvas) {
    final g = game;
    final L = layout;
    final sr = L.shelfRect;
    canvas.drawRRect(RRect.fromRectAndRadius(sr.shift(Offset(0, sr.height * 0.06)), Radius.circular(sr.height * 0.3)),
        Paint()..color = const Color(0xFFCFCFDB));
    canvas.drawRRect(RRect.fromRectAndRadius(sr, Radius.circular(sr.height * 0.3)), Paint()..color = const Color(0xFFFAFAFC));
    final lift = _ease((g.now - g.selTime) / 0.14);
    final shake = _shakeOffset();
    for (var i = 0; i < kShelfSize; i++) {
      final r = L.slots[i];
      final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.28));
      canvas.drawRRect(rr, Paint()..color = const Color(0xFFD9D9E2));
      canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(r.width * 0.2), Radius.circular(r.width * 0.2)), Paint()..color = const Color(0xFFE9E9EF));
      final c = g.shelf[i];
      if (c == null || g.hiddenSlots.contains(i)) continue;
      final gr = r.inflate(r.width * 0.06);
      if (g.selSlots.contains(i)) {
        final lr = Rect.fromCenter(center: gr.center.translate(0, -r.height * 0.3 * lift) + shake, width: gr.width * (1 + 0.1 * lift), height: gr.height * (1 + 0.1 * lift));
        drawGem(canvas, lr, gemColor(c), lift: lift);
      } else {
        drawGem(canvas, gr, gemColor(c));
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}

/// Finished picture used on the "Level complete" card.
class PicturePainter extends CustomPainter {
  final int cols, rows;
  final List<String?> target;
  PicturePainter(this.cols, this.rows, this.target);
  @override
  void paint(Canvas canvas, Size size) {
    final cell = min(size.width / cols, size.height / rows);
    final origin = Offset((size.width - cell * cols) / 2, (size.height - cell * rows) / 2);
    for (var i = 0; i < target.length; i++) {
      final t = target[i];
      if (t == null) continue;
      final r = Rect.fromLTWH(origin.dx + (i % cols) * cell, origin.dy + (i ~/ cols) * cell, cell, cell);
      canvas.drawRect(r.inflate(0.3), Paint()..color = gemColor(t));
      drawPlacedGem(canvas, r, gemColor(t));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
