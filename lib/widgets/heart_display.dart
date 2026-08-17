import 'package:flutter/material.dart';

class HeartDisplay extends StatelessWidget {
  const HeartDisplay({super.key, required this.hearts, this.maxHearts = 6});

  final int hearts;
  final int maxHearts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: List.generate(maxHearts, (index) {
        final filled = index < hearts;
        return Icon(
          filled ? Icons.favorite : Icons.favorite_border,
          color: filled ? const Color(0xFFD65A4D) : Colors.white24,
          size: 16,
        );
      }),
    );
  }
}
