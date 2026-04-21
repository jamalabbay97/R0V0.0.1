import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:r0/presentation/access_control/access_control_definitions.dart';
import 'package:r0/presentation/providers/report_access_provider.dart';
import 'package:r0/presentation/screens/home_screen.dart';

/// Employee and feature management screen for administrators.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const List<String> _roles = ['employee', 'manager', 'admin'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _updateRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setUserReports(String userId, Set<String> reports) async {
    await _firestore.collection('users').doc(userId).set({
      'allowedReports': reports.toList()..sort(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setUserCapabilities(
    String userId,
    Set<String> capabilities,
  ) async {
    await _firestore.collection('users').doc(userId).set({
      'capabilities': capabilities.toList()..sort(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setReportEnabled(String key, bool enabled) async {
    final defaultOrder =
        ReportAccessProvider.defaultReportKeys.indexOf(key).clamp(0, 999);
    await _firestore.collection('report_definitions').doc(key).set({
      'enabled': enabled,
      'order': defaultOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _addReportToCatalog(String key) async {
    final defaultOrder =
        ReportAccessProvider.defaultReportKeys.indexOf(key).clamp(0, 999);
    await _firestore.collection('report_definitions').doc(key).set({
      'enabled': true,
      'order': defaultOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _removeFromCatalog(String key) async {
    await _firestore.collection('report_definitions').doc(key).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Control Center'),
        actions: [
          IconButton(
            tooltip: 'Open dashboard',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('report_definitions').snapshots(),
        builder: (context, reportSnapshot) {
          final reportDocs = reportSnapshot.data?.docs ?? const [];
          final activeCatalog = {
            for (final doc in reportDocs) doc.id,
          };

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Application Controls',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable/hide report modules globally. Removed modules are deleted from the catalog.',
                      ),
                      const SizedBox(height: 12),
                      ...AccessControlDefinitions.allReportKeys.map((key) {
                        final isConfigured = activeCatalog.contains(key);
                        final isEnabled = isConfigured
                            ? ((reportSnapshot.data?.docs
                                    .firstWhere((d) => d.id == key)
                                    .data()['enabled'] as bool?) ??
                                true)
                            : false;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            AccessControlDefinitions.reportLabels[key] ?? key,
                          ),
                          subtitle: Text(
                            isConfigured
                                ? (isEnabled ? 'Visible' : 'Hidden')
                                : 'Not in catalog',
                          ),
                          leading: Switch(
                            value: isEnabled,
                            onChanged: isConfigured
                                ? (value) => _setReportEnabled(key, value)
                                : null,
                          ),
                          trailing: isConfigured
                              ? IconButton(
                                  tooltip: 'Remove from catalog',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _removeFromCatalog(key),
                                )
                              : TextButton.icon(
                                  onPressed: () => _addReportToCatalog(key),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add'),
                                ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Users',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('Failed to load users: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('No users found.'),
                      ),
                    );
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final authUser = FirebaseAuth.instance.currentUser;
                      final isCurrentUser = authUser?.uid == doc.id;
                      final fallbackEmail =
                          isCurrentUser ? authUser?.email : null;
                      final email = (data['email'] as String?) ??
                          fallbackEmail ??
                          '(no email)';
                      final name = (data['displayName'] as String?) ??
                          (isCurrentUser ? authUser?.displayName : null) ??
                          (email != '(no email)'
                              ? email.split('@').first
                              : null) ??
                          'User ${doc.id.substring(0, 6)}';
                      final currentRole =
                          (data['role'] as String?)?.toLowerCase() ??
                              'employee';
                      final isPrimaryAccount =
                          AccessControlDefinitions.isPrimaryProtectedAccount(
                        uid: doc.id,
                        email: email == '(no email)' ? null : email,
                      );
                      final isReadonlyAccount = isPrimaryAccount;

                      final rawAssignedReports =
                          (data['allowedReports'] as List<dynamic>?)
                              ?.whereType<String>()
                              .toSet();
                      final rawCapabilities =
                          (data['capabilities'] as List<dynamic>?)
                              ?.whereType<String>()
                              .toSet();
                      final effectiveCapabilities =
                          AccessControlDefinitions.effectiveCapabilities(
                        currentRole,
                        rawCapabilities,
                      );

                      final assignedReports =
                          ((data['allowedReports'] as List<dynamic>?)
                                      ?.whereType<String>()
                                      .toSet() ??
                                  (currentRole == 'admin'
                                      ? ReportAccessProvider.defaultReportKeys
                                          .toSet()
                                      : <String>{}))
                              .intersection(
                        ReportAccessProvider.defaultReportKeys.toSet(),
                      );

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(email),
                                        Text(
                                          'uid: ${doc.id}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      DropdownButton<String>(
                                        value: _roles.contains(currentRole)
                                            ? currentRole
                                            : 'employee',
                                        items: _roles
                                            .map(
                                              (role) =>
                                                  DropdownMenuItem<String>(
                                                value: role,
                                                child: Text(role),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: isReadonlyAccount
                                            ? null
                                            : (value) async {
                                                if (value == null ||
                                                    value == currentRole) {
                                                  return;
                                                }
                                                await _updateRole(
                                                  doc.id,
                                                  value,
                                                );
                                              },
                                      ),
                                      if (isPrimaryAccount)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Chip(
                                            label: Text(
                                              'Primary account (locked)',
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              const Text(
                                'Assigned reports',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: AccessControlDefinitions.allReportKeys
                                    .map((key) {
                                  final isVisibleInCatalog =
                                      activeCatalog.contains(key);
                                  final selected = (currentRole == 'admin' ||
                                          assignedReports.contains(key)) &&
                                      isVisibleInCatalog;

                                  return FilterChip(
                                    label: Text(
                                      AccessControlDefinitions
                                              .reportLabels[key] ??
                                          key,
                                    ),
                                    selected: selected,
                                    onSelected: !isVisibleInCatalog ||
                                            currentRole == 'admin' ||
                                            isReadonlyAccount
                                        ? null
                                        : (next) async {
                                            final nextReports =
                                                (rawAssignedReports ?? {})
                                                    .toSet();
                                            if (next) {
                                              nextReports.add(key);
                                            } else {
                                              nextReports.remove(key);
                                            }
                                            await _setUserReports(
                                              doc.id,
                                              nextReports,
                                            );
                                          },
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Permissions (what this user can do)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: AccessControlDefinitions
                                    .capabilityLabels.entries
                                    .map((entry) {
                                  final selected =
                                      effectiveCapabilities.contains(entry.key);
                                  return FilterChip(
                                    label: Text(entry.value),
                                    selected: selected,
                                    onSelected: currentRole == 'admin' ||
                                            isReadonlyAccount
                                        ? null
                                        : (next) async {
                                            final nextCapabilities =
                                                (rawCapabilities ?? {}).toSet();
                                            if (next) {
                                              nextCapabilities.add(entry.key);
                                            } else {
                                              nextCapabilities
                                                  .remove(entry.key);
                                            }
                                            await _setUserCapabilities(
                                              doc.id,
                                              nextCapabilities,
                                            );
                                          },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
