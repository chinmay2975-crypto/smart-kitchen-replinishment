import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService authService;
  final TokenStorage tokenStorage;

  AuthStatus status = AuthStatus.unknown;
  String? userName;
  String? userEmail;

  AuthProvider({required this.authService, required this.tokenStorage});

  bool get isAuthenticated => status == AuthStatus.authenticated;

  Future<void> bootstrap() async {
    try {
      final hasSession = await tokenStorage.hasSession();
      status = hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    } catch (_) {
      // If secure storage can't be read at startup, fail safe to the
      // logged-out state rather than hanging the splash screen forever.
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final result = await authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      await _onAuthSuccess(result.accessToken, result.refreshToken, result.name, result.email);
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (e) {
      // Catch-all so a parsing/unexpected error always surfaces as a
      // message instead of leaving the caller's Future unresolved (which
      // would strand the UI in its loading state with no feedback). Includes
      // the exception detail temporarily to help diagnose real-device
      // issues that can't be reproduced from this environment.
      return 'Something went wrong: $e';
    }
  }

  Future<String?> login({required String email, required String password}) async {
    try {
      final result = await authService.login(email: email, password: password);
      await _onAuthSuccess(result.accessToken, result.refreshToken, result.name, result.email);
      return null;
    } on DioException catch (e) {
      return _extractError(e);
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  Future<void> _onAuthSuccess(
    String accessToken,
    String refreshToken,
    String? name,
    String email,
  ) async {
    await tokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    userName = name;
    userEmail = email;
    status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> logout() async {
    await tokenStorage.clear();
    userName = null;
    userEmail = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'Unable to reach the server. Please check your internet connection.';
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Please try again.';
      case DioExceptionType.sendTimeout:
        return 'Sending the request timed out. Please try again.';
      case DioExceptionType.badCertificate:
        return 'Could not verify the server\'s security certificate.';
      default:
        // Temporary: include the raw type/message to help diagnose
        // real-device failures that can't be reproduced from this
        // environment.
        return 'Something went wrong (${e.type.name}): ${e.message ?? e.error}';
    }
  }
}
