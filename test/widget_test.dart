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
import 'package:crashland/widgets/heart_display.dart';

void main() {
  testWidgets('Planecrash Survival home screen loads', (tester) async {
    await tester.pumpWidget(const PlanecrashApp());

    expect(find.text('Planecrash Survival'), findsOneWidget);
    expect(find.text('Pass-and-play'), findsOneWidget);
    expect(find.text('Host on this device'), findsOneWidget);
  });

  testWidgets('Empty hearts can be tapped to assign a heal', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HeartDisplay(
            hearts: 2,
            pending: 0,
            canAssign: true,
            onSlotTap: taps.add,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.favorite_border).first);
    expect(taps, [2]);
  });

  test('Deck composition matches component counts', () {
    var id = 0;
    int nextId() => ++id;
    final random = Random(1);

    expect(
      DeckComposition.wood +
          DeckComposition.stone +
          DeckComposition.fiber +
          DeckComposition.bonePile +
          DeckComposition.seagull +
          DeckComposition.moose +
          DeckComposition.waspNest +
          DeckComposition.poisonousMushrooms +
          DeckComposition.paralysisMushroom +
          DeckComposition.neurotoxicMushroom +
          DeckComposition.magicalMushrooms +
          DeckComposition.psychotropicMushrooms +
          DeckComposition.grub +
          DeckComposition.wildOnion +
          DeckComposition.wildParsnip +
          DeckComposition.berries +
          DeckComposition.currants +
          DeckComposition.squirrel +
          DeckComposition.wildPlum +
          DeckComposition.minnows +
          DeckComposition.chanterelle +
          DeckComposition.pineNuts +
          DeckComposition.honeycomb +
          DeckComposition.trout +
          DeckComposition.rabbit +
          DeckComposition.dandelion,
      DeckComposition.forage,
    );
    expect(Decks.wreckagePool(nextId).length, DeckComposition.wreckage);
    expect(Decks.madnessDeck(random, nextId).length, DeckComposition.madness);

    final craftTotal = Decks.craftStock().values.fold<int>(0, (a, b) => a + b) -
        DeckComposition.craftFire;
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
    expect(find.textContaining('Camp'), findsOneWidget);
    expect(find.text('Empty'), findsNWidgets(2));
    expect(find.text('Campfire'), findsNothing);
  });

  testWidgets('Matching forage cards stack in the roster', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.state!.players.first.hand.addAll(const [
      GameCard(id: 'st1', name: 'Stone', kind: CardKind.stone),
      GameCard(id: 'st2', name: 'Stone', kind: CardKind.stone),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GameScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stone ×2'), findsOneWidget);
  });

  testWidgets('Spear craft lets you pick who receives it', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    engine.state!.campStash.addAll(const [
      GameCard(id: 'w1', name: 'Wood', kind: CardKind.wood),
      GameCard(id: 's1', name: 'Stone', kind: CardKind.stone),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GameScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose who'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('craft-spear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-p1')));
    await tester.pumpAndSettle();

    expect(engine.state!.players.first.spearCount, 0);
    expect(engine.state!.players.last.spearCount, 1);
  });

  testWidgets('Camp vodka Use +3♥ heals the acting survivor', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final alex = engine.state!.players.first;
    for (final player in engine.state!.players) {
      player.hand.removeWhere((card) => card.wreckage != null);
    }
    alex.hearts = 2;
    engine.state!.campStash.add(
      const GameCard(
        id: 'camp-vodka',
        name: 'Bottle of Vodka',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.vodka,
        healValue: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GameScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Bottle of Vodka'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-p0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-p0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-p0')));
    await tester.pumpAndSettle();

    expect(alex.hearts, 5);
    expect(
      engine.state!.campStash.any((card) => card.id == 'camp-vodka'),
      isFalse,
    );
  });

  testWidgets('Camp vodka fills tapped empty hearts', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final alex = engine.state!.players.first;
    for (final player in engine.state!.players) {
      player.hand.removeWhere((card) => card.wreckage != null);
    }
    alex.hearts = 2;
    engine.state!.players.last.hearts = 2;
    engine.state!.campStash.add(
      const GameCard(
        id: 'camp-vodka-tap',
        name: 'Bottle of Vodka',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.vodka,
        healValue: 3,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: GameScreen(engine: engine),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Bottle of Vodka'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('player-p0')));
      await tester.pumpAndSettle();
    }

    expect(alex.hearts, 5);
    expect(
      engine.state!.campStash.any((card) => card.id == 'camp-vodka-tap'),
      isFalse,
    );
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

  test('Trout can be eaten whole, split 2/1, or split 1/1/1', () {
    final engine = GameEngine();
    engine.startGame(
      playerNames: ['Alex', 'Blake', 'Casey'],
      totalNights: 8,
    );
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    final casey = engine.state!.players[2];
    alex.hearts = 2;
    blake.hearts = 2;
    casey.hearts = 2;
    alex.hand.removeWhere((card) => card.isFood);

    alex.hand.add(
      const GameCard(
        id: 'trout-full',
        name: 'Trout',
        kind: CardKind.food,
        healValue: 3,
      ),
    );
    engine.eatFood(alex.id, 'trout-full');
    expect(alex.hearts, 5);

    alex.hearts = 2;
    blake.hearts = 2;
    alex.hand.add(
      const GameCard(
        id: 'trout-21',
        name: 'Trout',
        kind: CardKind.food,
        healValue: 3,
      ),
    );
    engine.splitHeal(
      ownerId: alex.id,
      cardId: 'trout-21',
      shares: {blake.id: 2, alex.id: 1},
    );
    expect(blake.hearts, 4);
    expect(alex.hearts, 3);

    alex.hearts = 2;
    blake.hearts = 2;
    casey.hearts = 2;
    alex.hand.add(
      const GameCard(
        id: 'trout-111',
        name: 'Trout',
        kind: CardKind.food,
        healValue: 3,
      ),
    );
    engine.splitHeal(
      ownerId: alex.id,
      cardId: 'trout-111',
      shares: {alex.id: 1, blake.id: 1, casey.id: 1},
    );
    expect(alex.hearts, 3);
    expect(blake.hearts, 3);
    expect(casey.hearts, 3);
  });

  test('Food can fill empty hearts on one survivor or from camp', () {
    final engine = GameEngine();
    engine.startGame(
      playerNames: ['Alex', 'Blake'],
      totalNights: 8,
    );
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    alex.hearts = 2;
    blake.hearts = 4;
    alex.hand.removeWhere((card) => card.isFood);

    alex.hand.add(
      const GameCard(
        id: 'berries-partial',
        name: 'Berries',
        kind: CardKind.food,
        healValue: 2,
      ),
    );
    engine.splitHeal(
      ownerId: alex.id,
      cardId: 'berries-partial',
      shares: {alex.id: 1},
    );
    expect(alex.hearts, 3);
    expect(alex.hand.any((card) => card.id == 'berries-partial'), isFalse);

    engine.state!.campStash.add(
      const GameCard(
        id: 'camp-trout',
        name: 'Trout',
        kind: CardKind.food,
        healValue: 3,
      ),
    );
    alex.hearts = 2;
    blake.hearts = 2;
    engine.splitHeal(
      ownerId: alex.id,
      cardId: 'camp-trout',
      shares: {blake.id: 2, alex.id: 1},
    );
    expect(blake.hearts, 4);
    expect(alex.hearts, 3);
    expect(
      engine.state!.campStash.any((card) => card.id == 'camp-trout'),
      isFalse,
    );
    expect(engine.state!.message, contains('shares camp'));
  });

  test('Camp vodka can be drunk by the acting survivor or split', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    final alex = engine.state!.players[0];
    final blake = engine.state!.players[1];
    alex.hearts = 2;
    blake.hearts = 2;
    engine.state!.campStash.add(
      const GameCard(
        id: 'camp-vodka',
        name: 'Bottle of Vodka',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.vodka,
        healValue: 3,
      ),
    );

    engine.useHealCard(
      ownerId: alex.id,
      cardId: 'camp-vodka',
      targetId: alex.id,
    );
    expect(alex.hearts, 5);
    expect(
      engine.state!.campStash.any((card) => card.id == 'camp-vodka'),
      isFalse,
    );

    engine.state!.campStash.add(
      const GameCard(
        id: 'camp-vodka-2',
        name: 'Bottle of Vodka',
        kind: CardKind.wreckage,
        wreckage: WreckageAbility.vodka,
        healValue: 3,
      ),
    );
    alex.hearts = 2;
    blake.hearts = 2;
    final split = engine.splitHeal(
      ownerId: alex.id,
      cardId: 'camp-vodka-2',
      shares: {blake.id: 2, alex.id: 1},
    );
    expect(split, isTrue);
    expect(blake.hearts, 4);
    expect(alex.hearts, 3);
    expect(
      engine.state!.campStash.any((card) => card.id == 'camp-vodka-2'),
      isFalse,
    );
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

  test('Craft spear and basket go to a chosen survivor', () {
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
    final blake = state.players.last;
    state.campStash.addAll(const [
      GameCard(id: 'w1', name: 'Wood', kind: CardKind.wood),
      GameCard(id: 'w2', name: 'Wood', kind: CardKind.wood),
      GameCard(id: 's1', name: 'Stone', kind: CardKind.stone),
      GameCard(id: 'f1', name: 'Fiber', kind: CardKind.fiber),
      GameCard(id: 'f2', name: 'Fiber', kind: CardKind.fiber),
    ]);

    engine.craft(CraftItem.spear, recipientId: blake.id);
    expect(alex.spearCount, 0);
    expect(blake.spearCount, 1);

    alex.hasBasket = true;
    expect(engine.canCraft(CraftItem.basket, playerId: alex.id), isTrue);
    engine.craft(CraftItem.basket, playerId: alex.id, recipientId: blake.id);
    expect(alex.hasBasket, isTrue);
    expect(blake.hasBasket, isTrue);
    expect(engine.canCraft(CraftItem.basket), isFalse);

    final remaining = state.craftRemaining(CraftItem.basket);
    engine.craft(CraftItem.basket, recipientId: alex.id);
    expect(state.craftRemaining(CraftItem.basket), remaining);
    expect(state.message, contains('already has'));
  });

  test('Selecting wood lights the fire; wood stays with survivors', () {
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
    final blake = state.players.last;
    state.fireLit = false;
    state.fireBlockedNextNight = false;
    alex.hand.removeWhere((card) => card.kind == CardKind.wood);
    blake.hand.removeWhere((card) => card.kind == CardKind.wood);
    state.campStash.removeWhere((card) => card.kind == CardKind.wood);

    alex.hand.add(
      const GameCard(id: 'alex-wood', name: 'Wood', kind: CardKind.wood),
    );
    engine.contributeToCamp(alex.id, 'alex-wood');
    expect(alex.hand.any((card) => card.id == 'alex-wood'), isTrue);
    expect(state.campStash.any((card) => card.id == 'alex-wood'), isFalse);

    engine.lightFire(playerId: alex.id, woodCardId: 'alex-wood');
    expect(state.fireLit, isTrue);
    expect(alex.hand.any((card) => card.id == 'alex-wood'), isFalse);

    state.fireLit = false;
    state.fireFromCraft = false;
    blake.hand.add(
      const GameCard(id: 'blake-wood', name: 'Wood', kind: CardKind.wood),
    );
    engine.lightFire(playerId: alex.id, woodCardId: 'blake-wood');
    expect(state.fireLit, isTrue);
    expect(blake.hand.any((card) => card.id == 'blake-wood'), isFalse);
  });

  test('A dead survivor\'s wood goes to camp and can light the fire', () {
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
    final blake = state.players.last;
    alex.hearts = 5;
    blake.hearts = 1;
    blake.hand
      ..clear()
      ..add(
        const GameCard(id: 'dead-wood', name: 'Wood', kind: CardKind.wood),
      );
    state.campStash.removeWhere((card) => card.id == 'dead-wood');
    state.fireLit = false;
    state.fireFromCraft = false;
    state.fireBlockedNextNight = false;
    state.shelters.clear();
    state.phase = GamePhase.night;
    state.activeNight = const NightCard(
      id: 'wolves',
      title: 'The Wolves',
      description: 'Attack',
      eventType: NightEventType.animal,
      allHearts: -3,
    );
    engine.resolveNight();
    expect(blake.dead, isTrue);
    expect(state.campStash.any((card) => card.id == 'dead-wood'), isTrue);
    expect(blake.hand, isEmpty);

    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }

    expect(engine.state!.phase, GamePhase.dayCamp);
    engine.lightFire(playerId: alex.id, woodCardId: 'dead-wood');
    expect(engine.state!.fireLit, isTrue);
    expect(
      engine.state!.campStash.any((card) => card.id == 'dead-wood'),
      isFalse,
    );
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

  test('Forage deck matches the 109-card list', () {
    var id = 0;
    final deck = Decks.forageDeck(Random(3), () => ++id);
    expect(deck.where((c) => c.kind == CardKind.wood), hasLength(22));
    expect(deck.where((c) => c.kind == CardKind.stone), hasLength(12));
    expect(deck.where((c) => c.kind == CardKind.fiber), hasLength(12));
    expect(deck.where((c) => c.kind == CardKind.bonePile), hasLength(9));
    expect(deck.where((c) => c.name == 'Seagull'), hasLength(1));
    expect(deck.where((c) => c.name == 'Moose'), hasLength(1));
    expect(deck.where((c) => c.name == 'Wasp Nest'), hasLength(1));
    expect(deck.where((c) => c.flavor == 'ludicrously poisonous'), hasLength(1));
    expect(deck.where((c) => c.flavor == 'Paralysis inducing'), hasLength(1));
    expect(deck.where((c) => c.flavor == 'a lovely neurotoxic'), hasLength(1));
    expect(deck.where((c) => c.flavor == 'mysteriously magical'), hasLength(1));
    expect(deck.where((c) => c.flavor == 'cute little psychotropic'), hasLength(1));
    expect(deck.where((c) => c.name == 'Grub'), hasLength(4));
    expect(deck.where((c) => c.name == 'Wild Onion'), hasLength(4));
    expect(deck.where((c) => c.name == 'Wild Parsnip'), hasLength(3));
    expect(deck.where((c) => c.name == 'Berries'), hasLength(4));
    expect(deck.where((c) => c.name == 'Currants'), hasLength(4));
    expect(deck.where((c) => c.name == 'Squirrel'), hasLength(3));
    expect(deck.where((c) => c.name == 'Wild Plum'), hasLength(3));
    expect(deck.where((c) => c.name == 'Minnows'), hasLength(3));
    expect(deck.where((c) => c.name == 'Chanterelle'), hasLength(4));
    expect(deck.where((c) => c.name == 'Pine Nuts'), hasLength(5));
    expect(deck.where((c) => c.name == 'Honeycomb'), hasLength(2));
    expect(deck.where((c) => c.name == 'Trout'), hasLength(2));
    expect(deck.where((c) => c.name == 'Rabbit'), hasLength(2));
    expect(deck.where((c) => c.name == 'Dandelion'), hasLength(3));
  });

  test('Poison mushrooms leave 1♥; moose and wasps deal heart loss', () {
    GameEngine startForage() {
      final engine = GameEngine();
      engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
      engine.resolveNight();
      while (engine.state!.phase == GamePhase.madness) {
        engine.applyMadness();
      }
      return engine;
    }

    var engine = startForage();
    var player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 5;
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'poison',
          name: 'Mushroom',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.setHeartsToOne,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(player.hearts, 1);
    expect(player.hand.any((card) => card.id == 'poison'), isFalse);

    engine = startForage();
    player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 4;
    player.spearCount = 0;
    player.hand.removeWhere((card) => card.wreckage != null);
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'moose-hit',
          name: 'Moose',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.loseHearts,
          uhOhDamage: 2,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(player.hearts, 1);

    engine = startForage();
    player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 4;
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'wasps',
          name: 'Wasp Nest',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.loseHearts,
          uhOhDamage: 1,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(player.hearts, 2);
  });

  test('Psychotropic mushrooms draw a madness card immediately', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }

    final player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 4;
    engine.state!.madnessPile
      ..clear()
      ..add(
        const MadnessCard(
          id: 'shroom-mad',
          kind: MadnessKind.heartLoss,
          title: 'The Fear',
          description: 'Lose 1 heart.',
        ),
      );
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'shrooms',
          name: 'Mushrooms',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.drawMadness,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(player.hearts, 2);
    expect(
      engine.state!.madnessPile.any((card) => card.id == 'shroom-mad'),
      isFalse,
    );
  });

  test('Magical mushrooms preview the next two night cards', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    final player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 3;
    final deck = engine.state!.nightDeck;
    final first = deck[deck.length - 1];
    final second = deck[deck.length - 2];
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'magic',
          name: 'Mushrooms',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.peekNights,
          peekCount: 2,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(engine.state!.peekedNights.map((night) => night.id), [first.id, second.id]);
    expect(engine.state!.nightDeck.length, deck.length);
  });

  test('Paralysis blocks camp actions until dawn; neurotoxin skips forage', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    var player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 3;
    engine.state!.foragePile
      ..clear()
      ..add(
        const GameCard(
          id: 'para',
          name: 'Mushroom',
          kind: CardKind.uhOh,
          uhOh: UhOhEffect.lockArms,
        ),
      );
    engine.forageCurrentPlayer(1);
    expect(player.armsLocked, isTrue);
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    engine.state!.fireLit = false;
    engine.state!.fireBlockedNextNight = false;
    engine.state!.campStash.add(
      const GameCard(id: 'w1', name: 'Wood', kind: CardKind.wood),
    );
    expect(engine.canCraft(CraftItem.fire, playerId: player.id), isFalse);

    player.immobilized = true;
    player.hearts = 4;
    engine.beginNight();
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    expect(player.armsLocked, isFalse);
    expect(player.immobilized, isFalse);

    player = engine.state!.currentPlayer;
    player.immobilized = true;
    player.hasBasket = false;
    player.hearts = 4;
    engine.forageCurrentPlayer(1);
    expect(player.hearts, 4);
    expect(engine.state!.foragedThisRound.contains(player.id), isTrue);
  });

  test('Four bone pile cards assemble a circle and leave extras', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    for (var i = 0; i < 5; i++) {
      engine.state!.campStash.add(
        GameCard(
          id: 'bone$i',
          name: 'Bone Pile',
          kind: CardKind.bonePile,
        ),
      );
    }
    expect(engine.state!.canAssembleBones, isTrue);
    final alex = engine.state!.players.first;
    final blake = engine.state!.players.last;
    final alexHearts = alex.hearts;
    blake.dead = true;
    blake.hearts = 0;
    engine.assembleBoneCircle();
    expect(blake.dead, isFalse);
    expect(blake.isAlive, isTrue);
    expect(blake.hearts, 3);
    expect(alex.hearts, min(alex.maxHearts, alexHearts + 2));
    expect(engine.state!.boneCount, 1);
    expect(engine.state!.message, contains('Blake returns with 3♥'));
  });

  test('Shelter with fewer than 4 survivors covers everyone automatically', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake', 'Casey'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    engine.state!.fireLit = false;
    engine.state!.campStash.addAll(const [
      GameCard(id: 'w1', name: 'Wood', kind: CardKind.wood),
      GameCard(id: 'w2', name: 'Wood', kind: CardKind.wood),
      GameCard(id: 's1', name: 'Stone', kind: CardKind.stone),
      GameCard(id: 's2', name: 'Stone', kind: CardKind.stone),
      GameCard(id: 'f1', name: 'Fiber', kind: CardKind.fiber),
      GameCard(id: 'f2', name: 'Fiber', kind: CardKind.fiber),
    ]);
    engine.craft(CraftItem.shelter);
    expect(engine.state!.shelters, hasLength(1));
    expect(
      engine.state!.shelters.first.occupantIds,
      {'p0', 'p1', 'p2'},
    );
  });

  test('Newly drawn forage cards are tracked until camp', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    final player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 3;
    const drawn = GameCard(
      id: 'fresh-wood',
      name: 'Wood',
      kind: CardKind.wood,
    );
    engine.state!.foragePile
      ..clear()
      ..add(drawn);
    engine.forageCurrentPlayer(1);
    expect(engine.state!.freshForageIds, contains('fresh-wood'));
    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    expect(engine.state!.freshForageIds, isEmpty);
  });

  test('Foraged bone piles go to camp and stay there', () {
    final engine = GameEngine();
    engine.startGame(playerNames: ['Alex', 'Blake'], totalNights: 8);
    engine.resolveNight();
    while (engine.state!.phase == GamePhase.madness) {
      engine.applyMadness();
    }
    final player = engine.state!.currentPlayer;
    player.hasBasket = false;
    player.hearts = 3;
    const bone = GameCard(
      id: 'fresh-bone',
      name: 'Bone Pile',
      kind: CardKind.bonePile,
    );
    engine.state!.foragePile
      ..clear()
      ..add(bone);
    engine.forageCurrentPlayer(1);
    expect(player.hand.any((card) => card.id == 'fresh-bone'), isFalse);
    expect(
      engine.state!.campStash.any((card) => card.id == 'fresh-bone'),
      isTrue,
    );
    expect(engine.state!.freshForageIds.contains('fresh-bone'), isFalse);

    while (engine.state!.phase == GamePhase.dayForage) {
      engine.restCurrentPlayer();
    }
    engine.takeFromCamp(player.id, 'fresh-bone');
    expect(player.hand.any((card) => card.id == 'fresh-bone'), isFalse);
    expect(
      engine.state!.campStash.any((card) => card.id == 'fresh-bone'),
      isTrue,
    );
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
