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
  String? _tradeTargetId;
  final _spearUsers = <String>{};
  final _activeWreckageIds = <String>{};
  final _wreckageTargets = <String, List<String?>>{};
  final _shelterDraftIds = <String>{};
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
              hideOtherHands: _networked || state.phase == GamePhase.dayForage,
              onCardTap: (id) => setState(() {
                _selectedCardId = _selectedCardId == id ? null : id;
              }),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                    if (state.craftRemaining(CraftItem.shelter) > 0) ...[
                      Text(
                        'Shelter occupants (pick 1–3, then craft)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...state.alivePlayers.map(
                        (player) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(player.name),
                          value: _shelterDraftIds.contains(player.id),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              if (_shelterDraftIds.length >= 3) return;
                              _shelterDraftIds.add(player.id);
                            } else {
                              _shelterDraftIds.remove(player.id);
                            }
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    ...CraftItem.values.map((item) {
                      final alreadyLit =
                          item == CraftItem.fire && state.fireLit;
                      final fireBlocked = item == CraftItem.fire &&
                          state.fireBlockedNextNight;
                      final remaining = state.craftRemaining(item);
                      final shelterReady = item != CraftItem.shelter ||
                          (_shelterDraftIds.isNotEmpty &&
                              _shelterDraftIds.length <= 3);
                      final canCraft = !alreadyLit &&
                          !fireBlocked &&
                          shelterReady &&
                          engine.canCraft(item, playerId: _me);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.label} ($remaining in deck)',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(item.description),
                                  Text(
                                    item.cost.entries
                                        .map((e) => '${e.value} ${e.key}')
                                        .join(' · '),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: canCraft
                                  ? () {
                                      _run(
                                        () => engine.craft(
                                          item,
                                          shelterOccupantIds:
                                              item == CraftItem.shelter
                                                  ? Set.of(_shelterDraftIds)
                                                  : const {},
                                          playerId: _me,
                                        ),
                                        {
                                          'type': 'craft',
                                          'item': item.name,
                                          'playerId': _me,
                                          'shelterOccupantIds':
                                              item == CraftItem.shelter
                                                  ? _shelterDraftIds.toList()
                                                  : const <String>[],
                                        },
                                      );
                                      if (item == CraftItem.shelter) {
                                        _shelterDraftIds.clear();
                                      }
                                      _refresh();
                                    }
                                  : null,
                              child: Text(
                                alreadyLit
                                    ? 'Already lit'
                                    : fireBlocked
                                        ? 'Blocked'
                                        : remaining <= 0
                                            ? 'All in play'
                                            : item == CraftItem.shelter &&
                                                    _shelterDraftIds.isEmpty
                                                ? 'Pick occupants'
                                                : _craftButtonLabel(
                                                    state,
                                                    item,
                                                    canCraft,
                                                    playerId: _me,
                                                  ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (state.canAssembleBones)
                      FilledButton(
                        onPressed: () => _run(
                          engine.assembleBoneCircle,
                          {'type': 'assembleBones'},
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
                      'Wreckage owners choose who is protected. '
                      'Tap food or heal wreckage in a hand to use it before resolving.',
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
                    if (state.activeNight?.dealsAnimalHeartDamage ?? false)
                      ...state.alivePlayers
                          .where(
                            (player) =>
                                player.spearCount > 0 &&
                                (_me == null || player.id == _me),
                          )
                          .map(
                            (player) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${player.name}: use Spear on self'),
                              value: _spearUsers.contains(player.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _spearUsers.add(player.id);
                                } else {
                                  _spearUsers.remove(player.id);
                                }
                              }),
                            ),
                          ),
                    if (state.activeNight?.raccoonChoice == true &&
                        !(state.fireLit &&
                            (state.activeNight?.fireCancels ?? false))) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Raccoons — each survivor chooses',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      ...state.alivePlayers.map((player) {
                        final discard = _raccoonDiscardFood[player.id] ?? false;
                        final hasFood = player.hand.any((c) => c.isFood);
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            discard
                                ? '${player.name}: discard 1 food'
                                : '${player.name}: lose 1♥',
                          ),
                          subtitle: Text(
                            hasFood
                                ? 'Check to discard food instead of a heart'
                                : 'No food — will lose 1♥ either way',
                          ),
                          value: discard,
                          onChanged: hasFood
                              ? (value) => setState(() {
                                    _raccoonDiscardFood[player.id] =
                                        value ?? false;
                                  })
                              : null,
                        );
                      }),
                    ],
                    ..._wreckageForNight(state)
                        .where(
                          (entry) => _me == null || entry.owner.id == _me,
                        )
                        .map((entry) {
                      final card = entry.card;
                      final ability = card.wreckage!;
                      final active = _activeWreckageIds.contains(card.id);
                      final slotsNeeded = ability.blocksAnimalCampWide
                          ? 0
                          : ability.blocksWeather
                              ? ability.weatherTargetCount
                              : 1;
                      final slots = _wreckageTargets[card.id] ??
                          List<String?>.filled(slotsNeeded, null);
                      return Material(
                        color: Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                '${entry.owner.name}\'s ${card.name}'
                                '${ability.reusable ? ' (reusable)' : ''}',
                              ),
                              subtitle: Text(ability.blurb),
                              value: active,
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _activeWreckageIds.add(card.id);
                                  _wreckageTargets.putIfAbsent(
                                    card.id,
                                    () => List<String?>.filled(slotsNeeded, null),
                                  );
                                } else {
                                  _activeWreckageIds.remove(card.id);
                                }
                              }),
                            ),
                            if (active && ability.blocksAnimalCampWide)
                              const Padding(
                                padding: EdgeInsets.only(left: 16, bottom: 8),
                                child: Text('Protects the whole camp.'),
                              ),
                            if (active && slotsNeeded > 0)
                              ...List.generate(slotsNeeded, (index) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    left: 8,
                                    bottom: 8,
                                  ),
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      '${card.id}-$index-${slots[index]}',
                                    ),
                                    initialValue: state.alivePlayers.any(
                                      (p) => p.id == slots[index],
                                    )
                                        ? slots[index]
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: slotsNeeded > 1
                                          ? 'Protect survivor ${index + 1}'
                                          : 'Protect survivor',
                                    ),
                                    items: state.alivePlayers
                                        .map(
                                          (p) => DropdownMenuItem(
                                            value: p.id,
                                            child: Text(p.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (id) => setState(() {
                                      final list = _wreckageTargets.putIfAbsent(
                                        card.id,
                                        () => List<String?>.filled(
                                          slotsNeeded,
                                          null,
                                        ),
                                      );
                                      list[index] = id;
                                    }),
                                  ),
                                );
                              }),
                          ],
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

  String _craftButtonLabel(
    GameState state,
    CraftItem item,
    bool canCraft, {
    String? playerId,
  }) {
    if (item == CraftItem.fire && state.fireLit) return 'Already lit';
    if (item == CraftItem.fire && state.fireBlockedNextNight) {
      return 'Blocked';
    }
    if (item == CraftItem.basket &&
        (playerId == null
            ? state.currentPlayer.hasBasket
            : state.players.any((p) => p.id == playerId && p.hasBasket))) {
      return 'Owned';
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
              players: state.alivePlayers,
              nightUse: state.phase == GamePhase.night,
              tradeTargetId: _tradeTargetId,
              onTradeTargetChanged: (id) => setState(() => _tradeTargetId = id),
              onEat: (hearts) {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null) return;
                if (_networked && _me != null && owner.id != _me) return;
                final targetId = _tradeTargetId ?? owner.id;
                final cardId = _selectedCardId!;
                _run(
                  () => engine.useHealCard(
                    ownerId: owner.id,
                    cardId: cardId,
                    targetId: targetId,
                    hearts: hearts,
                  ),
                  {
                    'type': 'heal',
                    'ownerId': owner.id,
                    'cardId': cardId,
                    'targetId': targetId,
                    'hearts': hearts,
                  },
                );
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
              },
              onSplit: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null || _tradeTargetId == null) return;
                if (_networked && _me != null && owner.id != _me) return;
                final card = _card(_selectedCardId!);
                final cardId = _selectedCardId!;
                final otherId = _tradeTargetId!;
                if (card?.wreckage == WreckageAbility.vodka) {
                  _run(
                    () => engine.shareHealCard(
                      ownerId: owner.id,
                      cardId: cardId,
                      otherId: otherId,
                    ),
                    {
                      'type': 'shareHeal',
                      'ownerId': owner.id,
                      'cardId': cardId,
                      'otherId': otherId,
                    },
                  );
                } else {
                  _run(
                    () => engine.splitFood(
                      fromPlayerId: owner.id,
                      toPlayerId: otherId,
                      cardId: cardId,
                    ),
                    {
                      'type': 'splitFood',
                      'fromId': owner.id,
                      'toId': otherId,
                      'cardId': cardId,
                    },
                  );
                }
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
              },
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
                setState(() => _selectedCardId = null);
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
                setState(() => _selectedCardId = null);
              },
              onTrade: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null || _tradeTargetId == null) return;
                if (_networked && _me != null && owner.id != _me) return;
                final cardId = _selectedCardId!;
                final toId = _tradeTargetId!;
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
                  _tradeTargetId = null;
                });
              },
            ),
          if (state.phase == GamePhase.dayForage) ...[
            if (_networked && !session!.isMyForageTurn)
              Text(
                'Waiting for ${current.name} to forage or rest.',
                textAlign: TextAlign.center,
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

class _RosterGrid extends StatelessWidget {
  const _RosterGrid({
    required this.players,
    required this.campStash,
    required this.activeId,
    this.youId,
    required this.selectedCardId,
    required this.shelterIds,
    required this.onCardTap,
    this.caveShelter = false,
    this.hideOtherHands = false,
  });

  final List<Player> players;
  final List<GameCard> campStash;
  final String activeId;
  final String? youId;
  final String? selectedCardId;
  final Set<String> shelterIds;
  final ValueChanged<String> onCardTap;
  final bool caveShelter;
  final bool hideOtherHands;

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
            LayoutBuilder(
              builder: (context, constraints) {
                final itemCount = players.length + 1;
                final columns = itemCount <= 2 || constraints.maxWidth >= 900
                    ? itemCount.clamp(1, 4)
                    : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: itemCount,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    mainAxisExtent: 148,
                  ),
                  itemBuilder: (context, index) {
                    if (index == players.length) {
                      return _CampPanel(
                        cards: campStash,
                        selectedCardId: selectedCardId,
                        onCardTap: onCardTap,
                      );
                    }
                    final player = players[index];
                    return _PlayerPanel(
                      player: player,
                      active: player.id == activeId,
                      you: player.id == youId,
                      selectedCardId: selectedCardId,
                      shelter: shelterIds.contains(player.id),
                      hideHand: hideOtherHands &&
                          player.id != (youId ?? activeId),
                      onCardTap: onCardTap,
                    );
                  },
                );
              },
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
    required this.hideHand,
    required this.onCardTap,
  });

  final Player player;
  final bool active;
  final bool you;
  final String? selectedCardId;
  final bool shelter;
  final bool hideHand;
  final ValueChanged<String> onCardTap;

  @override
  Widget build(BuildContext context) {
    final status = [
      if (player.hasBasket) 'Basket',
      if (player.spearCount > 0) 'Spear ×${player.spearCount}',
      if (shelter) 'Shelter',
      if (!player.isAlive) 'Gone',
      if (player.isAlive && player.hearts <= 0) '0♥',
    ].join(' · ');
    final visibleCards = hideHand
        ? const <GameCard>[]
        : player.hand;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: (active || you) ? const Color(0xFF2A4033) : const Color(0xFF16241C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (active || you) ? AppTheme.accent : const Color(0xFF2E4036),
          width: (active || you) ? 2.5 : 1,
        ),
      ),
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
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    decoration:
                        player.isAlive ? null : TextDecoration.lineThrough,
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
          HeartDisplay(hearts: player.hearts),
          if (status.isNotEmpty)
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _MiniCardRow(
              cards: visibleCards,
              emptyLabel: hideHand
                  ? (player.hand.isEmpty
                      ? 'No cards'
                      : '${player.hand.length} hidden')
                  : 'No cards',
              selectedCardId: selectedCardId,
              onCardTap: onCardTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _CampPanel extends StatelessWidget {
  const _CampPanel({
    required this.cards,
    required this.selectedCardId,
    required this.onCardTap,
  });

  final List<GameCard> cards;
  final String? selectedCardId;
  final ValueChanged<String> onCardTap;

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
            'Camp',
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
          Expanded(
            child: _MiniCardRow(
              cards: cards,
              emptyLabel: 'No cards',
              selectedCardId: selectedCardId,
              onCardTap: onCardTap,
            ),
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

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: cards.length,
      separatorBuilder: (context, index) => const SizedBox(width: 6),
      itemBuilder: (context, index) {
        final card = cards[index];
        return ResourceCardTile(
          card: card,
          compact: true,
          mini: true,
          selected: card.id == selectedCardId,
          onTap: () => onCardTap(card.id),
        );
      },
    );
  }
}

class _CampCardActions extends StatelessWidget {
  const _CampCardActions({
    required this.card,
    required this.owner,
    required this.inCamp,
    required this.current,
    required this.players,
    required this.tradeTargetId,
    required this.onTradeTargetChanged,
    required this.onEat,
    required this.onSplit,
    required this.onToCamp,
    required this.onFromCamp,
    required this.onTrade,
    this.nightUse = false,
  });

  final GameCard? card;
  final Player? owner;
  final bool inCamp;
  final Player current;
  final List<Player> players;
  final String? tradeTargetId;
  final ValueChanged<String?> onTradeTargetChanged;
  final ValueChanged<int> onEat;
  final VoidCallback onSplit;
  final VoidCallback onToCamp;
  final VoidCallback onFromCamp;
  final VoidCallback onTrade;
  final bool nightUse;

  @override
  Widget build(BuildContext context) {
    if (card == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!inCamp && players.length > 1) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(tradeTargetId),
            initialValue: players.any((player) => player.id == tradeTargetId)
                ? tradeTargetId
                : null,
            decoration: const InputDecoration(labelText: 'Use on / give to'),
            items: players
                .where((player) => player.id != owner?.id)
                .map(
                  (player) => DropdownMenuItem(
                    value: player.id,
                    child: Text(player.name),
                  ),
                )
                .toList(),
            onChanged: onTradeTargetChanged,
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (nightUse &&
                card!.wreckage != null &&
                !card!.isWreckageHeal)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  'Assign this protection above, then resolve night.',
                ),
              ),
            if (card!.isFood || card!.isWreckageHeal)
              OutlinedButton(
                onPressed: () => onEat(
                  card!.fullHeal ? card!.healValue : card!.healValue,
                ),
                child: Text(
                  card!.fullHeal
                      ? (tradeTargetId == null
                          ? 'Full heal (self)'
                          : 'Full heal (chosen)')
                      : (tradeTargetId == null
                          ? 'Use +${card!.healValue}♥ (self)'
                          : 'Use +${card!.healValue}♥ (chosen)'),
                ),
              ),
            if ((card!.isFood && card!.healValue >= 2) ||
                card!.wreckage == WreckageAbility.vodka)
              OutlinedButton(
                onPressed: tradeTargetId == null ? null : onSplit,
                child: Text(
                  card!.wreckage == WreckageAbility.vodka
                      ? 'Share vodka (1♥ / 2♥)'
                      : 'Split 1♥ each',
                ),
              ),
            if (!nightUse && !inCamp)
              OutlinedButton(
                onPressed: onToCamp,
                child: const Text('To camp'),
              ),
            if (inCamp &&
                (!nightUse ||
                    card!.isFood ||
                    card!.isWreckageHeal))
              OutlinedButton(
                onPressed: onFromCamp,
                child: Text('${current.name} takes'),
              ),
            if (!nightUse && !inCamp)
              OutlinedButton(
                onPressed: tradeTargetId == null ? null : onTrade,
                child: const Text('Give'),
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
