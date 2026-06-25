class User {
  final int id;
  final String phone;
  final String? name;
  final String? email;
  final String? createdAt;

  User({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      phone: json['phone'] ?? '',
      name: json['name'],
      email: json['email'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'name': name,
    'email': email,
  };
}