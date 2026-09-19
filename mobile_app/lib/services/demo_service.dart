import 'package:dio/dio.dart';

class DemoService {
  final Dio dio;

  DemoService(this.dio);

  Future<void> generate({bool force = false}) async {
    await dio.post('/api/v1/demo/generate', queryParameters: {'force': force});
  }
}
