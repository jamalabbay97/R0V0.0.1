import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:r0/services/stop_sorting_service.dart';
import 'package:r0/services/trip_sorting_service.dart';

class Report {
  final int? id; // Local SQLite ID
  final String? firestoreId; // Firestore document ID
  final String description;
  final DateTime date;
  final String group;
  final String type;
  final Map<String, dynamic>? additionalData;
  final bool isSentToSheets;

  Report({
    this.id,
    this.firestoreId,
    required this.description,
    required this.date,
    required this.group,
    required this.type,
    this.additionalData,
    this.isSentToSheets = false,
  });

  Map<String, dynamic> toMap() {
    final normalizedAdditionalData = additionalData != null
        ? Map<String, dynamic>.from(additionalData!)
        : null;
    StopSortingService.sortStopsInAdditionalData(normalizedAdditionalData);
    TripSortingService.sortTripsInAdditionalData(normalizedAdditionalData);

    return {
      'id': id,
      'firestore_id': firestoreId,
      'description': description,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
      'group_name': group,
      'type': type,
      'additional_data': normalizedAdditionalData != null
          ? jsonEncode(normalizedAdditionalData)
          : null,
      'sheets_synced': isSentToSheets ? 1 : 0,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    final parsedAdditionalData = map['additional_data'] != null
        ? Map<String, dynamic>.from(jsonDecode(map['additional_data']))
        : null;
    StopSortingService.sortStopsInAdditionalData(parsedAdditionalData);
    TripSortingService.sortTripsInAdditionalData(parsedAdditionalData);

    return Report(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      description: map['description'] as String,
      date: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['date'] as String),
      group: map['group_name'] as String,
      type: map['type'] as String,
      additionalData: parsedAdditionalData,
      isSentToSheets: (map['sheets_synced'] as int? ?? 0) == 1,
    );
  }

  Report copyWith({
    int? id,
    String? firestoreId,
    String? description,
    DateTime? date,
    String? group,
    String? type,
    Map<String, dynamic>? additionalData,
    bool? isSentToSheets,
  }) {
    return Report(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      description: description ?? this.description,
      date: date ?? this.date,
      group: group ?? this.group,
      type: type ?? this.type,
      additionalData: additionalData ?? this.additionalData,
      isSentToSheets: isSentToSheets ?? this.isSentToSheets,
    );
  }
}
