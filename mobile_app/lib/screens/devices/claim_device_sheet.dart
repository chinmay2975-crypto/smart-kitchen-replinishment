import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/devices_provider.dart';
import '../../widgets/app_toast.dart';

Future<void> showClaimDeviceSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ClaimDeviceSheet(),
  );
}

class ClaimDeviceSheet extends StatefulWidget {
  const ClaimDeviceSheet({super.key});

  @override
  State<ClaimDeviceSheet> createState() => _ClaimDeviceSheetState();
}

class _ClaimDeviceSheetState extends State<ClaimDeviceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _uidController = TextEditingController();
  final _nameController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _reorderQuantityController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _reorderLevelController.dispose();
    _reorderQuantityController.dispose();
    super.dispose();
  }

  Future<void> _handleClaim() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    // Empty inputs parse as null, matching handleClaimDevice in devices.js.
    final reorderLevel =
        _reorderLevelController.text.isNotEmpty ? double.tryParse(_reorderLevelController.text) : null;
    final reorderQuantity = _reorderQuantityController.text.isNotEmpty
        ? double.tryParse(_reorderQuantityController.text)
        : null;

    final error = await context.read<DevicesProvider>().claim(
          deviceUid: _uidController.text.trim(),
          deviceName: _nameController.text.trim(),
          reorderLevel: reorderLevel,
          reorderQuantity: reorderQuantity,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (error == null) {
      Navigator.of(context).pop();
      showAppToast(context, 'Device "${_nameController.text}" claimed successfully!');
    } else {
      showAppToast(context, error, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Claim a Device', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'Device UID / MAC Address',
                hintText: 'e.g. kitchen/pantry/scale_001',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Device Name',
                hintText: 'e.g. Pantry Scale',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _reorderLevelController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Reorder Level',
                      hintText: 'e.g. 100',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _reorderQuantityController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Reorder Quantity',
                      hintText: 'e.g. 5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _isSubmitting ? null : _handleClaim,
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Claim'),
            ),
          ],
        ),
      ),
    );
  }
}
