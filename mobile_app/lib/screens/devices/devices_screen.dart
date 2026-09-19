import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/devices_provider.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/container_card.dart';
import '../../widgets/loading_error_view.dart';
import 'claim_device_sheet.dart';
import 'device_detail_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DevicesProvider>().load();
    });
  }

  Future<void> _handleDelete(String deviceId, String deviceName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete device?'),
        content: Text('Delete device "$deviceName"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await context.read<DevicesProvider>().delete(deviceId);
    if (!mounted) return;
    if (error == null) {
      showAppToast(context, 'Device "$deviceName" deleted');
    } else {
      showAppToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => showClaimDeviceSheet(context),
          ),
        ],
      ),
      body: Consumer<DevicesProvider>(
        builder: (context, devicesProvider, _) {
          return LoadingErrorView(
            isLoading: devicesProvider.isLoading,
            error: devicesProvider.error,
            onRetry: () => devicesProvider.load(),
            child: RefreshIndicator(
              onRefresh: () => devicesProvider.load(),
              child: devicesProvider.devices.isEmpty
                  ? EmptyStateView(
                      emoji: '📡',
                      title: 'No Devices Yet',
                      message: 'Claim a device to start monitoring your kitchen inventory',
                      action: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Claim Your First Device'),
                        onPressed: () => showClaimDeviceSheet(context),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: devicesProvider.devices.length,
                      itemBuilder: (context, index) {
                        final device = devicesProvider.devices[index];
                        return ContainerCard(
                          device: device,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeviceDetailScreen(deviceId: device.deviceId),
                            ),
                          ),
                          onDelete: () => _handleDelete(device.deviceId, device.deviceName),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
