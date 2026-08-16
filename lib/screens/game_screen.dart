import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../models/game_phase.dart';
import '../models/night_threat.dart';
import '../models/player.dart';
import '../models/structure_type.dart';
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

  GameEngine get engine => widget.engine;

  void _refresh() => setState(() {});

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

    final currentPlayer = state.currentPlayer;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.phase == GamePhase.night
            ? 'Night ${state.nightNumber}'
            : 'Day ${state.nightNumber + 1}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${state.nightNumber}/${state.totalNights} nights',
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
            _PhaseBanner(phase: state.phase, message: state.message),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (state.phase == GamePhase.night && state.activeThreat != null)
                    _NightPanel(threat: state.activeThreat!),
                  _PlayerStatusList(players: state.players, activeId: currentPlayer.id),
                  const SizedBox(height: 16),
                  if (state.builtStructures.isNotEmpty) ...[
                    Text('Camp structures', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.builtStructures
                          .map(
                            (structure) => Chip(
                              label: Text(structure.label),
                              backgroundColor: const Color(0xFF24362C),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (state.contributionPool.isNotEmpty) ...[
                    Text('Resource pool', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.contributionPool.entries
                          .map(
                            (entry) => Chip(
                              avatar: Text(entry.key.emoji),
                              label: Text('${entry.key.label} × ${entry.value}'),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    state.phase == GamePhase.night
                        ? 'Everyone\'s hand'
                        : '${currentPlayer.name}\'s hand',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (state.phase == GamePhase.night)
                    ...state.alivePlayers.map((player) => _HandSection(
                          player: player,
                          selectedCardId: _selectedCardId,
                          onCardTap: (cardId) {
                            setState(() {
                              _selectedCardId =
                                  _selectedCardId == cardId ? null : cardId;
                            });
                          },
                        ))
                  else
                    _HandSection(
                      player: currentPlayer,
                      selectedCardId: _selectedCardId,
                      onCardTap: (cardId) {
                        setState(() {
                          _selectedCardId =
                              _selectedCardId == cardId ? null : cardId;
                        });
                      },
                    ),
                  if (state.phase == GamePhase.dayAction) ...[
                    const SizedBox(height: 16),
                    Text('Build', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    ...StructureType.values.map(
                      (structure) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(structure.label),
                        subtitle: Text(structure.description),
                        trailing: state.builtStructures.contains(structure)
                            ? const Icon(Icons.check_circle, color: AppTheme.success)
                            : OutlinedButton(
                                onPressed: () {
                                  engine.buildStructure(structure);
                                  _refresh();
                                },
                                child: const Text('Build'),
                              ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(
              phase: state.phase,
              currentPlayer: currentPlayer,
              selectedCardId: _selectedCardId,
              tradeTargetId: _tradeTargetId,
              players: state.alivePlayers,
              onDraw: () {
                engine.drawForCurrentPlayer();
                _refresh();
              },
              onContribute: () {
                if (_selectedCardId == null) return;
                engine.contributeCard(currentPlayer.id, _selectedCardId!);
                setState(() => _selectedCardId = null);
                _refresh();
              },
              onTradeTargetChanged: (playerId) {
                setState(() => _tradeTargetId = playerId);
              },
              onTrade: () {
                if (_selectedCardId == null || _tradeTargetId == null) return;
                engine.tradeCard(
                  fromPlayerId: currentPlayer.id,
                  toPlayerId: _tradeTargetId!,
                  cardId: _selectedCardId!,
                );
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
                _refresh();
              },
              onEndTurn: () {
                engine.endPlayerTurn();
                setState(() {
                  _selectedCardId = null;
                  _tradeTargetId = null;
                });
                _refresh();
              },
              onResolveNight: () {
                engine.resolveNightWithPool();
                setState(() => _selectedCardId = null);
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, required this.message});

  final GamePhase phase;
  final String message;

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      GamePhase.dayDraw => 'Draw phase',
      GamePhase.dayAction => 'Day actions',
      GamePhase.night => 'Nightfall',
      _ => 'Crashland',
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

class _NightPanel extends StatelessWidget {
  const _NightPanel({required this.threat});

  final NightThreatType threat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(threat.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(threat.description),
            if (threat.structure != null) ...[
              const SizedBox(height: 8),
              Text('Protected by: ${threat.structure}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlayerStatusList extends StatelessWidget {
  const _PlayerStatusList({required this.players, required this.activeId});

  final List<Player> players;
  final String activeId;

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
                  player.name.isNotEmpty
                      ? player.name[0].toUpperCase()
                      : '?',
                ),
              ),
              title: Text(
                player.name,
                style: TextStyle(
                  color: player.isAlive ? Colors.white : Colors.white38,
                  decoration: player.isAlive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text(
                player.isAlive
                    ? '${player.hand.length} cards'
                    : 'Lost at sea',
              ),
              trailing: HeartDisplay(hearts: player.hearts),
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

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.phase,
    required this.currentPlayer,
    required this.selectedCardId,
    required this.tradeTargetId,
    required this.players,
    required this.onDraw,
    required this.onContribute,
    required this.onTradeTargetChanged,
    required this.onTrade,
    required this.onEndTurn,
    required this.onResolveNight,
  });

  final GamePhase phase;
  final Player currentPlayer;
  final String? selectedCardId;
  final String? tradeTargetId;
  final List<Player> players;
  final VoidCallback onDraw;
  final VoidCallback onContribute;
  final ValueChanged<String?> onTradeTargetChanged;
  final VoidCallback onTrade;
  final VoidCallback onEndTurn;
  final VoidCallback onResolveNight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1B2A22),
        border: Border(top: BorderSide(color: Color(0xFF2E4036))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (phase == GamePhase.dayAction && selectedCardId != null) ...[
            DropdownButtonFormField<String>(
              initialValue: tradeTargetId,
              decoration: const InputDecoration(labelText: 'Trade to'),
              items: players
                  .where((player) => player.id != currentPlayer.id)
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onContribute,
                    child: const Text('To pool'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: tradeTargetId == null ? null : onTrade,
                    child: const Text('Trade'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (phase == GamePhase.dayDraw)
            FilledButton(
              onPressed: onDraw,
              child: Text('${currentPlayer.name}, draw 2 cards'),
            )
          else if (phase == GamePhase.dayAction)
            FilledButton(
              onPressed: onEndTurn,
              child: Text('End ${currentPlayer.name}\'s turn'),
            )
          else if (phase == GamePhase.night) ...[
            if (selectedCardId != null)
              OutlinedButton(
                onPressed: onContribute,
                child: const Text('Add selected card to pool'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: onResolveNight,
              child: const Text('Resolve night'),
            ),
          ],
        ],
      ),
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
                won ? 'Rescued!' : 'Game Over',
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
