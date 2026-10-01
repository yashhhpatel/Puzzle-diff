// Writes the target pictures of a spread of levels to build/levels_preview.txt
// for previewing with tool/render_levels.py.
//
// Run: flutter test tool/dump_levels.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/levels.dart';

void main() {
  test('dump level pictures', () {
    final levels = [3, 4, 5, 9, 10, 11, 20, 50, 99, 150, 200, 201, 260, 330, 400, 470, 500, 501, 560, 630, 700, 760, 800, 801, 850, 900, 950, 999, 1000];
    final out = StringBuffer();
    for (final l in levels) {
      final d = buildLevel(l);
      out.writeln('# $l ${difficultyOf(l).label} ${d.cols}x${d.rows}');
      for (var y = 0; y < d.rows; y++) {
        out.writeln([for (var x = 0; x < d.cols; x++) d.target[y * d.cols + x] ?? '.'].join());
      }
    }
    Directory('build').createSync(recursive: true);
    File('build/levels_preview.txt').writeAsStringSync(out.toString());
  });
}
