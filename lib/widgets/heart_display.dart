import 'package:flutter/material.dart';

class HeartDisplay extends StatelessWidget {
  const HeartDisplay({super.key, required this.hearts, this.maxHearts = 3});

  final int hearts;
  final int maxHearts;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxHearts, (index) {
        final filled = index < hearts;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            color: filled ? const Color(0xFFD65A4D) : Colors.white24,
            size: 20,
          ),
        );
      }),
    );
  }
}
