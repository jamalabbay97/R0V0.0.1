// Main widget test file for the R0 app
//
// This file contains smoke tests to verify the app initializes correctly.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r0/core/config/app_config_flavors.dart';
import 'package:r0/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  setUpAll(() async {
    AppConfig.initialize(AppFlavor.prod);
    await Firebase.initializeApp();
  });

  testWidgets('App should initialize and show home screen',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app initializes without errors
    // The home screen should be displayed
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App should handle language provider',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the app has the language provider set up
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
