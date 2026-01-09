import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Report Title Formatting', () {
    String formatReportTitle(String description, String type) {
      final typeLower = type.toLowerCase();
      if (typeLower == 'activity tnb' || typeLower == 'daily tsud') {
        // Regex to match " - YYYY-MM-DD" at the end of the string
        final datePattern = RegExp(r' - \d{4}-\d{2}-\d{2}$');
        return description.replaceAll(datePattern, '');
        // Also handle cases where it might just be the date appended differently or if the format varies slightly if needed
        // But based on the code seen: "Activity TNB - 2026-01-04"
      }
      return description;
    }

    test('should remove date from Activity TNB report description', () {
      const description = 'Activity TNB - 2026-01-04';
      const type = 'Activity TNB';
      expect(formatReportTitle(description, type), 'Activity TNB');
    });

    test('should remove date from daily TSUD report description', () {
      const description = 'Daily TSUD - 2026-01-04';
      const type = 'daily TSUD';
      expect(formatReportTitle(description, type), 'Daily TSUD');
    });

    test('should NOT remove date from other report types', () {
      const description = 'Other Report - 2026-01-04';
      const type = 'Other';
      expect(formatReportTitle(description, type), 'Other Report - 2026-01-04');
    });

    test('should handle descriptions without date correctly', () {
      const description = 'Activity TNB No Date';
      const type = 'Activity TNB';
      expect(formatReportTitle(description, type), 'Activity TNB No Date');
    });

    test('should handle different dates', () {
      const description = 'Activity TNB - 2023-12-31';
      const type = 'Activity TNB';
      expect(formatReportTitle(description, type), 'Activity TNB');
    });
  });
}
