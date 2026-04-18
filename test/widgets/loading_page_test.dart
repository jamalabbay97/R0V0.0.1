import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:r0/presentation/widgets/loading_page.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('LoadingPage Widget Tests', () {
    testWidgets('should display loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoadingPage(),
        ),
      );

      // Verify that a CircularProgressIndicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display REPORTS DAILY text', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoadingPage(),
        ),
      );

      expect(find.text('REPORTS DAILY'), findsOneWidget);
    });

    testWidgets('should have white background', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoadingPage(),
        ),
      );

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.white);
    });
  });
}
