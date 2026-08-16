import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import 'game_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 3;
  int _nights = 7;
  final _controllers = List.generate(4, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startGame() {
    final names = List<String>.generate(
      _playerCount,
      (index) => _controllers[index].text,
    );

    final engine = GameEngine();
    engine.startGame(playerNames: names, totalNights: _nights);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(engine: engine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expedition Setup')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Survivors',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how many players are around the campfire.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
              ],
              selected: {_playerCount},
              onSelectionChanged: (selection) {
                setState(() => _playerCount = selection.first);
              },
            ),
            const SizedBox(height: 24),
            ...List.generate(_playerCount, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[index],
                  decoration: InputDecoration(
                    labelText: 'Survivor ${index + 1}',
                    hintText: 'Optional name',
                    filled: true,
                    fillColor: const Color(0xFF1B2A22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF355043)),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Nights to survive',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 7, label: Text('7')),
                ButtonSegment(value: 10, label: Text('10')),
              ],
              selected: {_nights},
              onSelectionChanged: (selection) {
                setState(() => _nights = selection.first);
              },
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _startGame,
              child: const Text('Begin Day 1'),
            ),
          ],
        ),
      ),
    );
  }
}
