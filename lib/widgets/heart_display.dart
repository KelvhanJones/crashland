import 'package:flutter/material.dart';

class HeartDisplay extends StatelessWidget {
  const HeartDisplay({
    super.key,
    required this.hearts,
    this.maxHearts = 6,
    this.pending = 0,
    this.canAssign = false,
    this.slotPrefix,
    this.onSlotTap,
  });

  final int hearts;
  final int maxHearts;
  final int pending;
  final bool canAssign;
  final String? slotPrefix;
  final ValueChanged<int>? onSlotTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: List.generate(maxHearts, (index) {
        final filled = index < hearts;
        final pledged = !filled && index < hearts + pending;
        final nextEmpty = index == hearts + pending;
        final tappable = canAssign &&
            onSlotTap != null &&
            (pledged || nextEmpty);

        late final IconData icon;
        late final Color color;
        if (filled) {
          icon = Icons.favorite;
          color = const Color(0xFFD65A4D);
        } else if (pledged) {
          icon = Icons.favorite;
          color = const Color(0xFFE8A54B);
        } else if (canAssign && nextEmpty) {
          icon = Icons.favorite_border;
          color = const Color(0xFFE8A54B);
        } else {
          icon = Icons.favorite_border;
          color = Colors.white24;
        }

        final heart = Icon(
          icon,
          key: slotPrefix == null ? null : ValueKey('$slotPrefix-heart-$index'),
          color: color,
          size: 16,
        );
        if (!tappable) return heart;
        return GestureDetector(
          onTap: () => onSlotTap!(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: heart,
          ),
        );
      }),
    );
  }
}
