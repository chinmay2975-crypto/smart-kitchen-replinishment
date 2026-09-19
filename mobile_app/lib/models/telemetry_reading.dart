class TelemetryReading {
  final String sensorType;
  final double value;
  final String unit;
  final String recordedAt;

  TelemetryReading({
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.recordedAt,
  });

  factory TelemetryReading.fromJson(Map<String, dynamic> json) {
    return TelemetryReading(
      sensorType: json['sensor_type'] as String,
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
      recordedAt: json['recorded_at'] as String,
    );
  }
}

class TelemetrySummary {
  final int count;
  final double? min;
  final double? max;
  final double? avg;
  final double? latest;

  TelemetrySummary({
    required this.count,
    required this.min,
    required this.max,
    required this.avg,
    required this.latest,
  });

  factory TelemetrySummary.fromJson(Map<String, dynamic> json) {
    return TelemetrySummary(
      count: json['count'] as int,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      avg: (json['avg'] as num?)?.toDouble(),
      latest: (json['latest'] as num?)?.toDouble(),
    );
  }
}

class TelemetryResult {
  final String deviceId;
  final List<TelemetryReading> telemetry;
  final TelemetrySummary summary;

  TelemetryResult({
    required this.deviceId,
    required this.telemetry,
    required this.summary,
  });

  factory TelemetryResult.fromJson(Map<String, dynamic> json) {
    return TelemetryResult(
      deviceId: json['device_id'] as String,
      telemetry: (json['telemetry'] as List<dynamic>)
          .map((e) => TelemetryReading.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: TelemetrySummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }
}
