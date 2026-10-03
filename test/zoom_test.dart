import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/game/board_painter.dart';
import 'package:sparkle_sort/levels.dart';
import 'package:sparkle_sort/screens/game_screen.dart';
import 'package:sparkle_sort/services.dart';

/// Drives the real GameScreen with two-finger gestures.
void main() {
  testWidgets('pinch zooms the board, taps still work while zoomed, reset restores', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Progress.I
      ..level = 30
      ..boosters = {'wand': 2, 'broom': 2, 'magnet': 2};

    await tester.pumpWidget(const MaterialApp(home: GameScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Moves 0'), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsNothing);

    // A misplaced gem near the middle of the board, at zoom 1.
    final data = buildLevel(30);
    const screen = Size(360, 780);
    final l1 = GameLayout(screen, data.cols, data.rows);
    final centre = Offset(data.cols / 2, data.rows / 2);
    var cell = -1;
    var best = double.infinity;
    for (var i = 0; i < data.target.length; i++) {
      if (data.initial[i] == null || data.initial[i] == data.target[i]) continue;
      final d = (Offset((i % data.cols) + 0.5, (i ~/ data.cols) + 0.5) - centre).distance;
      if (d < best) {
        best = d;
        cell = i;
      }
    }
    final focal = l1.cellCenter(cell);

    // Pinch out symmetrically around that gem: it stays under the fingers.
    final a = await tester.startGesture(focal - const Offset(20, 0), pointer: 1);
    final b = await tester.startGesture(focal + const Offset(20, 0), pointer: 2);
    for (var k = 1; k <= 10; k++) {
      await a.moveTo(focal - Offset(20.0 + k * 6, 0));
      await b.moveTo(focal + Offset(20.0 + k * 6, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pump(const Duration(milliseconds: 100));

    // Zoomed: the reset button is shown and no move was made by the pinch.
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsOneWidget);
    expect(find.text('Moves 0'), findsOneWidget);

    // Tap the (now bigger) gem, then the shelf: one move is made.
    await tester.tapAt(focal);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tapAt(l1.shelfRect.center);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Moves 1'), findsOneWidget);

    // Reset animates back to the fitted board.
    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded));
    for (var k = 0; k < 30; k++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  test('zoom limits and pan clamping keep the board on screen', () {
    final d = buildLevel(900);
    const screen = Size(360, 780);
    final base = GameLayout(screen, d.cols, d.rows);
    expect(base.maxZoom, greaterThan(1.5));
    final z = base.maxZoom;
    final zoomed = GameLayout(screen, d.cols, d.rows, zoom: z);
    // A wild pan is pulled back so the board still covers the viewport centre.
    final pan = zoomed.clampPan(const Offset(5000, -5000), z);
    final l = GameLayout(screen, d.cols, d.rows, zoom: z, pan: pan);
    expect(l.boardRect().contains(l.viewport.center), isTrue);
    expect(l.cell, closeTo(base.cell * z, 1e-9));
  });
}
