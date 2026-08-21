import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:crashland/game/game_codec.dart';
import 'package:crashland/game/deck_composition.dart';
import 'package:crashland/game/decks.dart';
import 'package:crashland/game/game_engine.dart';
import 'package:crashland/main.dart';
import 'package:crashland/models/card_kind.dart';
import 'package:crashland/models/craft_item.dart';
import 'package:crashland/models/game_card.dart';
import 'package:crashland/models/game_phase.dart';
import 'package:crashland/models/madness_card.dart';
import 'package:crashland/models/night_card.dart';
import 'package:crashland/models/wreckage_assignment.dart';
import 'package:crashland/screens/game_screen.dart';
import 'package:crashland/theme/app_theme.dart';

void main() {
  testWidgets('Planecrash Survival home screen loads', (tester) async {
    await tester.pumpWidget(const PlanecrashApp());

    expect(find.text('Planecrash Survival'), findsOneWidget);
    expect(find.text('Pass-and-play'), findsOneWidget);
    expect(find.text('Host on this device'), findsOneWidget);
  });

  test('Deck composition matches component counts', () {
    var id = 0;
    int nextId() => ++id;
    final random = Random(1);

    expect(Decks.forageDeck(random, nextId).length, DeckComposition.forage);
    expect(Decks.wreckagePool(nextId).length, DeckComposition.wreckage);
    expect(Decks.madnessDeck(random, nextId).length, DeckComposition.madness);

    final craftTotal = Decks.craftStock().values.fold<int>(0, (a, b) => a + b);
    expect(
      craftTotal + DeckComposition.craftGuides,
      DeckComposition.craftAndGuides,
    );
    expect(
      DeckComposition.nightThreats + 1,
      DeckComposition.night,
    );
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
      state.nightDeck.where((card) => card.isRescue),
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
    expect(find.text('Alex'), findsWidgets);
    expect(find.text('Blake'), findsWidgets);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Camp'), findsOneWidget);
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

  test('Foraging to 0♥ does not kill until dawn; heal wreckage works at 0♥', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }

    final alex = engine.state!.players.first;
    alex.hearts = 1;
    alex.hand.removeWhere((card) => card.isFood);
    alex.hand.removeWhere((card) => card.isWreckageHeal);
    alex.hand.add(
      const GameCard(
        id: 'test-choc',
        name: 'Chocolate Bar',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.chocolate,
        healValue: 3,
      ),
    );

    engine.forageCurrentPlayer(1);

    expect(alex.dead, isFalse);
    expect(alex.hearts, 0);
    expect(alex.isAlive, isTrue);

    final heal = alex.hand.firstWhere((card) => card.isWreckageHeal);
    engine.useHealCard(
      ownerId: alex.id,
      cardId: heal.id,
      targetId: alex.id,
    );
    expect(alex.hearts, 3);
  });

  test('Owner can heal another survivor; reusable tarp stays in hand', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }

    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    alex.hand.removeWhere((card) => card.wreckage != null);
    blake.hearts = 2;

    alex.hand.add(
      const GameCard(
        id: 'test-vodka',
        name: 'Bottle of Vodka',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.vodka,
        healValue: 3,
      ),
    );
    alex.hand.add(
      const GameCard(
        id: 'test-tarp',
        name: 'Tarp',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.tarp,
      ),
    );

    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    blake.hearts = 2;
    engine.useHealCard(
      ownerId: alex.id,
      cardId: 'test-vodka',
      targetId: blake.id,
    );
    expect(blake.hearts, 5);
    expect(alex.hand.any((c) => c.id == 'test-vodka'), isFalse);

    // Force a weather night and protect Blake with Alex's tarp.
    engine.state!.activeNight = const NightCard(
      id: 'test-storm',
      title: 'The Rain',
      description: 'Test weather',
      eventType: NightEventType.weather,
      unshelteredHearts: -1,
    );
    engine.state!.phase = GamePhase.night;
    engine.state!.fireLit = false;
    engine.state!.shelters.clear();

    final blakeBefore = blake.hearts;
    final alexBefore = alex.hearts;
    engine.resolveNight(
      wreckageUses: [
        WreckageAssignment(cardId: 'test-tarp', targetIds: [blake.id]),
      ],
    );

    expect(alex.hand.any((c) => c.id == 'test-tarp'), isTrue);
    expect(blake.hearts, blakeBefore);
    expect(alex.hearts, alexBefore - 1);
  });

  test('Craft spears return to the deck after use', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final state = engine.state!;
    final alex = state.players.first;
    expect(state.craftRemaining(CraftItem.spear), DeckComposition.craftSpear);

    // Grant materials and craft a spear without going through forage.
    for (var i = 0; i < 2; i++) {
      state.campStash.add(
        GameCard(
          id: 'wood-$i',
          name: 'Fallen Branch',
          kind: CardKind.wood,
        ),
      );
      state.campStash.add(
        GameCard(
          id: 'stone-$i',
          name: 'River Stone',
          kind: CardKind.stone,
        ),
      );
    }
    state.currentPlayerIndex = state.players.indexOf(alex);
    expect(engine.canCraft(CraftItem.spear), isTrue);
    engine.craft(CraftItem.spear);
    expect(alex.spearCount, 1);
    expect(state.craftRemaining(CraftItem.spear), DeckComposition.craftSpear - 1);

    state.phase = GamePhase.night;
    state.activeNight = const NightCard(
      id: 'cougar',
      title: 'The Cougar',
      description: 'Test animal',
      eventType: NightEventType.animal,
      allHearts: -2,
    );
    engine.resolveNight(spearUsers: {alex.id});
    expect(alex.spearCount, 0);
    expect(state.craftRemaining(CraftItem.spear), DeckComposition.craftSpear);
  });

  test('Full night threat pool matches 40 cards', () {
    var id = 0;
    final deck = Decks.nightDeck(
      random: Random(2),
      totalNights: DeckComposition.night,
      nextId: () => ++id,
    );
    expect(deck.length, DeckComposition.night);
    expect(deck.where((card) => card.isRescue), hasLength(1));
    expect(deck.where((card) => card.isWeather).length, greaterThan(0));
    expect(deck.where((card) => card.isAnimal).length, greaterThan(0));
  });

  test('Madness deck is 8 heart-loss and 13 roleplay cards', () {
    var id = 0;
    final deck = Decks.madnessDeck(Random(3), () => ++id);
    expect(deck.length, DeckComposition.madness);
    expect(
      deck.where((card) => card.kind == MadnessKind.heartLoss),
      hasLength(DeckComposition.madnessHeartLoss),
    );
    expect(
      deck.where((card) => card.kind == MadnessKind.roleplay),
      hasLength(DeckComposition.madnessRoleplay),
    );
  });

  test('Food and heal wreckage can be used during night', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    alex.hand.removeWhere((card) => card.isFood || card.isWreckageHeal);
    blake.hearts = 2;
    alex.hand.add(
      const GameCard(
        id: 'night-food',
        name: 'Wild Berries',
        kind: CardKind.food,
        healValue: 1,
      ),
    );
    engine.useHealCard(
      ownerId: alex.id,
      cardId: 'night-food',
      targetId: blake.id,
    );
    expect(blake.hearts, 3);
    expect(alex.hand.any((card) => card.id == 'night-food'), isFalse);
  });

  test('A survivor at 1♥ draws only one madness card per night', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    blake.hearts = 4;
    alex.hearts = 1;
    engine.state!.activeNight = const NightCard(
      id: 'quiet',
      title: 'The Fog',
      description: 'Nothing happens.',
      eventType: NightEventType.none,
    );
    engine.state!.phase = GamePhase.night;
    engine.resolveNight();

    expect(engine.state!.phase, GamePhase.madness);
    expect(alex.pendingMadness, isNotNull);
    expect(alex.drewMadnessThisNight, isTrue);
    alex.pendingMadness = const MadnessCard(
      id: 'pirate',
      kind: MadnessKind.roleplay,
      title: 'Talk Like a Pirate',
      description: 'Arr!',
    );

    engine.applyMadness();
    expect(alex.hearts, 1);
    expect(alex.pendingMadness, isNull);
    expect(engine.state!.phase, isNot(GamePhase.madness));
  });

  test('game state codec round-trips a started expedition', () {
    final engine = GameEngine(random: Random(7));
    engine.startGame(playerNames: const ['Alex', 'Blake'], totalNights: 8);
    final json = GameCodec.encodeState(
      engine.state!,
      idCursor: engine.idCursor,
    );
    final restored = GameCodec.decodeState(json);
    expect(restored.players.map((p) => p.name), ['Alex', 'Blake']);
    expect(restored.phase, GamePhase.night);
    expect(restored.fireLit, isTrue);
    expect(restored.foragePile.length, DeckComposition.forage);
  });
}
