import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceRepository {
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
     FETCH USER DEVICES (NAME FROM PROVISIONED_DEVICES)
  -------------------------------------------------- */
  Future<List<Map<String, dynamic>>> getDevices() async {
    final data = await _client
        .from('provisioned_devices')
        .select('''
          device_id,
          name,
          devices (
            id,
            mac_address,
            last_active
          )
        ''')
        .eq('user_id', _userId);

    return List<Map<String, dynamic>>.from(
      data.map(
        (e) => {
          'id': e['devices']['id'],
          'name': e['name'],
          'mac_address': e['devices']['mac_address'],
          'last_active': e['devices']['last_active'],
        },
      ),
    );
  }

  /* --------------------------------------------------
     FETCH SINGLE DEVICE
  -------------------------------------------------- */
  Future<Map<String, dynamic>> getDeviceById(int deviceId) async {
    final data = await _client
        .from('provisioned_devices')
        .select('''
          device_id,
          name,
          devices (
            id,
            mac_address,
            last_active
          )
        ''')
        .eq('user_id', _userId)
        .eq('device_id', deviceId)
        .single();

    return {
      'id': data['devices']['id'],
      'name': data['name'],
      'mac_address': data['devices']['mac_address'],
      'last_active': data['devices']['last_active'],
    };
  }

  /* --------------------------------------------------
     FETCH DEVICE CONFIG
  -------------------------------------------------- */
  Future<Map<String, dynamic>?> getDeviceConfig(int deviceId) async {
    final data = await _client
        .from('device_config')
        .select('''
        id,
        medicine_name,
        reorder_level,
        reorder_quantity,
        address,
        created_at
      ''')
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data;
  }

  /* --------------------------------------------------
     FETCH LATEST TELEMETRY (STRING PAYLOAD)
  -------------------------------------------------- */
  Future<num?> getLatestPayload(int deviceId) async {
    final data = await _client
        .from('device_telemetry')
        .select('payload')
        .eq('device_id', deviceId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data?['payload'] as num?;
  }

  /* --------------------------------------------------
     CLAIM DEVICE (UID → PROVISIONED + NAME)
  -------------------------------------------------- */
  Future<int> claimDevice({
    required String deviceUid,
    required String deviceName,
  }) async {
    final response = await _client
        .from('devices')
        .select('id')
        .eq('mac_address', deviceUid.trim())
        .maybeSingle();

    if (response == null) {
      throw Exception('Invalid device UID');
    }

    final deviceId = response['id'] as int;

    final exists = await _client
        .from('provisioned_devices')
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();

    if (exists != null) {
      throw Exception('Device already claimed');
    }

    await _client.from('provisioned_devices').insert({
      'user_id': _userId,
      'device_id': deviceId,
      'name': deviceName.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    return deviceId;
  }

  /* --------------------------------------------------
     UPSERT DEVICE CONFIG
  -------------------------------------------------- */
  Future<void> upsertDeviceConfig({
    required int deviceId,
    required String medicineName,
    required int reorderLevel,
    required int reorderQuantity,
    int? addressId,
  }) async {
    await _client.from('device_config').upsert({
      'device_id': deviceId,
      'medicine_name': medicineName,
      'reorder_level': reorderLevel,
      'reorder_quantity': reorderQuantity,
      'address': addressId,
    }, onConflict: 'device_id');
  }

  /* --------------------------------------------------
     FETCH ADDRESS
  -------------------------------------------------- */
  Future<Map<String, dynamic>?> getAddress(int addressId) async {
    return await _client
        .from('addresses')
        .select()
        .eq('id', addressId)
        .maybeSingle();
  }

  /* --------------------------------------------------
     CREATE / UPDATE ADDRESS
  -------------------------------------------------- */
  Future<int> upsertAddress({
    int? id,
    required String address,
    required int pincode,
    required String city,
    required String state,
  }) async {
    // 🔹 UPDATE EXISTING
    if (id != null) {
      final data = await _client
          .from('addresses')
          .update({
            'address': address,
            'city': city,
            'state': state,
            'pincode': pincode,
          })
          .eq('id', id)
          .eq('user_id', _userId)
          .select('id')
          .single();

      return data['id'] as int;
    }

    // 🔹 INSERT NEW
    final data = await _client
        .from('addresses')
        .insert({
          'user_id': _userId,
          'address': address,
          'city': city,
          'state': state,
          'pincode': pincode,
        })
        .select('id')
        .single();

    return data['id'] as int;
  }

  /* --------------------------------------------------
     UNLINK DEVICE (USER ONLY)
  -------------------------------------------------- */
  Future<void> deleteDevice(int deviceId) async {
    await _client
        .from('provisioned_devices')
        .delete()
        .eq('device_id', deviceId)
        .eq('user_id', _userId);
  }

  /* --------------------------------------------------
   UPDATE DEVICE NAME (PROVISIONED_DEVICES)
-------------------------------------------------- */
  Future<void> updateProvisionedDeviceName({
    required int deviceId,
    required String name,
  }) async {
    await _client
        .from('provisioned_devices')
        .update({'name': name})
        .eq('device_id', deviceId)
        .eq('user_id', _userId);
  }
}
