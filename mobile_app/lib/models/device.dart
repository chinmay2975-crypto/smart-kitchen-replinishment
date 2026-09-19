import 'telemetry_reading.dart';

class Device {
  final String deviceId;
  final String deviceName;
  final String deviceType;
  final bool isOnline;
  final String? lastSeenAt;
  final String? mqttTopic;
  final double? reorderLevel;
  final double? reorderQuantity;
  final double? currentQuantity;
  final String? currentQuantityUpdatedAt;
  final double? batteryLevel;
  // Detail-only fields (null when parsed from the list endpoint)
  final String? householdId;
  final String? firmwareVer;
  final Map<String, dynamic>? configJson;
  final List<TelemetryReading>? latestTelemetry;

  Device({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.isOnline,
    required this.lastSeenAt,
    required this.mqttTopic,
    required this.reorderLevel,
    required this.reorderQuantity,
    required this.currentQuantity,
    required this.currentQuantityUpdatedAt,
    required this.batteryLevel,
    this.householdId,
    this.firmwareVer,
    this.configJson,
    this.latestTelemetry,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      deviceName: json['device_name'] as String,
      deviceType: json['device_type'] as String,
      isOnline: json['is_online'] as bool,
      lastSeenAt: json['last_seen_at'] as String?,
      mqttTopic: json['mqtt_topic'] as String?,
      reorderLevel: (json['reorder_level'] as num?)?.toDouble(),
      reorderQuantity: (json['reorder_quantity'] as num?)?.toDouble(),
      currentQuantity: (json['current_quantity'] as num?)?.toDouble(),
      currentQuantityUpdatedAt: json['current_quantity_updated_at'] as String?,
      batteryLevel: (json['battery_level'] as num?)?.toDouble(),
      householdId: json['household_id'] as String?,
      firmwareVer: json['firmware_ver'] as String?,
      configJson: json['config_json'] as Map<String, dynamic>?,
      latestTelemetry: json['latest_telemetry'] != null
          ? (json['latest_telemetry'] as List<dynamic>)
              .map((e) => TelemetryReading.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }
}
