import 'container.dart';

class Kitchen {
  final int id;
  final int userId;
  final String name;
  final String? address;
  final String? createdAt;
  final List<Container>? containers;

  Kitchen({
    required this.id,
    required this.userId,
    required this.name,
    this.address,
    this.createdAt,
    this.containers,
  });

  factory Kitchen.fromJson(Map<String, dynamic> json) {
    return Kitchen(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'],
      createdAt: json['created_at'],
      containers: json['containers'] != null
          ? (json['containers'] as List)
              .map((c) => Container.fromJson(c))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
  };
}