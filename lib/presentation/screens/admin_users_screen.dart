import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/firebase_options.dart';
import 'package:r0/presentation/access_control/access_control_definitions.dart';
import 'package:r0/presentation/providers/role_provider.dart';
import 'package:r0/presentation/providers/report_access_provider.dart';
import 'package:r0/presentation/screens/home_screen.dart';

/// Employee and feature management screen for admins and managers.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  static const List<String> _roles = ['employee', 'manager', 'admin'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _createUserFormKey = GlobalKey<FormState>();
  String _selectedCreateRole = 'employee';
  bool _isCreatingUser = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updateRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _setUserReports(
    String userId,
    Set<String> reports, {
    String? reportCreationEntityId,
  }) async {
    final payload = {
      'allowedReports': reports.toList()..sort(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final entityId = reportCreationEntityId?.trim();
    if (entityId == null || entityId.isEmpty) {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(payload, SetOptions(merge: true));
      return;
    }

    final usersInSameEntity = await _firestore
        .collection('users')
        .where('reportCreationEntityId', isEqualTo: entityId)
        .get();

    if (usersInSameEntity.docs.isEmpty) {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(payload, SetOptions(merge: true));
      return;
    }

    final batch = _firestore.batch();
    for (final userDoc in usersInSameEntity.docs) {
      batch.set(userDoc.reference, payload, SetOptions(merge: true));
    }
    await batch.commit();
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

  Future<void> _createUserAccount() async {
    final form = _createUserFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final displayName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final role = _selectedCreateRole;
    final temporaryAppName =
        'user-provisioning-${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;

    setState(() => _isCreatingUser = true);
    try {
      secondaryApp = await Firebase.initializeApp(
        name: temporaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final createdUser = credential.user;
      if (createdUser == null) {
        throw FirebaseAuthException(
          code: 'internal-error',
          message: 'Unable to provision account.',
        );
      }

      if (displayName.isNotEmpty) {
        await createdUser.updateDisplayName(displayName);
      }

      await _firestore.collection('users').doc(createdUser.uid).set({
        'email': email,
        'displayName': displayName.isEmpty ? null : displayName,
        'role': role,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await secondaryAuth.signOut();

      if (!mounted) {
        return;
      }
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() => _selectedCreateRole = 'employee');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User account created for $email.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to create account.'),
        ),
      );
    } finally {
      if (secondaryApp != null) {
        await secondaryApp.delete();
      }
      if (mounted) {
        setState(() => _isCreatingUser = false);
      }
    }
  }

  Future<void> _deactivateUser({
    required String userId,
    required String email,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'isDeleted': true,
      'allowedReports': <String>[],
      'capabilities': <String>[],
      'role': 'employee',
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Account deactivated: $email')));
  }

  @override
  Widget build(BuildContext context) {
    final roleProvider = context.watch<RoleProvider>();
    final actorRole = roleProvider.role ?? 'employee';
    final isActorManager = actorRole == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store • Control Center'),
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
                        'Store settings',
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
              if (isActorManager)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Manager account restrictions'),
                    subtitle: Text(
                      'Managers can add, delete, and edit employee accounts, but cannot modify manager/admin accounts.',
                    ),
                  ),
                ),
              if (isActorManager) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _createUserFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add new user account',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.isEmpty || !text.contains('@')) {
                              return 'Please enter a valid email.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Temporary password',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final text = (value ?? '').trim();
                            if (text.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCreateRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: _roles
                              .where(
                                (role) => !isActorManager || role != 'admin',
                              )
                              .map(
                                (role) => DropdownMenuItem<String>(
                                  value: role,
                                  child: Text(role),
                                ),
                              )
                              .toList(),
                          onChanged: _isCreatingUser
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() => _selectedCreateRole = value);
                                },
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _isCreatingUser ? null : _createUserAccount,
                          icon: _isCreatingUser
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(
                            _isCreatingUser ? 'Creating...' : 'Create account',
                          ),
                        ),
                      ],
                    ),
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

                  final docs = snapshot.data!.docs.where((doc) {
                    final data = doc.data();
                    return data['isDeleted'] != true;
                  }).toList();
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
                      final isTargetManager = currentRole == 'manager';
                      final isTargetAdmin = currentRole == 'admin';
                      final isReadonlyAccount = isPrimaryAccount ||
                          (isActorManager &&
                              (isTargetManager || isTargetAdmin));

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
                      final reportCreationEntityId =
                          data['reportCreationEntityId'] as String?;

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
                                                if (isActorManager &&
                                                    value == 'admin') {
                                                  if (!mounted) {
                                                    return;
                                                  }
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'Managers cannot assign admin role.',
                                                      ),
                                                    ),
                                                  );
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
                                      if (isActorManager && isTargetManager)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 6),
                                          child: Chip(
                                            label: Text('Manager (locked)'),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: isReadonlyAccount || isCurrentUser
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (dialogContext) =>
                                                AlertDialog(
                                              title: const Text(
                                                'Deactivate account?',
                                              ),
                                              content: Text(
                                                'This will block $email from using the app until reactivated.',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(false),
                                                  child: const Text('Cancel'),
                                                ),
                                                FilledButton(
                                                  onPressed: () => Navigator.of(
                                                    dialogContext,
                                                  ).pop(true),
                                                  child: const Text(
                                                    'Deactivate',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirmed != true) {
                                            return;
                                          }
                                          await _deactivateUser(
                                            userId: doc.id,
                                            email: email,
                                          );
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete account'),
                                ),
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
                                              reportCreationEntityId:
                                                  reportCreationEntityId,
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
