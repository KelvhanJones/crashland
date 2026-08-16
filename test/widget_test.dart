import 'package:flutter_test/flutter_test.dart';

import 'package:crashland/game/game_engine.dart';
import 'package:crashland/main.dart';

void main() {
  testWidgets('Crashland home screen loads', (tester) async {
    await tester.pumpWidget(const CrashlandApp());

    expect(find.text('Crashland'), findsOneWidget);
    expect(find.text('New Expedition'), findsOneWidget);
  });

  test('Game engine starts with expected player count', () {
    final engine = GameEngine();
    final state = engine.startGame(
      playerNames: ['Alex', 'Blake', 'Casey'],
      totalNights: 7,
    );

    expect(state.players.length, 3);
    expect(state.totalNights, 7);
    expect(state.phase.name, 'dayDraw');
  });
}
