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
    this.count = 1,
  });

  final GameCard card;
  final bool selected;
  final VoidCallback? onTap;
  final bool compact;
  final bool mini;
  final int count;

  @override
  Widget build(BuildContext context) {
    final subtitle = card.isFood
        ? '+${card.healValue}♥'
        : card.fullHeal
            ? 'Full heal'
            : card.uhOh != null
                ? (card.effectBlurb.isEmpty ? card.kind.label : card.effectBlurb)
                : card.wreckage != null
                    ? card.wreckage!.label
                    : card.boneIndex != null
                        ? 'Piece ${card.boneIndex}'
                        : card.flavor.isNotEmpty
                            ? card.flavor
                            : card.kind.label;
    final radius = mini ? 6.0 : (compact ? 12.0 : 16.0);
    final label = [
      if (count > 1) '${card.name} ×$count' else card.name,
      if (mini && card.isFood) '+${card.healValue}♥',
    ].join(' ');

    return Material(
      color: selected ? const Color(0xFF3A4F43) : const Color(0xFF24362C),
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: mini ? null : (compact ? 84.0 : 100.0),
          padding: mini
              ? const EdgeInsets.symmetric(horizontal: 6, vertical: 4)
              : EdgeInsets.all(compact ? 8.0 : 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected ? const Color(0xFFE8A54B) : const Color(0xFF355043),
              width: selected ? 2 : 1,
            ),
          ),
          child: mini ? _chip(label) : _face(subtitle),
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(card.kind.emoji, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _face(String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.kind.emoji,
          style: TextStyle(fontSize: compact ? 22 : 28),
        ),
        const SizedBox(height: 6),
        Text(
          count > 1 ? '${card.name} ×$count' : card.name,
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white70,
            fontSize: compact ? 10 : 11,
          ),
        ),
      ],
    );
  }
}
