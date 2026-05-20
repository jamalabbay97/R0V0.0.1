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
  Future<void> sendReportToSheets(Report report) async {
    // Ensure the report is synced to Firestore first if authenticated so that we have a firestoreId
    if (_firestoreService.isAuthenticated &&
        (report.firestoreId == null || report.firestoreId!.isEmpty)) {
      try {
        await _syncService.updateReport(report);
        if (report.id != null) {
          final reloaded = await _databaseHelper.getReport(report.id!);
          if (reloaded != null) {
            report = reloaded;
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Pre-sync to Firestore for Sheets failed: $e');
        }
      }
    }

    await _databaseHelper.sendReportToSheets(report);

    if (!_firestoreService.isAuthenticated) {
      return;
    }

    try {
      final syncedReport = report.id == null
          ? report.copyWith(isSentToSheets: true)
          : (await _databaseHelper.getReport(report.id!)) ??
              report.copyWith(isSentToSheets: true);
      await _syncService.updateReport(syncedReport);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to share Sheets-sent report status to cloud: $e');
      }
    }
  }

  @override
  Future<int> deleteReport(int id) async {
    final report = await _databaseHelper.getReport(id);
    if (report == null) {
      return 0;
    }

    if (_firestoreService.isAuthenticated) {
      try {
        await _syncService.deleteReport(report);
        return 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Cloud-aware delete failed, deleting local only: $e');
        }
      }
    }

    return _databaseHelper.deleteReport(id);
  }

  @override
  Future<void> close() {
    return _databaseHelper.close();
  }
}
