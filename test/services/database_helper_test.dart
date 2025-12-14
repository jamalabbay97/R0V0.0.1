import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';

void main() {
  // Initialize FFI for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Tests', () {
    late DatabaseHelper databaseHelper;

    setUp(() async {
      databaseHelper = DatabaseHelper();
      // Clean up any existing database
      final db = await databaseHelper.database;
      await db.delete('reports');
    });

    tearDown(() async {
      await databaseHelper.close();
    });

    test('should insert a report and return an id', () async {
      final report = Report(
        description: 'Test Report',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );

      final id = await databaseHelper.insertReport(report);

      expect(id, greaterThan(0));
    });

    test('should retrieve all reports', () async {
      final report1 = Report(
        description: 'Report 1',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );
      final report2 = Report(
        description: 'Report 2',
        date: DateTime(2024, 1, 2),
        group: 'R0',
        type: 'Daily',
      );

      await databaseHelper.insertReport(report1);
      await databaseHelper.insertReport(report2);

      final reports = await databaseHelper.getReports();

      expect(reports.length, 2);
      expect(reports.any((r) => r.description == 'Report 1'), isTrue);
      expect(reports.any((r) => r.description == 'Report 2'), isTrue);
    });

    test('should retrieve a report by id', () async {
      final report = Report(
        description: 'Test Report',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );

      final id = await databaseHelper.insertReport(report);
      final retrieved = await databaseHelper.getReport(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.id, id);
      expect(retrieved.description, 'Test Report');
      expect(retrieved.type, 'Activity');
    });

    test('should return null when report not found', () async {
      final report = await databaseHelper.getReport(999);

      expect(report, isNull);
    });

    test('should retrieve reports by type', () async {
      final report1 = Report(
        description: 'Activity Report',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );
      final report2 = Report(
        description: 'Daily Report',
        date: DateTime(2024, 1, 2),
        group: 'R0',
        type: 'Daily',
      );
      final report3 = Report(
        description: 'Another Activity Report',
        date: DateTime(2024, 1, 3),
        group: 'R0',
        type: 'Activity',
      );

      await databaseHelper.insertReport(report1);
      await databaseHelper.insertReport(report2);
      await databaseHelper.insertReport(report3);

      final activityReports = await databaseHelper.getReportsByType('Activity');

      expect(activityReports.length, 2);
      expect(activityReports.every((r) => r.type == 'Activity'), isTrue);
    });

    test('should update a report', () async {
      final report = Report(
        description: 'Original Description',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );

      final id = await databaseHelper.insertReport(report);
      final updatedReport = report.copyWith(
        id: id,
        description: 'Updated Description',
      );

      await databaseHelper.updateReport(updatedReport);
      final retrieved = await databaseHelper.getReport(id);

      expect(retrieved!.description, 'Updated Description');
    });

    test('should delete a report', () async {
      final report = Report(
        description: 'Test Report',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );

      final id = await databaseHelper.insertReport(report);
      await databaseHelper.deleteReport(id);

      final retrieved = await databaseHelper.getReport(id);
      expect(retrieved, isNull);
    });

    test('should handle reports with additional data', () async {
      final additionalData = {
        'selectedPoste': '1er',
        'selectedMine': 'Mine A',
        'counters': [1, 2, 3],
      };
      final report = Report(
        description: 'Report with Additional Data',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'R0',
        additionalData: additionalData,
      );

      final id = await databaseHelper.insertReport(report);
      final retrieved = await databaseHelper.getReport(id);

      expect(retrieved, isNotNull);
      expect(retrieved!.additionalData, isNotNull);
      expect(retrieved.additionalData!['selectedPoste'], '1er');
      expect(retrieved.additionalData!['selectedMine'], 'Mine A');
      expect(retrieved.additionalData!['counters'], [1, 2, 3]);
    });

    test('should handle empty reports list', () async {
      final reports = await databaseHelper.getReports();

      expect(reports, isEmpty);
    });

    test('should handle multiple operations in sequence', () async {
      // Insert
      final report1 = Report(
        description: 'Report 1',
        date: DateTime(2024, 1, 1),
        group: 'R0',
        type: 'Activity',
      );
      final id1 = await databaseHelper.insertReport(report1);

      // Update
      final updated = report1.copyWith(
        id: id1,
        description: 'Updated Report 1',
      );
      await databaseHelper.updateReport(updated);

      // Insert another
      final report2 = Report(
        description: 'Report 2',
        date: DateTime(2024, 1, 2),
        group: 'R0',
        type: 'Daily',
      );
      await databaseHelper.insertReport(report2);

      // Get all
      final allReports = await databaseHelper.getReports();
      expect(allReports.length, 2);

      // Delete one
      await databaseHelper.deleteReport(id1);
      final remaining = await databaseHelper.getReports();
      expect(remaining.length, 1);
      expect(remaining.first.description, 'Report 2');
    });
  });
}
