import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;
  String? _pendingPhone;

  User? get user => _user;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null && _accessToken != null;
  String? get error => _error;
  String? get pendingPhone => _pendingPhone;

  /// Send OTP to phone
  Future<bool> sendOtp(String phone) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.sendOtp(phone);
      if (response['status'] == 'Success') {
        _pendingPhone = phone;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to send OTP';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify OTP and login
  Future<Map<String, dynamic>> verifyOtp(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.verifyOtp(_pendingPhone!, code);
      
      if (response['status'] == 'Success') {
        if (response['is_new_user'] == true) {
          _isLoading = false;
          notifyListeners();
          return {'is_new_user': true, 'phone': _pendingPhone};
        }
        
        _user = User.fromJson(response['user']);
        _accessToken = response['access_token'];
        _refreshToken = response['refresh_token'];
        _authService.setToken(_accessToken);
        _pendingPhone = null;
        _isLoading = false;
        notifyListeners();
        return {'is_new_user': false, 'success': true};
      } else {
        _error = response['message'] ?? 'Invalid OTP';
        _isLoading = false;
        notifyListeners();
        return {'error': _error};
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return {'error': _error};
    }
  }

  /// Register new user
  Future<bool> register(String name, {String? email}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.register(
        _pendingPhone!,
        name,
        email: email,
      );

      if (response['status'] == 'Success') {
        _user = User.fromJson(response['user']);
        _accessToken = response['access_token'];
        _refreshToken = response['refresh_token'];
        _authService.setToken(_accessToken);
        _pendingPhone = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _user = null;
    _accessToken = null;
    _refreshToken = null;
    _pendingPhone = null;
    _error = null;
    _authService.setToken(null);
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}