import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:r0/models/report.dart';
import 'package:flutter/foundation.dart';

/// Service for syncing reports with Firestore
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection name for reports
  static const String _reportsCollection = 'reports';

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Enable offline persistence (call this once at app startup)
  Future<void> enableOfflinePersistence() async {
    try {
      await _firestore.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to enable Firestore offline persistence: $e');
      }
      // Persistence might already be enabled, which is fine
    }
  }

  /// Upload a report to Firestore
  Future<String> uploadReport(Report report) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to upload reports');
    }

    try {
      final reportData = _reportToFirestore(report);
      
      // If report has a Firestore ID, update it; otherwise create new
      if (report.firestoreId != null) {
        await _firestore
            .collection(_reportsCollection)
            .doc(report.firestoreId)
            .update(reportData);
        return report.firestoreId!;
      } else {
        final docRef = await _firestore
            .collection(_reportsCollection)
            .add(reportData);
        return docRef.id;
      }
    } catch (e) {
      throw Exception('Failed to upload report to Firestore: $e');
    }
  }

  /// Download all reports from Firestore
  Future<List<Report>> downloadReports() async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to download reports');
    }

    try {
      final snapshot = await _firestore
          .collection(_reportsCollection)
          .where('userId', isEqualTo: _userId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => _reportFromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to download reports from Firestore: $e');
    }
  }

  /// Get reports stream (real-time updates)
  Stream<List<Report>> getReportsStream() {
    if (!isAuthenticated) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_reportsCollection)
        .where('userId', isEqualTo: _userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _reportFromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Delete a report from Firestore
  Future<void> deleteReport(String firestoreId) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to delete reports');
    }

    try {
      await _firestore
          .collection(_reportsCollection)
          .doc(firestoreId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete report from Firestore: $e');
    }
  }

  /// Sync local reports to Firestore (batch upload)
  Future<void> syncLocalReportsToFirestore(List<Report> localReports) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to sync reports');
    }

    try {
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final report in localReports) {
        if (report.firestoreId == null) {
          // New report - add to batch
          final docRef = _firestore.collection(_reportsCollection).doc();
          batch.set(docRef, _reportToFirestore(report));
          batchCount++;

          // Firestore batch limit is 500
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to sync reports to Firestore: $e');
    }
  }

  /// Convert Report to Firestore document
  Map<String, dynamic> _reportToFirestore(Report report) {
    return {
      'userId': _userId,
      'description': report.description,
      'date': Timestamp.fromDate(report.date),
      'group': report.group,
      'type': report.type,
      'additionalData': report.additionalData,
      'localId': report.id, // Keep local SQLite ID for reference
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Firestore document to Report
  Report _reportFromFirestore(String firestoreId, Map<String, dynamic> data) {
    return Report(
      id: data['localId'] as int?,
      firestoreId: firestoreId,
      description: data['description'] as String,
      date: (data['date'] as Timestamp).toDate(),
      group: data['group'] as String,
      type: data['type'] as String,
      additionalData: data['additionalData'] as Map<String, dynamic>?,
    );
  }
}
