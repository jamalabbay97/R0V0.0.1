# Testing Guide

This directory contains all tests for the R0 application.

## Test Structure

```
test/
├── models/              # Unit tests for data models
│   └── report_test.dart
├── services/           # Unit tests for services
│   └── database_helper_test.dart
├── providers/          # Unit tests for state management
│   └── language_provider_test.dart
├── widgets/            # Widget tests for reusable widgets
│   └── loading_page_test.dart
├── helpers/            # Test utilities and helpers
│   └── test_helpers.dart
└── widget_test.dart    # Main smoke tests
```

## Running Tests

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/models/report_test.dart
```

### Run tests with coverage
```bash
flutter test --coverage
```

### View coverage report
```bash
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Test Types

### Unit Tests
- **Models**: Test data serialization, deserialization, and business logic
- **Services**: Test database operations, API calls, and business logic
- **Providers**: Test state management and data flow

### Widget Tests
- Test individual widgets in isolation
- Verify UI rendering and user interactions
- Test widget state changes

### Integration Tests
- Test complete user flows
- Test multiple components working together
- Located in `integration_test/` directory

## Writing Tests

### Example Unit Test
```dart
test('should create a Report with all required fields', () {
  final report = Report(
    description: 'Test Report',
    date: DateTime(2024, 1, 1),
    group: 'R0',
    type: 'Activity',
  );

  expect(report.description, 'Test Report');
});
```

### Example Widget Test
```dart
testWidgets('should display loading indicator', (WidgetTester tester) async {
  await tester.pumpWidget(
    createTestApp(child: const LoadingPage()),
  );

  expect(find.byType(CircularProgressIndicator), findsOneWidget);
});
```

## Test Helpers

Use the helper functions in `test/helpers/test_helpers.dart`:
- `createTestApp()`: Creates a test app with necessary providers
- `createMockReport()`: Creates a mock report for testing
- `waitForAsync()`: Waits for async operations

## Best Practices

1. **Test one thing at a time**: Each test should verify a single behavior
2. **Use descriptive test names**: Test names should clearly describe what they test
3. **Arrange-Act-Assert**: Structure tests with clear sections
4. **Mock external dependencies**: Use mocks for database, network, etc.
5. **Keep tests independent**: Tests should not depend on each other
6. **Test edge cases**: Include tests for null, empty, and error cases

## Coverage Goals

- Aim for at least 70% code coverage
- Focus on critical business logic
- Test all user-facing features
- Test error handling paths
