class Container {
  final int id;
  final int? kitchenId;
  final int? deviceId;
  final String label;
  final double? capacityKg;
  final double? maxCapacityKg;
  final String? macAddress;
  final String? deviceStatus;
  final double? lastPercent;
  final double? lastWeight;
  final String? lastReadAt;
  final String? createdAt;

  Container({
    required this.id,
    this.kitchenId,
    this.deviceId,
    required this.label,
    this.capacityKg,
    this.maxCapacityKg,
    this.macAddress,
    this.deviceStatus,
    this.lastPercent,
    this.lastWeight,
    this.lastReadAt,
    this.createdAt,
  });

  factory Container.fromJson(Map<String, dynamic> json) {
    return Container(
      id: json['id'] ?? 0,
      kitchenId: json['kitchen_id'],
      deviceId: json['device_id'],
      label: json['label'] ?? '',
      capacityKg: (json['capacity_kg'] as num?)?.toDouble(),
      maxCapacityKg: (json['max_capacity_kg'] as num?)?.toDouble(),
      macAddress: json['mac_address'],
      deviceStatus: json['device_status'],
      lastPercent: (json['last_percent'] as num?)?.toDouble(),
      lastWeight: (json['last_weight'] as num?)?.toDouble(),
      lastReadAt: json['last_read_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'capacity_kg': capacityKg,
    'max_capacity_kg': maxCapacityKg,
    'device_id': deviceId,
  };
}