import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device.dart';
import '../utils/format.dart';
import 'container_painter.dart';
import 'online_dot.dart';

/// Battery icon + color for a given battery percentage, mirroring the
/// threshold logic in frontend/js/devices.js's createContainerCard.
class BatteryVisual {
  final IconData icon;
  final Color color;

  const BatteryVisual({required this.icon, required this.color});

  factory BatteryVisual.fromLevel(double battery) {
    if (battery <= 15) {
      return const BatteryVisual(icon: Icons.battery_alert, color: Color(0xFFEF4444));
    } else if (battery <= 40) {
      return const BatteryVisual(icon: Icons.battery_2_bar, color: Color(0xFFF59E0B));
    } else if (battery <= 70) {
      return BatteryVisual(icon: Icons.battery_4_bar, color: Colors.grey.shade600);
    }
    return const BatteryVisual(icon: Icons.battery_full, color: Color(0xFF059669));
  }
}

/// Capacity/fillPct/markerPct/isLow math, ported 1:1 from
/// `createContainerCard` in frontend/js/devices.js. Kept as a plain
/// value class (no BuildContext/Canvas) so it's independently testable.
class ContainerVisualParams {
  final double fillPct;
  final double? markerPct;
  final bool isLow;

  const ContainerVisualParams({
    required this.fillPct,
    required this.markerPct,
    required this.isLow,
  });

  factory ContainerVisualParams.fromDevice(Device device) {
    final current = device.currentQuantity;
    final reorderLevel = device.reorderLevel;
    final reorderQuantity = device.reorderQuantity;

    double capacity;
    if (reorderLevel != null && reorderQuantity != null) {
      capacity = reorderLevel + reorderQuantity;
    } else if (reorderLevel != null) {
      capacity = reorderLevel * 2;
    } else {
      capacity = math.max(current ?? 0, 100).toDouble();
    }
    if (current != null && current > capacity) {
      capacity = current;
    }

    final fillPct = current != null ? (current / capacity) * 100 : 0.0;
    final markerPct = reorderLevel != null ? (reorderLevel / capacity) * 100 : null;
    final isLow = reorderLevel != null && current != null && current < reorderLevel;

    return ContainerVisualParams(fillPct: fillPct, markerPct: markerPct, isLow: isLow);
  }
}

class ContainerCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const ContainerCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final params = ContainerVisualParams.fromDevice(device);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final current = device.currentQuantity;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    width: 96,
                    height: 140,
                    child: CustomPaint(
                      painter: ContainerPainter(
                        fillPct: params.fillPct,
                        markerPct: params.markerPct,
                        isLow: params.isLow,
                        emptyColor: emptyColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    device.deviceName,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    device.deviceType,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  current != null
                      ? Text(
                          '${current.toStringAsFixed(0)}g',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: params.isLow ? const Color(0xFFDC2626) : null,
                          ),
                        )
                      : Text('No readings yet', style: TextStyle(color: Colors.grey.shade500)),
                  if (device.reorderLevel != null)
                    Text(
                      'Reorder below ${device.reorderLevel!.toStringAsFixed(0)}g',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OnlineDot(isOnline: device.isOnline),
                      const SizedBox(width: 6),
                      Text(
                        device.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: device.isOnline ? const Color(0xFF059669) : Colors.grey.shade500,
                        ),
                      ),
                      if (device.batteryLevel != null) ...[
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Battery level',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                BatteryVisual.fromLevel(device.batteryLevel!).icon,
                                size: 14,
                                color: BatteryVisual.fromLevel(device.batteryLevel!).color,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${device.batteryLevel!.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: BatteryVisual.fromLevel(device.batteryLevel!).color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last reading: ${formatTimestamp(device.currentQuantityUpdatedAt)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              Positioned(
                top: -4,
                right: -4,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey.shade400,
                  onPressed: onDelete,
                  tooltip: 'Delete device',
                ),
              ),
              if (params.isLow)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Low',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
