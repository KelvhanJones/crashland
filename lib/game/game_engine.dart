import 'dart:math';

import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';
import '../models/player.dart';
import '../models/built_shelter.dart';
import '../models/wreckage_assignment.dart';
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
    this.fireFromCraft = false,
    this.caveShelter = false,
    this.pendingNoFireTomorrow = false,
    this.fireBlockedNextNight = false,
    Map<CraftItem, int>? craftStock,
    List<GameCard>? campStash,
    List<BuiltShelter>? shelters,
    this.activeNight,
    List<NightCard>? peekedNights,
    String message = 'Day 1 — forage, then return to camp.',
    this.won = false,
    Set<String>? foragedThisRound,
    Set<String>? freshForageIds,
    List<String>? actionLog,
  })  : craftStock = craftStock ?? Decks.craftStock(),
        campStash = campStash ?? [],
        shelters = shelters ?? [],
        peekedNights = peekedNights ?? [],
        foragedThisRound = foragedThisRound ?? {},
        freshForageIds = freshForageIds ?? {},
        _message = message,
        actionLog = List<String>.from(actionLog ?? [message]);

  final List<Player> players;
  final List<GameCard> foragePile;
  final List<NightCard> nightDeck;
  final List<MadnessCard> madnessPile;
  final int totalNights;
  GamePhase phase;
  int currentPlayerIndex;
  int nightNumber;
  bool fireLit;
  /// True when tonight's fire came from a craft card (not the crash blaze).
  bool fireFromCraft;
  /// The Cave: permanent shelter for everyone.
  bool caveShelter;
  /// Set during night resolve; applied at dawn to block the next fire.
  bool pendingNoFireTomorrow;
  /// Cannot light a fire for the upcoming night.
  bool fireBlockedNextNight;
  Map<CraftItem, int> craftStock;
  List<GameCard> campStash;
  /// Each shelter protects up to 3 survivors chosen when it was crafted.
  final List<BuiltShelter> shelters;
  NightCard? activeNight;
  /// Magical mushrooms: upcoming nights still in the deck.
  List<NightCard> peekedNights;
  String _message;
  bool won;
  Set<String> foragedThisRound;
  /// Cards drawn this forage round; hidden from other survivors until camp.
  Set<String> freshForageIds;
  /// Scrollable history of what happened (banner messages + heart changes).
  final List<String> actionLog;

  String get message => _message;

  set message(String value) {
    _message = value;
    log(value);
  }

  void log(String entry) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) return;
    if (actionLog.isNotEmpty && actionLog.last == trimmed) return;
    actionLog.add(trimmed);
  }

  bool get hasShelter => caveShelter || shelters.isNotEmpty;

  int get shelterCount => shelters.length;

  Set<String> get shelterOccupants => {
        for (final shelter in shelters) ...shelter.occupantIds,
      };

  bool isSheltered(String playerId) =>
      caveShelter || shelters.any((shelter) => shelter.protects(playerId));

  int craftRemaining(CraftItem item) => craftStock[item] ?? 0;

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

  int get boneCount {
    var total = campStash.where((card) => card.kind == CardKind.bonePile).length;
    for (final player in alivePlayers) {
      total += player.hand.where((card) => card.kind == CardKind.bonePile).length;
    }
    return total;
  }

  bool get canAssembleBones => boneCount >= 4;
}

class GameEngine {
  GameEngine({Random? random}) : _random = random ?? Random();

  final Random _random;
  int _id = 0;
  GameState? _state;

  GameState? get state => _state;

  int _nextId() => ++_id;

  int get idCursor => _id;

  void restore(GameState state, {int? idCursor}) {
    _state = state;
    _id = idCursor ?? _highestId(state);
  }

  static int _highestId(GameState state) {
    var maxId = 0;
    void consider(String id) {
      final match = RegExp(r'(\d+)$').firstMatch(id);
      final value = int.tryParse(match?.group(1) ?? '') ?? 0;
      if (value > maxId) maxId = value;
    }

    for (final player in state.players) {
      consider(player.id);
      for (final card in player.hand) {
        consider(card.id);
      }
    }
    for (final card in state.campStash) {
      consider(card.id);
    }
    for (final card in state.foragePile) {
      consider(card.id);
    }
    for (final card in state.nightDeck) {
      consider(card.id);
    }
    if (state.activeNight != null) consider(state.activeNight!.id);
    for (final card in state.madnessPile) {
      consider(card.id);
    }
    for (final player in state.players) {
      if (player.pendingMadness != null) consider(player.pendingMadness!.id);
    }
    return maxId;
  }

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

    final wreckage = Decks.wreckageForPlayers(
      players.length,
      _random,
      _nextId,
    );
    for (var i = 0; i < players.length; i++) {
      players[i].hand.add(wreckage[i]);
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
    if (player.immobilized) {
      skipImmobilizedForage();
      return;
    }
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
        _receiveDrawnForage(player, card);
        if (card.kind == CardKind.uhOh) {
          notes.add(_resolveUhOh(player, card));
        }
      }
      final found = card == null
          ? 'nothing'
          : (card.kind == CardKind.bonePile
              ? '${card.name} (camp)'
              : card.name);
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
    if (player.immobilized) {
      skipImmobilizedForage();
      return;
    }
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
    state.log(
      '${player.name} spends $amount♥ foraging (now ${player.hearts}♥)',
    );
    var draws = amount + (player.hasBasket ? 1 : 0);
    final drawn = <GameCard>[];
    for (var i = 0; i < draws; i++) {
      final card = _drawForage();
      if (card == null) break;
      drawn.add(card);
      _receiveDrawnForage(player, card);
    }

    final notes = <String>[];
    for (final card in List<GameCard>.from(drawn)) {
      if (card.kind == CardKind.uhOh) {
        notes.add(_resolveUhOh(player, card));
      }
    }

    if (player.hearts <= 0) {
      notes.add(
        player.hasHealWreckage
            ? '${player.name} is at 0♥ — use a heal wreckage (or eat food) before tomorrow\'s dawn.'
            : '${player.name} is at 0♥ — eat food or use a heal wreckage before tomorrow\'s dawn, or they die.',
      );
    }

    state.foragedThisRound.add(player.id);
    final haul = drawn
        .map(
          (card) => card.kind == CardKind.bonePile
              ? '${card.name} (camp)'
              : card.name,
        )
        .join(', ');
    state.message =
        '${player.name} flipped $amount♥ and found: ${haul.isEmpty ? 'nothing' : haul}.'
        '${notes.isEmpty ? '' : ' ${notes.join(' ')}'}';
    _advanceForage(state);
  }

  void skipImmobilizedForage() {
    final state = _requireState();
    if (state.phase != GamePhase.dayForage) return;
    final player = state.currentPlayer;
    if (!player.isAlive || state.foragedThisRound.contains(player.id)) return;
    state.foragedThisRound.add(player.id);
    state.message =
        '${player.name} cannot move and skips foraging until the next day.';
    _advanceForage(state);
  }

  void contributeToCamp(String playerId, String cardId) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final player = _player(playerId);
    if (player.cannotAct) return;
    final held = player.hand.cast<GameCard?>().firstWhere(
          (item) => item?.id == cardId,
          orElse: () => null,
        );
    if (held == null) return;
    if (held.kind == CardKind.wood) {
      state.message = 'Wood stays with survivors. Select it to light the fire.';
      return;
    }
    final card = _takeFromHand(player, cardId);
    if (card == null) return;
    state.campStash.add(card);
    state.message = '${player.name} placed ${card.name} by the fire.';
  }

  void takeFromCamp(String playerId, String cardId) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp && state.phase != GamePhase.night) {
      return;
    }
    final player = _player(playerId);
    if (player.cannotAct) return;
    final index = state.campStash.indexWhere((card) => card.id == cardId);
    if (index == -1) return;
    final card = state.campStash[index];
    if (card.kind == CardKind.bonePile) {
      state.message = 'Bone piles stay at camp.';
      return;
    }
    state.campStash.removeAt(index);
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
    if (from.cannotAct || to.cannotAct || from.cannotTrade) return;
    final card = _takeFromHand(from, cardId);
    if (card == null) return;
    to.hand.add(card);
    state.message = '${from.name} gave ${card.name} to ${to.name}.';
  }

  void eatFood(String playerId, String cardId, {int? hearts}) {
    useHealCard(
      ownerId: playerId,
      cardId: cardId,
      targetId: playerId,
      hearts: hearts,
    );
  }

  /// Heal with food or wreckage. [ownerId] acts; the card may be in their hand
  /// or in the camp stash.
  void useHealCard({
    required String ownerId,
    required String cardId,
    required String targetId,
    int? hearts,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp &&
        state.phase != GamePhase.dayForage &&
        state.phase != GamePhase.night) {
      return;
    }
    var actor = _player(ownerId);
    final target = _player(targetId);
    if (target.dead) return;

    final located = _locateHealCard(cardId);
    if (located == null) return;
    final (card, fromCamp) = located;
    if (actor.cannotAct || actor.dead) {
      if (!fromCamp) return;
      final capable = state.alivePlayers.where((player) => !player.cannotAct);
      if (capable.isEmpty) return;
      actor = capable.first;
    }

    final isWreckage = card.wreckage != null;
    if (!card.isFood && !card.isWreckageHeal) return;
    if (state.phase == GamePhase.dayForage && !isWreckage) return;
    if (fromCamp && state.phase == GamePhase.dayForage) return;

    // Chocolate may be used on another survivor (full amount) but cannot be split.
    if (card.fullHeal || card.wreckage == WreckageAbility.adrenaline) {
      _removeLocatedCard(card, actor: actor, fromCamp: fromCamp);
      target.hearts = target.maxHearts;
      if (target.hearts >= 2) target.cannotTrade = false;
      state.message =
          '${actor.name} uses ${card.name} on ${target.name} — fully restored to ${target.hearts}♥.';
      return;
    }

    final heal = hearts ?? card.healValue;
    if (heal <= 0) return;
    _removeLocatedCard(card, actor: actor, fromCamp: fromCamp);
    target.hearts = min(target.maxHearts, target.hearts + heal);
    if (target.hearts >= 2) target.cannotTrade = false;
    state.message = ownerId == targetId
        ? '${target.name} uses ${card.name} and is at ${target.hearts}♥.'
        : '${actor.name} uses ${card.name} on ${target.name} — now ${target.hearts}♥.';
  }

  bool _canSplitHeal(GameCard card) =>
      card.wreckage == WreckageAbility.vodka ||
      (card.isFood && card.healValue > 0 && !card.fullHeal);

  (GameCard, bool)? _locateHealCard(String cardId) {
    final state = _requireState();
    final campIndex = state.campStash.indexWhere((item) => item.id == cardId);
    if (campIndex != -1) {
      return (state.campStash[campIndex], true);
    }
    for (final player in state.players) {
      final index = player.hand.indexWhere((item) => item.id == cardId);
      if (index == -1) continue;
      return (player.hand[index], false);
    }
    return null;
  }

  void _removeLocatedCard(
    GameCard card, {
    required Player actor,
    required bool fromCamp,
  }) {
    final state = _requireState();
    if (fromCamp) {
      state.campStash.removeWhere((item) => item.id == card.id);
      return;
    }
    for (final player in state.players) {
      if (player.hand.remove(card)) return;
    }
    actor.hand.remove(card);
  }

  /// Heal with food or vodka. [shares] may be one or more living survivors
  /// and may use some or all of the card's hearts.
  bool splitHeal({
    required String ownerId,
    required String cardId,
    required Map<String, int> shares,
  }) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp && state.phase != GamePhase.night) {
      return false;
    }

    var actor = _player(ownerId);
    final located = _locateHealCard(cardId);
    if (located == null) return false;
    final (card, fromCamp) = located;
    if (!_canSplitHeal(card)) return false;

    if (actor.cannotAct) {
      if (!fromCamp) return false;
      final capable = state.alivePlayers.where((player) => !player.cannotAct);
      if (capable.isEmpty) return false;
      actor = capable.first;
    }

    final cleaned = <String, int>{
      for (final entry in shares.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (cleaned.isEmpty) return false;

    final recipients = <Player, int>{};
    var total = 0;
    for (final entry in cleaned.entries) {
      final player = _player(entry.key);
      if (player.dead) {
        state.message = '${player.name} cannot be healed.';
        return false;
      }
      final room = player.maxHearts - player.hearts;
      final given = min(entry.value, room);
      if (given < 1) continue;
      recipients[player] = given;
      total += given;
    }
    if (recipients.isEmpty || total < 1) {
      state.message = 'No empty hearts to fill with ${card.name}.';
      return false;
    }
    if (total > card.healValue) return false;

    _removeLocatedCard(card, actor: actor, fromCamp: fromCamp);
    for (final entry in recipients.entries) {
      entry.key.hearts =
          min(entry.key.maxHearts, entry.key.hearts + entry.value);
      if (entry.key.hearts >= 2) entry.key.cannotTrade = false;
    }
    final parts = recipients.entries
        .map((entry) => '${entry.key.name} +${entry.value}♥')
        .join(', ');
    state.message = fromCamp
        ? '${actor.name} shares camp ${card.name}: $parts.'
        : '${actor.name} uses ${card.name}: $parts.';
    return true;
  }

  /// Split a shareable heal (vodka) between the owner and one other survivor.
  void shareHealCard({
    required String ownerId,
    required String cardId,
    required String otherId,
    int ownerHearts = 1,
    int otherHearts = 2,
  }) {
    splitHeal(
      ownerId: ownerId,
      cardId: cardId,
      shares: {ownerId: ownerHearts, otherId: otherHearts},
    );
  }

  void splitFood({
    required String fromPlayerId,
    required String toPlayerId,
    required String cardId,
    int fromHearts = 1,
    int toHearts = 1,
  }) {
    splitHeal(
      ownerId: fromPlayerId,
      cardId: cardId,
      shares: {fromPlayerId: fromHearts, toPlayerId: toHearts},
    );
  }

  bool canCraft(CraftItem item, {String? playerId}) {
    final state = _state;
    if (state == null || state.phase != GamePhase.dayCamp) return false;
    if (item != CraftItem.fire && state.craftRemaining(item) <= 0) return false;
    if (item == CraftItem.fire && state.fireLit) return false;
    if (item == CraftItem.fire && state.fireBlockedNextNight) return false;
    final crafter = playerId == null ? state.currentPlayer : _player(playerId);
    if (crafter.cannotAct) return false;
    if (item == CraftItem.basket &&
        state.alivePlayers.every((player) => player.hasBasket)) {
      return false;
    }
    return _canPay(item);
  }

  void craft(
    CraftItem item, {
    Set<String> shelterOccupantIds = const {},
    String? playerId,
    String? recipientId,
  }) {
    if (item == CraftItem.fire) {
      lightFire(playerId: playerId);
      return;
    }
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final crafter = playerId == null ? state.currentPlayer : _player(playerId);
    if (crafter.cannotAct) return;

    if (state.craftRemaining(item) <= 0) {
      state.message =
          'No ${item.label} cards available — all are in play.';
      return;
    }

    Player? recipient;
    if (item == CraftItem.spear || item == CraftItem.basket) {
      recipient = recipientId == null ? crafter : _player(recipientId);
      if (!recipient.isAlive) {
        state.message =
            '${recipient.name} is gone and cannot take a ${item.label}.';
        return;
      }
      if (item == CraftItem.basket && recipient.hasBasket) {
        state.message = '${recipient.name} already has a Basket.';
        return;
      }
    }

    if (!_canPay(item)) {
      state.message = 'Not enough materials for ${item.label}.';
      return;
    }

    Set<String>? shelterOccupants;
    if (item == CraftItem.shelter) {
      final aliveIds = state.alivePlayers.map((p) => p.id).toSet();
      shelterOccupants = shelterOccupantIds.where(aliveIds.contains).toSet();
      if (shelterOccupants.isEmpty && aliveIds.length <= 3) {
        shelterOccupants = aliveIds;
      }
      if (shelterOccupants.isEmpty || shelterOccupants.length > 3) {
        state.message =
            'Choose 1–3 living survivors for this shelter when you craft it.';
        return;
      }
    }

    _pay(item);
    _takeCraft(item);
    switch (item) {
      case CraftItem.fire:
        break;
      case CraftItem.shelter:
        final occupants = shelterOccupants!;
        state.shelters.add(BuiltShelter(occupantIds: occupants));
        final names = state.alivePlayers
            .where((p) => occupants.contains(p.id))
            .map((p) => p.name)
            .join(', ');
        state.message =
            'Shelter built for $names. Occupants are locked in until the shelter is wrecked.';
      case CraftItem.basket:
        recipient!.hasBasket = true;
        state.message = recipient.id == crafter.id
            ? '${crafter.name} crafted a Basket.'
            : '${crafter.name} crafted a Basket for ${recipient.name}.';
      case CraftItem.spear:
        recipient!.spearCount += 1;
        state.message = recipient.id == crafter.id
            ? '${crafter.name} crafted a Spear.'
            : '${crafter.name} crafted a Spear for ${recipient.name}.';
    }
  }

  /// Light the campfire with a specific wood card, or any wood if [woodCardId] is omitted.
  void lightFire({String? playerId, String? woodCardId}) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp) return;
    final actor = playerId == null ? state.currentPlayer : _player(playerId);
    if (actor.cannotAct) return;
    if (state.fireLit) {
      state.message = 'The campfire is already lit.';
      return;
    }
    if (state.fireBlockedNextNight) {
      state.message = 'Last night\'s weather blocks fire for tonight.';
      return;
    }

    if (woodCardId != null) {
      if (!_spendWoodCard(woodCardId)) {
        state.message = 'Select a wood card to light the fire.';
        return;
      }
    } else if (!_canPay(CraftItem.fire)) {
      state.message = 'Need 1 wood to light the fire.';
      return;
    } else {
      _pay(CraftItem.fire);
    }

    _takeCraft(CraftItem.fire);
    state.fireLit = true;
    state.fireFromCraft = true;
    state.message =
        '${actor.name} lights the campfire. It lasts through tonight.';
  }

  bool _spendWoodCard(String cardId) {
    final state = _requireState();
    final campIndex = state.campStash.indexWhere(
      (card) => card.id == cardId && card.kind == CardKind.wood,
    );
    if (campIndex != -1) {
      state.campStash.removeAt(campIndex);
      return true;
    }
    for (final player in state.players) {
      final index = player.hand.indexWhere(
        (card) => card.id == cardId && card.kind == CardKind.wood,
      );
      if (index == -1) continue;
      player.hand.removeAt(index);
      return true;
    }
    return false;
  }

  void assembleBoneCircle({String? playerId}) {
    final state = _requireState();
    if (state.phase != GamePhase.dayCamp || !state.canAssembleBones) return;
    final actor = playerId == null ? state.currentPlayer : _player(playerId);
    if (actor.cannotAct) return;

    _removeBones();
    final alreadyLiving = state.alivePlayers.toList();
    Player? revived;
    for (final player in state.players) {
      if (player.isAlive) continue;
      player.dead = false;
      player.hearts = 3;
      player.cannotTrade = false;
      player.armsLocked = false;
      player.immobilized = false;
      player.forcedRest = false;
      player.forcedForage = null;
      player.pendingMadness = null;
      revived = player;
      break;
    }
    for (final player in alreadyLiving) {
      player.hearts = min(player.maxHearts, player.hearts + 2);
      if (player.hearts >= 2) player.cannotTrade = false;
    }
    state.message = revived == null
        ? 'The bone circle hums. Every living survivor gains 2♥.'
        : '${revived.name} returns with 3♥. Every living survivor gains 2♥.';
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
    state.peekedNights.clear();
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
    List<WreckageAssignment> wreckageUses = const [],
    /// For Raccoons: playerId -> true means discard a food card; false means take 1♥.
    Map<String, bool> raccoonDiscardFood = const {},
  }) {
    final state = _requireState();
    final night = state.activeNight;
    if (state.phase != GamePhase.night || night == null) return;

    if (night.isRescue) {
      _win(state, 'Rescue reaches the wreck. You survived Planecrash Survival.');
      return;
    }

    final fireHelps = state.fireLit;
    final notes = <String>[];

    // Wreckage + spear defenses
    final weatherProtected = <String>{};
    final attackProtected = <String>{};
    var campAnimalProtected = false;

    for (final use in wreckageUses) {
      final found = _findWreckage(use.cardId);
      if (found == null) continue;
      final (owner, card) = found;
      if (owner.cannotAct) continue;
      final ability = card.wreckage!;

      if (night.isWeather && ability.blocksWeather) {
        final needed = ability.weatherTargetCount;
        final targets = use.targetIds
            .where((id) => state.alivePlayers.any((p) => p.id == id))
            .take(needed)
            .toList();
        if (targets.length < needed && ability == WreckageAbility.newspaper) {
          continue;
        }
        if (targets.isEmpty) continue;
        weatherProtected.addAll(targets);
        _consumeWreckageCard(owner, card);
      } else if (night.dealsAnimalHeartDamage) {
        if (ability.blocksAnimalCampWide) {
          campAnimalProtected = true;
          _consumeWreckageCard(owner, card);
        } else if (ability.blocksAnimalOrHuman) {
          final target = use.targetIds.cast<String?>().firstWhere(
                (id) => state.alivePlayers.any((p) => p.id == id),
                orElse: () => null,
              );
          if (target == null) continue;
          attackProtected.add(target);
          _consumeWreckageCard(owner, card);
        }
      }
    }

    if (night.dealsAnimalHeartDamage) {
      for (final playerId in spearUsers) {
        final player = _player(playerId);
        if (player.cannotAct) continue;
        if (player.spearCount <= 0) continue;
        _consumeSpear(player);
        attackProtected.add(player.id);
      }
    }

    // Global cancelled-by-fire packages
    final eventCancelled = night.fireCancels && fireHelps;

    if (night.permanentCave) {
      state.caveShelter = true;
      notes.add('The Cave is found — permanent shelter for everyone.');
    }

    if (!eventCancelled && night.loseAllForage) {
      _loseAllForageCards(state);
      notes.add('All forage cards are washed away.');
    }

    if (!eventCancelled && night.loseAllFiber) {
      _loseAllFiber(state);
      notes.add('All fiber is lost.');
    }

    if (!eventCancelled && night.discardOneForage) {
      for (final player in state.alivePlayers) {
        _discardOneForage(player);
      }
      notes.add('Everyone discards 1 forage card if they have one.');
    }

    if (!eventCancelled && night.raccoonChoice) {
      for (final player in List<Player>.from(state.alivePlayers)) {
        final discardFood = raccoonDiscardFood[player.id] ?? false;
        if (discardFood) {
          final food = player.hand.cast<GameCard?>().firstWhere(
                (card) => card?.isFood ?? false,
                orElse: () => null,
              );
          if (food != null) {
            player.hand.remove(food);
            state.log('${player.name} discards ${food.name} (Raccoons)');
          } else {
            _damage(player, 1, cause: night.title);
          }
        } else {
          _damage(player, 1, cause: night.title);
        }
      }
    }

    for (final player in List<Player>.from(state.alivePlayers)) {
      final weatherSafe =
          state.isSheltered(player.id) || weatherProtected.contains(player.id);
      final attackSafe =
          attackProtected.contains(player.id) || campAnimalProtected;

      if (eventCancelled) continue;

      // Heals
      if (night.allHearts > 0) {
        var heal = night.allHearts;
        if (fireHelps) heal += night.fireBonusHeal;
        _heal(player, heal, cause: night.title);
      }

      // All-player damage
      if (night.allHearts < 0) {
        if (night.damageIfHasForage && !_hasForageCard(player)) {
          state.log('${player.name} has no forage — ${night.title} misses');
        } else if (night.dealsAnimalHeartDamage && attackSafe) {
          state.log('${player.name} is protected from ${night.title}');
        } else {
          var loss = -night.allHearts;
          if (fireHelps && night.fireReducesAbsDamageTo != null) {
            loss = night.fireReducesAbsDamageTo!;
          }
          _damage(player, loss, cause: night.title);
        }
      }

      // Unsheltered weather damage
      if (night.unshelteredHearts < 0 && !weatherSafe) {
        _damage(
          player,
          -night.unshelteredHearts,
          cause: '${night.title} (unsheltered)',
        );
      } else if (night.unshelteredHearts < 0 && weatherSafe) {
        state.log('${player.name} is sheltered from ${night.title}');
      }
    }

    if (night.destroyShelter && state.shelters.isNotEmpty) {
      _destroyAllShelters(state);
      notes.add('Shelter is destroyed.');
    }

    if (night.noFireTomorrow) {
      if (state.fireLit) {
        _extinguishFire(state);
        notes.add('Fire is drowned out immediately.');
        state.log('${night.title} puts out the fire');
      }
      state.pendingNoFireTomorrow = true;
      notes.add('No fire tomorrow night.');
    }

    if (eventCancelled && fireHelps) {
      notes.add('Fire keeps the camp safe.');
      state.log('${night.title} cancelled by fire');
    }

    if (notes.isNotEmpty) {
      state.message = '${night.title}: ${notes.join(' ')}';
    } else {
      state.log('Resolved ${night.title}');
    }

    _startMadnessCheck(state);
  }

  void applyMadness() {
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
      case MadnessKind.heartLoss:
        _damage(player, 1, cause: card.title);
        state.message =
            '${player.name} draws ${card.title} and loses 1♥.';
      case MadnessKind.roleplay:
        state.message =
            '${player.name} draws ${card.title}: ${card.description}';
        state.log('${player.name} must: ${card.description}');
    }

    _queueMadnessForOneHeart(state);
    if (state.alivePlayers.every((item) => item.pendingMadness == null)) {
      _finishNight(state);
    } else {
      final next = state.alivePlayers.firstWhere(
        (item) => item.pendingMadness != null,
      );
      state.message =
          '${state.message} Next: ${next.name} faces ${next.pendingMadness!.title}.';
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

  void _advanceForage(GameState state) {
    if (state.phase == GamePhase.gameOver) return;
    if (state.alivePlayers.every((p) => state.foragedThisRound.contains(p.id))) {
      state.phase = GamePhase.dayCamp;
      state.freshForageIds.clear();
      _collectBonesAtCamp(state);
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

  void _receiveDrawnForage(Player player, GameCard card) {
    final state = _requireState();
    if (card.kind == CardKind.bonePile) {
      state.campStash.add(card);
      return;
    }
    player.hand.add(card);
    state.freshForageIds.add(card.id);
  }

  void _collectBonesAtCamp(GameState state) {
    for (final player in state.players) {
      final bones = [
        for (final card in player.hand)
          if (card.kind == CardKind.bonePile) card,
      ];
      for (final bone in bones) {
        player.hand.remove(bone);
        state.campStash.add(bone);
      }
    }
  }

  String _resolveUhOh(Player player, GameCard card) {
    player.hand.remove(card);
    switch (card.uhOh) {
      case UhOhEffect.none:
        return '${card.flavor} ${card.name}.'.trim();
      case UhOhEffect.drawMadness:
        return _resolveForageMadness(player, card);
      case UhOhEffect.setHeartsToOne:
        if (player.hearts > 1) {
          final lost = player.hearts - 1;
          player.hearts = 1;
          _requireState().log(
            '${player.name} loses $lost♥ — ${card.name} (now 1♥)',
          );
        }
        return '${card.flavor} ${card.name}: ${player.name} is left with ${player.hearts}♥.';
      case UhOhEffect.loseHearts:
        final loss = card.uhOhDamage <= 0 ? 2 : card.uhOhDamage;
        if (card.blockable && player.canBlockAttack) {
          final weapon = _consumeAttackBlock(player);
          return '${card.name} attacks; ${player.name}\'s $weapon holds it off.';
        }
        _damage(player, loss, cause: card.name);
        return '${card.flavor} ${card.name}: ${player.name} loses $loss♥.';
      case UhOhEffect.lockArms:
        player.armsLocked = true;
        return '${card.flavor} ${card.name}: ${player.name} cannot use their arms until the next day.';
      case UhOhEffect.immobilize:
        player.immobilized = true;
        return '${card.flavor} ${card.name}: ${player.name} cannot move or speak until the next day.';
      case UhOhEffect.peekNights:
        return _peekUpcomingNights(player, card);
      case null:
        return '';
    }
  }

  String _peekUpcomingNights(Player player, GameCard source) {
    final state = _requireState();
    final count = source.peekCount <= 0 ? 2 : source.peekCount;
    final upcoming = <NightCard>[];
    for (var i = 1; i <= count; i++) {
      final index = state.nightDeck.length - i;
      if (index < 0) break;
      upcoming.add(state.nightDeck[index]);
    }
    state.peekedNights
      ..clear()
      ..addAll(upcoming);
    if (upcoming.isEmpty) {
      return '${source.name}: ${player.name} looks ahead, but no nights remain.';
    }
    final titles = upcoming.map((night) => night.title).join(', then ');
    return '${source.name}: ${player.name} sees the next nights — $titles.';
  }

  String _resolveForageMadness(Player player, GameCard source) {
    final state = _requireState();
    if (state.madnessPile.isEmpty) {
      state.madnessPile.addAll(Decks.madnessDeck(_random, _nextId));
    }
    if (state.madnessPile.isEmpty) {
      return '${source.name}: ${player.name} should draw madness, but the pile is empty.';
    }
    final card = state.madnessPile.removeLast();
    switch (card.kind) {
      case MadnessKind.heartLoss:
        _damage(player, 1, cause: card.title);
        return '${source.name}: ${player.name} draws ${card.title} and loses 1♥.';
      case MadnessKind.roleplay:
        state.log('${player.name} must: ${card.description}');
        return '${source.name}: ${player.name} draws ${card.title}: ${card.description}';
    }
  }

  (Player, GameCard)? _findWreckage(String cardId) {
    final state = _requireState();
    for (final player in state.alivePlayers) {
      for (final card in player.hand) {
        if (card.id == cardId && card.wreckage != null) {
          return (player, card);
        }
      }
    }
    return null;
  }

  void _consumeWreckageCard(Player owner, GameCard card) {
    if (card.wreckage?.reusable ?? false) return;
    owner.hand.remove(card);
  }

  /// Spend one attack defense (spear or taser). Returns the item name.
  String _consumeAttackBlock(Player player) {
    if (player.spearCount > 0) {
      _consumeSpear(player);
      return 'spear';
    }
    final taser = player.hand.cast<GameCard?>().firstWhere(
          (card) => card?.wreckage == WreckageAbility.taser,
          orElse: () => null,
        );
    if (taser != null) {
      // Reusable — keep the card.
      return 'Taser';
    }
    return 'weapon';
  }

  void _consumeSpear(Player player) {
    if (player.spearCount <= 0) return;
    player.spearCount -= 1;
    _returnCraft(CraftItem.spear);
  }

  void _takeCraft(CraftItem item) {
    final state = _requireState();
    final remaining = state.craftRemaining(item);
    if (remaining <= 0) return;
    state.craftStock[item] = remaining - 1;
  }

  void _returnCraft(CraftItem item) {
    final state = _requireState();
    final max = Decks.craftMax(item);
    final current = state.craftRemaining(item);
    if (current >= max) return;
    state.craftStock[item] = current + 1;
  }

  void _extinguishFire(GameState state, {String? reason}) {
    if (!state.fireLit) return;
    if (state.fireFromCraft) {
      _returnCraft(CraftItem.fire);
      state.fireFromCraft = false;
    }
    state.fireLit = false;
    if (reason != null) {
      state.message = reason;
    }
  }

  void _destroyAllShelters(GameState state) {
    while (state.shelters.isNotEmpty) {
      state.shelters.removeLast();
      _returnCraft(CraftItem.shelter);
    }
  }

  bool _hasForageCard(Player player) =>
      player.hand.any((card) => _isForageCard(card));

  bool _isForageCard(GameCard card) =>
      card.isFood ||
      card.isResource ||
      card.kind == CardKind.bonePile ||
      card.uhOh != null;

  void _discardOneForage(Player player) {
    final index = player.hand.indexWhere(_isForageCard);
    if (index == -1) return;
    player.hand.removeAt(index);
  }

  void _loseAllFiber(GameState state) {
    state.campStash.removeWhere((card) => card.kind == CardKind.fiber);
    for (final player in state.players) {
      player.hand.removeWhere((card) => card.kind == CardKind.fiber);
    }
  }

  void _loseAllForageCards(GameState state) {
    state.campStash.removeWhere(_isForageCard);
    for (final player in state.players) {
      player.hand.removeWhere(_isForageCard);
    }
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

  /// Spend from camp first, then any living survivor's hand.
  void _spend(CardKind kind, int amount) {
    if (amount <= 0) return;
    final state = _requireState();
    var remaining = amount;
    remaining -= _removeKind(state.campStash, kind, remaining);
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
    var remaining = 4;
    remaining -= _removeKind(_requireState().campStash, CardKind.bonePile, remaining);
    if (remaining <= 0) return;
    for (final player in _requireState().players) {
      remaining -= _removeKind(player.hand, CardKind.bonePile, remaining);
      if (remaining <= 0) return;
    }
  }

  void _damage(Player player, int amount, {String? cause}) {
    if (player.dead || amount <= 0) return;
    player.hearts -= amount;
    if (player.hearts < 0) player.hearts = 0;

    final state = _requireState();
    final why = cause == null ? '' : ' — $cause';
    state.log('${player.name} loses $amount♥$why (now ${player.hearts}♥)');

    // Forage/camp: survivors may sit at 0♥ until the next dawn.
    final deferDeath = state.phase == GamePhase.dayForage ||
        state.phase == GamePhase.dayCamp;
    if (player.hearts <= 0 && !deferDeath) {
      _kill(player, '${player.name} has fallen.');
    }
  }

  void _heal(Player player, int amount, {String? cause}) {
    if (player.dead || amount <= 0) return;
    player.hearts = min(player.maxHearts, player.hearts + amount);
    if (player.hearts >= 2) player.cannotTrade = false;
    final why = cause == null ? '' : ' — $cause';
    _requireState().log(
      '${player.name} recovers $amount♥$why (now ${player.hearts}♥)',
    );
  }

  void _kill(Player player, String reason) {
    final state = _requireState();
    player.hearts = 0;
    player.dead = true;
    if (player.hasBasket) {
      player.hasBasket = false;
      _returnCraft(CraftItem.basket);
    }
    while (player.spearCount > 0) {
      _consumeSpear(player);
    }
    state.campStash.addAll(player.hand);
    player.hand.clear();
    player.pendingMadness = null;
    state.message = '$reason Their cards go to camp.';
    if (state.alivePlayers.isEmpty) {
      _lose(state, 'No one made it out of the wreck.');
    }
  }

  void _resolveDawnDeaths(GameState state) {
    for (final player in List<Player>.from(state.alivePlayers)) {
      if (player.hearts > 0) continue;
      _kill(
        player,
        '${player.name} never recovered from 0♥ and dies at dawn.',
      );
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
      if (player.hearts == 1 &&
          player.pendingMadness == null &&
          !player.drewMadnessThisNight) {
        if (state.madnessPile.isEmpty) break;
        player.pendingMadness = state.madnessPile.removeLast();
        player.drewMadnessThisNight = true;
      }
    }
  }

  void _finishNight(GameState state) {
    if (state.phase == GamePhase.gameOver) return;
    _extinguishFire(state);
    state.fireBlockedNextNight = state.pendingNoFireTomorrow;
    state.pendingNoFireTomorrow = false;
    state.activeNight = null;
    state.foragedThisRound.clear();
    state.freshForageIds.clear();
    for (final player in state.players) {
      player.drewMadnessThisNight = false;
      player.armsLocked = false;
      player.immobilized = false;
    }
    _resolveDawnDeaths(state);
    if (state.phase == GamePhase.gameOver) return;

    for (var i = 0; i < state.shelters.length; i++) {
      final living = state.shelters[i].occupantIds
          .where((id) => state.players.any((p) => p.id == id && p.isAlive))
          .toSet();
      if (living.length != state.shelters[i].occupantIds.length) {
        state.shelters[i] = BuiltShelter(occupantIds: living);
      }
    }
    if (state.alivePlayers.isEmpty) {
      _lose(state, 'No one made it out of the wreck.');
      return;
    }
    state.currentPlayerIndex = state.players.indexOf(state.alivePlayers.first);
    state.phase = GamePhase.dayForage;
    final fireNote = state.fireBlockedNextNight
        ? ' Weather blocks fire tonight.'
        : ' The fire is out.';
    state.message =
        'Dawn.$fireNote Day ${state.nightNumber + 1} — ${state.currentPlayer.name} forages.';
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
