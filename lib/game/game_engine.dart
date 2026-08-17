import 'dart:math';

import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';
import '../models/player.dart';
import 'decks.dart';

class GameState {
  GameState({
    required this.players,
    required this.foragePile,
    required this.nightDeck,
    required this.madnessPile,
    required this.totalNights,
    this.phase = GamePhase.dayForage,
    this.currentPlayerIndex = 0,
    this.nightNumber = 0,
    this.fireLit = false,
    this.hasShelter = false,
    List<GameCard>? campStash,
    this.activeNight,
    Set<String>? shelterOccupants,
    this.message = 'Day 1 — forage, then return to camp.',
    this.won = false,
    Set<String>? foragedThisRound,
  })  : campStash = campStash ?? [],
        shelterOccupants = shelterOccupants ?? {},
        foragedThisRound = foragedThisRound ?? {};

  final List<Player> players;
  final List<GameCard> foragePile;
  final List<NightCard> nightDeck;
  final List<MadnessCard> madnessPile;
  final int totalNights;
  GamePhase phase;
  int currentPlayerIndex;
  int nightNumber;
  bool fireLit;
  bool hasShelter;
  List<GameCard> campStash;
  NightCard? activeNight;
  Set<String> shelterOccupants;
  String message;
  bool won;
  Set<String> foragedThisRound;

  List<Player> get alivePlayers =>
      players.where((player) => player.isAlive).toList();

  Player get currentPlayer => players[currentPlayerIndex];

  int countResource(CardKind kind) {
    var total = campStash.where((card) => card.kind == kind).length;
    for (final player in alivePlayers) {
      total += player.hand.where((card) => card.kind == kind).length;
    }
    return total;
  }

  Set<int> get collectedBones {
    final bones = <int>{};
    for (final card in campStash) {
      if (card.boneIndex != null) bones.add(card.boneIndex!);
    }
    for (final player in alivePlayers) {
      for (final card in player.hand) {
        if (card.boneIndex != null) bones.add(card.boneIndex!);
      }
    }
    return bones;
  }

  bool get canAssembleBones => collectedBones.length >= 4;
}

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _id = 0;
  GameState? _state;

  GameState? get state => _state;

  int _nextId() => ++_id;

  GameState startGame({
    required List<String> playerNames,
    int totalNights = 8,
  }) {
    final players = playerNames.asMap().entries.map((entry) {
      final rolled = List.generate(3, (_) => _random.nextBool() ? 1 : 0)
          .fold<int>(0, (sum, value) => sum + value);
      return Player(
        id: 'p${entry.key}',
        name: entry.value.trim().isEmpty
            ? 'Survivor ${entry.key + 1}'
            : entry.value.trim(),
        hearts: 3 + rolled,
      );
    }).toList();

    final wreckage = Decks.wreckageForPlayers(players.length, _nextId);
    for (var i = 0; i < players.length; i++) {
      final card = wreckage[i];
      players[i].hand.add(card);
      _applyWreckageGrant(players[i], card);
    }

    _state = GameState(
      players: players,
      foragePile: Decks.forageDeck(_random, _nextId),
      nightDeck: Decks.nightDeck(
        random: _random,
        totalNights: totalNights,
        nextId: _nextId,
      ),
      madnessPile: Decks.madnessDeck(_random, _nextId),
      totalNights: totalNights,
      fireLit: true,
      phase: GamePhase.night,
      message:
          'The wreck is on fire. ${players.map((p) => '${p.name} (${p.hearts}♥)').join(', ')}.',
    );
    _revealNight(_state!, fromCrash: true);
    return _state!;
  }

  void restCurrentPlayer({bool useBasket = false}) {
    final state = _requireState();
    if (state.phase != GamePhase.dayForage) return;
    final player = state.currentPlayer;
    if (!player.isAlive || state.foragedThisRound.contains(player.id)) return;
    if (player.forcedForage != null) {
      state.message = '${player.name} is in a frenzy and must forage.';
      return;
    }
    if (useBasket && (!player.hasBasket || player.forcedRest)) {
      state.message = '${player.name} cannot use a basket while resting.';
      return;
    }

    state.foragedThisRound.add(player.id);
    player.forcedRest = false;

    if (useBasket) {
      final card = _drawForage();
      final notes = <String>[];
      if (card != null) {
        player.hand.add(card);
        if (card.kind == CardKind.uhOh) {
          notes.add(_resolveUhOh(player, card));
        }
      }
      final found = card == null ? 'nothing' : card.name;
      state.message =
          '${player.name} rests and uses the basket to forage $found (no heart recovered).'
          '${notes.isEmpty ? '' : ' ${notes.join(' ')}'}';
      _advanceForage(state);
      return;
    }

    player.hearts = min(player.maxHearts, player.hearts + 1);
    state.message = '${player.name} rests and recovers to ${player.hearts}♥.';
    _advanceForage(state);
  }

  void forageCurrentPlayer(int heartsToFlip) {
    final state = _requireState();
    if (state.phase != GamePhase.dayForage) return;
    final player = state.currentPlayer;
    if (!player.isAlive || state.foragedThisRound.contains(player.id)) return;
    if (player.forcedRest) {
      state.message = '${player.name} collapses and must rest.';
      return;
    }

    var amount = heartsToFlip.clamp(1, player.forageMax);
    if (player.forcedForage != null) {
      amount = min(player.hearts, player.forcedForage!);
    }
    if (amount <= 0) {
      restCurrentPlayer();
      return;
    }

    player.hearts -= amount;
    player.forcedForage = null;
    var draws = amount + (player.hasBasket ? 1 : 0);
    final drawn = <GameCard>[];
    for (var i = 0; i < draws; i++) {
      final card = _drawForage();
      if (card == null) break;
      drawn.add(card);
      player.hand.add(card);
    }

    final notes = <String>[];
    for (final card in List<GameCard>.from(drawn)) {
      if (card.kind == CardKind.uhOh) {
        notes.add(_resolveUhOh(player, card));
      }
    }

    if (player.hearts <= 0) {
      final food = player.hand.where((card) => card.isFood).toList();
      if (food.isEmpty) {
        _kill(player, '${player.name} foraged on their last heart and found no food.');
      } else {
        _eat(player, food.first.id, 1);
        notes.add('${player.name} ate just in time and stays at ${player.hearts}♥.');
      }
    }

    state.foragedThisRound.add(player.id);
    final haul = drawn.map((card) => card.name).join(', ');
    state.message =
        '${player.name} flipped $amount♥ and found: ${haul.isEmpty ? 'nothing' : haul}.'
        '${notes.isEmpty ? '' : ' ${notes.join(' ')}'}';
    _advanceForage(state);
  }

  void contributeToCamp(String playerId, String cardId) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final player = _player(playerId);
    if (!player.isAlive) return;
    final card = _takeFromHand(player, cardId);
    if (card == null) return;
    state.campStash.add(card);
    state.message = '${player.name} placed ${card.name} by the fire.';
  }

  void takeFromCamp(String playerId, String cardId) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final player = _player(playerId);
    if (!player.isAlive) return;
    final index = state.campStash.indexWhere((card) => card.id == cardId);
    if (index == -1) return;
    final card = state.campStash.removeAt(index);
    player.hand.add(card);
    state.message = '${player.name} took ${card.name} from camp.';
  }

  void tradeCard({
    required String fromPlayerId,
    required String toPlayerId,
    required String cardId,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final from = _player(fromPlayerId);
    final to = _player(toPlayerId);
    if (!from.isAlive || !to.isAlive || from.cannotTrade) return;
    final card = _takeFromHand(from, cardId);
    if (card == null) return;
    to.hand.add(card);
    state.message = '${from.name} gave ${card.name} to ${to.name}.';
  }

  void eatFood(String playerId, String cardId, {int hearts = 1}) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final player = _player(playerId);
    if (!player.isAlive) return;
    _eat(player, cardId, hearts);
    if (player.hearts >= 2) player.cannotTrade = false;
    state.message = '${player.name} ate and is now at ${player.hearts}♥.';
  }

  void splitFood({
    required String fromPlayerId,
    required String toPlayerId,
    required String cardId,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final from = _player(fromPlayerId);
    final to = _player(toPlayerId);
    final card = from.hand.cast<GameCard?>().firstWhere(
          (item) => item?.id == cardId,
          orElse: () => null,
        );
    if (card == null || !card.isFood || card.healValue < 2) return;
    from.hand.remove(card);
    from.hearts = min(from.maxHearts, from.hearts + 1);
    to.hearts = min(to.maxHearts, to.hearts + 1);
    if (from.hearts >= 2) from.cannotTrade = false;
    if (to.hearts >= 2) to.cannotTrade = false;
    state.message =
        '${from.name} split ${card.name} with ${to.name}. Both gain 1♥.';
  }

  bool canCraft(CraftItem item) {
    final state = _state;
    if (state == null || state.phase != GamePhase.dayCamp) return false;
    if (item == CraftItem.fire && state.fireLit) return false;
    if (item == CraftItem.shelter && state.hasShelter) return false;
    if (item == CraftItem.basket && state.currentPlayer.hasBasket) return false;
    return _canPay(item);
  }

  void craft(CraftItem item) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;

    if (item == CraftItem.fire && state.fireLit) {
      state.message = 'The campfire is already lit.';
      return;
    }
    if (item == CraftItem.shelter && state.hasShelter) {
      state.message = 'Shelter is already built.';
      return;
    }
    if (!_canPay(item)) {
      state.message = 'Not enough materials for ${item.label}.';
      return;
    }
    if (item == CraftItem.basket && state.currentPlayer.hasBasket) {
      state.message = '${state.currentPlayer.name} already has a Basket.';
      return;
    }

    _pay(item);
    switch (item) {
      case CraftItem.fire:
        state.fireLit = true;
        state.message = 'The campfire is lit. It lasts through tonight.';
      case CraftItem.shelter:
        state.hasShelter = true;
        state.message = 'Shelter is up. Choose up to 3 occupants before night.';
      case CraftItem.basket:
        state.currentPlayer.hasBasket = true;
        state.message = '${state.currentPlayer.name} crafted a Basket.';
      case CraftItem.spear:
        state.currentPlayer.spearCount += 1;
        state.message = '${state.currentPlayer.name} crafted a Spear.';
    }
  }

  void assembleBoneCircle() {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp || !state.canAssembleBones) return;

    _removeBones();
    Player? revived;
    for (final player in state.players) {
      if (!player.isAlive) {
        player.hearts = 3;
        revived = player;
        break;
      }
    }
    for (final player in state.alivePlayers) {
      player.hearts = min(player.maxHearts, player.hearts + 2);
    }
    state.message = revived == null
        ? 'The bone circle hums. Every living survivor gains 2♥.'
        : '${revived.name} returns with 3♥. Every living survivor gains 2♥.';
  }

  void toggleShelterOccupant(String playerId) {
    final state = _requireState();
    if (!state.hasShelter || state.phase != GamePhase.dayCamp) return;
    if (state.shelterOccupants.contains(playerId)) {
      state.shelterOccupants.remove(playerId);
      return;
    }
    if (state.shelterOccupants.length >= 3) {
      state.message = 'Shelter only holds 3 survivors.';
      return;
    }
    state.shelterOccupants.add(playerId);
  }

  void beginNight() {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    _revealNight(state);
  }

  void _revealNight(GameState state, {bool fromCrash = false}) {
    if (state.nightDeck.isEmpty) {
      _lose(state, 'The nights never ended. No one is coming.');
      return;
    }

    state.nightNumber += 1;
    state.activeNight = state.nightDeck.removeLast();
    state.phase = GamePhase.night;
    final fireNote = state.fireLit
        ? (fromCrash
            ? ' The crash fire is burning — it will protect the camp tonight.'
            : ' The campfire is lit.')
        : '';
    state.message =
        '${fromCrash ? 'Night falls on the wreck. ' : ''}'
        'Night ${state.nightNumber}: ${state.activeNight!.title}. '
        '${state.activeNight!.description}$fireNote';
  }

  void resolveNight({
    Set<String> spearUsers = const {},
    Set<String> tarpUsers = const {},
    Set<String> flareUsers = const {},
  }) {
    final state = _requireState();
    final night = state.activeNight;
    if (state.phase != GamePhase.night || night == null) return;

    if (night.isRescue) {
      _win(state, 'Rescue reaches the wreck. You survived Planecrash Survival.');
      return;
    }

    var fireHelps = state.fireLit;
    if (flareUsers.isNotEmpty) {
      for (final id in flareUsers) {
        final player = _player(id);
        if (player.flareCharges > 0) {
          player.flareCharges -= 1;
          fireHelps = true;
        }
      }
    }

    if (night.kind == NightKind.downpour) {
      fireHelps = false;
      state.fireLit = false;
    }

    for (final player in List<Player>.from(state.alivePlayers)) {
      final inShelter = state.hasShelter &&
          state.shelterOccupants.contains(player.id);
      final usedTarp = tarpUsers.contains(player.id) && player.tarpCharges > 0;
      if (usedTarp) player.tarpCharges -= 1;
      final weatherSafe = inShelter || usedTarp;

      final usedSpear = spearUsers.contains(player.id) &&
          (player.spearCount > 0 || player.knifeCount > 0);
      if (usedSpear) {
        if (player.spearCount > 0) {
          player.spearCount -= 1;
        } else {
          player.knifeCount -= 1;
        }
      }

      switch (night.kind) {
        case NightKind.cold:
          if (!fireHelps) _damage(player, 1);
        case NightKind.storm:
        case NightKind.downpour:
          if (!weatherSafe) _damage(player, 1);
        case NightKind.predators:
          if (!fireHelps && !usedSpear) _damage(player, 2);
        case NightKind.raiders:
          if (!usedSpear) _damage(player, 1);
        case NightKind.rescue:
          break;
      }
    }

    _startMadnessCheck(state);
  }

  void applyMadness({
    String? targetId,
    bool defendWithWeapon = false,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.madness) return;
    final player = state.alivePlayers.cast<Player?>().firstWhere(
          (item) => item?.pendingMadness != null,
          orElse: () => null,
        );
    if (player == null) {
      _finishNight(state);
      return;
    }

    final card = player.pendingMadness!;
    player.pendingMadness = null;

    switch (card.kind) {
      case MadnessKind.lashOut:
        final target = state.alivePlayers.firstWhere(
          (item) => item.id == (targetId ?? _otherAlive(player)?.id),
          orElse: () => player,
        );
        if (target.id == player.id) {
          state.message = '${player.name} had no one to lash out at.';
        } else if (defendWithWeapon &&
            (target.spearCount > 0 || target.knifeCount > 0)) {
          if (target.spearCount > 0) {
            target.spearCount -= 1;
          } else {
            target.knifeCount -= 1;
          }
          _damage(player, 1);
          state.message =
              '${target.name} turned a weapon on ${player.name}. ${player.name} loses 1♥.';
        } else {
          _damage(target, 1);
          state.message = '${player.name} lashes out. ${target.name} loses 1♥.';
        }
      case MadnessKind.hoard:
        player.cannotTrade = true;
        state.message = '${player.name} hoards everything until they recover.';
      case MadnessKind.frenzy:
        player.forcedForage = 3;
        state.message = '${player.name} will forage 3 hearts tomorrow.';
      case MadnessKind.collapse:
        player.forcedRest = true;
        state.message = '${player.name} will be forced to rest tomorrow.';
      case MadnessKind.paranoia:
        _damage(player, 1);
        state.message = '${player.name} spirals and loses 1♥.';
    }

    _queueMadnessForOneHeart(state);
    if (state.alivePlayers.every((item) => item.pendingMadness == null)) {
      _finishNight(state);
    }
  }

  void reset() {
    _state = null;
    _id = 0;
  }

  GameState _requireState() {
    final state = _state;
    if (state == null) throw StateError('Game has not started.');
    return state;
  }

  Player _player(String id) =>
      _requireState().players.firstWhere((player) => player.id == id);

  Player? _otherAlive(Player player) {
    final others = _requireState()
        .alivePlayers
        .where((item) => item.id != player.id)
        .toList();
    if (others.isEmpty) return null;
    return others.first;
  }

  void _advanceForage(GameState state) {
    if (state.phase == GamePhase.gameOver) return;
    if (state.alivePlayers.every((p) => state.foragedThisRound.contains(p.id))) {
      state.phase = GamePhase.dayCamp;
      state.currentPlayerIndex =
          state.players.indexOf(state.alivePlayers.first);
      state.message =
          'Back at camp. Eat, trade, craft, then face the night.';
      return;
    }

    do {
      state.currentPlayerIndex =
          (state.currentPlayerIndex + 1) % state.players.length;
    } while (!state.currentPlayer.isAlive ||
        state.foragedThisRound.contains(state.currentPlayer.id));
    state.message =
        '${state.message} Pass the device to ${state.currentPlayer.name}.';
  }

  GameCard? _drawForage() {
    final state = _requireState();
    if (state.foragePile.isEmpty) {
      state.foragePile.addAll(Decks.forageDeck(_random, _nextId));
    }
    if (state.foragePile.isEmpty) return null;
    return state.foragePile.removeLast();
  }

  String _resolveUhOh(Player player, GameCard card) {
    player.hand.remove(card);
    switch (card.uhOh) {
      case UhOhEffect.injury:
        _damage(player, 1);
        return 'Unstable slope: ${player.name} loses 1♥.';
      case UhOhEffect.spoiled:
        final food = player.hand.where((item) => item.isFood).toList();
        if (food.isNotEmpty) {
          player.hand.remove(food.first);
          return 'Spoiled cache: ${player.name} loses ${food.first.name}.';
        }
        _damage(player, 1);
        return 'Spoiled cache: no food to lose, ${player.name} loses 1♥.';
      case UhOhEffect.beast:
        if (player.spearCount > 0) {
          player.spearCount -= 1;
          return 'A beast attacks; ${player.name}\'s spear breaks holding it off.';
        }
        if (player.knifeCount > 0) {
          player.knifeCount -= 1;
          return 'A beast attacks; ${player.name}\'s knife breaks holding it off.';
        }
        _damage(player, 2);
        return 'A beast attacks ${player.name} for 2♥.';
      case null:
        return '';
    }
  }

  void _eat(Player player, String cardId, int hearts) {
    final card = player.hand.cast<GameCard?>().firstWhere(
          (item) => item?.id == cardId,
          orElse: () => null,
        );
    if (card == null) return;
    if (!card.isFood && card.wreckage != WreckageAbility.medkit) return;
    final heal = min(hearts, card.healValue);
    if (heal <= 0) return;
    player.hand.remove(card);
    player.hearts = min(player.maxHearts, player.hearts + heal);
  }

  GameCard? _takeFromHand(Player player, String cardId) {
    final index = player.hand.indexWhere((card) => card.id == cardId);
    if (index == -1) return null;
    return player.hand.removeAt(index);
  }

  bool _canPay(CraftItem item) {
    final state = _requireState();
    return state.countResource(CardKind.wood) >= item.wood &&
        state.countResource(CardKind.stone) >= item.stone &&
        state.countResource(CardKind.fiber) >= item.fiber;
  }

  void _pay(CraftItem item) {
    _spend(CardKind.wood, item.wood);
    _spend(CardKind.stone, item.stone);
    _spend(CardKind.fiber, item.fiber);
  }

  void _spend(CardKind kind, int amount) {
    if (amount <= 0) return;
    final state = _requireState();
    var remaining = amount;
    remaining -= _removeKind(state.campStash, kind, remaining);
    if (remaining <= 0) return;
    remaining -= _removeKind(state.currentPlayer.hand, kind, remaining);
    if (remaining <= 0) return;
    for (final player in state.alivePlayers) {
      remaining -= _removeKind(player.hand, kind, remaining);
      if (remaining <= 0) return;
    }
  }

  int _removeKind(List<GameCard> cards, CardKind kind, int amount) {
    var spent = 0;
    while (spent < amount) {
      final index = cards.indexWhere((card) => card.kind == kind);
      if (index == -1) break;
      cards.removeAt(index);
      spent += 1;
    }
    return spent;
  }

  void _removeBones() {
    final state = _requireState();
    state.campStash.removeWhere((card) => card.kind == CardKind.bonePile);
    for (final player in state.players) {
      player.hand.removeWhere((card) => card.kind == CardKind.bonePile);
    }
  }

  void _applyWreckageGrant(Player player, GameCard card) {
    switch (card.wreckage) {
      case WreckageAbility.tarp:
        player.tarpCharges = 1;
      case WreckageAbility.flare:
        player.flareCharges = 1;
      case WreckageAbility.knife:
        player.knifeCount = 1;
      case WreckageAbility.medkit:
      case null:
        break;
    }
  }

  void _damage(Player player, int amount) {
    player.hearts -= amount;
    if (player.hearts <= 0) {
      _kill(player, '${player.name} has fallen.');
    }
  }

  void _kill(Player player, String reason) {
    final state = _requireState();
    player.hearts = 0;
    state.campStash.addAll(player.hand);
    player.hand.clear();
    player.pendingMadness = null;
    state.message = '$reason Their cards go to camp.';
    if (state.alivePlayers.isEmpty) {
      _lose(state, 'No one made it out of the wreck.');
    }
  }

  void _startMadnessCheck(GameState state) {
    if (state.phase == GamePhase.gameOver) return;
    _queueMadnessForOneHeart(state);
    if (state.alivePlayers.any((player) => player.pendingMadness != null)) {
      state.phase = GamePhase.madness;
      final next = state.alivePlayers.firstWhere(
        (player) => player.pendingMadness != null,
      );
      state.message =
          '${next.name} is down to 1♥ and must face madness: ${next.pendingMadness!.title}. '
          '${next.pendingMadness!.description}';
      return;
    }
    _finishNight(state);
  }

  void _queueMadnessForOneHeart(GameState state) {
    if (state.madnessPile.isEmpty) {
      state.madnessPile.addAll(Decks.madnessDeck(_random, _nextId));
    }
    for (final player in state.alivePlayers) {
      if (player.hearts == 1 && player.pendingMadness == null) {
        if (state.madnessPile.isEmpty) break;
        player.pendingMadness = state.madnessPile.removeLast();
      }
    }
  }

  void _finishNight(GameState state) {
    if (state.phase == GamePhase.gameOver) return;
    state.fireLit = false;
    state.activeNight = null;
    state.foragedThisRound.clear();
    state.shelterOccupants.removeWhere((id) {
      final player = state.players.firstWhere((item) => item.id == id);
      return !player.isAlive;
    });
    state.currentPlayerIndex = state.players.indexOf(state.alivePlayers.first);
    state.phase = GamePhase.dayForage;
    state.message =
        'Dawn. The fire is out. Day ${state.nightNumber + 1} — ${state.currentPlayer.name} forages.';
  }

  void _win(GameState state, String message) {
    state.phase = GamePhase.gameOver;
    state.won = true;
    state.message = message;
  }

  void _lose(GameState state, String message) {
    state.phase = GamePhase.gameOver;
    state.won = false;
    state.message = message;
  }
}
