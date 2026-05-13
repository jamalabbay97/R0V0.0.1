import 'package:r0/data/services/database_helper.dart';
import 'package:r0/data/services/firestore_service.dart';
import 'package:r0/domain/models/report.dart';
import 'package:flutter/foundation.dart';

/// Service for syncing between local SQLite and Firestore
class SyncService {
  final DatabaseHelper _localDb = DatabaseHelper();
  final FirestoreService _firestore = FirestoreService();

  Future<Report> _withResolvedFirestoreId(Report report) async {
    if (!_firestore.isAuthenticated ||
        report.firestoreId != null ||
        report.id == null) {
      return report;
    }

    try {
      final firestoreId = await _firestore.findReportIdByLocalId(report.id!);
      if (firestoreId == null) return report;
      return report.copyWith(firestoreId: firestoreId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            'Failed to resolve Firestore ID for report ${report.id}: $e');
      }
      return report;
    }
  }

  /// Sync all local reports to Firestore
  Future<void> syncLocalToCloud() async {
    if (!_firestore.isAuthenticated) {
      if (kDebugMode) {
        debugPrint('User not authenticated, skipping sync');
      }
      return;
    }

    try {
      // Get all local reports
      final localReports = await _localDb.getReports();

      // Filter reports that haven't been synced
      final unsyncedReports =
          localReports.where((r) => r.firestoreId == null).toList();

      if (unsyncedReports.isEmpty) {
        if (kDebugMode) {
          debugPrint('No unsynced reports to upload');
        }
        return;
      }

      // Upload unsynced reports
      for (final report in unsyncedReports) {
        try {
          final reportToUpload = await _withResolvedFirestoreId(report);
          final firestoreId = await _firestore.uploadReport(reportToUpload);

          // Update local report with Firestore ID
          final updatedReport =
              reportToUpload.copyWith(firestoreId: firestoreId);
          await _localDb.updateReport(updatedReport);

          if (kDebugMode) {
            debugPrint('Synced report ${report.id} to Firestore: $firestoreId');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to sync report ${report.id}: $e');
          }
          // Continue with other reports even if one fails
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during local to cloud sync: $e');
      }
      rethrow;
    }
  }

  /// Sync all cloud reports to local database
  Future<void> syncCloudToLocal() async {
    if (!_firestore.isAuthenticated) {
      if (kDebugMode) {
        debugPrint('User not authenticated, skipping sync');
      }
      return;
    }

    try {
      // Get all reports from Firestore
      final cloudReports = await _firestore.downloadReports();

      // Get all local reports
      final localReports = await _localDb.getReports();
      final localReportsByFirestoreId = {
        for (var r in localReports)
          if (r.firestoreId != null) r.firestoreId!: r
      };

      // Process each cloud report
      for (final cloudReport in cloudReports) {
        try {
          final localReport =
              localReportsByFirestoreId[cloudReport.firestoreId];

          if (localReport == null) {
            // New report from cloud - add to local with a fresh local id.
            // Cloud documents can carry creator-device local ids that collide
            // when an admin syncs reports from multiple users.
            await _localDb.insertReport(cloudReport.copyWith(id: null));
            if (kDebugMode) {
              debugPrint(
                  'Downloaded new report from cloud: ${cloudReport.firestoreId}');
            }
          } else {
            // Report exists locally - check if cloud is newer
            // For simplicity, we'll keep the cloud version
            // In a production app, you'd implement conflict resolution
            if (cloudReport.date.isAfter(localReport.date)) {
              // Preserve local row id when updating an existing local record.
              await _localDb.updateReport(
                cloudReport.copyWith(id: localReport.id),
              );
              if (kDebugMode) {
                debugPrint(
                    'Updated local report from cloud: ${cloudReport.firestoreId}');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
                'Error processing cloud report ${cloudReport.firestoreId}: $e');
          }
          // Continue with next report
        }
      }

      // Remove local cloud-linked reports that are no longer visible for this user
      // (for example, hidden/deleted only for this account).
      final visibleCloudIds = cloudReports
          .map((report) => report.firestoreId)
          .whereType<String>()
          .toSet();
      for (final localReport in localReports) {
        final localFirestoreId = localReport.firestoreId;
        if (localFirestoreId == null) {
          continue;
        }
        if (!visibleCloudIds.contains(localFirestoreId) &&
            localReport.id != null) {
          await _localDb.deleteReport(localReport.id!);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during cloud to local sync: $e');
      }
      rethrow;
    }
  }

  /// Perform bidirectional sync
  Future<void> performFullSync() async {
    if (!_firestore.isAuthenticated) {
      if (kDebugMode) {
        debugPrint('User not authenticated, skipping full sync');
      }
      return;
    }

    try {
      // First, upload local changes to cloud
      await syncLocalToCloud();

      // Then, download cloud changes to local
      await syncCloudToLocal();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during full sync: $e');
      }
      rethrow;
    }
  }

  /// Save report locally and sync to cloud
  Future<int> saveReport(Report report) async {
    // Save to local database first (offline-first)
    final localId = await _localDb.insertReport(report);
    final savedReport = report.copyWith(id: localId);

    // Try to sync to cloud if authenticated
    if (_firestore.isAuthenticated) {
      try {
        final firestoreId = await _firestore.uploadReport(savedReport);
        final updatedReport = savedReport.copyWith(firestoreId: firestoreId);
        await _localDb.updateReport(updatedReport);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to sync report to cloud, saved locally only: $e');
        }
        // Report is saved locally, will sync later
      }
    }

    return localId;
  }

  /// Update report locally and sync to cloud
  Future<void> updateReport(Report report) async {
    Report reportToUpdate = report;

    // Editors often rebuild Report objects from form data. Preserve sync
    // metadata from the existing local row so an update does not become a
    // brand-new unsynced report and later duplicate the original Firestore doc.
    if (report.id != null) {
      final existingReport = await _localDb.getReport(report.id!);
      if (existingReport != null) {
        reportToUpdate = report.copyWith(
          firestoreId: report.firestoreId ?? existingReport.firestoreId,
          isSentToSheets:
              report.isSentToSheets || existingReport.isSentToSheets,
        );
      }

      reportToUpdate = await _withResolvedFirestoreId(reportToUpdate);
      await _localDb.updateReport(reportToUpdate);
    }

    // Try to sync to cloud if authenticated.
    if (_firestore.isAuthenticated && reportToUpdate.firestoreId != null) {
      try {
        await _firestore.uploadReport(reportToUpdate);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to sync report update to cloud: $e');
        }
        // Report is updated locally, will sync later
      }
    }
  }

  /// Delete report locally and from cloud
  Future<void> deleteReport(Report report) async {
    // Delete from local database
    if (report.id != null) {
      await _localDb.deleteReport(report.id!);
    }

    // Delete from cloud if authenticated
    if (_firestore.isAuthenticated && report.firestoreId != null) {
      try {
        await _firestore.deleteReport(report.firestoreId!);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to delete report from cloud: $e');
        }
        // Report is deleted locally, will handle cloud deletion later
      }
    }
  }
}
