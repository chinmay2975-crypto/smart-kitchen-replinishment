import 'package:flutter/material.dart';

class DeviceContainerTile extends StatelessWidget {
  final String deviceName;
  final int levelPercent;
  final VoidCallback onTap;

  const DeviceContainerTile({
    super.key,
    required this.deviceName,
    required this.levelPercent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = levelPercent.clamp(0, 100);
    final fillFactor = clampedLevel / 100;
    final bool isFull = clampedLevel == 100;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              color: Colors.black12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            /// Container visual
            Expanded(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Outer container
                  Container(
                    width: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black54, width: 2),
                      color: Colors.white,
                    ),
                  ),

                  // Water fill
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    heightFactor: fillFactor,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.only(
                          bottomLeft: const Radius.circular(10),
                          bottomRight: const Radius.circular(10),
                          topLeft: isFull
                              ? const Radius.circular(10)
                              : Radius.zero,
                          topRight: isFull
                              ? const Radius.circular(10)
                              : Radius.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              "$levelPercent%",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              deviceName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
