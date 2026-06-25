import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _client = Supabase.instance.client;

  /* --------------------------------------------------
     HELPERS
  -------------------------------------------------- */
  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  /* --------------------------------------------------
     UPDATE PROFILE (NO ADDRESS HERE)
  -------------------------------------------------- */
  Future<void> updateProfile({
    required String name,
    required String surname,
    required String phone,
  }) async {
    await _client
        .from('profiles')
        .update({'name': name, 'surname': surname, 'phone': phone})
        .eq('id', _userId);
  }

  /* --------------------------------------------------
     FETCH PROFILE (ADDRESS = INT FK ONLY)
  -------------------------------------------------- */
  Future<Map<String, dynamic>> getProfile() async {
    final data = await _client
        .from('profiles')
        .select('id, name, surname, phone, address')
        .eq('id', _userId)
        .maybeSingle();

    if (data == null) {
      throw Exception('Profile not found');
    }

    return data;
  }

  /* --------------------------------------------------
     FETCH ADDRESS BY ID (EXPLICIT FK RESOLUTION)
  -------------------------------------------------- */
  Future<Map<String, dynamic>?> getAddressById(int addressId) async {
    final data = await _client
        .from('addresses')
        .select('id, address, city, state, pincode')
        .eq('id', addressId)
        .maybeSingle();

    return data;
  }

  /* --------------------------------------------------
   LINK PROFILE TO ADDRESS (FK UPDATE)
-------------------------------------------------- */
  Future<void> updateProfileAddress(int addressId) async {
    await _client
        .from('profiles')
        .update({'address': addressId})
        .eq('id', _userId);
  }

  /* --------------------------------------------------
     CREATE / UPDATE ADDRESS
  -------------------------------------------------- */
  Future<int> upsertAddress({
    int? id,
    required String address,
    required String city,
    required String state,
    required int pincode,
  }) async {
    final payload = {
      if (id != null) 'id': id,
      'user_id': _userId,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
    };

    final data = await _client
        .from('addresses')
        .upsert(payload)
        .select('id')
        .single();

    return data['id'] as int;
  }
}
