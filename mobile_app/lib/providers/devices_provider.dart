import 'package:flutter/foundation.dart';

import '../models/device.dart';
import '../services/device_service.dart';

class DevicesProvider extends ChangeNotifier {
  final DeviceService deviceService;

  DevicesProvider({required this.deviceService});

  List<Device> devices = [];
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      devices = await deviceService.list();
    } catch (_) {
      error = 'Failed to load devices';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> claim({
    required String deviceUid,
    required String deviceName,
    double? reorderLevel,
    double? reorderQuantity,
  }) async {
    try {
      await deviceService.claim(
        deviceUid: deviceUid,
        deviceName: deviceName,
        reorderLevel: reorderLevel,
        reorderQuantity: reorderQuantity,
      );
      await load();
      return null;
    } catch (_) {
      return 'Failed to claim device';
    }
  }

  Future<String?> delete(String deviceId) async {
    try {
      await deviceService.delete(deviceId);
      devices = devices.where((d) => d.deviceId != deviceId).toList();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Failed to delete device';
    }
  }
}
