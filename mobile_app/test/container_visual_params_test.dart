import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/device.dart';
import 'package:mobile_app/widgets/container_card.dart';

Device _device({double? current, double? reorderLevel, double? reorderQuantity}) {
  return Device(
    deviceId: 'd1',
    deviceName: 'Test',
    deviceType: 'smart_scale',
    isOnline: true,
    lastSeenAt: null,
    mqttTopic: null,
    reorderLevel: reorderLevel,
    reorderQuantity: reorderQuantity,
    currentQuantity: current,
    currentQuantityUpdatedAt: null,
    batteryLevel: null,
  );
}

void main() {
  test('no reorder level, no reading -> 0% fill, not low', () {
    final params = ContainerVisualParams.fromDevice(_device());
    expect(params.fillPct, 0);
    expect(params.markerPct, isNull);
    expect(params.isLow, isFalse);
  });

  test('reorder_level + reorder_quantity both set: capacity = sum, 50% fill', () {
    // capacity = 100 + 100 = 200; current 100 -> 50%
    final params = ContainerVisualParams.fromDevice(
      _device(current: 100, reorderLevel: 100, reorderQuantity: 100),
    );
    expect(params.fillPct, 50);
    expect(params.markerPct, 50); // reorderLevel/capacity*100 = 100/200*100
    expect(params.isLow, isFalse); // current == reorderLevel, not strictly below
  });

  test('only reorder_level set: capacity = reorderLevel*2', () {
    // capacity = 100*2 = 200; current 20 -> 10%, below reorderLevel -> low
    final params = ContainerVisualParams.fromDevice(
      _device(current: 20, reorderLevel: 100),
    );
    expect(params.fillPct, 10);
    expect(params.markerPct, 50);
    expect(params.isLow, isTrue);
  });

  test('current exceeds capacity: capacity clamps up to current (100% full)', () {
    // reorderLevel+reorderQuantity = 200, but current is 850 (e.g. after a
    // large delivery) -> capacity snaps to 850, fillPct is exactly 100.
    final params = ContainerVisualParams.fromDevice(
      _device(current: 850, reorderLevel: 100, reorderQuantity: 100),
    );
    expect(params.fillPct, 100);
    expect(params.isLow, isFalse);
  });

  test('no reorder_level at all, current below 100: capacity floors at 100', () {
    final params = ContainerVisualParams.fromDevice(_device(current: 40));
    expect(params.fillPct, 40); // capacity = max(40,100) = 100 -> 40/100*100
    expect(params.markerPct, isNull);
  });
}
