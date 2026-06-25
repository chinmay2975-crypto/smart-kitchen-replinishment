import 'package:flutter/material.dart';
import '../widgets/device_container_tile.dart';
import '../repository/device_repository.dart';
import 'device_details_page.dart';
import 'add_device_page.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final DeviceRepository _repo = DeviceRepository();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final data = await _repo.getDevices();

      if (mounted) {
        setState(() {
          _devices = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              "Your Devices",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.65,
                        ),
                    itemCount: _devices.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _devices.length) {
                        return _buildAddDeviceTile(context);
                      }

                      final device = _devices[index];
                      final deviceId = device['id'] as int;

                      return FutureBuilder<num?>(
                        future: _repo.getLatestPayload(deviceId),
                        builder: (context, snapshot) {
                          final payload = snapshot.data;
                          final level = payload?.round() ?? 0;

                          return DeviceContainerTile(
                            deviceName: device['name'] ?? 'Unnamed Device',
                            levelPercent: level,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DeviceDetailsPage(deviceId: deviceId),
                                ),
                              );
                              _loadDevices();
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddDeviceTile(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDevicePage()),
        );

        if (result == true) {
          _loadDevices();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black26, width: 1.5),
          boxShadow: const [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.add_circle_outline, size: 56, color: Colors.black54),
            SizedBox(height: 12),
            Text(
              "Add New Device",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
