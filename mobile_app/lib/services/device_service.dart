import 'package:dio/dio.dart';

import '../models/device.dart';
import '../models/telemetry_reading.dart';

class DeviceService {
  final Dio dio;

  DeviceService(this.dio);

  Future<List<Device>> list() async {
    final response = await dio.get('/api/v1/devices/');
    return (response.data as List<dynamic>)
        .map((e) => Device.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Device> detail(String deviceId) async {
    final response = await dio.get('/api/v1/devices/$deviceId');
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Device> claim({
    required String deviceUid,
    required String deviceName,
    double? reorderLevel,
    double? reorderQuantity,
  }) async {
    final response = await dio.post('/api/v1/devices/claim', data: {
      'device_uid': deviceUid,
      'device_name': deviceName,
      'reorder_level': reorderLevel,
      'reorder_quantity': reorderQuantity,
    });
    return Device.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String deviceId) async {
    await dio.delete('/api/v1/devices/$deviceId');
  }

  Future<TelemetryResult> telemetry(String deviceId, {int limit = 50}) async {
    final response = await dio.get(
      '/api/v1/devices/$deviceId/telemetry',
      queryParameters: {'limit': limit},
    );
    return TelemetryResult.fromJson(response.data as Map<String, dynamic>);
  }
}
