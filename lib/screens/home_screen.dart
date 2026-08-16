import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
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
              Text(
                '🏕️',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Crashland',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'A cooperative survival card game for 2–4 players on one device. '
                'Gather resources by day, survive the island by night.',
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
                child: const Text('New Expedition'),
              ),
              const SizedBox(height: 12),
              Text(
                'Pass the phone between players during your turn.',
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
