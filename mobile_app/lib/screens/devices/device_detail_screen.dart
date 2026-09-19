import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/device.dart';
import '../../providers/cart_provider.dart';
import '../../services/device_service.dart';
import '../../services/reading_service.dart';
import '../../utils/format.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/loading_error_view.dart';

class DeviceDetailScreen extends StatefulWidget {
  final String deviceId;

  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  Device? _device;
  bool _isLoading = true;
  String? _error;
  final _readingController = TextEditingController();
  bool _isSendingReading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _readingController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final device = await context.read<DeviceService>().detail(widget.deviceId);
      if (!mounted) return;
      setState(() => _device = device);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load device details');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestReading() async {
    final value = double.tryParse(_readingController.text);
    if (value == null || value < 0) {
      showAppToast(context, 'Enter a valid non-negative reading value', isError: true);
      return;
    }

    setState(() => _isSendingReading = true);
    try {
      await context.read<ReadingService>().sendReading(deviceId: widget.deviceId, readingValue: value);
      if (!mounted) return;
      showAppToast(context, 'Reading $value sent successfully!');
      _readingController.clear();
      await Future.wait([_load(), context.read<CartProvider>().load()]);
    } catch (_) {
      if (!mounted) return;
      showAppToast(context, 'Failed to send reading', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingReading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_device?.deviceName ?? 'Device')),
      body: LoadingErrorView(
        isLoading: _isLoading,
        error: _error,
        onRetry: _load,
        child: _device == null ? const SizedBox.shrink() : _buildContent(_device!),
      ),
    );
  }

  Widget _buildContent(Device device) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Status', value: device.isOnline ? 'Online' : 'Offline'),
                _DetailRow(label: 'Firmware', value: device.firmwareVer ?? 'N/A'),
                _DetailRow(label: 'MQTT Topic', value: device.mqttTopic ?? 'N/A'),
                _DetailRow(label: 'Device ID', value: device.deviceId, isMono: true),
                _DetailRow(
                  label: 'Reorder Level',
                  value: device.reorderLevel?.toStringAsFixed(0) ?? 'Not set',
                ),
                _DetailRow(
                  label: 'Reorder Quantity',
                  value: device.reorderQuantity?.toStringAsFixed(0) ?? 'Not set',
                ),
                _DetailRow(
                  label: 'Current Quantity',
                  value: device.currentQuantity != null
                      ? '${device.currentQuantity!.toStringAsFixed(0)}g'
                      : 'No data',
                ),
                _DetailRow(
                  label: 'Battery Level',
                  value: device.batteryLevel != null
                      ? '${device.batteryLevel!.toStringAsFixed(0)}%'
                      : 'N/A',
                ),
                _DetailRow(
                  label: 'Last Reading',
                  value: formatTimestamp(device.currentQuantityUpdatedAt),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFFFFBEB),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Send Test Reading', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Reorder level: ${device.reorderLevel?.toStringAsFixed(0) ?? 'not set'}. '
                  'Submitting a value below it will add an item to your Cart.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _readingController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'e.g. 50',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSendingReading ? null : _sendTestReading,
                      child: _isSendingReading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (device.latestTelemetry != null && device.latestTelemetry!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Recent Readings', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...device.latestTelemetry!.take(10).map(
                (t) => ListTile(
                  dense: true,
                  title: Text(t.sensorType),
                  trailing: Text('${t.value.toStringAsFixed(2)} ${t.unit}'),
                  subtitle: Text(t.recordedAt),
                ),
              ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _DetailRow({required this.label, required this.value, this.isMono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey.shade600))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontFamily: isMono ? 'monospace' : null, fontSize: isMono ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }
}
