class TripSortingService {
  TripSortingService._();

  static void sortTripsInAdditionalData(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;
    final rawTruckData = additionalData['truckData'];
    if (rawTruckData is! List) return;

    for (final rawTruck in rawTruckData) {
      if (rawTruck is! Map) continue;
      final counts = rawTruck['counts'];
      if (counts is! List) continue;
      counts.sort((a, b) {
        final aMinutes = _tripMinutes(a);
        final bMinutes = _tripMinutes(b);
        return aMinutes.compareTo(bMinutes);
      });
    }
  }

  static int _tripMinutes(dynamic rawTrip) {
    if (rawTrip is! Map) return (24 * 60) + 1;
    final rawTime = rawTrip['time']?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawTime);
    if (match == null) return (24 * 60) + 1;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return (24 * 60) + 1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (24 * 60) + 1;
    }
    return (hour * 60) + minute;
  }
}
