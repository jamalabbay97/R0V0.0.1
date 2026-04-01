class StopSortingService {
  StopSortingService._();

  static const List<String> _defaultStartKeys = <String>[
    'OriginalStart',
    'startTime',
    'Début',
    'debut',
    'Start',
    'start',
  ];

  static void sortStopsInAdditionalData(Map<String, dynamic>? additionalData) {
    if (additionalData == null) return;
    _sortDynamicStopsListInPlace(additionalData['Arrets']);
    _sortDynamicStopsListInPlace(additionalData['module1Stops']);
    _sortDynamicStopsListInPlace(additionalData['module2Stops']);
  }

  static void _sortDynamicStopsListInPlace(dynamic value) {
    if (value is! List) return;

    value.sort((a, b) {
      final aMinutes = _extractStartMinutes(a);
      final bMinutes = _extractStartMinutes(b);
      return aMinutes.compareTo(bMinutes);
    });
  }

  static int _extractStartMinutes(dynamic stop) {
    if (stop is! Map) return 24 * 60 + 1;

    for (final key in _defaultStartKeys) {
      final parsed = _parseTimeToMinutes(stop[key]);
      if (parsed != null) return parsed;
    }
    return 24 * 60 + 1;
  }

  static int? _parseTimeToMinutes(dynamic value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(
      value.toString().trim(),
    );
    if (match == null) return null;

    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour * 60) + minute;
  }
}
