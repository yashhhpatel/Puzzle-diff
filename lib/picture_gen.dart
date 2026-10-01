import 'dart:math';

/// Procedural pixel-art pictures for levels without a hand-drawn picture.
///
/// Every generator returns `rows` strings of `cols` palette keys ('.' marks a
/// cell that is not part of the board) and uses only keys from [palette],
/// where `palette[0]` is the background colour.

/// Curated palettes: background first, then colours that stay easy to tell
/// apart from each other on the board.
const List<List<String>> kPalettes = [
  ['A', 'R', 'Y', 'G', 'W', 'K'],
  ['N', 'Y', 'W', 'P', 'T', 'O'],
  ['L', 'R', 'W', 'K', 'B', 'Y'],
  ['C', 'R', 'G', 'S', 'B', 'K'],
  ['P', 'V', 'W', 'Y', 'K', 'T'],
  ['T', 'N', 'W', 'O', 'R', 'Y'],
  ['E', 'R', 'Y', 'B', 'G', 'W'],
  ['W', 'B', 'R', 'Y', 'G', 'K'],
  ['M', 'Y', 'W', 'O', 'P', 'T'],
  ['V', 'Y', 'W', 'L', 'P', 'K'],
  ['Y', 'B', 'R', 'K', 'W', 'G'],
  ['G', 'Y', 'W', 'R', 'N', 'P'],
];

typedef _Gen = List<List<String?>> Function(Random rnd, int cols, int rows, List<String> pal);

const List<String> kGeneratorNames = ['creature', 'frames', 'stripes', 'landscape', 'emblem', 'shape', 'checks', 'mandala'];

final List<_Gen> _generators = [_creature, _frames, _stripes, _landscape, _emblem, _shapeBoard, _checks, _mandala];

/// Builds a picture of `cols x rows` using exactly the first [colors] keys of
/// a palette chosen by [rnd].
List<String> generatePicture(Random rnd, int cols, int rows, int colors) {
  final base = kPalettes[rnd.nextInt(kPalettes.length)];
  // Keep the background, shuffle which accents are used.
  final accents = base.sublist(1).toList()..shuffle(rnd);
  final pal = [base[0], ...accents.take(colors - 1)];
  final gen = _generators[rnd.nextInt(_generators.length)];
  final g = gen(rnd, cols, rows, pal);
  _ensureAllColors(g, pal, rnd);
  return [for (final row in g) row.map((c) => c ?? '.').join()];
}

List<List<String?>> _grid(int cols, int rows, String? fill) => List.generate(rows, (_) => List<String?>.filled(cols, fill));

/// Makes sure every palette colour appears, painting small mirrored patches
/// over the most common colour where one is missing.
void _ensureAllColors(List<List<String?>> g, List<String> pal, Random rnd) {
  final rows = g.length, cols = g[0].length;
  for (final c in pal) {
    var count = 0;
    for (final row in g) {
      for (final v in row) {
        if (v == c) count++;
      }
    }
    if (count >= 2) continue;
    final counts = <String, int>{};
    for (final row in g) {
      for (final v in row) {
        if (v != null) counts[v] = (counts[v] ?? 0) + 1;
      }
    }
    final common = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    var painted = 0;
    for (var tries = 0; tries < 400 && painted < 3; tries++) {
      final x = rnd.nextInt(cols), y = rnd.nextInt(rows);
      if (g[y][x] != common) continue;
      g[y][x] = c;
      final mx = cols - 1 - x;
      if (g[y][mx] == common) g[y][mx] = c;
      painted++;
    }
  }
}

// ------------------------------------------------------------------ shapes

bool _inShape(int kind, double nx, double ny) {
  // nx, ny in [-1, 1].
  switch (kind) {
    case 0: // circle
      return nx * nx + ny * ny <= 1.0;
    case 1: // diamond
      return nx.abs() + ny.abs() <= 1.05;
    case 2: // heart
      final x = nx * 1.15, y = -ny * 1.15 + 0.25;
      final a = x * x + y * y - 1;
      return a * a * a - x * x * y * y * y <= 0;
    case 3: // cross / plus
      return nx.abs() <= 0.36 || ny.abs() <= 0.36;
    case 4: // triangle pointing up
      return ny >= -0.95 && nx.abs() <= (ny + 1) / 2 * 1.05;
    case 5: // octagon
      return nx.abs() <= 0.95 && ny.abs() <= 0.95 && nx.abs() + ny.abs() <= 1.4;
    default: // star (5 points), via polar radius modulation
      final r = sqrt(nx * nx + ny * ny);
      final a = atan2(ny, nx) + pi / 2;
      final k = (cos(a * 5) + 1) / 2;
      return r <= 0.5 + 0.5 * k;
  }
}

// ------------------------------------------------------------------ generators

/// Mirrored "space creature" sprite on a background.
List<List<String?>> _creature(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, pal[0]);
  final mx = cols >= 7 ? 1 : 0, my = rows >= 7 ? 1 : 0;
  final iw = cols - mx * 2, ih = rows - my * 2;
  final half = (iw + 1) ~/ 2;
  var body = List.generate(ih, (_) => List.generate(half, (_) => rnd.nextDouble() < 0.55));
  // Smooth once so the creature is chunky rather than noisy.
  body = List.generate(ih, (y) {
    return List.generate(half, (x) {
      var n = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final yy = y + dy, xx = x + dx;
          if (yy >= 0 && yy < ih && xx >= 0 && xx < half && body[yy][xx]) n++;
          // Mirror side counts as filled to keep the centre solid.
          if (xx == half && yy >= 0 && yy < ih && body[yy][half - 1]) n++;
        }
      }
      return n >= 5;
    });
  });
  for (var y = 0; y < ih; y++) {
    for (var x = 0; x < half; x++) {
      if (!body[y][x]) continue;
      g[y + my][x + mx] = pal[1];
      g[y + my][cols - 1 - mx - x] = pal[1];
    }
  }
  // Outline / accents / eyes for the extra colours.
  if (pal.length >= 3) {
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (g[y][x] != pal[1]) continue;
        final edge = [
          if (x > 0) g[y][x - 1],
          if (x < cols - 1) g[y][x + 1],
          if (y > 0) g[y - 1][x],
          if (y < rows - 1) g[y + 1][x],
        ].contains(pal[0]);
        if (edge && y > rows / 2) g[y][x] = pal[2];
      }
    }
  }
  if (pal.length >= 4) {
    final int ey = my + ih ~/ 3, ex = mx + max(0, half - 2);
    for (final x in [ex, cols - 1 - ex]) {
      g[ey][x] = pal[3];
    }
  }
  if (pal.length >= 5) {
    for (var x = 0; x < cols; x++) {
      if (g[rows - 1][x] == pal[0]) g[rows - 1][x] = pal[4];
    }
  }
  if (pal.length >= 6) {
    final cy = my + (ih * 2) ~/ 3;
    for (var x = cols ~/ 2 - 1; x <= (cols - 1) ~/ 2 + 1; x++) {
      if (x >= 0 && x < cols && g[cy][x] != pal[0]) g[cy][x] = pal[5];
    }
  }
  return g;
}

/// Concentric frames (square, diamond or round) around a centre.
List<List<String?>> _frames(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, null);
  final cx = (cols - 1) / 2 + (rnd.nextDouble() - 0.5) * cols * 0.3;
  final cy = (rows - 1) / 2 + (rnd.nextDouble() - 0.5) * rows * 0.3;
  final metric = rnd.nextInt(3);
  final thick = 1 + rnd.nextInt(2);
  final order = [...pal]..shuffle(rnd);
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final dx = (x - cx).abs(), dy = (y - cy).abs();
      final d = switch (metric) { 0 => max(dx, dy), 1 => dx + dy, _ => sqrt(dx * dx + dy * dy) };
      g[y][x] = order[(d / thick).floor() % order.length];
    }
  }
  return g;
}

/// Horizontal, vertical, diagonal, chevron or wavy stripes.
List<List<String?>> _stripes(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, null);
  final kind = rnd.nextInt(5);
  final w = 1 + rnd.nextInt(3);
  final amp = 1 + rnd.nextInt(2), freq = 0.5 + rnd.nextDouble() * 0.6;
  final order = [...pal]..shuffle(rnd);
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final v = switch (kind) {
        0 => y,
        1 => x,
        2 => x + y,
        3 => y + (x - cols ~/ 2).abs(),
        _ => y + (amp * sin(x * freq)).round(),
      };
      g[y][x] = order[((v / w).floor() % order.length + order.length) % order.length];
    }
  }
  return g;
}

/// Sky, sun, rolling hills, ground and a tree.
List<List<String?>> _landscape(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, pal[0]);
  final k = pal.length;
  final ground = k >= 4 ? pal[3] : pal[1];
  final hill = pal[1];
  final phase = rnd.nextDouble() * pi * 2, freq = 0.5 + rnd.nextDouble() * 0.5;
  final base = rows * 0.62;
  for (var x = 0; x < cols; x++) {
    final int top = (base - 1.6 * sin(x * freq + phase)).round().clamp(1, rows - 1);
    for (var y = top; y < rows; y++) {
      g[y][x] = hill;
    }
    for (var y = max<int>(top + 2, rows - max<int>(1, rows ~/ 5)); y < rows; y++) {
      g[y][x] = ground;
    }
  }
  if (k >= 3) {
    // Sun in a top corner.
    final sx = rnd.nextBool() ? 1.5 : cols - 2.5, sy = 1.5;
    final r = max(1.2, min(cols, rows) * 0.16);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if ((x - sx) * (x - sx) + (y - sy) * (y - sy) <= r * r && g[y][x] == pal[0]) g[y][x] = pal[2];
      }
    }
  }
  if (k >= 5) {
    // Tree: trunk + crown standing on the hill.
    final tx = cols ~/ 2 + (rnd.nextBool() ? 1 : -1) * (cols ~/ 4);
    var gy = 0;
    while (gy < rows && g[gy][tx] != hill) {
      gy++;
    }
    for (var y = max(0, gy - 2); y < gy; y++) {
      g[y][tx] = pal[4];
    }
    final cy = max(1, gy - 3);
    for (var y = cy - 1; y <= cy + 1; y++) {
      for (var x = tx - 1; x <= tx + 1; x++) {
        if (y >= 0 && x >= 0 && x < cols && (y != cy - 1 || x == tx)) g[y][x] = pal[k >= 6 ? 5 : 1];
      }
    }
  }
  return g;
}

/// A centred emblem (heart, star, circle...) with outline and inner detail.
List<List<String?>> _emblem(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, pal[0]);
  final kind = rnd.nextInt(7);
  final k = pal.length;
  final cx = (cols - 1) / 2, cy = (rows - 1) / 2;
  final sx = cols / 2 * 0.92, sy = rows / 2 * 0.92;
  bool inside(int x, int y, double scale) => _inShape(kind, (x - cx) / (sx * scale), (y - cy) / (sy * scale));
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      if (!inside(x, y, 1)) continue;
      g[y][x] = pal[1];
      if (k >= 3 && !inside(x, y, 0.72)) g[y][x] = pal[2];
      if (k >= 4 && inside(x, y, 0.38)) g[y][x] = pal[3];
    }
  }
  if (k >= 5) {
    for (final p in [(0, 0), (cols - 1, 0), (0, rows - 1), (cols - 1, rows - 1)]) {
      if (g[p.$2][p.$1] == pal[0]) g[p.$2][p.$1] = pal[4];
    }
  }
  if (k >= 6) {
    for (var x = 0; x < cols; x += 2) {
      if (g[0][x] == pal[0]) g[0][x] = pal[5];
    }
  }
  return g;
}

/// The board itself is a shape (no background), filled with bands.
List<List<String?>> _shapeBoard(Random rnd, int cols, int rows, List<String> pal) {
  final kind = [0, 1, 2, 5, 6][rnd.nextInt(5)];
  final g = _grid(cols, rows, null);
  final cx = (cols - 1) / 2, cy = (rows - 1) / 2;
  final sx = cols / 2 * 1.02, sy = rows / 2 * 1.02;
  final thick = 1 + rnd.nextInt(2);
  final order = [...pal]..shuffle(rnd);
  final vertical = rnd.nextBool();
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      if (!_inShape(kind, (x - cx) / sx, (y - cy) / sy)) continue;
      final v = vertical ? x : y;
      g[y][x] = order[(v ~/ thick) % order.length];
    }
  }
  // Fall back to a full board if the shape came out too small.
  final cells = g.expand((r) => r).where((c) => c != null).length;
  if (cells < cols * rows * 0.45) return _frames(rnd, cols, rows, pal);
  return g;
}

/// Checkerboard, plaid or tile mosaic.
List<List<String?>> _checks(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, null);
  final b = 1 + rnd.nextInt(3);
  final kind = rnd.nextInt(3);
  final order = [...pal]..shuffle(rnd);
  final n = order.length;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final bx = x ~/ b, by = y ~/ b;
      final i = switch (kind) { 0 => bx + by, 1 => (bx % n) * (by % 2 + 1) + by, _ => bx * 2 + by * 3 };
      g[y][x] = order[i % n];
    }
  }
  return g;
}

/// Radially symmetric mandala of sectors and rings.
List<List<String?>> _mandala(Random rnd, int cols, int rows, List<String> pal) {
  final g = _grid(cols, rows, null);
  final sectors = [4, 6, 8][rnd.nextInt(3)];
  final ring = 1.5 + rnd.nextDouble() * 1.5;
  final order = [...pal]..shuffle(rnd);
  final cx = (cols - 1) / 2, cy = (rows - 1) / 2;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final dx = x - cx, dy = y - cy;
      final r = sqrt(dx * dx + dy * dy);
      final a = (atan2(dy, dx) + pi) / (2 * pi);
      final s = (a * sectors).floor();
      g[y][x] = order[((r / ring).floor() + (s.isEven ? 0 : 1)) % order.length];
    }
  }
  return g;
}
