class Household {
  final String householdId;
  final String? name;

  Household({required this.householdId, required this.name});

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      householdId: json['household_id'] as String,
      name: json['name'] as String?,
    );
  }
}

class UserProfile {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final Household? household;

  UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.household,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      household: json['household'] != null
          ? Household.fromJson(json['household'] as Map<String, dynamic>)
          : null,
    );
  }
}
