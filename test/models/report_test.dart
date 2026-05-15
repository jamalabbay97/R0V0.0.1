import 'package:flutter_test/flutter_test.dart';
import 'package:r0/domain/models/report.dart';
import 'dart:convert';

void main() {
  group('Report Model Tests', () {
    test('should create a Report with all required fields', () {
      final report = Report(
        description: 'Test Report',
        date: DateTime(2024, 1, 1, 10, 30),
        group: 'R0',
        type: 'Activity',
      );

      expect(report.description, 'Test Report');
      expect(report.date, DateTime(2024, 1, 1, 10, 30));
      expect(report.group, 'R0');
      expect(report.type, 'Activity');
      expect(report.id, isNull);
      expect(report.additionalData, isNull);
    });

    test('should create a Report with optional fields', () {
      final additionalData = {'key': 'value', 'number': 42};
      final report = Report(
        id: 1,
        description: 'Test Report',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
        additionalData: additionalData,
      );

      expect(report.id, 1);
      expect(report.additionalData, additionalData);
    });

    test('should convert Report to Map correctly', () {
      final date = DateTime(2024, 1, 15, 14, 30, 45);
      final report = Report(
        id: 1,
        description: 'Test Report',
        date: date,
        group: 'R0',
        type: 'Activity',
        additionalData: {'key': 'value'},
      );

      final map = report.toMap();

      expect(map['id'], 1);
      expect(map['description'], 'Test Report');
      expect(map['date'], '2024-01-15 14:30:45');
      expect(map['group_name'], 'R0');
      expect(map['type'], 'Activity');
      expect(map['additional_data'], jsonEncode({'key': 'value'}));
    });

    test('should create Report from Map correctly', () {
      final map = {
        'id': 1,
        'description': 'Test Report',
        'date': '2024-01-15 14:30:45',
        'group_name': 'R0',
        'type': 'Activity',
        'additional_data': jsonEncode({'key': 'value'}),
      };

      final report = Report.fromMap(map);

      expect(report.id, 1);
      expect(report.description, 'Test Report');
      expect(report.date, DateTime(2024, 1, 15, 14, 30, 45));
      expect(report.group, 'R0');
      expect(report.type, 'Activity');
      expect(report.additionalData, {'key': 'value'});
    });

    test('should handle null additional_data in fromMap', () {
      final map = {
        'id': 1,
        'description': 'Test Report',
        'date': '2024-01-15 14:30:45',
        'group_name': 'R0',
        'type': 'Activity',
        'additional_data': null,
      };

      final report = Report.fromMap(map);

      expect(report.additionalData, isNull);
    });

    test('should handle null id in fromMap', () {
      final map = {
        'id': null,
        'description': 'Test Report',
        'date': '2024-01-15 14:30:45',
        'group_name': 'R0',
        'type': 'Activity',
        'additional_data': null,
      };

      final report = Report.fromMap(map);

      expect(report.id, isNull);
    });

    test('copyWith should create a new Report with updated fields', () {
      final original = Report(
        id: 1,
        description: 'Original',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );

      final updated = original.copyWith(
        description: 'Updated',
        type: 'Daily',
      );

      expect(updated.id, 1);
      expect(updated.description, 'Updated');
      expect(updated.date, DateTime(2024, 1, 1));
      expect(updated.group, 'R0');
      expect(updated.type, 'Daily');
    });

    test(
        'copyWith should preserve original values when fields are not provided',
        () {
      final original = Report(
        id: 1,
        description: 'Original',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
        additionalData: {'key': 'value'},
      );

      final updated = original.copyWith();

      expect(updated.id, 1);
      expect(updated.description, 'Original');
      expect(updated.date, DateTime(2024, 1, 1));
      expect(updated.group, 'R0');
      expect(updated.type, 'Activity');
      expect(updated.additionalData, {'key': 'value'});
    });

    test('toMap and fromMap should preserve R0 stop details', () {
      final original = Report(
        id: 1,
        description: 'Rapport R0 - 1er',
        date: DateTime(2024, 1, 15, 14, 30, 45),
        group: '1er',
        type: 'BULL D9',
        additionalData: {
          'Arrets': [
            {
              'Arret': 'Panne',
              'Détail': 'Flexible cassé',
              'Début': '08:00',
              'Fin': '08:30',
            },
          ],
        },
      );

      final restored = Report.fromMap(original.toMap());
      final arrets = restored.additionalData!['Arrets'] as List;
      final arret = arrets.first as Map<String, dynamic>;

      expect(arret['Detail'], 'Flexible cassé');
    });

    test('toMap and fromMap should be reversible', () {
      final original = Report(
        id: 1,
        description: 'Test Report',
        date: DateTime(2024, 1, 15, 14, 30, 45),
        group: 'R0',
        type: 'Activity',
        additionalData: {'key': 'value', 'number': 42},
      );

      final map = original.toMap();
      final restored = Report.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.description, original.description);
      expect(restored.date, original.date);
      expect(restored.group, original.group);
      expect(restored.type, original.type);
      expect(restored.additionalData, original.additionalData);
    });
  });
}
