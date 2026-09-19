import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import '../models/auth_response.dart';
import 'token_storage.dart';

/// Shared Dio instance with auth-header injection and a one-time 401
/// refresh-and-retry, mirroring frontend/js/api.js's request()/
/// refreshAccessToken() logic.
class ApiClient {
  final TokenStorage tokenStorage;
  final VoidCallback? onAuthExpired;
  late final Dio dio;

  // Serializes concurrent refreshes so simultaneous 401s don't each kick off
  // their own /auth/refresh call.
  Future<bool>? _refreshFuture;

  ApiClient({required this.tokenStorage, this.onAuthExpired}) {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ));

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (DioException err, handler) async {
          final path = err.requestOptions.path;
          final isAuthEndpoint = path.contains('/auth/login') ||
              path.contains('/auth/register') ||
              path.contains('/auth/refresh');

          if (err.response?.statusCode == 401 && !isAuthEndpoint) {
            final refreshed = await _refresh();
            if (refreshed) {
              try {
                final newToken = await tokenStorage.accessToken;
                final opts = err.requestOptions;
                opts.headers['Authorization'] = 'Bearer $newToken';
                final retried = await dio.fetch(opts);
                return handler.resolve(retried);
              } catch (_) {
                // fall through to reject with the original error
              }
            } else {
              await tokenStorage.clear();
              onAuthExpired?.call();
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  Future<bool> _refresh() {
    // If a refresh is already in flight, piggyback on it instead of firing
    // a second concurrent /auth/refresh call.
    _refreshFuture ??= _doRefresh().whenComplete(() => _refreshFuture = null);
    return _refreshFuture!;
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await tokenStorage.refreshToken;
    if (refreshToken == null) return false;

    try {
      // Plain, non-intercepted request — refresh doesn't need a Bearer header
      // and must not recurse through this same interceptor.
      final plainDio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));
      final response = await plainDio.post(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final result = RefreshResponse.fromJson(response.data as Map<String, dynamic>);
      await tokenStorage.saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
