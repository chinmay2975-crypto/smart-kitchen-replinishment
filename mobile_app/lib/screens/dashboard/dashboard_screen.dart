import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/cart_item.dart';
import '../../models/device.dart';
import '../../providers/cart_provider.dart';
import '../../providers/devices_provider.dart';
import '../../services/demo_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/container_card.dart';
import '../../widgets/loading_error_view.dart';
import '../../widgets/summary_card.dart';
import '../devices/device_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isGeneratingDemo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    await Future.wait([
      context.read<DevicesProvider>().load(),
      context.read<CartProvider>().load(),
    ]);
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
    showAppToast(context, error ?? 'Device "$deviceName" deleted', isError: error != null);
  }

  Future<void> _generateDemoData() async {
    setState(() => _isGeneratingDemo = true);
    try {
      await context.read<DemoService>().generate();
      if (!mounted) return;
      showAppToast(context, 'Demo data generated successfully');
      await _loadAll();
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, 'Failed to generate demo data', isError: true);
    } finally {
      if (mounted) setState(() => _isGeneratingDemo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Dashboard')),
      body: Consumer2<DevicesProvider, CartProvider>(
        builder: (context, devicesProvider, cartProvider, _) {
          return LoadingErrorView(
            isLoading: devicesProvider.isLoading && devicesProvider.devices.isEmpty,
            error: devicesProvider.error,
            onRetry: _loadAll,
            child: RefreshIndicator(
              onRefresh: _loadAll,
              child: _buildBody(devicesProvider.devices, cartProvider.items),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(List<Device> devices, List<CartItem> cartItems) {
    final lowStock = devices.where(
      (d) => d.reorderLevel != null && d.currentQuantity != null && d.currentQuantity! < d.reorderLevel!,
    ).length;
    final outOfStock = devices.where((d) => d.currentQuantity == 0).length;
    final activeOrders = cartItems
        .where((i) => i.status == CartItemStatus.placed || i.status == CartItemStatus.delivered)
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            SummaryCard(label: 'Total Items', value: devices.length, accentColor: const Color(0xFF10B981)),
            SummaryCard(label: 'Low Stock', value: lowStock, accentColor: const Color(0xFFF59E0B)),
            SummaryCard(label: 'Out of Stock', value: outOfStock, accentColor: const Color(0xFFEF4444)),
            SummaryCard(label: 'Active Orders', value: activeOrders, accentColor: const Color(0xFF3B82F6)),
          ],
        ),
        const SizedBox(height: 24),
        Text('Current Inventory', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        devices.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    const Text('No Containers Yet', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Claim a device from the My Devices tab, or generate demo data',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: _isGeneratingDemo
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Generate Demo Data'),
                      onPressed: _isGeneratingDemo ? null : _generateDemoData,
                    ),
                  ],
                ),
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ContainerCard(
                    device: device,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DeviceDetailScreen(deviceId: device.deviceId)),
                    ),
                    onDelete: () => _handleDelete(device.deviceId, device.deviceName),
                  );
                },
              ),
      ],
    );
  }
}
