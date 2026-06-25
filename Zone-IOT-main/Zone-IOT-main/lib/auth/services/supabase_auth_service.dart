import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// SIGN UP (EMAIL + PASSWORD)
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signUp(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Signup failed");
    }
  }

  /// SIGN IN (EMAIL + PASSWORD)
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception("Login failed");
    }
  }

  /// LOGOUT
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// CURRENT USER
  User? get currentUser => _client.auth.currentUser;

  /// CURRENT SESSION
  Session? get currentSession => _client.auth.currentSession;

  /// AUTH STATE STREAM
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
