import 'package:flutter/material.dart';

import '../net/table_session.dart';
import 'game_screen.dart';
import 'home_screen.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key, required this.session});

  final TableSession session;

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  TableSession get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.addListener(_onSession);
  }

  @override
  void dispose() {
    session.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (session.started && session.engine.state != null) {
      session.removeListener(_onSession);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            engine: session.engine,
            session: session,
          ),
        ),
      );
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camp lobby'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await session.disposeSession();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (session.isHost) ...[
                Text(
                  'Share this address',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.hostAddress}:$kPlayPort',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Everyone must be on the same Wi‑Fi. Windows may ask to allow the firewall.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ] else
                Text(
                  session.status,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 24),
              Text(
                'Survivors (${session.seats.length}/${session.seatsWanted})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...session.seats.map(
                (seat) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(seat.name),
                  subtitle: Text(
                    seat.id == session.localPlayerId ? 'You' : seat.id,
                  ),
                ),
              ),
              const Spacer(),
              if (session.isHost)
                FilledButton(
                  onPressed: session.seats.length >= 2
                      ? session.startHostedGame
                      : null,
                  child: const Text('Start expedition'),
                )
              else
                Text(
                  'Wait for the host to start.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
