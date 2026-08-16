import 'dart:math';

import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/night_threat.dart';
import '../models/player.dart';
import '../models/resource_type.dart';
import '../models/structure_type.dart';

class GameState {
  GameState({
    required this.players,
    required this.drawPile,
    required this.nightDeck,
    this.phase = GamePhase.setup,
    this.currentPlayerIndex = 0,
    this.nightNumber = 0,
    this.totalNights = 7,
    Set<StructureType>? builtStructures,
    Map<ResourceType, int>? contributionPool,
    this.activeThreat,
    this.message = 'Gather your crew and prepare for the first day.',
    this.won = false,
  })  : builtStructures = builtStructures ?? {},
        contributionPool = contributionPool ?? {};

  final List<Player> players;
  final List<GameCard> drawPile;
  final List<NightThreatType> nightDeck;
  GamePhase phase;
  int currentPlayerIndex;
  int nightNumber;
  final int totalNights;
  Set<StructureType> builtStructures;
  Map<ResourceType, int> contributionPool;
  NightThreatType? activeThreat;
  String message;
  bool won;

  List<Player> get alivePlayers =>
      players.where((player) => player.isAlive).toList();

  Player get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver =>
      phase == GamePhase.gameOver || alivePlayers.isEmpty || won;

  int countInHands(ResourceType resource) {
    var total = 0;
    for (final player in alivePlayers) {
      total += player.hand.where((card) => card.resource == resource).length;
    }
    return total;
  }

  int countAvailable(ResourceType resource) {
    return (contributionPool[resource] ?? 0) + countInHands(resource);
  }

  bool hasStructure(StructureType structure) =>
      builtStructures.contains(structure);
}

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _cardCounter = 0;
  GameState? _state;

  GameState? get state => _state;

  GameState startGame({
    required List<String> playerNames,
    int totalNights = 7,
  }) {
    final players = playerNames
        .asMap()
        .entries
        .map(
          (entry) => Player(
            id: 'p${entry.key}',
            name: entry.value.trim().isEmpty
                ? 'Survivor ${entry.key + 1}'
                : entry.value.trim(),
          ),
        )
        .toList();

    _state = GameState(
      players: players,
      drawPile: _createDrawDeck(),
      nightDeck: _createNightDeck(),
      phase: GamePhase.dayDraw,
      totalNights: totalNights,
      message: 'Day 1 — each survivor draws two cards.',
    );

    return _state!;
  }

  void drawForCurrentPlayer() {
    final state = _requireState();
    if (state.phase != GamePhase.dayDraw) return;

    final player = state.currentPlayer;
    if (!player.isAlive) {
      _advancePlayer(state);
      return;
    }

    _drawCards(player, 2);
    state.message = '${player.name} drew two cards.';
    state.phase = GamePhase.dayAction;
  }

  void contributeCard(String playerId, String cardId) {
    final state = _requireState();
    if (state.phase != GamePhase.dayAction && state.phase != GamePhase.night) {
      return;
    }

    final player = state.players.firstWhere((entry) => entry.id == playerId);
    final cardIndex = player.hand.indexWhere((card) => card.id == cardId);
    if (cardIndex == -1) return;

    final card = player.hand.removeAt(cardIndex);
    state.contributionPool.update(
      card.resource,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    state.message = '${player.name} added ${card.resource.label} to the pool.';
  }

  void tradeCard({
    required String fromPlayerId,
    required String toPlayerId,
    required String cardId,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.dayAction) return;

    final fromPlayer = state.players.firstWhere((p) => p.id == fromPlayerId);
    final toPlayer = state.players.firstWhere((p) => p.id == toPlayerId);
    final cardIndex = fromPlayer.hand.indexWhere((card) => card.id == cardId);
    if (cardIndex == -1 || fromPlayerId == toPlayerId) return;

    final card = fromPlayer.hand.removeAt(cardIndex);
    toPlayer.hand.add(card);
    state.message =
        '${fromPlayer.name} traded ${card.resource.label} to ${toPlayer.name}.';
  }

  void buildStructure(StructureType structure) {
    final state = _requireState();
    if (state.phase != GamePhase.dayAction) return;
    if (state.builtStructures.contains(structure)) {
      state.message = '${structure.label} is already built.';
      return;
    }

    if (!_canAfford(state, structure.cost)) {
      state.message =
          'Not enough pooled resources to build ${structure.label}.';
      return;
    }

    _payCost(state, structure.cost);
    state.builtStructures.add(structure);
    state.message = 'The group built a ${structure.label}.';
  }

  void endPlayerTurn() {
    final state = _requireState();
    if (state.phase != GamePhase.dayAction) return;

    _advancePlayer(state);
    if (state.currentPlayerIndex == 0) {
      _beginNight(state);
    } else {
      state.phase = GamePhase.dayDraw;
      state.message =
          'Day ${state.nightNumber + 1} — ${state.currentPlayer.name} draws next.';
    }
  }

  void resolveNightWithPool() {
    final state = _requireState();
    final threat = state.activeThreat;
    if (state.phase != GamePhase.night || threat == null) return;

    if (_structureCovers(state, threat)) {
      state.message = 'Your camp structures handled ${threat.title}.';
      _finishNight(state);
      return;
    }

    final requirements = _scaledRequirements(state, threat);
    if (!_canAfford(state, requirements)) {
      _applyNightDamage(state, threat.title);
      _finishNight(state);
      return;
    }

    _payCost(state, requirements);
    state.message = 'The group survived ${threat.title}.';
    _finishNight(state);
  }

  void reset() {
    _state = null;
    _cardCounter = 0;
  }

  GameState _requireState() {
    final state = _state;
    if (state == null) {
      throw StateError('Game has not started.');
    }
    return state;
  }

  List<GameCard> _createDrawDeck() {
    final weights = <ResourceType, int>{
      ResourceType.food: 12,
      ResourceType.wood: 10,
      ResourceType.flint: 6,
      ResourceType.rope: 4,
    };

    final cards = <GameCard>[];
    for (final entry in weights.entries) {
      for (var i = 0; i < entry.value; i++) {
        cards.add(_nextCard(entry.key));
      }
    }
    cards.shuffle(_random);
    return cards;
  }

  List<NightThreatType> _createNightDeck() {
    final deck = <NightThreatType>[
      ...NightThreatType.values,
      ...NightThreatType.values,
    ];
    deck.shuffle(_random);
    return deck;
  }

  void _drawCards(Player player, int count) {
    final state = _requireState();
    for (var i = 0; i < count; i++) {
      if (state.drawPile.isEmpty) {
        state.drawPile.addAll(_createDrawDeck());
      }
      if (state.drawPile.isEmpty) break;
      player.hand.add(state.drawPile.removeLast());
    }
  }

  void _advancePlayer(GameState state) {
    if (state.alivePlayers.length <= 1) return;

    final total = state.players.length;
    for (var i = 0; i < total; i++) {
      state.currentPlayerIndex =
          (state.currentPlayerIndex + 1) % state.players.length;
      if (state.currentPlayer.isAlive) return;
    }
  }

  void _beginNight(GameState state) {
    if (state.nightDeck.isEmpty) {
      state.nightDeck.addAll(_createNightDeck());
    }

    state.nightNumber += 1;
    state.phase = GamePhase.night;
    state.contributionPool.clear();
    state.activeThreat = state.nightDeck.removeLast();
    state.message =
        'Night ${state.nightNumber}: ${state.activeThreat!.title} approaches.';
  }

  void _finishNight(GameState state) {
    state.contributionPool.clear();
    state.activeThreat = null;

    if (state.alivePlayers.isEmpty) {
      state.phase = GamePhase.gameOver;
      state.won = false;
      state.message = 'No one made it off the island.';
      return;
    }

    if (state.nightNumber >= state.totalNights) {
      state.phase = GamePhase.gameOver;
      state.won = true;
      state.message = 'Rescue arrives at dawn. You survived Crashland!';
      return;
    }

    state.currentPlayerIndex = state.players.indexOf(state.alivePlayers.first);
    state.phase = GamePhase.dayDraw;
    state.message =
        'Day ${state.nightNumber + 1} — ${state.currentPlayer.name} draws next.';
  }

  void _applyNightDamage(GameState state, String threatTitle) {
    for (final player in state.alivePlayers) {
      player.hearts -= 1;
    }
    state.message =
        '$threatTitle overwhelmed the camp. Each survivor loses a heart.';
  }

  bool _structureCovers(GameState state, NightThreatType threat) {
    if (threat.structure == null) return false;

    return state.builtStructures.any(
      (structure) => structure.name == threat.structure,
    );
  }

  Map<String, int> _scaledRequirements(
    GameState state,
    NightThreatType threat,
  ) {
    final requirements = <String, int>{};
    for (final entry in threat.requirements.entries) {
      requirements[entry.key] = threat.perPlayer
          ? entry.value * state.alivePlayers.length
          : entry.value;
    }
    return requirements;
  }

  bool _canAfford(GameState state, Map<String, int> cost) {
    for (final entry in cost.entries) {
      final resource = ResourceType.values.firstWhere(
        (value) => value.name == entry.key,
      );
      if (state.countAvailable(resource) < entry.value) {
        return false;
      }
    }
    return true;
  }

  void _payCost(GameState state, Map<String, int> cost) {
    for (final entry in cost.entries) {
      var remaining = entry.value;
      final resource = ResourceType.values.firstWhere(
        (value) => value.name == entry.key,
      );

      final pooled = state.contributionPool[resource] ?? 0;
      final fromPool = min(pooled, remaining);
      if (fromPool > 0) {
        state.contributionPool[resource] = pooled - fromPool;
        if (state.contributionPool[resource] == 0) {
          state.contributionPool.remove(resource);
        }
        remaining -= fromPool;
      }

      if (remaining == 0) continue;

      for (final player in state.alivePlayers) {
        while (remaining > 0) {
          final cardIndex =
              player.hand.indexWhere((card) => card.resource == resource);
          if (cardIndex == -1) break;
          player.hand.removeAt(cardIndex);
          remaining -= 1;
        }
        if (remaining == 0) break;
      }
    }
  }

  GameCard _nextCard(ResourceType resource) {
    _cardCounter += 1;
    return GameCard(id: 'c$_cardCounter', resource: resource);
  }
}
