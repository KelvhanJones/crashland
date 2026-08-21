import 'package:flutter/material.dart';

import '../net/table_session.dart';
import 'lobby_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _ip = TextEditingController();
  final _name = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final ip = _ip.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Enter the host\'s IP address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = createClientSession();
    try {
      await session.join(address: ip, name: _name.text);
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join expedition')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Same Wi‑Fi as the host. Type the IP shown on their lobby screen.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Your name',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ip,
              decoration: const InputDecoration(
                labelText: 'Host IP address',
                hintText: '192.168.1.12',
                filled: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Color(0xFFD65A4D))),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text(_busy ? 'Connecting…' : 'Join camp'),
            ),
          ],
        ),
      ),
    );
  }
}
