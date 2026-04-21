import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ReportDefinition {
  final String key;
  final bool enabled;
  final int order;

  const ReportDefinition({
    required this.key,
    required this.enabled,
    required this.order,
  });

  factory ReportDefinition.fromMap(String key, Map<String, dynamic> data) {
    return ReportDefinition(
      key: key,
      enabled: (data['enabled'] as bool?) ?? true,
      order: (data['order'] as num?)?.toInt() ?? 999,
    );
  }
}

class ReportAccessProvider extends ChangeNotifier {
  ReportAccessProvider();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _defsSub;

  static const List<String> defaultReportKeys = [
    'r0_report',
    'activity_report',
    'daily_report',
    'truck_tracking',
    'machines_stopped',
    'reports_archive',
  ];

  String? _userId;
  bool _isLoading = false;
  Set<String> _assignedReportKeys = {};
  final Map<String, ReportDefinition> _definitionsByKey = {};

  bool get isLoading => _isLoading;
  Set<String> get assignedReportKeys => _assignedReportKeys;
  List<ReportDefinition> get definitions {
    if (_definitionsByKey.isEmpty) {
      return [
        for (var i = 0; i < defaultReportKeys.length; i++)
          ReportDefinition(key: defaultReportKeys[i], enabled: true, order: i),
      ];
    }

    final defs = _definitionsByKey.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return defs;
  }

  List<String> get orderedVisibleReportKeys {
    final visible = visibleReportKeys;
    return definitions
        .where((def) => visible.contains(def.key))
        .map((def) => def.key)
        .toList();
  }

  Set<String> get visibleReportKeys {
    final enabled = {
      for (final def in definitions)
        if (def.enabled) def.key,
    };
    return _assignedReportKeys.intersection(enabled);
  }

  void onAuthStateChanged(User? user) {
    final nextUserId = user?.uid;
    if (_userId == nextUserId) {
      return;
    }

    _userId = nextUserId;
    _userSub?.cancel();
    _defsSub?.cancel();

    _assignedReportKeys = {};
    _definitionsByKey.clear();

    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    _userSub =
        _firestore.collection('users').doc(user.uid).snapshots().listen((doc) {
      final data = doc.data();
      final role = (data?['role'] as String?)?.toLowerCase();
      final keys = (data?['allowedReports'] as List<dynamic>?)
          ?.whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      _assignedReportKeys =
          role == 'admin' ? defaultReportKeys.toSet() : (keys ?? <String>{});
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });

    _defsSub = _firestore.collection('report_definitions').snapshots().listen(
        (snapshot) {
      _definitionsByKey
        ..clear()
        ..addEntries(snapshot.docs.map((doc) {
          return MapEntry(
            doc.id,
            ReportDefinition.fromMap(doc.id, doc.data()),
          );
        }));
      notifyListeners();
    }, onError: (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _defsSub?.cancel();
    super.dispose();
  }
}
