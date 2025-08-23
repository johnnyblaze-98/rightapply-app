// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:rightapply/device_authentication.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MaterialApp(
      home: DeviceAuthenticationPage(testMode: true),
    ));

  // DeviceAuthenticationPage should show test info
  expect(find.text('Device Management'), findsOneWidget);
  expect(find.text('Test Model'), findsOneWidget);
  expect(find.text('Test OS'), findsOneWidget);
  expect(find.text('TestPlatform'), findsOneWidget);
  });
}
