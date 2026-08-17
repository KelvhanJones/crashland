import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/card_kind.dart';
import '../models/craft_item.dart';
import '../models/game_card.dart';
import '../models/game_phase.dart';
import '../models/madness_card.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import '../widgets/heart_display.dart';
import '../widgets/resource_card_tile.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.engine});

  final GameEngine engine;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String? _selectedCardId;
  String? _tradeTargetId;
  final _spearUsers = <String>{};
  final _tarpUsers = <String>{};
  final _flareUsers = <String>{};
  String? _madnessTargetId;
  bool _defend = false;

  GameEngine get engine => widget.engine;

  void _refresh() => setState(() {});

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
        onRestart: () {
          engine.reset();
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                state.fireLit ? '🔥 Fire lit' : 'Fire out',
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
            _Banner(phase: state.phase, message: state.message),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PlayerStatusList(
                    players: state.players,
                    activeId: current.id,
                    shelterIds: state.shelterOccupants,
                    hasShelter: state.hasShelter,
                    onToggleShelter: state.phase == GamePhase.dayCamp
                        ? (id) {
                            engine.toggleShelterOccupant(id);
                            _refresh();
                          }
                        : null,
                  ),
                  const SizedBox(height: 16),
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
                  if (state.campStash.isNotEmpty) ...[
                    Text('Camp stash', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.campStash
                          .map(
                            (card) => ResourceCardTile(
                              card: card,
                              compact: true,
                              selected: card.id == _selectedCardId,
                              onTap: () => setState(() {
                                _selectedCardId =
                                    _selectedCardId == card.id ? null : card.id;
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    state.phase == GamePhase.dayForage
                        ? '${current.name}\'s hand'
                        : 'Hands',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.phase == GamePhase.dayForage)
                    _HandSection(
                      player: current,
                      selectedCardId: _selectedCardId,
                      onCardTap: (id) => setState(() {
                        _selectedCardId = _selectedCardId == id ? null : id;
                      }),
                    )
                  else
                    ...state.alivePlayers.map(
                      (player) => _HandSection(
                        player: player,
                        selectedCardId: _selectedCardId,
                        onCardTap: (id) => setState(() {
                          _selectedCardId = _selectedCardId == id ? null : id;
                        }),
                      ),
                    ),
                  if (state.phase == GamePhase.dayCamp) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Materials — wood ${state.countResource(CardKind.wood)}, '
                      'stone ${state.countResource(CardKind.stone)}, '
                      'fiber ${state.countResource(CardKind.fiber)}'
                      '${state.canAssembleBones ? ' · bone circle ready' : ''}',
                    ),
                    const SizedBox(height: 12),
                    ...CraftItem.values.map((item) {
                      final alreadyLit =
                          item == CraftItem.fire && state.fireLit;
                      final canCraft = !alreadyLit && engine.canCraft(item);
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
                                    item.label,
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  Text(item.description),
                                  Text(
                                    item.cost.entries
                                        .map((e) => '${e.value} ${e.key}')
                                        .join(' · '),
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton(
                              onPressed: canCraft
                                  ? () {
                                      engine.craft(item);
                                      _refresh();
                                    }
                                  : null,
                              child: Text(
                                alreadyLit
                                    ? 'Already lit'
                                    : _craftButtonLabel(state, item, canCraft),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (state.canAssembleBones)
                      FilledButton(
                        onPressed: () {
                          engine.assembleBoneCircle();
                          _refresh();
                        },
                        child: const Text('Assemble bone circle'),
                      ),
                  ],
                  if (state.phase == GamePhase.night) ...[
                    Text(
                      'Assign defenses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    ...state.alivePlayers.map(
                      (player) => Material(
                        color: Colors.transparent,
                        child: Column(
                        children: [
                          if (player.spearCount + player.knifeCount > 0)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${player.name}: spear / knife'),
                              value: _spearUsers.contains(player.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _spearUsers.add(player.id);
                                } else {
                                  _spearUsers.remove(player.id);
                                }
                              }),
                            ),
                          if (player.tarpCharges > 0)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${player.name}: cargo tarp'),
                              value: _tarpUsers.contains(player.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _tarpUsers.add(player.id);
                                } else {
                                  _tarpUsers.remove(player.id);
                                }
                              }),
                            ),
                          if (player.flareCharges > 0)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${player.name}: signal flare'),
                              value: _flareUsers.contains(player.id),
                              onChanged: (value) => setState(() {
                                if (value == true) {
                                  _flareUsers.add(player.id);
                                } else {
                                  _flareUsers.remove(player.id);
                                }
                              }),
                            ),
                        ],
                        ),
                      ),
                    ),
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

  String _craftButtonLabel(GameState state, CraftItem item, bool canCraft) {
    if (item == CraftItem.fire && state.fireLit) return 'Already lit';
    if (item == CraftItem.shelter && state.hasShelter) return 'Built';
    if (item == CraftItem.basket && state.currentPlayer.hasBasket) {
      return 'Owned';
    }
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
          if (state.phase == GamePhase.dayCamp && _selectedCardId != null)
            _CampCardActions(
              card: _card(_selectedCardId!),
              owner: _ownerOf(_selectedCardId!),
              inCamp: state.campStash.any((card) => card.id == _selectedCardId),
              current: current,
              players: state.alivePlayers,
              tradeTargetId: _tradeTargetId,
              onTradeTargetChanged: (id) => setState(() => _tradeTargetId = id),
              onEat: (hearts) {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null) return;
                engine.eatFood(owner.id, _selectedCardId!, hearts: hearts);
                setState(() => _selectedCardId = null);
                _refresh();
              },
              onSplit: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null || _tradeTargetId == null) return;
                engine.splitFood(
                  fromPlayerId: owner.id,
                  toPlayerId: _tradeTargetId!,
                  cardId: _selectedCardId!,
                );
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
                _refresh();
              },
              onToCamp: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null) return;
                engine.contributeToCamp(owner.id, _selectedCardId!);
                setState(() => _selectedCardId = null);
                _refresh();
              },
              onFromCamp: () {
                engine.takeFromCamp(current.id, _selectedCardId!);
                setState(() => _selectedCardId = null);
                _refresh();
              },
              onTrade: () {
                final owner = _ownerOf(_selectedCardId!);
                if (owner == null || _tradeTargetId == null) return;
                engine.tradeCard(
                  fromPlayerId: owner.id,
                  toPlayerId: _tradeTargetId!,
                  cardId: _selectedCardId!,
                );
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
                _refresh();
              },
            ),
          if (state.phase == GamePhase.dayForage) ...[
            if (current.forcedRest)
              FilledButton(
                onPressed: () {
                  engine.restCurrentPlayer();
                  _refresh();
                },
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
                          : () {
                              engine.forageCurrentPlayer(i);
                              _refresh();
                            },
                      child: Text('Forage $i♥'),
                    ),
                  if (current.forcedForage == null) ...[
                    OutlinedButton(
                      onPressed: () {
                        engine.restCurrentPlayer();
                        _refresh();
                      },
                      child: const Text('Rest +1♥'),
                    ),
                    if (current.hasBasket)
                      OutlinedButton(
                        onPressed: () {
                          engine.restCurrentPlayer(useBasket: true);
                          _refresh();
                        },
                        child: const Text('Basket: draw 1, no heal'),
                      ),
                  ],
                ],
              ),
            ],
          ] else if (state.phase == GamePhase.dayCamp)
            FilledButton(
              onPressed: () {
                engine.beginNight();
                _spearUsers.clear();
                _tarpUsers.clear();
                _flareUsers.clear();
                _refresh();
              },
              child: const Text('Begin night'),
            )
          else if (state.phase == GamePhase.night)
            FilledButton(
              onPressed: () {
                engine.resolveNight(
                  spearUsers: _spearUsers,
                  tarpUsers: _tarpUsers,
                  flareUsers: _flareUsers,
                );
                _refresh();
              },
              child: const Text('Resolve night'),
            )
          else if (state.phase == GamePhase.madness)
            _MadnessActions(
              player: state.alivePlayers.firstWhere(
                (player) => player.pendingMadness != null,
                orElse: () => current,
              ),
              others: state.alivePlayers,
              targetId: _madnessTargetId,
              defend: _defend,
              onTargetChanged: (id) => setState(() => _madnessTargetId = id),
              onDefendChanged: (value) => setState(() => _defend = value),
              onConfirm: () {
                engine.applyMadness(
                  targetId: _madnessTargetId,
                  defendWithWeapon: _defend,
                );
                setState(() {
                  _madnessTargetId = null;
                  _defend = false;
                });
                _refresh();
              },
            ),
        ],
      ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.phase, required this.message});

  final GamePhase phase;
  final String message;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      GamePhase.dayForage => 'Forage',
      GamePhase.dayCamp => 'Camp',
      GamePhase.night => 'Night',
      GamePhase.madness => 'Madness',
      _ => 'Planecrash Survival',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1B2A22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _PlayerStatusList extends StatelessWidget {
  const _PlayerStatusList({
    required this.players,
    required this.activeId,
    required this.shelterIds,
    required this.hasShelter,
    this.onToggleShelter,
  });

  final List<Player> players;
  final String activeId;
  final Set<String> shelterIds;
  final bool hasShelter;
  final ValueChanged<String>? onToggleShelter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Survivors', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...players.map(
          (player) => Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: player.id == activeId
                    ? AppTheme.accent
                    : const Color(0xFF355043),
                foregroundColor:
                    player.id == activeId ? AppTheme.background : Colors.white,
                child: Text(
                  player.name.isNotEmpty ? player.name[0].toUpperCase() : '?',
                ),
              ),
              title: Text(
                player.name,
                style: TextStyle(
                  color: player.isAlive ? Colors.white : Colors.white38,
                  decoration:
                      player.isAlive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                [
                  if (player.hasBasket) 'Basket',
                  if (player.spearCount > 0) 'Spear ×${player.spearCount}',
                  if (player.knifeCount > 0) 'Knife',
                  if (shelterIds.contains(player.id)) 'In shelter',
                  if (!player.isAlive) 'Gone',
                  if (hasShelter && player.isAlive && onToggleShelter != null)
                    shelterIds.contains(player.id)
                        ? 'tap to leave shelter'
                        : 'tap to enter shelter',
                ].join(' · '),
              ),
              trailing: FittedBox(
                child: HeartDisplay(hearts: player.hearts),
              ),
              onTap: hasShelter && player.isAlive && onToggleShelter != null
                  ? () => onToggleShelter!(player.id)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _HandSection extends StatelessWidget {
  const _HandSection({
    required this.player,
    required this.selectedCardId,
    required this.onCardTap,
  });

  final Player player;
  final String? selectedCardId;
  final ValueChanged<String> onCardTap;

  @override
  Widget build(BuildContext context) {
    if (player.hand.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('${player.name} has no cards.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(player.name, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: player.hand
              .map(
                (card) => ResourceCardTile(
                  card: card,
                  compact: true,
                  selected: card.id == selectedCardId,
                  onTap: () => onCardTap(card.id),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
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
    required this.players,
    required this.tradeTargetId,
    required this.onTradeTargetChanged,
    required this.onEat,
    required this.onSplit,
    required this.onToCamp,
    required this.onFromCamp,
    required this.onTrade,
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
            decoration: const InputDecoration(labelText: 'Give / split with'),
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
            if (card!.isFood ||
                (card!.wreckage != null && card!.healValue > 0))
              OutlinedButton(
                onPressed: () => onEat(card!.healValue),
                child: Text('Eat +${card!.healValue}♥'),
              ),
            if (card!.isFood && card!.healValue >= 2)
              OutlinedButton(
                onPressed: tradeTargetId == null ? null : onSplit,
                child: const Text('Split 1♥ each'),
              ),
            if (!inCamp)
              OutlinedButton(
                onPressed: onToCamp,
                child: const Text('To camp'),
              ),
            if (inCamp)
              OutlinedButton(
                onPressed: onFromCamp,
                child: Text('${current.name} takes'),
              ),
            if (!inCamp)
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
    required this.others,
    required this.targetId,
    required this.defend,
    required this.onTargetChanged,
    required this.onDefendChanged,
    required this.onConfirm,
  });

  final Player player;
  final List<Player> others;
  final String? targetId;
  final bool defend;
  final ValueChanged<String?> onTargetChanged;
  final ValueChanged<bool> onDefendChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final card = player.pendingMadness;
    final isLash = card?.kind == MadnessKind.lashOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLash) ...[
          DropdownButtonFormField<String>(
            key: ValueKey(targetId),
            initialValue: others.any((item) => item.id == targetId)
                ? targetId
                : null,
            decoration: const InputDecoration(labelText: 'Target'),
            items: others
                .where((item) => item.id != player.id)
                .map(
                  (item) => DropdownMenuItem(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            onChanged: onTargetChanged,
          ),
          Row(
            children: [
              Checkbox(
                value: defend,
                onChanged: (value) => onDefendChanged(value ?? false),
              ),
              const Expanded(
                child: Text('Target defends with spear / knife'),
              ),
            ],
          ),
        ],
        FilledButton(
          onPressed: onConfirm,
          child: Text('Resolve ${card?.title ?? 'madness'}'),
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
