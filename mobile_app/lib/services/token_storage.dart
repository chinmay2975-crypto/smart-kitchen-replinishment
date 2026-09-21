import 'package:flutter/services.dart' show PlatformException;
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

  // Android's Keystore-backed encryption key can become invalidated while
  // the previously-encrypted value stays behind (observed after reinstalling
  // over an older build) — every read then throws a PlatformException
  // wrapping BadPaddingException/BAD_DECRYPT. That data is unrecoverable
  // either way, so treat it as "no session" and wipe it rather than
  // surfacing a crash on every request that touches storage (including
  // login, since the request interceptor reads the token unconditionally).
  Future<String?> _readSafely(String key) async {
    try {
      return await _storage.read(key: key).timeout(
            _storageTimeout,
            onTimeout: () => throw SecureStorageTimeoutException(),
          );
    } on PlatformException {
      await _storage.deleteAll();
      return null;
    }
  }

  Future<String?> get accessToken => _readSafely(_accessTokenKey);
  Future<String?> get refreshToken => _readSafely(_refreshTokenKey);

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
