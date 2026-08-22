import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/madness_card.dart';
import '../models/night_card.dart';
import '../models/player.dart';
import '../models/wreckage_assignment.dart';
import '../net/game_action.dart';
import '../net/table_session.dart';
import '../theme/app_theme.dart';
import '../widgets/heart_display.dart';
import '../widgets/resource_card_tile.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.engine,
    this.session,
  });

  final GameEngine engine;
  final TableSession? session;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _selectedCardId;
  final _healShares = <String, int>{};
  CraftItem? _pendingCraft;
  final _shelterPicks = <String>{};
  final _spearUsers = <String>{};
  final _activeWreckageIds = <String>{};
  final _wreckageTargets = <String, List<String?>>{};
  /// Raccoons: true = discard food, false = lose 1♥
  final _raccoonDiscardFood = <String, bool>{};

  GameEngine get engine => widget.engine;
  TableSession? get session => widget.session;
  String? get _me => session?.localPlayerId;
  bool get _networked => session?.networked ?? false;

  @override
  void initState() {
    super.initState();
    session?.addListener(_refresh);
  }

  @override
  void dispose() {
    session?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _run(void Function() local, [Map<String, dynamic>? action]) {
    if (_networked && action != null) {
      session!.dispatch(action);
    } else {
      local();
    }
    _refresh();
  }

  void _showActionLog(BuildContext context, GameState state) {
    final entries = state.actionLog.reversed.toList();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('What happened'),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.sizeOf(context).height * 0.55,
            child: entries.isEmpty
                ? const Text('No actions yet.')
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final text = entries[index];
                      final isHeart = text.contains('♥');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isHeart
                                    ? AppTheme.accent
                                    : null,
                                fontWeight:
                                    isHeart ? FontWeight.w600 : FontWeight.normal,
                              ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _clearNightAssignments() {
    _spearUsers.clear();
    _activeWreckageIds.clear();
    _wreckageTargets.clear();
    _raccoonDiscardFood.clear();
  }

  List<({Player owner, GameCard card})> _wreckageForNight(GameState state) {
    final night = state.activeNight;
    if (night == null) return const [];
    final result = <({Player owner, GameCard card})>[];
    for (final player in state.alivePlayers) {
      for (final card in player.hand) {
        final ability = card.wreckage;
        if (ability == null) continue;
        final useful = switch (night.eventType) {
          NightEventType.weather => ability.blocksWeather,
          NightEventType.animal =>
            night.dealsAnimalHeartDamage &&
                (ability.blocksAnimalOrHuman || ability.blocksAnimalCampWide),
          NightEventType.none || NightEventType.rescue => false,
        };
        if (useful) result.add((owner: player, card: card));
      }
    }
    return result;
  }

  List<WreckageAssignment> _buildWreckageUses() {
    return _activeWreckageIds.map((cardId) {
      final slots = _wreckageTargets[cardId] ?? const <String?>[];
      return WreckageAssignment(
        cardId: cardId,
        targetIds: slots.whereType<String>().toList(),
      );
    }).toList();
  }

  Player? _ownerOf(String cardId) {
    final state = engine.state;
    if (state == null) return null;
    for (final player in state.players) {
      if (player.hand.any((card) => card.id == cardId)) return player;
    }
    return null;
  }

  GameCard? _card(String id) {
    final state = engine.state;
    if (state == null) return null;
    for (final player in state.players) {
      for (final card in player.hand) {
        if (card.id == id) return card;
      }
    }
    for (final card in state.campStash) {
      if (card.id == id) return card;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = engine.state;
    if (state == null) {
      return const Scaffold(body: Center(child: Text('Game not started.')));
    }

    if (state.phase == GamePhase.gameOver) {
      return _GameOverView(
        won: state.won,
        message: state.message,
        onRestart: () async {
          session?.removeListener(_refresh);
          await session?.disposeSession();
          engine.reset();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        },
      );
    }

    final current = state.currentPlayer;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          state.phase == GamePhase.night || state.phase == GamePhase.madness
              ? 'Night ${state.nightNumber}'
              : 'Day ${state.nightNumber + 1}',
        ),
        actions: [
          IconButton(
            tooltip: 'Action log',
            onPressed: () => _showActionLog(context, state),
            icon: const Icon(Icons.history),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                state.fireLit
                    ? '🔥 Fire lit'
                    : state.fireBlockedNextNight
                        ? 'Fire blocked'
                        : 'Fire out',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Banner(
              phase: state.phase,
              message: state.message,
              onOpenLog: () => _showActionLog(context, state),
            ),
            _RosterGrid(
              players: state.players,
              campStash: state.campStash,
              activeId: current.id,
              youId: _me,
              selectedCardId: _selectedCardId,
              shelterIds: {
                for (final player in state.players)
                  if (state.isSheltered(player.id)) player.id,
              },
              caveShelter: state.caveShelter,
              hiddenCardIds: state.phase == GamePhase.dayForage
                  ? state.freshForageIds
                  : const {},
              revealPlayerId: _me ?? current.id,
              fireLit: state.fireLit,
              healShares: _assignableHealCard(state) == null
                  ? const <String, int>{}
                  : Map<String, int>.from(_healShares),
              canAssignHearts: _assignableHealCard(state) != null,
              pickedIds: _pickedPlayerIds(state),
              targeting: _playerTapHint(state) != null,
              tapHint: _playerTapHint(state),
              onPlayerTap: _tapPlayer,
              onPlayerLongPress: _longPressPlayer,
              onCardTap: _selectCard,
            ),
            _CraftBoxes(
              state: state,
              enabled: state.phase == GamePhase.dayCamp,
              canCraft: (item) => engine.canCraft(item, playerId: _me),
              buttonLabel: (item, canCraft) => _craftButtonLabel(
                state,
                item,
                canCraft,
              ),
              pendingItem: _pendingCraft,
              shelterPickCount: _shelterPicks.length,
              onCraft: _craftItem,
              onStartPick: _startCraftPick,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.peekedNights.isNotEmpty) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Looking ahead',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            for (final night in state.peekedNights) ...[
                              Text(
                                night.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(night.description),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.activeNight != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.activeNight!.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(state.activeNight!.description),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.phase == GamePhase.dayCamp) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Materials — wood ${state.countResource(CardKind.wood)}, '
                      'stone ${state.countResource(CardKind.stone)}, '
                      'fiber ${state.countResource(CardKind.fiber)}'
                      '${state.canAssembleBones ? ' · bone circle ready' : ''}',
                    ),
                    const SizedBox(height: 12),
                    if (state.canAssembleBones)
                      FilledButton(
                        onPressed: () => _run(
                          () => engine.assembleBoneCircle(playerId: _me),
                          {'type': 'assembleBones', 'playerId': _me},
                        ),
                        child: const Text('Assemble bone circle'),
                      ),
                  ],
                  if (state.phase == GamePhase.night) ...[
                    Text(
                      'Assign defenses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a wreckage card, then tap who it protects. '
                      'Tap food to share hearts. Tap a spear-holder to defend.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_networked && (session?.isHost ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Night choices received: ${session!.nightPrepByPlayer.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    if (_spearUsers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final id in _spearUsers)
                        Text(
                          '✓ ${state.players.firstWhere((player) => player.id == id).name} uses a spear',
                        ),
                    ],
                    if (state.activeNight?.raccoonChoice == true &&
                        !(state.fireLit &&
                            (state.activeNight?.fireCancels ?? false))) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Raccoons — tap a survivor to discard food instead of 1♥',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final player in state.alivePlayers)
                        Text(
                          (_raccoonDiscardFood[player.id] ?? false)
                              ? '✓ ${player.name} discards food'
                              : '${player.name} will lose 1♥',
                        ),
                    ],
                    ..._wreckageForNight(state).map((entry) {
                      final card = entry.card;
                      final ability = card.wreckage!;
                      final active = _activeWreckageIds.contains(card.id);
                      if (!active) return const SizedBox.shrink();
                      final names = (_wreckageTargets[card.id] ?? const [])
                          .whereType<String>()
                          .map(
                            (id) => state.players
                                .firstWhere((player) => player.id == id)
                                .name,
                          )
                          .join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          ability.blocksAnimalCampWide
                              ? '✓ ${card.name} covers the camp'
                              : names.isEmpty
                                  ? '${card.name} — tap who to protect'
                                  : '✓ ${card.name} → $names',
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            _buildActions(state, current),
          ],
        ),
      ),
    );
  }

  void _craftItem(
    CraftItem item, {
    Set<String> occupants = const {},
    String? recipientId,
  }) {
    _run(
      () => engine.craft(
        item,
        shelterOccupantIds: occupants,
        playerId: _me,
        recipientId: recipientId,
      ),
      {
        'type': 'craft',
        'item': item.name,
        'playerId': _me,
        'recipientId': recipientId,
        'shelterOccupantIds': occupants.toList(),
      },
    );
  }

  GameCard? _assignableHealCard(GameState state) {
    if (_selectedCardId == null) return null;
    if (state.phase != GamePhase.dayCamp && state.phase != GamePhase.night) {
      return null;
    }
    final card = _card(_selectedCardId!);
    if (card == null) return null;
    if (card.isFood && card.healValue > 0 && !card.fullHeal) return card;
    if (card.wreckage == WreckageAbility.vodka) return card;
    return null;
  }

  GameCard? _dumpHealCard(GameState state) {
    if (_selectedCardId == null) return null;
    if (state.phase != GamePhase.dayCamp && state.phase != GamePhase.night) {
      return null;
    }
    final card = _card(_selectedCardId!);
    if (card == null || _assignableHealCard(state) != null) return null;
    if (card.wreckage == WreckageAbility.chocolate) return card;
    if (card.wreckage == WreckageAbility.adrenaline || card.fullHeal) {
      return card;
    }
    return null;
  }

  GameCard? _nightProtectCard(GameState state) {
    if (state.phase != GamePhase.night || _selectedCardId == null) return null;
    final card = _card(_selectedCardId!);
    if (card?.wreckage == null || card!.isWreckageHeal) return null;
    final night = state.activeNight;
    if (night == null) return null;
    final ability = card.wreckage!;
    final useful = switch (night.eventType) {
      NightEventType.weather => ability.blocksWeather,
      NightEventType.animal =>
        night.dealsAnimalHeartDamage &&
            (ability.blocksAnimalOrHuman || ability.blocksAnimalCampWide),
      NightEventType.none || NightEventType.rescue => false,
    };
    return useful ? card : null;
  }

  int _protectSlotsNeeded(GameCard card) {
    final ability = card.wreckage!;
    if (ability.blocksAnimalCampWide) return 0;
    if (ability.blocksWeather) return ability.weatherTargetCount;
    return 1;
  }

  int _healAssigned() =>
      _healShares.values.fold<int>(0, (sum, n) => sum + n);

  int _healRemaining(GameState state) {
    final card = _assignableHealCard(state);
    if (card == null) return 0;
    return card.healValue - _healAssigned();
  }

  bool _raccoonTapOpen(GameState state) {
    final night = state.activeNight;
    return state.phase == GamePhase.night &&
        night?.raccoonChoice == true &&
        !(state.fireLit && (night?.fireCancels ?? false));
  }

  Set<String> _pickedPlayerIds(GameState state) {
    return {
      ..._healShares.keys.where((id) => (_healShares[id] ?? 0) > 0),
      ..._shelterPicks,
      ..._spearUsers,
      for (final player in state.alivePlayers)
        if (_raccoonDiscardFood[player.id] == true) player.id,
      if (_selectedCardId != null)
        ...(_wreckageTargets[_selectedCardId] ?? const [])
            .whereType<String>(),
    };
  }

  String? _playerTapHint(GameState state) {
    final heal = _assignableHealCard(state);
    if (heal != null) {
      final left = _healRemaining(state);
      return left > 0
          ? 'Tap a survivor to give 1♥ ($left left)'
          : 'Tap a survivor to give 1♥';
    }
    final dump = _dumpHealCard(state);
    if (dump != null) {
      return 'Tap who gets ${dump.name}';
    }
    final protect = _nightProtectCard(state);
    if (protect != null) {
      final needed = _protectSlotsNeeded(protect);
      if (needed == 0) return '${protect.name} covers the whole camp';
      final filled = (_wreckageTargets[protect.id] ?? const [])
          .whereType<String>()
          .length;
      final left = (needed - filled).clamp(0, needed);
      return left > 0
          ? 'Tap who ${protect.name} protects ($left left)'
          : 'Tap a protected survivor to remove them';
    }
    if (_pendingCraft == CraftItem.spear) return 'Tap who gets the Spear';
    if (_pendingCraft == CraftItem.basket) return 'Tap who gets the Basket';
    if (_pendingCraft == CraftItem.shelter) {
      return 'Tap who the shelter covers (${_shelterPicks.length}/3)';
    }
    if (_selectedCardId != null &&
        state.phase == GamePhase.dayCamp &&
        _ownerOf(_selectedCardId!) != null) {
      final card = _card(_selectedCardId!);
      if (card != null && card.kind != CardKind.bonePile) {
        return 'Tap who receives ${card.name}';
      }
    }
    if (state.phase == GamePhase.night &&
        (state.activeNight?.dealsAnimalHeartDamage ?? false)) {
      return 'Tap a survivor with a spear to defend';
    }
    if (_raccoonTapOpen(state)) {
      return 'Tap a survivor to discard food instead of 1♥';
    }
    return null;
  }

  void _selectCard(String id) {
    final state = engine.state;
    final deselect = _selectedCardId == id;
    setState(() {
      _selectedCardId = deselect ? null : id;
      _healShares.clear();
      _pendingCraft = null;
      _shelterPicks.clear();
      if (!deselect && state != null) {
        final card = _card(id);
        if (card != null && _nightProtectCard(state) != null) {
          final needed = _protectSlotsNeeded(card);
          _activeWreckageIds.add(id);
          _wreckageTargets.putIfAbsent(
            id,
            () => List<String?>.filled(needed, null),
          );
        }
      } else if (deselect) {
        final card = _card(id);
        if (card?.wreckage?.blocksAnimalCampWide ?? false) {
          _activeWreckageIds.remove(id);
        }
      }
    });
  }

  void _startCraftPick(CraftItem item) {
    if (_pendingCraft == item) {
      if (item == CraftItem.shelter && _shelterPicks.isNotEmpty) {
        _craftItem(item, occupants: Set.of(_shelterPicks));
        setState(() {
          _pendingCraft = null;
          _shelterPicks.clear();
        });
        return;
      }
      setState(() {
        _pendingCraft = null;
        _shelterPicks.clear();
      });
      return;
    }
    setState(() {
      _pendingCraft = item;
      _shelterPicks.clear();
      _selectedCardId = null;
      _healShares.clear();
    });
  }

  Player? _living(String playerId) {
    final matches = engine.state?.players.where((item) => item.id == playerId);
    if (matches == null || matches.isEmpty) return null;
    final player = matches.first;
    return player.isAlive ? player : null;
  }

  void _tapPlayer(String playerId) {
    final state = engine.state;
    if (state == null) return;
    final player = _living(playerId);
    if (player == null) return;

    if (_assignableHealCard(state) != null) {
      _changeHealShare(player, 1);
      return;
    }
    if (_dumpHealCard(state) != null) {
      _useSelectedHealOn(player.id);
      return;
    }
    final protect = _nightProtectCard(state);
    if (protect != null) {
      _toggleProtectTarget(protect, player.id);
      return;
    }
    if (_pendingCraft == CraftItem.spear || _pendingCraft == CraftItem.basket) {
      if (_pendingCraft == CraftItem.basket && player.hasBasket) return;
      final item = _pendingCraft!;
      _pendingCraft = null;
      _craftItem(item, recipientId: player.id);
      return;
    }
    if (_pendingCraft == CraftItem.shelter) {
      setState(() {
        if (_shelterPicks.contains(player.id)) {
          _shelterPicks.remove(player.id);
        } else if (_shelterPicks.length < 3) {
          _shelterPicks.add(player.id);
        }
      });
      if (_shelterPicks.length == 3) {
        _craftItem(CraftItem.shelter, occupants: Set.of(_shelterPicks));
        setState(() {
          _pendingCraft = null;
          _shelterPicks.clear();
        });
      }
      return;
    }
    if (_selectedCardId != null &&
        state.phase == GamePhase.dayCamp &&
        _ownerOf(_selectedCardId!) != null &&
        _ownerOf(_selectedCardId!)!.id != player.id) {
      _giveSelectedTo(player.id);
      return;
    }
    if (state.phase == GamePhase.night &&
        (state.activeNight?.dealsAnimalHeartDamage ?? false) &&
        player.spearCount > 0 &&
        (_me == null || player.id == _me)) {
      setState(() {
        if (_spearUsers.contains(player.id)) {
          _spearUsers.remove(player.id);
        } else {
          _spearUsers.add(player.id);
        }
      });
      return;
    }
    if (_raccoonTapOpen(state) &&
        player.hand.any((card) => card.isFood) &&
        (_me == null || player.id == _me)) {
      setState(() {
        _raccoonDiscardFood[player.id] =
            !(_raccoonDiscardFood[player.id] ?? false);
      });
    }
  }

  void _longPressPlayer(String playerId) {
    final state = engine.state;
    if (state == null) return;
    final player = _living(playerId);
    if (player == null) return;
    if (_assignableHealCard(state) != null) {
      _changeHealShare(player, -1);
    }
  }

  void _changeHealShare(Player player, int delta) {
    final state = engine.state;
    if (state == null) return;
    final card = _assignableHealCard(state);
    if (card == null) return;
    final shares = Map<String, int>.from(_healShares);
    final pending = shares[player.id] ?? 0;
    final assigned = shares.values.fold<int>(0, (sum, n) => sum + n);
    final remaining = card.healValue - assigned;

    if (delta > 0) {
      if (remaining <= 0) return;
      if (player.hearts + pending >= player.maxHearts) return;
      shares[player.id] = pending + 1;
    } else {
      if (pending <= 0) return;
      if (pending == 1) {
        shares.remove(player.id);
      } else {
        shares[player.id] = pending - 1;
      }
    }

    _healShares
      ..clear()
      ..addAll(shares);
    if (_healAssigned() == card.healValue) {
      _commitHealShares();
      return;
    }
    setState(() {});
  }

  void _toggleProtectTarget(GameCard card, String playerId) {
    final needed = _protectSlotsNeeded(card);
    if (needed <= 0) return;
    setState(() {
      _activeWreckageIds.add(card.id);
      final slots = _wreckageTargets.putIfAbsent(
        card.id,
        () => List<String?>.filled(needed, null),
      );
      final existing = slots.indexOf(playerId);
      if (existing != -1) {
        slots[existing] = null;
        return;
      }
      final empty = slots.indexWhere((id) => id == null);
      if (empty != -1) {
        slots[empty] = playerId;
      } else {
        slots[needed - 1] = playerId;
      }
    });
  }

  void _useSelectedHealOn(String targetId) {
    final state = engine.state;
    if (state == null || _selectedCardId == null) return;
    final cardId = _selectedCardId!;
    final owner = _ownerOf(cardId);
    if (_networked && _me != null && owner != null && owner.id != _me) return;
    final actorId = owner?.id ?? _me ?? state.currentPlayer.id;
    final card = _card(cardId);
    _run(
      () => engine.useHealCard(
        ownerId: actorId,
        cardId: cardId,
        targetId: targetId,
        hearts: card?.healValue,
      ),
      {
        'type': 'heal',
        'ownerId': actorId,
        'cardId': cardId,
        'targetId': targetId,
        'hearts': card?.healValue,
      },
    );
    setState(() {
      _selectedCardId = null;
      _healShares.clear();
    });
  }

  void _giveSelectedTo(String toId) {
    final owner = _ownerOf(_selectedCardId!);
    if (owner == null) return;
    if (_networked && _me != null && owner.id != _me) return;
    final cardId = _selectedCardId!;
    _run(
      () => engine.tradeCard(
        fromPlayerId: owner.id,
        toPlayerId: toId,
        cardId: cardId,
      ),
      {
        'type': 'trade',
        'fromId': owner.id,
        'toId': toId,
        'cardId': cardId,
      },
    );
    setState(() {
      _selectedCardId = null;
      _healShares.clear();
    });
  }

  void _commitHealShares() {
    final state = engine.state;
    if (state == null || _selectedCardId == null) return;
    final shares = {
      for (final entry in _healShares.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (shares.isEmpty) return;
    final owner = _ownerOf(_selectedCardId!);
    final actorId = owner?.id ?? _me ?? state.currentPlayer.id;
    final cardId = _selectedCardId!;
    var applied = true;
    if (_networked) {
      session!.dispatch({
        'type': 'splitFood',
        'ownerId': actorId,
        'cardId': cardId,
        'shares': [
          for (final entry in shares.entries)
            {'playerId': entry.key, 'hearts': entry.value},
        ],
      });
    } else {
      applied = engine.splitHeal(
        ownerId: actorId,
        cardId: cardId,
        shares: shares,
      );
    }
    setState(() {
      if (!applied) return;
      _selectedCardId = null;
      _healShares.clear();
    });
  }

  String _craftButtonLabel(
    GameState state,
    CraftItem item,
    bool canCraft,
  ) {
    if (item == CraftItem.fire) {
      if (state.fireLit) return 'Already lit';
      if (state.fireBlockedNextNight) return 'Blocked';
      if (state.phase != GamePhase.dayCamp) return 'At camp';
      return canCraft ? 'Light fire' : 'Can\'t light';
    }
    if (item == CraftItem.basket &&
        state.alivePlayers.every((player) => player.hasBasket)) {
      return 'All owned';
    }
    if (state.craftRemaining(item) <= 0) return 'All in play';
    return canCraft ? 'Craft' : 'Need more';
  }

  Widget _buildActions(GameState state, Player current) {
    return Material(
      color: const Color(0xFF1B2A22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2E4036))),
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if ((state.phase == GamePhase.dayCamp ||
                  state.phase == GamePhase.night) &&
              _selectedCardId != null)
            _CampCardActions(
              card: _card(_selectedCardId!),
              owner: _ownerOf(_selectedCardId!),
              inCamp: state.campStash.any((card) => card.id == _selectedCardId),
              current: current,
              nightUse: state.phase == GamePhase.night,
              tapHint: _playerTapHint(state),
              canLightFire: state.phase == GamePhase.dayCamp &&
                  engine.canCraft(CraftItem.fire, playerId: _me),
              lightFireLabel: _craftButtonLabel(
                state,
                CraftItem.fire,
                engine.canCraft(CraftItem.fire, playerId: _me),
              ),
              onLightFire: () {
                final cardId = _selectedCardId!;
                _run(
                  () => engine.lightFire(playerId: _me, woodCardId: cardId),
                  {
                    'type': 'lightFire',
                    'playerId': _me,
                    'cardId': cardId,
                  },
                );
                setState(() {
                  _selectedCardId = null;
                  _healShares.clear();
                });
              },
              onGiveHearts: _healAssigned() > 0 ? _commitHealShares : null,
              heartsPicked: _healAssigned(),
              onToCamp: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null) return;
                if (_networked && _me != null && owner.id != _me) return;
                final cardId = _selectedCardId!;
                _run(
                  () => engine.contributeToCamp(owner.id, cardId),
                  {
                    'type': 'contribute',
                    'playerId': owner.id,
                    'cardId': cardId,
                  },
                );
                setState(() {
                  _selectedCardId = null;
                  _healShares.clear();
                });
              },
              onFromCamp: () {
                final takerId = _me ?? current.id;
                final cardId = _selectedCardId!;
                _run(
                  () => engine.takeFromCamp(takerId, cardId),
                  {
                    'type': 'takeCamp',
                    'playerId': takerId,
                    'cardId': cardId,
                  },
                );
                setState(() {
                  _selectedCardId = null;
                  _healShares.clear();
                });
              },
            )
          else if (_playerTapHint(state) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_playerTapHint(state)!),
            ),
          if (state.phase == GamePhase.dayForage) ...[
            if (_networked && !session!.isMyForageTurn)
              Text(
                'Waiting for ${current.name} to forage or rest.',
                textAlign: TextAlign.center,
              )
            else if (current.immobilized)
              FilledButton(
                onPressed: () => _run(
                  engine.skipImmobilizedForage,
                  {'type': 'skipForage', 'playerId': _me},
                ),
                child: Text('${current.name} cannot move'),
              )
            else if (current.forcedRest)
              FilledButton(
                onPressed: () => _run(
                  engine.restCurrentPlayer,
                  {'type': 'rest', 'useBasket': false, 'playerId': _me},
                ),
                child: Text('${current.name} must rest'),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 1; i <= current.forageMax; i++)
                    FilledButton(
                      onPressed: current.forcedForage != null &&
                              i != current.forcedForage &&
                              i != current.hearts
                          ? null
                          : () => _run(
                                () => engine.forageCurrentPlayer(i),
                                {'type': 'forage', 'hearts': i, 'playerId': _me},
                              ),
                      child: Text('Forage $i♥'),
                    ),
                  if (current.forcedForage == null) ...[
                    OutlinedButton(
                      onPressed: () => _run(
                        engine.restCurrentPlayer,
                        {'type': 'rest', 'useBasket': false, 'playerId': _me},
                      ),
                      child: const Text('Rest +1♥'),
                    ),
                    if (current.hasBasket)
                      OutlinedButton(
                        onPressed: () => _run(
                          () => engine.restCurrentPlayer(useBasket: true),
                          {'type': 'rest', 'useBasket': true, 'playerId': _me},
                        ),
                        child: const Text('Basket: draw 1, no heal'),
                      ),
                    if (current.hasHealWreckage)
                      for (final card in current.hand.where(
                        (item) => item.isWreckageHeal,
                      ))
                        OutlinedButton(
                          onPressed: () => _run(
                            () => engine.useHealCard(
                              ownerId: current.id,
                              cardId: card.id,
                              targetId: current.id,
                            ),
                            {
                              'type': 'heal',
                              'ownerId': current.id,
                              'cardId': card.id,
                              'targetId': current.id,
                            },
                          ),
                          child: Text(
                            current.hearts <= 0
                                ? 'Use ${card.name} (at 0♥)'
                                : 'Use ${card.name}',
                          ),
                        ),
                  ],
                ],
              ),
            ],
          ] else if (state.phase == GamePhase.dayCamp)
            FilledButton(
              onPressed: () {
                _run(engine.beginNight, {'type': 'beginNight'});
                _clearNightAssignments();
              },
              child: const Text('Begin night'),
            )
          else if (state.phase == GamePhase.night) ...[
            if (_networked && !(session?.isHost ?? true))
              FilledButton(
                onPressed: () {
                  session!.sendNightPrep(
                    NightPrep(
                      spearUsers: {
                        if (_me != null && _spearUsers.contains(_me)) _me!,
                      },
                      wreckageUses: _buildWreckageUses(),
                      raccoonDiscardFood: {
                        if (_me != null && _raccoonDiscardFood.containsKey(_me))
                          _me!: _raccoonDiscardFood[_me]!,
                      },
                    ),
                  );
                  _refresh();
                },
                child: const Text('Send my night choices'),
              )
            else
              FilledButton(
                onPressed: () {
                  if (_networked && session != null) {
                    session!.resolveNightFromHost(
                      spearUsers: _spearUsers,
                      wreckageUses: _buildWreckageUses(),
                      raccoonDiscardFood: Map.of(_raccoonDiscardFood),
                    );
                  } else {
                    engine.resolveNight(
                      spearUsers: _spearUsers,
                      wreckageUses: _buildWreckageUses(),
                      raccoonDiscardFood: Map.of(_raccoonDiscardFood),
                    );
                  }
                  _clearNightAssignments();
                  _refresh();
                },
                child: const Text('Resolve night'),
              ),
          ] else if (state.phase == GamePhase.madness)
            _MadnessActions(
              player: state.alivePlayers.firstWhere(
                (player) => player.pendingMadness != null,
                orElse: () => current,
              ),
              onConfirm: () {
                final pending = state.alivePlayers.cast<Player?>().firstWhere(
                      (player) => player?.pendingMadness != null,
                      orElse: () => null,
                    );
                if (_networked &&
                    _me != null &&
                    pending != null &&
                    pending.id != _me) {
                  return;
                }
                _run(engine.applyMadness, {'type': 'applyMadness'});
              },
            ),
        ],
      ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.phase,
    required this.message,
    this.onOpenLog,
  });

  final GamePhase phase;
  final String message;
  final VoidCallback? onOpenLog;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      GamePhase.dayForage => 'Forage',
      GamePhase.dayCamp => 'Camp',
      GamePhase.night => 'Night',
      GamePhase.madness => 'Madness',
      _ => 'Planecrash Survival',
    };

    return Material(
      color: const Color(0xFF1B2A22),
      child: InkWell(
        onTap: onOpenLog,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (onOpenLog != null)
                    TextButton.icon(
                      onPressed: onOpenLog,
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('Log'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(message, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _CraftBoxes extends StatelessWidget {
  const _CraftBoxes({
    required this.state,
    required this.enabled,
    required this.canCraft,
    required this.buttonLabel,
    required this.onCraft,
    required this.onStartPick,
    this.pendingItem,
    this.shelterPickCount = 0,
  });

  final GameState state;
  final bool enabled;
  final bool Function(CraftItem item) canCraft;
  final String Function(CraftItem item, bool canCraft) buttonLabel;
  final void Function(
    CraftItem item, {
    Set<String> occupants,
    String? recipientId,
  }) onCraft;
  final ValueChanged<CraftItem> onStartPick;
  final CraftItem? pendingItem;
  final int shelterPickCount;

  bool get _autoShelter =>
      state.players.length < 4 || state.alivePlayers.length <= 3;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 128,
          children: [
            for (final item in CraftItem.values)
              if (item != CraftItem.fire) _box(context, item),
          ],
        ),
      ),
    );
  }

  Widget _box(BuildContext context, CraftItem item) {
    final remaining = state.craftRemaining(item);
    final ready = enabled && canCraft(item);
    final picking = pendingItem == item;
    final needsPick = item == CraftItem.spear ||
        item == CraftItem.basket ||
        (item == CraftItem.shelter && !_autoShelter);
    final emoji = switch (item) {
      CraftItem.fire => '🔥',
      CraftItem.spear => '🗡️',
      CraftItem.basket => '🧺',
      CraftItem.shelter => '🛖',
    };
    final cost = item.cost.entries
        .map((entry) => '${entry.value} ${entry.key}')
        .join(' · ');
    final label = picking
        ? (item == CraftItem.shelter && shelterPickCount > 0
            ? 'Build ($shelterPickCount)'
            : 'Tap a survivor')
        : (needsPick && ready ? 'Tap who' : buttonLabel(item, ready));

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: picking ? const Color(0xFF2A4033) : const Color(0xFF16241C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: picking ? AppTheme.accent : const Color(0xFF2E4036),
          width: picking ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$emoji ${item.label}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            '$remaining in deck · $cost',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: ValueKey('craft-${item.name}'),
              onPressed: !ready
                  ? null
                  : () {
                      if (needsPick) {
                        onStartPick(item);
                      } else {
                        onCraft(item);
                      }
                    },
              child: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

List<({GameCard card, int count, List<GameCard> cards})> _stackForageCards(
  List<GameCard> cards,
) {
  final groups = <String, List<GameCard>>{};
  final order = <String>[];
  for (final card in cards) {
    final key = card.stackKey;
    if (!groups.containsKey(key)) {
      order.add(key);
      groups[key] = <GameCard>[];
    }
    groups[key]!.add(card);
  }
  return [
    for (final key in order)
      (
        card: groups[key]!.first,
        count: groups[key]!.length,
        cards: groups[key]!,
      ),
  ];
}

class _RosterGrid extends StatelessWidget {
  const _RosterGrid({
    required this.players,
    required this.campStash,
    required this.activeId,
    this.youId,
    required this.selectedCardId,
    required this.shelterIds,
    required this.onCardTap,
    required this.onPlayerTap,
    this.onPlayerLongPress,
    this.caveShelter = false,
    this.hiddenCardIds = const {},
    this.revealPlayerId,
    this.fireLit = false,
    this.healShares = const {},
    this.canAssignHearts = false,
    this.pickedIds = const {},
    this.targeting = false,
    this.tapHint,
  });

  final List<Player> players;
  final List<GameCard> campStash;
  final String activeId;
  final String? youId;
  final String? selectedCardId;
  final Set<String> shelterIds;
  final ValueChanged<String> onCardTap;
  final ValueChanged<String> onPlayerTap;
  final ValueChanged<String>? onPlayerLongPress;
  final bool caveShelter;
  final Set<String> hiddenCardIds;
  final String? revealPlayerId;
  final bool fireLit;
  final Map<String, int> healShares;
  final bool canAssignHearts;
  final Set<String> pickedIds;
  final bool targeting;
  final String? tapHint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF2E4036)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (caveShelter)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Cave shelter — everyone is covered',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (tapHint != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  tapHint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accent,
                      ),
                ),
              ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < 5; index++) ...[
                    if (index > 0) const SizedBox(width: 8),
                    Expanded(
                      child: index == 4
                          ? _CampPanel(
                              cards: campStash,
                              selectedCardId: selectedCardId,
                              onCardTap: onCardTap,
                              fireLit: fireLit,
                            )
                          : index >= players.length
                              ? const _EmptySeat()
                              : _PlayerPanel(
                                  player: players[index],
                                  active: players[index].id == activeId,
                                  you: players[index].id == youId,
                                  selectedCardId: selectedCardId,
                                  shelter: shelterIds.contains(players[index].id),
                                  hiddenCardIds: hiddenCardIds,
                                  revealPlayerId: revealPlayerId,
                                  onCardTap: onCardTap,
                                  onPlayerTap: onPlayerTap,
                                  onPlayerLongPress: onPlayerLongPress,
                                  pendingHearts:
                                      healShares[players[index].id] ?? 0,
                                  canAssignHearts: canAssignHearts &&
                                      players[index].isAlive,
                                  targeting: targeting && players[index].isAlive,
                                  picked: pickedIds.contains(players[index].id),
                                ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  const _PlayerPanel({
    required this.player,
    required this.active,
    this.you = false,
    required this.selectedCardId,
    required this.shelter,
    required this.hiddenCardIds,
    this.revealPlayerId,
    required this.onCardTap,
    required this.onPlayerTap,
    this.onPlayerLongPress,
    this.pendingHearts = 0,
    this.canAssignHearts = false,
    this.targeting = false,
    this.picked = false,
  });

  final Player player;
  final bool active;
  final bool you;
  final String? selectedCardId;
  final bool shelter;
  final Set<String> hiddenCardIds;
  final String? revealPlayerId;
  final ValueChanged<String> onCardTap;
  final ValueChanged<String> onPlayerTap;
  final ValueChanged<String>? onPlayerLongPress;
  final int pendingHearts;
  final bool canAssignHearts;
  final bool targeting;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final status = [
      if (player.hasBasket) 'Basket',
      if (player.spearCount > 0) 'Spear ×${player.spearCount}',
      if (shelter) 'Shelter',
      if (player.armsLocked) 'No arms',
      if (player.immobilized) 'Cannot move',
      if (!player.isAlive) 'Gone',
      if (player.isAlive && player.hearts <= 0) '0♥',
    ].join(' · ');
    final showFresh = player.id == revealPlayerId;
    final visibleCards = player.hand
        .where((card) => showFresh || !hiddenCardIds.contains(card.id))
        .toList();
    final hiddenCount = player.hand.length - visibleCards.length;

    final borderColor = picked
        ? const Color(0xFFE8A54B)
        : targeting
            ? AppTheme.accent
            : (active || you)
                ? AppTheme.accent
                : const Color(0xFF2E4036);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (picked || targeting)
            ? const Color(0xFF2A4033)
            : (active || you)
                ? const Color(0xFF2A4033)
                : const Color(0xFF16241C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: (picked || targeting || active || you) ? 2.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('player-${player.id}'),
              onTap: player.isAlive ? () => onPlayerTap(player.id) : null,
              onLongPress: player.isAlive && onPlayerLongPress != null
                  ? () => onPlayerLongPress!(player.id)
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            player.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: player.isAlive
                                  ? (active ? AppTheme.accent : Colors.white)
                                  : Colors.white38,
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w600,
                              decoration: player.isAlive
                                  ? null
                                  : TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                        if (you || active)
                          Text(
                            [
                              if (you) 'You',
                              if (active) 'Active',
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    HeartDisplay(
                      hearts: player.hearts,
                      maxHearts: player.maxHearts,
                      pending: pendingHearts,
                      canAssign: canAssignHearts,
                      slotPrefix: player.id,
                    ),
                    if (status.isNotEmpty)
                      Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _MiniCardRow(
            cards: visibleCards,
            emptyLabel: hiddenCount > 0
                ? '$hiddenCount new hidden'
                : 'No cards',
            selectedCardId: selectedCardId,
            onCardTap: onCardTap,
          ),
        ],
      ),
    );
  }
}

class _EmptySeat extends StatelessWidget {
  const _EmptySeat();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF101A14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E4036)),
      ),
      child: Center(
        child: Text(
          'Empty',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white38,
              ),
        ),
      ),
    );
  }
}

class _CampPanel extends StatelessWidget {
  const _CampPanel({
    required this.cards,
    required this.selectedCardId,
    required this.onCardTap,
    this.fireLit = false,
  });

  final List<GameCard> cards;
  final String? selectedCardId;
  final ValueChanged<String> onCardTap;
  final bool fireLit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF16241C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E4036)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fireLit ? 'Camp 🔥' : 'Camp',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            cards.isEmpty ? 'Stash empty' : '${cards.length} in stash',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          _MiniCardRow(
            cards: cards,
            emptyLabel: 'No cards',
            selectedCardId: selectedCardId,
            onCardTap: onCardTap,
          ),
        ],
      ),
    );
  }
}

class _MiniCardRow extends StatelessWidget {
  const _MiniCardRow({
    required this.cards,
    required this.emptyLabel,
    required this.selectedCardId,
    required this.onCardTap,
  });

  final List<GameCard> cards;
  final String emptyLabel;
  final String? selectedCardId;
  final ValueChanged<String> onCardTap;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final stacks = _stackForageCards(cards);

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final stack in stacks)
          ResourceCardTile(
            card: stack.card,
            compact: true,
            mini: true,
            count: stack.count,
            selected: stack.cards.any((card) => card.id == selectedCardId),
            onTap: () => onCardTap(
              stack.cards
                  .firstWhere(
                    (card) => card.id == selectedCardId,
                    orElse: () => stack.card,
                  )
                  .id,
            ),
          ),
      ],
    );
  }
}

class _CampCardActions extends StatelessWidget {
  const _CampCardActions({
    required this.card,
    required this.owner,
    required this.inCamp,
    required this.current,
    required this.onToCamp,
    required this.onFromCamp,
    this.tapHint,
    this.canLightFire = false,
    this.lightFireLabel = 'Light fire',
    this.onLightFire,
    this.nightUse = false,
    this.heartsPicked = 0,
    this.onGiveHearts,
  });

  final GameCard? card;
  final Player? owner;
  final bool inCamp;
  final Player current;
  final String? tapHint;
  final VoidCallback onToCamp;
  final VoidCallback onFromCamp;
  final bool canLightFire;
  final String lightFireLabel;
  final VoidCallback? onLightFire;
  final bool nightUse;
  final int heartsPicked;
  final VoidCallback? onGiveHearts;

  @override
  Widget build(BuildContext context) {
    if (card == null) return const SizedBox.shrink();
    if (owner != null && owner!.cannotAct) {
      return Text(
        owner!.immobilized
            ? '${owner!.name} cannot move or speak until the next day.'
            : '${owner!.name} cannot use their arms until the next day.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tapHint != null) ...[
          Text(tapHint!),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onGiveHearts != null)
              FilledButton(
                onPressed: onGiveHearts,
                child: Text('Give $heartsPicked♥'),
              ),
            if (card!.kind == CardKind.wood)
              OutlinedButton(
                onPressed: canLightFire ? onLightFire : null,
                child: Text(lightFireLabel),
              ),
            if (!nightUse && !inCamp && card!.kind != CardKind.wood)
              OutlinedButton(
                onPressed: onToCamp,
                child: const Text('To camp'),
              ),
            if (inCamp &&
                (!nightUse ||
                    card!.isFood ||
                    card!.isWreckageHeal) &&
                card!.kind != CardKind.bonePile)
              OutlinedButton(
                onPressed: onFromCamp,
                child: Text('${current.name} takes'),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MadnessActions extends StatelessWidget {
  const _MadnessActions({
    required this.player,
    required this.onConfirm,
  });

  final Player player;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final card = player.pendingMadness;
    final isRoleplay = card?.kind == MadnessKind.roleplay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card != null) ...[
          Text(
            card.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(card.description),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: onConfirm,
          child: Text(
            isRoleplay
                ? 'Done — ${card?.title ?? 'madness'}'
                : 'Resolve ${card?.title ?? 'madness'}',
          ),
        ),
      ],
    );
  }
}

class _GameOverView extends StatelessWidget {
  const _GameOverView({
    required this.won,
    required this.message,
    required this.onRestart,
  });

  final bool won;
  final String message;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                won ? '🌅' : '🌑',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 16),
              Text(
                won ? 'Rescued!' : 'Lost',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: won ? AppTheme.success : AppTheme.danger,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: onRestart,
                child: const Text('Return to camp'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
