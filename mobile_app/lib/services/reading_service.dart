import 'package:dio/dio.dart';

class ReadingService {
  final Dio dio;

  ReadingService(this.dio);

  /// Note: this is `/api/v1/device/reading` (singular "device"), a distinct
  /// path prefix from the `/api/v1/devices/...` routes — kept as a literal
  /// here rather than derived from DeviceService's base path.
  Future<void> sendReading({
    required String deviceId,
    required double readingValue,
  }) async {
    await dio.post('/api/v1/device/reading', data: {
      'device_id': deviceId,
      'reading_value': readingValue,
    });
  }
}
