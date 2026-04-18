import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Reads and updates user authorization role metadata.
class AuthRoleService {
  AuthRoleService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String defaultRole = 'employee';

  User? get currentUser => _auth.currentUser;

  Future<String> fetchRole({String? uid}) async {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) {
      return defaultRole;
    }

    final snapshot = await _firestore.collection('users').doc(targetUid).get();
    final value = snapshot.data()?['role'];

    if (value is String && value.trim().isNotEmpty) {
      return value.toLowerCase();
    }
    return defaultRole;
  }

  Stream<String> watchRole({String? uid}) {
    final targetUid = uid ?? currentUser?.uid;
    if (targetUid == null) {
      return Stream<String>.value(defaultRole);
    }

    return _firestore.collection('users').doc(targetUid).snapshots().map((doc) {
      final value = doc.data()?['role'];
      if (value is String && value.trim().isNotEmpty) {
        return value.toLowerCase();
      }
      return defaultRole;
    });
  }
}
