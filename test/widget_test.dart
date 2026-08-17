import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crashland/game/game_engine.dart';
import 'package:crashland/main.dart';
import 'package:crashland/models/game_phase.dart';
import 'package:crashland/models/night_card.dart';
import 'package:crashland/screens/game_screen.dart';
import 'package:crashland/theme/app_theme.dart';

void main() {
  testWidgets('Planecrash Survival home screen loads', (tester) async {
    await tester.pumpWidget(const PlanecrashApp());

    expect(find.text('Planecrash Survival'), findsOneWidget);
    expect(find.text('New Expedition'), findsOneWidget);
  });

  test('Game starts with crash health, wreckage, and a hidden rescue', () {
    final engine = GameEngine();
    final state = engine.startGame(
      playerNames: ['Alex', 'Blake', 'Casey'],
      totalNights: 8,
    );

    expect(state.players.length, 3);
    expect(state.totalNights, 8);
    expect(state.phase, GamePhase.night);
    expect(state.fireLit, isTrue);
    expect(state.nightNumber, 1);
    expect(state.activeNight, isNotNull);
    expect(state.nightDeck.length, 7);
    expect(
      state.nightDeck.where((card) => card.kind == NightKind.rescue),
      hasLength(1),
    );
    for (final player in state.players) {
      expect(player.hearts, inInclusiveRange(3, 6));
      expect(player.hand, isNotEmpty);
    }
  });

  testWidgets('Game screen lays out on a wide Windows window', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GameScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Night'), findsWidgets);
  });

  test('Foraging spends hearts and then camp begins after everyone acts', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);

    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }

    expect(engine.state!.phase, GamePhase.dayForage);
    expect(engine.state!.fireLit, isFalse);

    engine.restCurrentPlayer();
    engine.restCurrentPlayer();

    expect(engine.state!.phase, GamePhase.dayCamp);
  });
}
