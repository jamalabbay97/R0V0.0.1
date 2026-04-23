import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:r0/domain/models/report.dart';
import 'package:flutter/foundation.dart';

/// Service for syncing reports with Firestore
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection name for reports
  static const String _reportsCollection = 'reports';
  static const String _archiveReportKey = 'reports_archive';
  static const Map<String, Set<String>> _reportTypesByAccessKey = {
    'r0_report': {'R0'},
    'activity_report': {'Activity TNB'},
    'daily_report': {'daily TSUD', 'Daily TSUD'},
    'truck_tracking': {'Suivi Camion', 'Chargeuse', 'Pelle'},
    'machines_stopped': {'Machine/Engin Arrêtés'},
  };
  static final Map<String, String> _accessKeyByReportType = {
    for (final entry in _reportTypesByAccessKey.entries)
      for (final type in entry.value) type: entry.key,
  };

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  Future<_ReportAccessContext> _getCurrentUserAccessContext() async {
    final uid = _userId;
    if (uid == null) {
      return const _ReportAccessContext(
        canViewSharedArchive: false,
      );
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();
    final role = (snapshot.data()?['role'] as String?)?.toLowerCase();
    final allowedReports =
        (snapshot.data()?['allowedReports'] as List<dynamic>?)
            ?.whereType<String>()
            .map((report) => report.trim())
            .toSet();

    final canViewSharedArchive = role == 'admin' ||
        (allowedReports?.contains(_archiveReportKey) ?? false);

    final allowedReportTypes = role == 'admin'
        ? <String>{}
        : _resolveAllowedReportTypes(allowedReports ?? const <String>{});
    final allowedCreationReportKeys = role == 'admin'
        ? <String>{}
        : _resolveAllowedCreationReportKeys(
            allowedReports ?? const <String>{},
          );

    return _ReportAccessContext(
      canViewSharedArchive: canViewSharedArchive,
      allowedReportTypes: allowedReportTypes,
      allowedCreationReportKeys: allowedCreationReportKeys,
    );
  }

  Set<String> _resolveAllowedReportTypes(Set<String> allowedReportKeys) {
    final allowedTypes = <String>{};
    for (final key in allowedReportKeys) {
      allowedTypes.addAll(_reportTypesByAccessKey[key] ?? const <String>{});
    }
    return allowedTypes;
  }

  Set<String> _resolveAllowedCreationReportKeys(Set<String> allowedReportKeys) {
    return allowedReportKeys.where(_reportTypesByAccessKey.containsKey).toSet();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterSharedArchiveDocs({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required _ReportAccessContext accessContext,
  }) {
    if (accessContext.isAdmin || !accessContext.canViewSharedArchive) {
      return docs;
    }

    final allowedCreationKeys = accessContext.allowedCreationReportKeys;
    if (allowedCreationKeys.isEmpty) {
      return const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    }

    final filtered = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

    for (final doc in docs) {
      final data = doc.data();
      final type = data['type'] as String?;
      final accessKey =
          (data['reportAccessKey'] as String?) ?? _accessKeyByReportType[type];
      if (accessKey == null || !allowedCreationKeys.contains(accessKey)) {
        continue;
      }

      final creatorKeys =
          (data['creatorAllowedCreationReportKeys'] as List<dynamic>?)
              ?.whereType<String>()
              .toSet();

      // For legacy reports that do not have creator key snapshots yet,
      // keep visibility based on type/access key matching only.
      if (creatorKeys == null || creatorKeys.contains(accessKey)) {
        filtered.add(doc);
      }
    }

    return filtered;
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _auth.currentUser != null;

  /// Enable offline persistence (call this once at app startup)
  /// Note: For Android/iOS, persistence is enabled by default.
  /// This method configures persistence settings if needed.
  Future<void> enableOfflinePersistence() async {
    try {
      // For web platforms, use enablePersistence
      // For Android/iOS, persistence is enabled by default via Settings
      // Configure settings if needed (persistence is enabled by default)
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to configure Firestore offline persistence: $e');
      }
      // Persistence might already be configured, which is fine
    }
  }

  /// Upload a report to Firestore
  Future<String> uploadReport(Report report) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to upload reports');
    }

    try {
      final accessContext = await _getCurrentUserAccessContext();
      final creatorAllowedCreationReportKeys = accessContext.isAdmin
          ? _reportTypesByAccessKey.keys.toSet()
          : accessContext.allowedCreationReportKeys;

      // If report has a Firestore ID, update it; otherwise create new
      if (report.firestoreId != null) {
        final reportData = _reportToFirestoreForUpdate(
          report,
          creatorAllowedCreationReportKeys: creatorAllowedCreationReportKeys,
        );
        await _firestore
            .collection(_reportsCollection)
            .doc(report.firestoreId)
            .update(reportData);
        return report.firestoreId!;
      } else {
        final reportData = _reportToFirestoreForCreate(
          report,
          creatorAllowedCreationReportKeys: creatorAllowedCreationReportKeys,
        );
        final docRef =
            await _firestore.collection(_reportsCollection).add(reportData);
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
      final accessContext = await _getCurrentUserAccessContext();
      if (!accessContext.isAdmin && accessContext.allowedReportTypes.isEmpty) {
        return [];
      }
      if (!accessContext.isAdmin &&
          accessContext.canViewSharedArchive &&
          accessContext.allowedCreationReportKeys.isEmpty) {
        return [];
      }
      Query<Map<String, dynamic>> query =
          _firestore.collection(_reportsCollection).orderBy(
                'date',
                descending: true,
              );
      if (!accessContext.isAdmin &&
          accessContext.allowedReportTypes.isNotEmpty) {
        query = query.where('type',
            whereIn: accessContext.allowedReportTypes.toList());
      }
      if (!accessContext.canViewSharedArchive) {
        query = query.where('userId', isEqualTo: _userId);
      }
      final snapshot = await query.get();
      final allowedDocs = _filterSharedArchiveDocs(
        docs: snapshot.docs,
        accessContext: accessContext,
      );

      return allowedDocs
          .map((doc) => _reportFromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to download reports from Firestore: $e');
    }
  }

  /// Download reports in pages (for large datasets)
  Future<ReportPage> downloadReportsPage({
    DocumentSnapshot? startAfter,
    int limit = 50,
  }) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to download reports');
    }

    try {
      final accessContext = await _getCurrentUserAccessContext();
      if (!accessContext.isAdmin && accessContext.allowedReportTypes.isEmpty) {
        return ReportPage(reports: const [], lastDocument: null);
      }
      if (!accessContext.isAdmin &&
          accessContext.canViewSharedArchive &&
          accessContext.allowedCreationReportKeys.isEmpty) {
        return ReportPage(reports: const [], lastDocument: null);
      }
      Query<Map<String, dynamic>> query = _firestore
          .collection(_reportsCollection)
          .orderBy('date', descending: true)
          .limit(limit);
      if (!accessContext.isAdmin &&
          accessContext.allowedReportTypes.isNotEmpty) {
        query = query.where('type',
            whereIn: accessContext.allowedReportTypes.toList());
      }
      if (!accessContext.canViewSharedArchive) {
        query = query.where('userId', isEqualTo: _userId);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final allowedDocs = _filterSharedArchiveDocs(
        docs: snapshot.docs,
        accessContext: accessContext,
      );

      return ReportPage(
        reports: allowedDocs
            .map((doc) => _reportFromFirestore(doc.id, doc.data()))
            .toList(),
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } catch (e) {
      throw Exception('Failed to download paged reports: $e');
    }
  }

  /// Get reports stream (real-time updates)
  Stream<List<Report>> getReportsStream() {
    if (!isAuthenticated) {
      return Stream.value([]);
    }

    return Stream.fromFuture(_getCurrentUserAccessContext())
        .asyncExpand((accessContext) {
      if (!accessContext.isAdmin && accessContext.allowedReportTypes.isEmpty) {
        return Stream.value(const <Report>[]);
      }
      if (!accessContext.isAdmin &&
          accessContext.canViewSharedArchive &&
          accessContext.allowedCreationReportKeys.isEmpty) {
        return Stream.value(const <Report>[]);
      }
      Query<Map<String, dynamic>> query = _firestore
          .collection(_reportsCollection)
          .orderBy('date', descending: true);
      if (!accessContext.isAdmin &&
          accessContext.allowedReportTypes.isNotEmpty) {
        query = query.where('type',
            whereIn: accessContext.allowedReportTypes.toList());
      }
      if (!accessContext.canViewSharedArchive) {
        query = query.where('userId', isEqualTo: _userId);
      }
      return query.snapshots().map((snapshot) {
        final allowedDocs = _filterSharedArchiveDocs(
          docs: snapshot.docs,
          accessContext: accessContext,
        );
        return allowedDocs
            .map((doc) => _reportFromFirestore(doc.id, doc.data()))
            .toList();
      });
    });
  }

  /// Delete a report from Firestore
  Future<void> deleteReport(String firestoreId) async {
    if (!isAuthenticated) {
      throw Exception('User must be authenticated to delete reports');
    }

    try {
      await _firestore.collection(_reportsCollection).doc(firestoreId).delete();
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
      final accessContext = await _getCurrentUserAccessContext();
      final creatorAllowedCreationReportKeys = accessContext.isAdmin
          ? _reportTypesByAccessKey.keys.toSet()
          : accessContext.allowedCreationReportKeys;
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final report in localReports) {
        if (report.firestoreId == null) {
          // New report - add to batch
          final docRef = _firestore.collection(_reportsCollection).doc();
          batch.set(
            docRef,
            _reportToFirestoreForCreate(
              report,
              creatorAllowedCreationReportKeys:
                  creatorAllowedCreationReportKeys,
            ),
          );
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
  Map<String, dynamic> _reportToFirestoreForCreate(
    Report report, {
    required Set<String> creatorAllowedCreationReportKeys,
  }) {
    return {
      'userId': _userId,
      'description': report.description,
      'date': Timestamp.fromDate(report.date),
      'group': report.group,
      'type': report.type,
      'reportAccessKey': _accessKeyByReportType[report.type],
      'creatorAllowedCreationReportKeys':
          creatorAllowedCreationReportKeys.toList()..sort(),
      'additionalData': report.additionalData,
      'localId': report.id, // Keep local SQLite ID for reference
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert Report to Firestore update payload
  Map<String, dynamic> _reportToFirestoreForUpdate(
    Report report, {
    required Set<String> creatorAllowedCreationReportKeys,
  }) {
    return {
      'description': report.description,
      'date': Timestamp.fromDate(report.date),
      'group': report.group,
      'type': report.type,
      'reportAccessKey': _accessKeyByReportType[report.type],
      'creatorAllowedCreationReportKeys':
          creatorAllowedCreationReportKeys.toList()..sort(),
      'additionalData': report.additionalData,
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

class _ReportAccessContext {
  final bool canViewSharedArchive;
  final Set<String> allowedReportTypes;
  final Set<String> allowedCreationReportKeys;

  bool get isAdmin => canViewSharedArchive && allowedReportTypes.isEmpty;

  const _ReportAccessContext({
    required this.canViewSharedArchive,
    this.allowedReportTypes = const <String>{},
    this.allowedCreationReportKeys = const <String>{},
  });
}

class ReportPage {
  final List<Report> reports;
  final DocumentSnapshot? lastDocument;

  ReportPage({
    required this.reports,
    required this.lastDocument,
  });
}
