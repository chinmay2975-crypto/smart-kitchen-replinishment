class ApiConfig {
  // Change this to your backend server URL
  static const String baseUrl = 'http://192.168.1.100:3000';
  
  // API Endpoints
  static const String sendOtp = '$baseUrl/api/auth/send-otp';
  static const String verifyOtp = '$baseUrl/api/auth/verify-otp';
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String refreshToken = '$baseUrl/api/auth/refresh';
  static const String kitchens = '$baseUrl/api/kitchens';
  static const String containers = '$baseUrl/api/containers';
  static const String items = '$baseUrl/api/items';
  static const String skuMappings = '$baseUrl/api/sku-mappings';
  static const String orders = '$baseUrl/api/orders';
  static const String cart = '$baseUrl/api/cart';
  static const String health = '$baseUrl/health';
  
  // Timeouts
  static const Duration requestTimeout = Duration(seconds: 30);
}