import 'package:intl/intl.dart';
import 'dart:convert';

class Report {
  final int? id; // Local SQLite ID
  final String? firestoreId; // Firestore document ID
  final String description;
  final DateTime date;
  final String group;
  final String type;
  final Map<String, dynamic>? additionalData;

  Report({
    this.id,
    this.firestoreId,
    required this.description,
    required this.date,
    required this.group,
    required this.type,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firestore_id': firestoreId,
      'description': description,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
      'group_name': group,
      'type': type,
      'additional_data': additionalData != null ? jsonEncode(additionalData) : null,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as int?,
      firestoreId: map['firestore_id'] as String?,
      description: map['description'] as String,
      date: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['date'] as String),
      group: map['group_name'] as String,
      type: map['type'] as String,
      additionalData: map['additional_data'] != null
          ? Map<String, dynamic>.from(jsonDecode(map['additional_data']))
          : null,
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
  }) {
    return Report(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      description: description ?? this.description,
      date: date ?? this.date,
      group: group ?? this.group,
      type: type ?? this.type,
      additionalData: additionalData ?? this.additionalData,
    );
  }
} 