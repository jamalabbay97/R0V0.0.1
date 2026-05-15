class StopDetailService {
  static const String canonicalKey = 'Detail';

  static const List<String> detailKeys = [
    canonicalKey,
    'Détail',
    'D茅tail',
    'detail',
    'details',
    'stopDetail',
    'StopDetail',
    'détails de l\'arrêt',
    'Détails de l\'arrêt',
    'detailsArret',
  ];

  static String readDetail(Map<dynamic, dynamic> stop) {
    for (final key in detailKeys) {
      final value = stop[key];
      final detail = value?.toString().trim() ?? '';
      if (detail.isNotEmpty) return detail;
    }
    return '';
  }

  static Map<String, dynamic> normalizeStopDetail(
    Map<dynamic, dynamic> stop, {
    String? detail,
  }) {
    final normalized = Map<String, dynamic>.from(stop);
    final normalizedDetail = (detail ?? readDetail(stop)).trim();
    final hasDetailKey = detailKeys.any(stop.containsKey);
    if (normalizedDetail.isNotEmpty || hasDetailKey) {
      normalized[canonicalKey] = normalizedDetail;
    }
    return normalized;
  }
}
