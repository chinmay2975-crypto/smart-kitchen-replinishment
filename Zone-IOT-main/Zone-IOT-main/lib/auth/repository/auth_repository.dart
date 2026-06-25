import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /* --------------------------------------------------
     SIGN UP
  -------------------------------------------------- */
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String name,
    required String surname,
    required String address,
    required String city,
    required String state,
    required int pincode,
    required String phone,
  }) async {
    final res = await _client.auth.signUp(email: email, password: password);

    final user = res.user;
    if (user == null) {
      throw Exception('Signup failed');
    }

    final addressRow = await _client
        .from('addresses')
        .insert({
          'user_id': user.id,
          'address': address,
          'city': city,
          'state': state,
          'pincode': pincode,
        })
        .select('id')
        .single();

    await _client.from('profiles').insert({
      'id': user.id,
      'name': name,
      'surname': surname,
      'phone': phone,
      'address': addressRow['id'],
    });
  }

  /* --------------------------------------------------
     SIGN IN
  -------------------------------------------------- */
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /* --------------------------------------------------
     CHANGE PASSWORD
  -------------------------------------------------- */
  Future<void> updatePassword({required String newPassword}) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /* --------------------------------------------------
     SESSION
  -------------------------------------------------- */
  User? get currentUser => _client.auth.currentUser;

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
