import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_app/main.dart';

void main() {
  // flutter_secure_storage has no real platform implementation under
  // `flutter test` — without a mock handler, its channel calls never
  // resolve and AuthProvider.bootstrap() hangs forever on `.hasSession()`.
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'read') return null;
      if (call.method == 'readAll') return <String, String>{};
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('App boots to the Welcome screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartKitchenApp());
    await tester.pumpAndSettle();

    expect(find.text('Smart Kitchen'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });
}
