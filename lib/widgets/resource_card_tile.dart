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
    final subtitle = card.isFood
        ? '+${card.healValue}♥'
        : card.boneIndex != null
            ? 'Piece ${card.boneIndex}'
            : card.kind.label;

    return Material(
      color: selected ? const Color(0xFF3A4F43) : const Color(0xFF24362C),
      borderRadius: BorderRadius.circular(compact ? 12 : 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 12 : 16),
        child: Container(
          width: compact ? 84 : 100,
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
                card.kind.emoji,
                style: TextStyle(fontSize: compact ? 22 : 28),
              ),
              const SizedBox(height: 6),
              Text(
                card.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
