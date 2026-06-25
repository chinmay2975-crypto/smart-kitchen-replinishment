import 'package:flutter/material.dart';
import '../repository/profile_repository.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic> profile;

  const EditProfilePage({super.key, required this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController nameController;
  late final TextEditingController surnameController;
  late final TextEditingController phoneController;

  // Address
  late final TextEditingController addressController;
  late final TextEditingController cityController;
  late final TextEditingController stateController;
  late final TextEditingController pincodeController;

  final ProfileRepository repo = ProfileRepository();

  bool loading = false;
  int? addressId;

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(text: widget.profile['name'] ?? '');
    surnameController = TextEditingController(
      text: widget.profile['surname'] ?? '',
    );
    phoneController = TextEditingController(
      text: widget.profile['phone'] ?? '',
    );

    addressController = TextEditingController();
    cityController = TextEditingController();
    stateController = TextEditingController();
    pincodeController = TextEditingController();

    // IMPORTANT: address is INT FK
    addressId = widget.profile['address'];

    // Fetch existing address if present
    if (addressId != null) {
      _loadAddress(addressId!);
    }
  }

  Future<void> _loadAddress(int id) async {
    try {
      final address = await repo.getAddressById(id);
      if (address == null) return;

      addressController.text = address['address'] ?? '';
      cityController.text = address['city'] ?? '';
      stateController.text = address['state'] ?? '';
      pincodeController.text = address['pincode']?.toString() ?? '';
    } catch (_) {
      // Silent fail — user can still enter manually
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    surnameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    cityController.dispose();
    stateController.dispose();
    pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _field("Name", nameController),
            _field("Surname", surnameController),
            _field("Phone", phoneController),

            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Address",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),

            _field("Address", addressController),
            Row(
              children: [
                Expanded(child: _field("City", cityController)),
                const SizedBox(width: 12),
                Expanded(child: _field("State", stateController)),
              ],
            ),
            _field(
              "Pincode",
              pincodeController,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _save,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Future<void> _save() async {
    final pincode = int.tryParse(pincodeController.text);

    if (nameController.text.isEmpty ||
        surnameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        addressController.text.isEmpty ||
        cityController.text.isEmpty ||
        stateController.text.isEmpty ||
        pincode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all fields")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await repo.updateProfile(
        name: nameController.text.trim(),
        surname: surnameController.text.trim(),
        phone: phoneController.text.trim(),
      );

      final newAddressId = await repo.upsertAddress(
        id: addressId,
        address: addressController.text.trim(),
        city: cityController.text.trim(),
        state: stateController.text.trim(),
        pincode: pincode,
      );

      // Link profile to address ONLY if it was missing
      if (addressId == null) {
        await repo.updateProfileAddress(newAddressId);
      }

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => loading = false);
    }
  }
}
