import 'dart:math';
import 'dart:ui';

/// Gem colours used by the pixel pictures, keyed by the character in the
/// picture strings.
const Map<String, Color> kGemColors = {
  'R': Color(0xFFEF2F2A), // red
  'G': Color(0xFF3DB43A), // green
  'C': Color(0xFFF0DDA4), // cream
  'M': Color(0xFF7C2239), // maroon
  'T': Color(0xFF42E0E4), // cyan
  'N': Color(0xFF2F3088), // navy
  'W': Color(0xFFF3F3F3), // white
  'K': Color(0xFF3B3B3F), // black
  'Y': Color(0xFFFFC925), // yellow
  'O': Color(0xFFFF8A22), // orange
  'P': Color(0xFFFF77B4), // pink
  'B': Color(0xFF2F7DF4), // blue
  'A': Color(0xFF93D6FF), // sky
  'L': Color(0xFF93DD3E), // lime
  'S': Color(0xFF93602F), // brown
  'E': Color(0xFFA2A7B0), // gray
  'V': Color(0xFF8C52F2), // violet
};

const Map<String, String> kColorNames = {
  'R': 'red', 'G': 'green', 'C': 'cream', 'M': 'maroon', 'T': 'cyan', 'N': 'navy', 'W': 'white',
  'K': 'black', 'Y': 'yellow', 'O': 'orange', 'P': 'pink', 'B': 'blue', 'A': 'sky', 'L': 'lime',
  'S': 'brown', 'E': 'gray', 'V': 'violet',
};

class LevelData {
  final int cols, rows;

  /// Target colour key per cell (row-major), null where there is no cell.
  final List<String?> target;

  /// Gem colour key initially sitting in each cell, null where empty.
  final List<String?> initial;

  LevelData(this.cols, this.rows, this.target, this.initial);
}

class _Picture {
  final List<String> rows;

  /// Hand-made starting layout; if null the level is scrambled procedurally.
  final List<String>? start;
  const _Picture(this.rows, [this.start]);
}

const List<_Picture> _pictures = [
  // 1 - tutorial flag
  _Picture([
    'RRRRRR',
    'RRRRRR',
    'GGGGGG',
    'GGGGGG',
  ], [
    'GGGGGG',
    'GGGGGG',
    'RRRRRR',
    'RRRRRR',
  ]),
  // 2 - mushroom
  _Picture([
    '..RR..',
    '.CRRR.',
    'CRRRCR',
    'RRRRRR',
    '..CC..',
    '..CC..',
    '.MMMM.',
    '.MMMM.',
  ], [
    '..MM..',
    '.CMMM.',
    'CCCMMM',
    'CCCRRR',
    '..RR..',
    '..RR..',
    '.RRRR.',
    '.RRRR.',
  ]),
  // 3 - penguin
  _Picture([
    'TTTTTTTT',
    'TTTNNNTT',
    'TTNNNKNT',
    'TTNWWNNN',
    'TNNWWWNT',
    'TNWWWWNT',
    'TNWWWWNT',
    'TNNWWNNT',
    'TTNNNNTT',
    'TTNTTNTT',
    'TTTTTTTT',
  ]),
  // 4 - heart
  _Picture([
    'PPPPPPPPP',
    'PRRPPPRRP',
    'RWRRPRRRR',
    'RRRRRRRRR',
    'RRRRRRRRR',
    'PRRRRRRRP',
    'PPRRRRRPP',
    'PPPRRRPPP',
    'PPPPRPPPP',
  ]),
  // 5 - apple
  _Picture([
    '....S...',
    '...SL...',
    '.RRSRRR.',
    'RRRRRRRR',
    'RWRRRRRR',
    'RWRRRRRR',
    'RRRRRRRR',
    '.RRRRRR.',
    '..RRRR..',
  ]),
  // 6 - fish
  _Picture([
    'BBBBBBBBBB',
    'BBBOOOOBBB',
    'OBOOOOOKOB',
    'OOOYOYOOOO',
    'OBOOOOOOOB',
    'BBBOOOOBBB',
    'BBBBBBBBBB',
  ]),
  // 7 - flower
  _Picture([
    'AAAPPPAAA',
    'AAPPPPPAA',
    'APPPYPPPA',
    'APPYYYPPA',
    'APPPYPPPA',
    'AAPPPPPAA',
    'AAAAGAAAA',
    'AGGAGAGGA',
    'AAGGGGGAA',
    'AAAAGAAAA',
  ]),
  // 8 - house
  _Picture([
    'AAAAAAAAAA',
    'AAAARRAAAA',
    'AAARRRRAAA',
    'AARRRRRRAA',
    'ARRRRRRRRA',
    'AAYYYYYYAA',
    'AAYBYYBYAA',
    'AAYYYSYYAA',
    'AAYYYSYYAA',
    'GGGGGGGGGG',
  ]),
  // 9 - ice cream
  _Picture([
    'AAAPPAAA',
    'AAPPPPAA',
    'APPWPPPA',
    'APPPPPPA',
    'ACCCCCCA',
    'ACCCCCCA',
    'AOOOOOOA',
    'AAOOOOAA',
    'AAOOOOAA',
    'AAAOOAAA',
    'AAAOOAAA',
  ]),
  // 10 - star
  _Picture([
    'NNNNYNNNN',
    'NNNNYNNWN',
    'NNNYYYNNN',
    'YYYYYYYYY',
    'NYYYYYYYN',
    'NNYYYYYNN',
    'NNYYNYYNN',
    'NYYNNNYYN',
    'NWNNNNNNN',
  ]),
  // 11 - cat
  _Picture([
    'LEELLLLEEL',
    'LEPELLEPEL',
    'LEEEEEEEEL',
    'EEKEEEEKEE',
    'EEKEEEEKEE',
    'EEEEPPEEEE',
    'EWEEEEEEWE',
    'EEEEEEEEEE',
    'LEEEEEEEEL',
    'LLEEEEEELL',
  ]),
  // 12 - tree
  _Picture([
    'AAAAGGAAAA',
    'AAAGGGGAAA',
    'AAGGLGGGAA',
    'AGGGGGGLGA',
    'AGLGGGGGGA',
    'GGGGGGLGGG',
    'AGGGLGGGGA',
    'AAGGGGGGAA',
    'AAAASSAAAA',
    'AAAASSAAAA',
    'AAAASSAAAA',
    'LLLLLLLLLL',
  ]),
  // 13 - sun
  _Picture([
    'AAAAOAAAAA',
    'AOAAAAAAOA',
    'AAAYYYYAAA',
    'AAYYYYYYAA',
    'OAYYYYYYAO',
    'AAYYYYYYAA',
    'AAAYYYYAAA',
    'AOAAAAWWOA',
    'AAAAWWWWWA',
    'AAAWWWWWWW',
  ]),
  // 14 - strawberry
  _Picture([
    'CCCGGGCCC',
    'CCGGGGGCC',
    'CRRRGRRRC',
    'RRYRRRYRR',
    'RRRRYRRRR',
    'RYRRRRRYR',
    'RRRYRRRRR',
    'CRRRRRYRC',
    'CRYRRRRRC',
    'CCRRRYRCC',
    'CCCRRRCCC',
  ]),
  // 15 - rocket
  _Picture([
    'NNNNRRNNNN',
    'NNNRRRRNNN',
    'NNNWWWWNNN',
    'NNNWBBWNNN',
    'NWNWBBWNNN',
    'NNNWWWWNWN',
    'NNNWWWWNNN',
    'NNRWWWWRNN',
    'NRRWWWWRRN',
    'NRNNOONNRN',
    'NNNOYYONNN',
    'NNNNOONNNN',
  ]),
  // 16 - watermelon
  _Picture([
    'AAAAAAAAAAAA',
    'ARRRRRRRRRRA',
    'ARRKRRRRKRRA',
    'AARRRKRRRRAA',
    'AAWWWWWWWWAA',
    'AAAGGGGGGAAA',
    'AAAALLLLAAAA',
    'AAAAAAAAAAAA',
  ]),
  // 17 - frog
  _Picture([
    'ALLAAAALLA',
    'LWKLAALWKL',
    'LLLLLLLLLL',
    'LLLLLLLLLL',
    'LRRRRRRRRL',
    'LLRRRRRRLL',
    'ALLLLLLLLA',
    'GGLGGGGLGG',
  ]),
  // 18 - ghost
  _Picture([
    'VVVVVVVVVV',
    'VVVWWWWVVV',
    'VVWWWWWWVV',
    'VWWKWWKWWV',
    'VWWKWWKWWV',
    'VWWWWWWWWV',
    'VWWWPPWWWV',
    'VWWWWWWWWV',
    'VWVWWVWWVV',
    'VVVVVVVVVV',
  ]),
  // 19 - duck
  _Picture([
    'AAAYYYAAAA',
    'AAYYYYYAAA',
    'AAYKYYOOAA',
    'AAYYYYOAAA',
    'AAAYYYAAAA',
    'YYYYYYYYAA',
    'YWYYYYYYYA',
    'AYYYYYYYAA',
    'BBBBBBBBBB',
    'BBBBBBBBBB',
  ]),
  // 20 - robot
  _Picture([
    'NNNNRNNNNN',
    'NNNNENNNNN',
    'NEEEEEEEEN',
    'NEBBEEBBEN',
    'NEBBEEBBEN',
    'NEEEEEEEEN',
    'NEYYYYYYEN',
    'NEEEEEEEEN',
    'NNEENNEENN',
    'NNEENNEENN',
  ]),
];

int get pictureCount => _pictures.length;

List<String?> _parse(List<String> rows) {
  final out = <String?>[];
  for (final r in rows) {
    for (final ch in r.split('')) {
      out.add(ch == '.' ? null : ch);
    }
  }
  return out;
}

/// Builds the data for 1-based [level]. After the last hand-drawn picture the
/// pictures repeat with fresh, harder scrambles.
LevelData buildLevel(int level) {
  final pic = _pictures[(level - 1) % _pictures.length];
  final rows = pic.rows.length;
  final cols = pic.rows.first.length;
  final target = _parse(pic.rows);
  if (pic.start != null && level <= _pictures.length) {
    return LevelData(cols, rows, target, _parse(pic.start!));
  }
  final loop = (level - 1) ~/ _pictures.length;
  // Difficulty: share of misplaced gems grows with the level.
  final frac = min(0.78, 0.42 + level * 0.015 + loop * 0.08);
  return _scrambled(pic, level * 7919, frac);
}

/// The Daily Challenge for [day]: the same puzzle for every player that day,
/// drawn from the regular pictures (never the tutorial) with a hard scramble.
LevelData buildDaily(DateTime day) {
  final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2024)).inDays;
  final pic = _pictures[2 + days % (_pictures.length - 2)];
  return _scrambled(pic, day.year * 10000 + day.month * 100 + day.day, 0.7);
}

LevelData _scrambled(_Picture pic, int seed, double frac) {
  final rows = pic.rows.length;
  final cols = pic.rows.first.length;
  final target = _parse(pic.rows);
  for (var attempt = 0; attempt < 400; attempt++) {
    final rnd = Random(seed + attempt * 104729);
    final start = _scramble(cols, rows, target, rnd, frac);
    if (start != null && solvableGreedy(cols, rows, target, start, 12)) {
      return LevelData(cols, rows, target, start);
    }
  }
  // Fallback that is always solvable: swap the two halves of the picture.
  final start = List<String?>.from(target);
  for (var i = 0; i < start.length ~/ 2; i++) {
    final j = start.length - 1 - i;
    if (target[i] != null && target[j] != null) {
      final t = start[i];
      start[i] = start[j];
      start[j] = t;
    }
  }
  return LevelData(cols, rows, target, start);
}

/// Swaps equally-sized rectangular blocks so misplaced gems form chunky
/// groups, like the reference game.
List<String?>? _scramble(int cols, int rows, List<String?> target, Random rnd, double frac) {
  final g = List<String?>.from(target);
  final cellCount = target.where((t) => t != null).length;
  int wrong() {
    var n = 0;
    for (var i = 0; i < g.length; i++) {
      if (g[i] != null && g[i] != target[i]) n++;
    }
    return n;
  }

  var tries = 0;
  while (wrong() < cellCount * frac && tries < 3000) {
    tries++;
    final w = 1 + rnd.nextInt(min(4, cols));
    final h = 1 + rnd.nextInt(min(4, rows));
    final ax = rnd.nextInt(cols - w + 1), ay = rnd.nextInt(rows - h + 1);
    final bx = rnd.nextInt(cols - w + 1), by = rnd.nextInt(rows - h + 1);
    final overlap = ax < bx + w && bx < ax + w && ay < by + h && by < ay + h;
    if (overlap) continue;
    var ok = true;
    for (var y = 0; y < h && ok; y++) {
      for (var x = 0; x < w; x++) {
        if (target[(ay + y) * cols + ax + x] == null || target[(by + y) * cols + bx + x] == null) {
          ok = false;
          break;
        }
      }
    }
    if (!ok) continue;
    final before = wrong();
    final saved = List<String?>.from(g);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = (ay + y) * cols + ax + x, b = (by + y) * cols + bx + x;
        final t = g[a];
        g[a] = g[b];
        g[b] = t;
      }
    }
    if (wrong() <= before) g.setAll(0, saved);
  }
  return wrong() >= cellCount * frac * 0.9 ? g : null;
}

/// Greedy playthrough used to reject scrambles that could dead-end.
bool solvableGreedy(int cols, int rows, List<String?> target, List<String?> start, int shelfSize) {
  final g = List<String?>.from(start);
  final shelf = <String>[];
  bool isWrong(int i) => g[i] != null && g[i] != target[i];
  List<int> neighbours(int i) {
    final x = i % cols, y = i ~/ cols;
    return [
      if (x > 0) i - 1,
      if (x < cols - 1) i + 1,
      if (y > 0) i - cols,
      if (y < rows - 1) i + cols,
    ];
  }

  for (var step = 0; step < 2000; step++) {
    if (!List.generate(g.length, (i) => i).any(isWrong) && shelf.isEmpty) return true;
    var progressed = false;
    // Place anything that has a free home.
    for (var i = 0; i < g.length; i++) {
      if (!isWrong(i)) continue;
      final c = g[i]!;
      final free = List.generate(g.length, (j) => j).where((j) => g[j] == null && target[j] == c);
      if (free.isNotEmpty) {
        g[free.first] = c;
        g[i] = null;
        progressed = true;
      }
    }
    for (var s = shelf.length - 1; s >= 0; s--) {
      final c = shelf[s];
      final free = List.generate(g.length, (j) => j).where((j) => g[j] == null && target[j] == c);
      if (free.isNotEmpty) {
        g[free.first] = c;
        shelf.removeAt(s);
        progressed = true;
      }
    }
    if (progressed) continue;
    if (shelf.length >= shelfSize) return false;
    // Move the most useful wrong group to the shelf: one sitting on cells the
    // shelf colours need, otherwise the smallest group.
    final seen = <int>{};
    List<int>? best;
    var bestScore = -1e9;
    final need = shelf.toSet();
    for (var i = 0; i < g.length; i++) {
      if (!isWrong(i) || seen.contains(i)) continue;
      final grp = <int>[i];
      seen.add(i);
      for (var k = 0; k < grp.length; k++) {
        for (final n in neighbours(grp[k])) {
          if (!seen.contains(n) && isWrong(n) && g[n] == g[i]) {
            seen.add(n);
            grp.add(n);
          }
        }
      }
      final frees = grp.where((j) => need.contains(target[j])).length;
      final score = frees * 100.0 - grp.length;
      if (score > bestScore) {
        bestScore = score;
        best = grp;
      }
    }
    if (best == null) return false;
    for (final i in best) {
      if (shelf.length >= shelfSize) break;
      shelf.add(g[i]!);
      g[i] = null;
    }
  }
  return false;
}
