import 'package:intl/intl.dart';

class Report {
  final int? id;
  final String description;
  final DateTime date;
  final String group;
  final String type;
  final Map<String, dynamic>? additionalData;

  Report({
    this.id,
    required this.description,
    required this.date,
    required this.group,
    required this.type,
    this.additionalData,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'date': DateFormat('yyyy-MM-dd HH:mm:ss').format(date),
      'group_name': group,
      'type': type,
      'additional_data': additionalData != null
          ? additionalData.toString()
          : null,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'] as int?,
      description: map['description'] as String,
      date: DateFormat('yyyy-MM-dd HH:mm:ss').parse(map['date'] as String),
      group: map['group_name'] as String,
      type: map['type'] as String,
      additionalData: map['additional_data'] != null
          ? Map<String, dynamic>.fromEntries(
              (map['additional_data'] as String)
                  .replaceAll('{', '')
                  .replaceAll('}', '')
                  .split(',')
                  .where((e) => e.contains(':'))
                  .map((e) {
                final parts = e.split(':');
                return MapEntry(
                  parts[0].trim(),
                  parts[1].trim(),
                );
              }),
            )
          : null,
    );
  }

  Report copyWith({
    int? id,
    String? description,
    DateTime? date,
    String? group,
    String? type,
    Map<String, dynamic>? additionalData,
  }) {
    return Report(
      id: id ?? this.id,
      description: description ?? this.description,
      date: date ?? this.date,
      group: group ?? this.group,
      type: type ?? this.type,
      additionalData: additionalData ?? this.additionalData,
    );
  }
} 