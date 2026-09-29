import 'package:flutter_test/flutter_test.dart';
import 'package:sparkle_sort/game/autoplay.dart';
import 'package:sparkle_sort/game/game_controller.dart';

/// Plays levels 1-17 through the controller's tap API, like a player would.
void main() {
  for (var level = 1; level <= 17; level++) {
    test('level $level can be completed with taps', () {
      final g = GameController(level, tutorial: level == 1);
      var won = false, deadlock = false;
      g.onWin = () => won = true;
      g.onDeadlock = () => deadlock = true;
      var t = 0.0;
      var taps = 0;
      while (!won && !deadlock && taps < 600) {
        final moved = autoplayStep(g);
        taps++;
        // Let every flight land.
        for (var k = 0; k < 60 && (g.busy || k < 2); k++) {
          g.tick(t += 0.05);
        }
        if (!moved) break;
      }
      expect(deadlock, isFalse, reason: 'level $level dead-ended');
      expect(won, isTrue, reason: 'level $level not solved after $taps taps');
      expect(g.isSolved, isTrue);
      // ignore: avoid_print
      print('level $level: ${g.cols}x${g.rows}, solved in $taps taps');
    });
  }
}
