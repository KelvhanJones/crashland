import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'join_screen.dart';
import 'setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 112,
                    height: 112,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Planecrash Survival',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'The crash starts at night. The wreck is already burning — '
                'use that fire, then forage at dawn, craft, and hold out until rescue.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textMuted,
                      height: 1.5,
                    ),
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SetupScreen(),
                    ),
                  );
                },
                child: const Text('Pass-and-play'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SetupScreen(hostOnline: true),
                    ),
                  );
                },
                child: const Text('Host on this device'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const JoinScreen(),
                    ),
                  );
                },
                child: const Text('Join another device'),
              ),
              const SizedBox(height: 12),
              Text(
                'Pass one device, or play on the same Wi‑Fi with a host.',
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
