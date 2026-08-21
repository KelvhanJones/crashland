import 'package:flutter/material.dart';

import '../models/game_card.dart';

class ResourceCardTile extends StatelessWidget {
  const ResourceCardTile({
    super.key,
    required this.card,
    this.selected = false,
    this.onTap,
    this.compact = false,
    this.mini = false,
  });

  final GameCard card;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;
  final bool mini;

  @override
  Widget build(BuildContext context) {
    final subtitle = card.isFood
        ? '+${card.healValue}♥'
        : card.fullHeal
            ? 'Full heal'
            : card.wreckage != null
                ? card.wreckage!.label
                : card.boneIndex != null
                    ? 'Piece ${card.boneIndex}'
                    : card.kind.label;
    final radius = mini ? 8.0 : (compact ? 12.0 : 16.0);
    final width = mini ? 72.0 : (compact ? 84.0 : 100.0);
    final pad = mini ? 6.0 : (compact ? 8.0 : 12.0);

    return Material(
      color: selected ? const Color(0xFF3A4F43) : const Color(0xFF24362C),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: width,
          padding: EdgeInsets.all(pad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
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
                style: TextStyle(fontSize: mini ? 16 : (compact ? 22 : 28)),
              ),
              SizedBox(height: mini ? 2 : 6),
              Text(
                card.name,
                textAlign: TextAlign.center,
                maxLines: mini ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: mini ? 10 : (compact ? 11 : 12),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: mini ? 9 : (compact ? 10 : 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
