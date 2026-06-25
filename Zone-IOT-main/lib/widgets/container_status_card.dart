import 'package:flutter/material.dart';
import '../models/container.dart';

class ContainerStatusCard extends StatelessWidget {
  final Container container;

  const ContainerStatusCard({super.key, required this.container});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = container.lastPercent ?? 0;
    final isLow = percent < 20;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: isLow ? Colors.orange : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    container.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (container.deviceStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: container.deviceStatus == 'active'
                          ? Colors.green[50]
                          : Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      container.deviceStatus ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        color: container.deviceStatus == 'active'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isLow ? Colors.orange : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${percent.toStringAsFixed(1)}% remaining',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isLow ? Colors.orange : Colors.grey[700],
                  ),
                ),
                if (container.lastWeight != null)
                  Text(
                    '${container.lastWeight!.toStringAsFixed(2)} kg',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
              ],
            ),
            if (container.lastReadAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last updated: ${_formatDate(container.lastReadAt!)}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
            if (container.macAddress != null) ...[
              const SizedBox(height: 4),
              Text(
                'Device: ${container.macAddress}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return dateStr;
    }
  }
}