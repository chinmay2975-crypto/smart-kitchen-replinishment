import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService profileService;

  ProfileProvider({required this.profileService});

  UserProfile? profile;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      profile = await profileService.getProfile();
    } catch (_) {
      error = 'Failed to load profile';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
