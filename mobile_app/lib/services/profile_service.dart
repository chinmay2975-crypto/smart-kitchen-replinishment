import 'package:dio/dio.dart';

import '../models/user_profile.dart';

class ProfileService {
  final Dio dio;

  ProfileService(this.dio);

  Future<UserProfile> getProfile() async {
    final response = await dio.get('/api/v1/profile');
    return UserProfile.fromJson(response.data as Map<String, dynamic>);
  }
}
