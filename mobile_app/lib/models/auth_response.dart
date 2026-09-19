class AuthResponse {
  final String userId;
  final String email;
  // Nullable to match the backend's AuthResponse schema (name: str | None) —
  // a login/register response is not guaranteed to include it.
  final String? name;
  final String? phone;
  final String? householdId;
  final String accessToken;
  final String refreshToken;

  AuthResponse({
    required this.userId,
    required this.email,
    required this.name,
    required this.phone,
    required this.householdId,
    required this.accessToken,
    required this.refreshToken,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      householdId: json['household_id'] as String?,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class RefreshResponse {
  final String accessToken;
  final String refreshToken;

  RefreshResponse({required this.accessToken, required this.refreshToken});

  factory RefreshResponse.fromJson(Map<String, dynamic> json) {
    return RefreshResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}
