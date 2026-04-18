import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Employee management screen for administrators.
class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  static const List<String> _roles = ['employee', 'manager', 'admin'];

  Future<void> _updateRole(String userId, String role) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Users'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load users: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final email = (data['email'] as String?) ?? '(no email)';
              final name = (data['displayName'] as String?) ?? 'Unnamed user';
              final currentRole =
                  (data['role'] as String?)?.toLowerCase() ?? 'employee';

              return ListTile(
                title: Text(name),
                subtitle: Text(email),
                trailing: DropdownButton<String>(
                  value:
                      _roles.contains(currentRole) ? currentRole : 'employee',
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        ),
                      )
                      .toList(),
                  onChanged: (value) async {
                    if (value == null || value == currentRole) {
                      return;
                    }
                    await _updateRole(doc.id, value);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
