import 'package:r0/domain/models/report.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/data/services/database_helper.dart';
import 'package:r0/data/services/firestore_service.dart';
import 'package:r0/data/services/sync_service.dart';
import 'package:flutter/foundation.dart';

class ReportRepositoryImpl implements ReportRepository {
  final DatabaseHelper _databaseHelper;
  final SyncService _syncService = SyncService();
  final FirestoreService _firestoreService = FirestoreService();

  ReportRepositoryImpl(this._databaseHelper);

  Future<void> _syncIfAuthenticated() async {
    if (_firestoreService.isAuthenticated) {
      try {
        await _syncService.performFullSync();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cloud sync failed, continuing with local data: $e');
        }
      }
    }
  }

  @override
  Future<int> insertReport(Report report) async {
    if (_firestoreService.isAuthenticated) {
      try {
        return await _syncService.saveReport(report);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cloud-backed save failed, writing local only: $e');
        }
      }
    }

    return _databaseHelper.insertReport(report);
  }

  @override
  Future<List<Report>> getReports() async {
    await _syncIfAuthenticated();
    return _databaseHelper.getReports();
  }

  @override
  Future<List<Report>> getReportsPage({int limit = 50, int offset = 0}) async {
    await _syncIfAuthenticated();
    return _databaseHelper.getReportsPage(limit: limit, offset: offset);
  }

  @override
  Future<List<Report>> getReportsByType(String type) async {
    await _syncIfAuthenticated();
    return _databaseHelper.getReportsByType(type);
  }

  @override
  Future<Report?> getReport(int id) async {
    await _syncIfAuthenticated();
    return _databaseHelper.getReport(id);
  }

  @override
  Future<int> updateReport(Report report) async {
    if (_firestoreService.isAuthenticated) {
      await _syncService.updateReport(report);
      return 1;
    }
    return _databaseHelper.updateReport(report);
  }

  @override
  Future<void> sendReportToSheets(Report report) {
    return _databaseHelper.sendReportToSheets(report);
  }

  @override
  Future<int> deleteReport(int id) {
    return _databaseHelper.deleteReport(id);
  }

  @override
  Future<void> close() {
    return _databaseHelper.close();
  }
}
