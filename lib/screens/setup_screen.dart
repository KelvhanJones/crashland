import 'package:flutter/material.dart';

import '../game/game_engine.dart';
import '../net/table_session.dart';
import 'game_screen.dart';
import 'lobby_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, this.hostOnline = false});

  final bool hostOnline;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 3;
  int _nights = 8;
  final _controllers = List.generate(4, (_) => TextEditingController());
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.hostOnline) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final session = createHostSession();
      try {
        await session.host(
          hostName: _controllers[0].text.trim().isEmpty
              ? 'Survivor 1'
              : _controllers[0].text.trim(),
          playerCount: _playerCount,
          totalNights: _nights,
        );
        if (!mounted) {
          await session.disposeSession();
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => LobbyScreen(session: session),
          ),
        );
      } catch (error) {
        await session.disposeSession();
        if (mounted) {
          setState(() {
            _busy = false;
            _error = '$error';
          });
        }
      }
      return;
    }

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
      appBar: AppBar(
        title: Text(widget.hostOnline ? 'Host expedition' : 'Expedition Setup'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Survivors', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              widget.hostOnline
                  ? 'How many survivors will join this Wi‑Fi game, including you?'
                  : 'Each survivor starts with 3 hearts, then rolls 3 more after the crash.',
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
            ...List.generate(
              widget.hostOnline ? 1 : _playerCount,
              (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _controllers[index],
                  decoration: InputDecoration(
                    labelText: widget.hostOnline
                        ? 'Your name (host)'
                        : 'Survivor ${index + 1}',
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
            Text('Difficulty', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Rescue is shuffled into the last 3 night cards. Longer decks are harder.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 8, label: Text('8 easy')),
                ButtonSegment(value: 12, label: Text('12')),
                ButtonSegment(value: 16, label: Text('16 hard')),
              ],
              selected: {_nights},
              onSelectionChanged: (selection) {
                setState(() => _nights = selection.first);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFD65A4D))),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _start,
              child: Text(
                widget.hostOnline
                    ? (_busy ? 'Opening camp…' : 'Open lobby')
                    : 'Face the first night',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
