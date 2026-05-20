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
  Timer? _loadingTimeout;

  String? _role;
  bool _isLoading = false;
  String? _errorMessage;

  String? get role => _role;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _role == 'admin';
  bool get isManager => _role == 'manager';
  bool get isAdminOrManager => isAdmin || isManager;

  void onAuthStateChanged(User? user) {
    final nextUserId = user?.uid;
    if (_currentUserId == nextUserId) {
      return;
    }

    _currentUserId = nextUserId;
    _roleSubscription?.cancel();
    _roleSubscription = null;
    _loadingTimeout?.cancel();
    _loadingTimeout = null;

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

    // Safety net: if Firestore never responds (e.g. no network),
    // clear the loading state after 10 seconds so the UI doesn't hang.
    _loadingTimeout = Timer(const Duration(seconds: 10), () {
      if (_isLoading) {
        _isLoading = false;
        _errorMessage = 'Could not reach server. Check your connection.';
        notifyListeners();
      }
    });

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
      _loadingTimeout?.cancel();
      final data = snapshot.data();
      final isDeleted = data?['isDeleted'] == true;
      if (isDeleted) {
        _role = null;
        _isLoading = false;
        _errorMessage =
            'Your account has been deactivated. Please contact an administrator.';
        FirebaseAuth.instance.signOut();
        notifyListeners();
        return;
      }
      _role = (data?['role'] as String?) ?? 'employee';
      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _loadingTimeout?.cancel();
      _role = null;
      _isLoading = false;
      _errorMessage = 'Failed to load role: $error';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _loadingTimeout?.cancel();
    _roleSubscription?.cancel();
    super.dispose();
  }
}
