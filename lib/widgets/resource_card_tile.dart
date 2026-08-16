import 'package:flutter/material.dart';

import '../models/game_card.dart';

class ResourceCardTile extends StatelessWidget {
  const ResourceCardTile({
    super.key,
    required this.card,
    this.selected = false,
    this.onTap,
    this.compact = false,
  });

  final GameCard card;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF3A4F43) : const Color(0xFF24362C),
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: Container(
          width: compact ? 72 : 92,
          padding: EdgeInsets.all(compact ? 8 : 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(compact ? 12 : 16),
            border: Border.all(
              color: selected ? const Color(0xFFE8A54B) : const Color(0xFF355043),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.resource.emoji,
                style: TextStyle(fontSize: compact ? 24 : 30),
              ),
              const SizedBox(height: 6),
              Text(
                card.resource.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
