// ignore_for_file: avoid_relative_lib_imports

import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/time_calculation_service.dart';

void main() {
  group('TimeCalculationService', () {
    test('calculateTotalDowntime - No overlaps', () {
      final ranges = [
        TimeRange(10 * 60, 11 * 60), // 1 hour
        TimeRange(13 * 60, 14 * 60), // 1 hour
      ];
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 2.0);
    });

    test('calculateTotalDowntime - With overlaps', () {
      final ranges = [
        TimeRange(10 * 60, 11 * 60), // 10:00 - 11:00
        TimeRange(10 * 60 + 30, 11 * 60 + 30), // 10:30 - 11:30
      ];
      // Merged: 10:00 - 11:30 = 1.5 hours
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 1.5);
    });

    test('calculateTotalDowntime - Nested overlap', () {
      final ranges = [
        TimeRange(10 * 60, 12 * 60), // 10:00 - 12:00 (2h)
        TimeRange(10 * 60 + 30, 11 * 60), // 10:30 - 11:00 (inside)
      ];
      // Merged: 10:00 - 12:00 = 2 hours
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 2.0);
    });

    test('calculateTotalDowntime - Multiple overlaps', () {
      final ranges = [
        TimeRange(10 * 60, 11 * 60), // 10-11
        TimeRange(10 * 60 + 50, 12 * 60), // 10:50-12
        TimeRange(13 * 60, 14 * 60), // 13-14
      ];
      // Merged: 10:00 - 12:00 (2h) AND 13:00 - 14:00 (1h) = 3h
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 3.0);
    });

    test('calculateTotalDowntime - Clamps to 8 hours', () {
      final ranges = [
        TimeRange(0, 10 * 60), // 10 hours
      ];
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 8.0);
    });

    test('calculateTotalDowntime - Exact 8 hours', () {
      final ranges = [
        TimeRange(0, 8 * 60), // 8 hours
      ];
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 8.0);
    });

    test('calculateTotalDowntime - Zero duration ranges', () {
      final ranges = [
        TimeRange(10 * 60, 10 * 60),
      ];
      final total = TimeCalculationService.calculateTotalDowntime(ranges);
      expect(total, 0.0);
    });

    test('parseTimeToMinutes', () {
      expect(TimeCalculationService.parseTimeToMinutes('10:30'), 10 * 60 + 30);
      expect(TimeCalculationService.parseTimeToMinutes('00:00'), 0);
      expect(TimeCalculationService.parseTimeToMinutes(''), null);
      expect(TimeCalculationService.parseTimeToMinutes('invalid'), null);
    });

    test('parseTimeRanges - Handling overnight', () {
      final input = [
        {'start': '23:00', 'end': '01:00'},
      ];
      final result = TimeCalculationService.parseTimeRanges(input);
      expect(result.length, 1);
      expect(result.first.startMinutes, 23 * 60);
      expect(result.first.endMinutes, 25 * 60); // 01:00 next day
    });
  });
}
