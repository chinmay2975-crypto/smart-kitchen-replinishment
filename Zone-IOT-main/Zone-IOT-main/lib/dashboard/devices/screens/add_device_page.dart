import 'package:flutter/material.dart';
import '../repository/device_repository.dart';

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  final DeviceRepository _repo = DeviceRepository();

  final TextEditingController uidController = TextEditingController();
  final TextEditingController nameController = TextEditingController();

  bool _loading = false;

  /* --------------------------------------------------
     FORM VALIDITY
  -------------------------------------------------- */
  bool get _canSubmit {
    final uid = uidController.text.trim();
    final name = nameController.text.trim();
    return uid.isNotEmpty && name.isNotEmpty;
  }

  /* --------------------------------------------------
     CLAIM DEVICE ONLY
  -------------------------------------------------- */
  Future<void> _save() async {
    if (_loading) return;

    final uid = uidController.text.trim();
    final name = nameController.text.trim();

    if (uid.isEmpty) {
      _showError('Device UID is required');
      return;
    }

    if (name.isEmpty) {
      _showError('Device name is required');
      return;
    }

    setState(() => _loading = true);

    try {
      // Claim device + save user-visible name
      await _repo.claimDevice(deviceUid: uid, deviceName: name);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    uidController.dispose();
    nameController.dispose();
    super.dispose();
  }

  /* --------------------------------------------------
     UI
  -------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Device')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: uidController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Device UID',
                hintText: 'ESP32-ABC-001',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Device Name'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_loading || !_canSubmit) ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Claim Device'),
            ),
          ],
        ),
      ),
    );
  }
}
