import 'dart:math';
import 'dart:ui';

import 'picture_gen.dart';

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

// ------------------------------------------------------------------ difficulty

/// Total number of levels in the game.
const int kMaxLevel = 1000;

enum Difficulty { easy, medium, hard, veryHard }

extension DifficultyInfo on Difficulty {
  String get label => const ['Easy', 'Medium', 'Hard', 'Very Hard'][index];

  /// First level of this tier.
  int get firstLevel => const [1, 201, 501, 801][index];
}

/// Easy 1-200, Medium 201-500, Hard 501-800, Very Hard 801-1000.
Difficulty difficultyOf(int level) {
  if (level <= 200) return Difficulty.easy;
  if (level <= 500) return Difficulty.medium;
  if (level <= 800) return Difficulty.hard;
  return Difficulty.veryHard;
}

/// Every 10th level is a hand-drawn "milestone" picture.
bool isMilestone(int level) => level > 2 && level % 10 == 0;

/// Smooth difficulty in 0..1. The base climbs steadily over all 1000 levels;
/// a small saw-tooth makes each block of 10 open with a breather and build up
/// to its milestone, so progress feels natural rather than a flat ramp.
double difficultyCurve(int level) {
  final t = (level.clamp(1, kMaxLevel) - 1) / (kMaxLevel - 1);
  final base = pow(t, 0.85).toDouble();
  final local = ((level - 1) % 10) / 9;
  return (base + (local - 0.5) * 0.05).clamp(0.0, 1.0);
}

/// All the knobs for one level, derived from [difficultyCurve].
class LevelSpec {
  final int level;
  final double effort;
  final int cols, rows, colors, maxBlock;

  /// Share of cells that start misplaced.
  final double scramble;
  const LevelSpec(this.level, this.effort, this.cols, this.rows, this.colors, this.maxBlock, this.scramble);
}

LevelSpec specFor(int level) {
  final e = difficultyCurve(level);
  final rnd = Random(level * 31337 + 11);
  // Board grows from ~30 cells to ~160 cells.
  final area = 30 + 130 * e;
  final aspect = 0.85 + rnd.nextDouble() * 0.45; // rows / cols
  final cols = sqrt(area / aspect).round().clamp(5, 12);
  final rows = (area / cols).round().clamp(5, 14);
  // 2-3 colours while learning, then 3 -> 6.
  final colors = level < 5 ? 2 : (level < 10 ? 3 : (3 + e * 3.6).floor().clamp(3, 6));
  // Smaller swap blocks mean more, smaller misplaced groups (more moves).
  final maxBlock = e < 0.3 ? 4 : (e < 0.62 ? 3 : 2);
  final scramble = 0.36 + 0.46 * e;
  return LevelSpec(level, e, cols, rows, colors, maxBlock, scramble);
}

// ------------------------------------------------------------------ building

final Map<int, LevelData> _cache = {};

/// Builds the data for 1-based [level] (1..[kMaxLevel]); deterministic, so
/// every player gets the same puzzle for the same level.
LevelData buildLevel(int level) {
  final cached = _cache[level];
  if (cached != null) return cached;
  final data = _buildLevel(level);
  if (_cache.length > 8) _cache.remove(_cache.keys.first);
  return _cache[level] = data;
}

LevelData _buildLevel(int level) {
  // Levels 1 and 2 are the hand-made openers from the reference game.
  if (level <= 2) {
    final pic = _pictures[level - 1];
    return LevelData(pic.rows.first.length, pic.rows.length, _parse(pic.rows), _parse(pic.start!));
  }
  final spec = specFor(level);
  for (var pictureTry = 0; pictureTry < 20; pictureTry++) {
    final rows = isMilestone(level) && pictureTry == 0
        ? _milestonePicture(level)
        : generatePicture(Random(level * 7919 + pictureTry * 15485863), spec.cols, spec.rows, spec.colors);
    final built = _scrambled(rows, level * 104729 + pictureTry, spec.scramble, spec.maxBlock);
    if (built != null) return built;
  }
  throw StateError('Could not build level $level');
}

/// The Daily Challenge for [day]: the same puzzle for every player that day,
/// sized and scrambled like a Medium/Hard level.
LevelData buildDaily(DateTime day) {
  final key = day.year * 10000 + day.month * 100 + day.day;
  final rnd = Random(key);
  final e = 0.5 + rnd.nextDouble() * 0.15;
  final cols = 8 + rnd.nextInt(3), rows = 9 + rnd.nextInt(3);
  final colors = (3 + e * 3.6).floor().clamp(3, 6);
  for (var pictureTry = 0; pictureTry < 20; pictureTry++) {
    final pic = generatePicture(Random(key * 31 + pictureTry), cols, rows, colors);
    final built = _scrambled(pic, key * 7 + pictureTry, 0.36 + 0.46 * e, 3);
    if (built != null) return built;
  }
  throw StateError('Could not build daily $key');
}

// Hand-drawn pictures (except the two openers), smallest first, so early
// milestones are small boards.
final List<int> _milestoneOrder = () {
  final idx = List.generate(_pictures.length - 2, (i) => i + 2);
  int area(int i) => _pictures[i].rows.length * _pictures[i].rows.first.length;
  idx.sort((a, b) => area(a).compareTo(area(b)));
  return idx;
}();

/// Milestone picture for [level]: each hand-drawn picture first appears in
/// its original colours, then returns recoloured (and mirrored) later on.
List<String> _milestonePicture(int level) {
  final m = level ~/ 10 - 1;
  final pic = _pictures[_milestoneOrder[m % _milestoneOrder.length]].rows;
  final variant = m ~/ _milestoneOrder.length;
  if (variant == 0) return pic;
  // Most frequent colour becomes the new background, and so on.
  final counts = <String, int>{};
  for (final r in pic) {
    for (final ch in r.split('')) {
      if (ch != '.') counts[ch] = (counts[ch] ?? 0) + 1;
    }
  }
  final keys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  final pal = kPalettes[(m * 7 + variant) % kPalettes.length];
  final map = {for (var i = 0; i < keys.length; i++) keys[i]: pal[i % pal.length]};
  return [
    for (final r in pic)
      (variant.isOdd ? r.split('').reversed : r.split('')).map((ch) => ch == '.' ? '.' : map[ch]!).join(),
  ];
}

/// Scrambles [rows] until the greedy solver can finish it; null if this
/// picture refuses to produce a fair puzzle.
LevelData? _scrambled(List<String> rows, int seed, double frac, int maxBlock) {
  final r = rows.length;
  final c = rows.first.length;
  final target = _parse(rows);
  for (var attempt = 0; attempt < 120; attempt++) {
    final rnd = Random(seed + attempt * 104729);
    // Ease off slightly if a picture keeps producing dead ends.
    final f = max(0.3, frac - (attempt ~/ 30) * 0.04);
    final start = _scramble(c, r, target, rnd, f, maxBlock);
    if (start != null && solvableGreedy(c, r, target, start, 12)) {
      return LevelData(c, r, target, start);
    }
  }
  return null;
}

/// Swaps equally-sized rectangular blocks so misplaced gems form chunky
/// groups, like the reference game.
List<String?>? _scramble(int cols, int rows, List<String?> target, Random rnd, double frac, int maxBlock) {
  final g = List<String?>.from(target);
  final cellCount = target.where((t) => t != null).length;
  var wrongNow = 0;
  int countWrong() {
    var n = 0;
    for (var i = 0; i < g.length; i++) {
      if (g[i] != null && g[i] != target[i]) n++;
    }
    return n;
  }

  var tries = 0;
  while (wrongNow < cellCount * frac && tries < 3000) {
    tries++;
    final w = 1 + rnd.nextInt(min(maxBlock, cols));
    final h = 1 + rnd.nextInt(min(maxBlock, rows));
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
    final saved = List<String?>.from(g);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final a = (ay + y) * cols + ax + x, b = (by + y) * cols + bx + x;
        final t = g[a];
        g[a] = g[b];
        g[b] = t;
      }
    }
    final after = countWrong();
    if (after <= wrongNow) {
      g.setAll(0, saved);
    } else {
      wrongNow = after;
    }
  }
  return wrongNow >= cellCount * frac * 0.9 && wrongNow > 0 ? g : null;
}

/// Greedy playthrough used to reject scrambles that could dead-end: place
/// everything that has a free home, otherwise park the most useful group on
/// the shelf. Mirrors what a player can do with taps.
bool solvableGreedy(int cols, int rows, List<String?> target, List<String?> start, int shelfSize) {
  final n = start.length;
  final g = List<String?>.from(start);
  final shelf = <String>[];
  final empty = <String, List<int>>{};
  for (var i = 0; i < n; i++) {
    if (target[i] != null && g[i] == null) (empty[target[i]!] ??= []).add(i);
  }
  bool isWrong(int i) => g[i] != null && g[i] != target[i];
  final seen = List<int>.filled(n, -1);
  var mark = 0;

  for (var step = 0; step < 5000; step++) {
    var progressed = false;
    for (var s = shelf.length - 1; s >= 0; s--) {
      final free = empty[shelf[s]];
      if (free != null && free.isNotEmpty) {
        g[free.removeLast()] = shelf.removeAt(s);
        progressed = true;
      }
    }
    var anyWrong = false;
    for (var i = 0; i < n; i++) {
      if (!isWrong(i)) continue;
      final free = empty[g[i]!];
      if (free != null && free.isNotEmpty) {
        g[free.removeLast()] = g[i];
        g[i] = null;
        (empty[target[i]!] ??= []).add(i);
        progressed = true;
      } else {
        anyWrong = true;
      }
    }
    if (progressed) continue;
    if (!anyWrong && shelf.isEmpty) return true;
    if (shelf.length >= shelfSize || !anyWrong) return false;
    // Park the group that frees cells the shelf colours need, else the smallest.
    final need = shelf.toSet();
    List<int>? best;
    var bestScore = -1e9;
    mark++;
    for (var i = 0; i < n; i++) {
      if (!isWrong(i) || seen[i] == mark) continue;
      final grp = <int>[i];
      seen[i] = mark;
      for (var k = 0; k < grp.length; k++) {
        final p = grp[k], x = p % cols, y = p ~/ cols;
        for (final q in [if (x > 0) p - 1, if (x < cols - 1) p + 1, if (y > 0) p - cols, if (y < rows - 1) p + cols]) {
          if (seen[q] != mark && isWrong(q) && g[q] == g[i]) {
            seen[q] = mark;
            grp.add(q);
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
    for (final i in best!) {
      if (shelf.length >= shelfSize) break;
      shelf.add(g[i]!);
      g[i] = null;
      (empty[target[i]!] ??= []).add(i);
    }
  }
  return false;
}
