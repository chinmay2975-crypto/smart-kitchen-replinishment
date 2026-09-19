import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thrown when a secure-storage platform-channel call (Android Keystore /
/// iOS Keychain) doesn't respond within [_storageTimeout] — this has been
/// observed to hang indefinitely on some devices with no error surfaced,
/// unlike a network call which at least has an HTTP timeout.
class SecureStorageTimeoutException implements Exception {
  @override
  String toString() => 'Secure storage did not respond in time';
}

const _storageTimeout = Duration(seconds: 10);

class TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  final FlutterSecureStorage _storage;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<String?> get accessToken => _storage
      .read(key: _accessTokenKey)
      .timeout(_storageTimeout, onTimeout: () => throw SecureStorageTimeoutException());
  Future<String?> get refreshToken => _storage
      .read(key: _refreshTokenKey)
      .timeout(_storageTimeout, onTimeout: () => throw SecureStorageTimeoutException());

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Run both writes concurrently rather than sequentially — each is a
    // separate Keystore-backed platform-channel call, so awaiting them one
    // at a time roughly doubles the latency for no benefit.
    await Future.wait([
      _storage
          .write(key: _accessTokenKey, value: accessToken)
          .timeout(_storageTimeout, onTimeout: () => throw SecureStorageTimeoutException()),
      _storage
          .write(key: _refreshTokenKey, value: refreshToken)
          .timeout(_storageTimeout, onTimeout: () => throw SecureStorageTimeoutException()),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<bool> hasSession() async {
    final token = await accessToken;
    return token != null && token.isNotEmpty;
  }
}
