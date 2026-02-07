import 'dart:math';

class TimeRange {
  final int startMinutes;
  final int endMinutes;

  TimeRange(this.startMinutes, this.endMinutes);

  int get duration => endMinutes - startMinutes;
}

class TimeCalculationService {
  /// Calculates the total downtime duration in hours from a list of time ranges.
  /// Overlapping intervals are merged to avoid double counting.
  /// The total duration is capped at 8 hours.
  static double calculateTotalDowntime(List<TimeRange> ranges) {
    if (ranges.isEmpty) return 0.0;

    // 1. Sort ranges by start time
    ranges.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    // 2. Merge overlapping intervals
    List<TimeRange> mergedRanges = [];
    TimeRange current = ranges[0];

    for (int i = 1; i < ranges.length; i++) {
      TimeRange next = ranges[i];

      if (next.startMinutes < current.endMinutes) {
        // Overlap detected, merge them
        // Use the maximum end time
        current = TimeRange(
          current.startMinutes,
          max(current.endMinutes, next.endMinutes),
        );
      } else {
        // No overlap, push current and move to next
        mergedRanges.add(current);
        current = next;
      }
    }
    mergedRanges.add(current);

    // 3. Calculate total duration from merged ranges
    int totalMinutes = 0;
    for (var range in mergedRanges) {
      totalMinutes += range.duration;
    }

    // 4. Convert to hours
    double totalHours = totalMinutes / 60.0;

    // 5. Clamp to 8 hours max
    if (totalHours > 8.0) {
      return 8.0;
    }

    return totalHours;
  }

  /// Parses a time string "HH:MM" to minutes from start of day.
  /// Returns null if parsing fails.
  static int? parseTimeToMinutes(String timeStr) {
    if (timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }

  /// Creates a list of TimeRange objects from raw start/end strings.
  /// Handles overnight ranges (end < start) by adding 24 hours to the end.
  static List<TimeRange> parseTimeRanges(List<Map<String, String>> rawRanges) {
    List<TimeRange> validRanges = [];

    for (var range in rawRanges) {
      final startStr = range['start'];
      final endStr = range['end'];

      if (startStr == null || endStr == null) continue;

      final startMin = parseTimeToMinutes(startStr);
      int? endMin = parseTimeToMinutes(endStr);

      if (startMin != null && endMin != null) {
        // Handle overnight
        if (endMin <= startMin) {
          endMin += 24 * 60;
        }

        validRanges.add(TimeRange(startMin, endMin));
      }
    }

    return validRanges;
  }

  /// Calculates R0 working hours (H.M) based on counter data or defect status.
  ///
  /// Parameters:
  /// - [startCounter]: Starting counter value (e.g., 100.5)
  /// - [endCounter]: Ending counter value (e.g., 108.0)
  /// - [hasDefect]: True if either counter is marked as defective
  /// - [totalStoppageHours]: Total downtime hours (H.A)
  ///
  /// Logic:
  /// - If no defect: H.M = endCounter - startCounter
  /// - If defect: H.M = 8.0 - totalStoppageHours
  ///
  /// Returns the calculated working hours (H.M).
  static double calculateWorkingHours({
    double? startCounter,
    double? endCounter,
    required bool hasDefect,
    required double totalStoppageHours,
  }) {
    if (hasDefect) {
      // When counter is defective, calculate H.M as remaining shift time
      double workingHours = 8.0 - totalStoppageHours;
      // Ensure non-negative and cap at 8.0
      return workingHours.clamp(0.0, 8.0);
    }

    // Normal case: calculate from counter difference
    if (startCounter != null &&
        endCounter != null &&
        endCounter > startCounter) {
      double workingHours = endCounter - startCounter;
      // Cap at 8.0 hours
      return workingHours.clamp(0.0, 8.0);
    }

    // Invalid or missing counter data
    return 0.0;
  }
}
