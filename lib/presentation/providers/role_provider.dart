import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Provider that loads and tracks the signed-in user's role from Firestore.
class RoleProvider extends ChangeNotifier {
  RoleProvider();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleSubscription;
  String? _currentUserId;

  String? _role;
  bool _isLoading = false;
  String? _errorMessage;

  String? get role => _role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _role == 'admin';

  void onAuthStateChanged(User? user) {
    final nextUserId = user?.uid;
    if (_currentUserId == nextUserId) {
      return;
    }

    _currentUserId = nextUserId;
    _roleSubscription?.cancel();
    _roleSubscription = null;

    if (user == null) {
      _role = null;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    unawaited(_firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'displayName': user.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));

    _roleSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      _role = (data?['role'] as String?) ?? 'employee';
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _role = null;
      _isLoading = false;
      _errorMessage = 'Failed to load role: $error';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _roleSubscription?.cancel();
    super.dispose();
  }
}
