import '../config/api_config.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  /// Send OTP to phone number
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return _api.post(ApiConfig.sendOtp, body: {'phone': phone});
  }

  /// Verify OTP code
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    return _api.post(ApiConfig.verifyOtp, body: {'phone': phone, 'code': code});
  }

  /// Register new user after OTP verification
  Future<Map<String, dynamic>> register(String phone, String name, {String? email}) async {
    return _api.post(ApiConfig.register, body: {
      'phone': phone,
      'name': name,
      'email': email,
    });
  }

  /// Set access token for subsequent requests
  void setToken(String? token) {
    _api.setAccessToken(token);
  }

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
}