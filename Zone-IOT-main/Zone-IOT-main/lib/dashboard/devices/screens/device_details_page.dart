import 'package:flutter/material.dart';
import '../repository/device_repository.dart';

class DeviceDetailsPage extends StatefulWidget {
  final int deviceId;

  const DeviceDetailsPage({super.key, required this.deviceId});

  @override
  State<DeviceDetailsPage> createState() => _DeviceDetailsPageState();
}

class _DeviceDetailsPageState extends State<DeviceDetailsPage> {
  final DeviceRepository _repo = DeviceRepository();

  // Device (provisioned_devices)
  late TextEditingController deviceNameController;

  // Telemetry (READ ONLY)
  late TextEditingController currentLevelController;

  // Device config
  late TextEditingController medicineController;
  late TextEditingController reorderLevelController;
  late TextEditingController reorderQtyController;

  // Address (addresses table)
  late TextEditingController addressController;
  late TextEditingController cityController;
  late TextEditingController stateController;
  late TextEditingController pincodeController;

  bool _loading = true;
  int? _addressId;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadData();
  }

  void _initControllers() {
    deviceNameController = TextEditingController();
    currentLevelController = TextEditingController();

    medicineController = TextEditingController();
    reorderLevelController = TextEditingController();
    reorderQtyController = TextEditingController();

    addressController = TextEditingController();
    cityController = TextEditingController();
    stateController = TextEditingController();
    pincodeController = TextEditingController();
  }

  /* --------------------------------------------------
     LOAD DEVICE + TELEMETRY + CONFIG + ADDRESS
  -------------------------------------------------- */
  Future<void> _loadData() async {
    try {
      // 1️⃣ Device (name from provisioned_devices)
      final device = await _repo.getDeviceById(widget.deviceId);
      deviceNameController.text = device['name'] ?? '';

      // 2️⃣ Telemetry (SOURCE OF TRUTH)
      final payload = await _repo.getLatestPayload(widget.deviceId);
      currentLevelController.text = payload == null
          ? 'N/A'
          : payload.round().toString();

      // 3️⃣ Device config
      final config = await _repo.getDeviceConfig(widget.deviceId);
      medicineController.text = config?['medicine_name'] ?? '';
      reorderLevelController.text = (config?['reorder_level'] ?? '').toString();
      reorderQtyController.text = (config?['reorder_quantity'] ?? '')
          .toString();

      _addressId = config?['address'];

      // 4️⃣ Address (optional)
      if (_addressId != null) {
        final address = await _repo.getAddress(_addressId!);
        if (address != null) {
          addressController.text = address['address'] ?? '';
          cityController.text = address['city'] ?? '';
          stateController.text = address['state'] ?? '';
          pincodeController.text = address['pincode']?.toString() ?? '';
        }
      }
    } catch (e) {
      _showError(e.toString());
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /* --------------------------------------------------
     SAVE (DEVICE NAME + CONFIG + ADDRESS)
  -------------------------------------------------- */
  Future<void> _save() async {
    final reorderLevel = int.tryParse(reorderLevelController.text);
    final reorderQty = int.tryParse(reorderQtyController.text);
    final pincode = pincodeController.text.isEmpty
        ? null
        : int.tryParse(pincodeController.text);

    if (deviceNameController.text.trim().isEmpty) {
      _showError('Device name cannot be empty');
      return;
    }

    if (reorderLevel == null || reorderLevel < 0 || reorderLevel > 100) {
      _showError('Reorder level must be between 0 and 100');
      return;
    }

    if (reorderQty == null || reorderQty <= 0) {
      _showError('Reorder quantity must be greater than 0');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1️⃣ Update device name (provisioned_devices)
      await _repo.updateProvisionedDeviceName(
        deviceId: widget.deviceId,
        name: deviceNameController.text.trim(),
      );

      int? addressId;

      // 2️⃣ Address (optional)
      if (addressController.text.isNotEmpty ||
          cityController.text.isNotEmpty ||
          stateController.text.isNotEmpty ||
          pincode != null) {
        if (addressController.text.isEmpty ||
            cityController.text.isEmpty ||
            stateController.text.isEmpty ||
            pincode == null) {
          throw Exception('Please complete the delivery address');
        }

        addressId = await _repo.upsertAddress(
          id: _addressId,
          address: addressController.text.trim(),
          city: cityController.text.trim(),
          state: stateController.text.trim(),
          pincode: pincode,
        );
      }

      // 3️⃣ Device config
      await _repo.upsertDeviceConfig(
        deviceId: widget.deviceId,
        medicineName: medicineController.text.trim(),
        reorderLevel: reorderLevel,
        reorderQuantity: reorderQty,
        addressId: addressId,
      );

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
    deviceNameController.dispose();
    currentLevelController.dispose();
    medicineController.dispose();
    reorderLevelController.dispose();
    reorderQtyController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  /* --------------------------------------------------
     UI
  -------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Device Configuration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _inputField('Device Name', deviceNameController),
            const SizedBox(height: 16),
            _inputField(
              'Current Level (from device)',
              currentLevelController,
              enabled: false,
            ),

            const SizedBox(height: 24),
            const Text(
              'Replenishment Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _inputField('Medicine Name', medicineController),
            const SizedBox(height: 16),
            _inputField(
              'Reorder Level (%)',
              reorderLevelController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _inputField(
              'Reorder Quantity',
              reorderQtyController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 24),
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _inputField('Address', addressController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _inputField('City', cityController)),
                const SizedBox(width: 12),
                Expanded(child: _inputField('State', stateController)),
              ],
            ),
            const SizedBox(height: 16),
            _inputField(
              'Pincode',
              pincodeController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
