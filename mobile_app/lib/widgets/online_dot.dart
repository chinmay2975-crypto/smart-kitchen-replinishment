import 'package:flutter/material.dart';

class OnlineDot extends StatelessWidget {
  final bool isOnline;

  const OnlineDot({super.key, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
      ),
    );
  }
}
