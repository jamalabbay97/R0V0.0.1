import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/providers/auth_provider.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _nameFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _didInit = false;
  bool _isEditingName = false;
  bool _isEditingPassword = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }

    final user = context.read<AuthProvider>().user;
    _displayNameController.text = _resolveDisplayName(user?.displayName, user?.email);
    _didInit = true;
  }

  String _resolveDisplayName(String? displayName, String? email) {
    final normalizedName = displayName?.trim();
    if (normalizedName != null && normalizedName.isNotEmpty) {
      return normalizedName;
    }
    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      return normalizedEmail;
    }
    return 'User';
  }

  Future<void> _saveDisplayName() async {
    final form = _nameFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.updateDisplayName(_displayNameController.text);
    if (!mounted) {
      return;
    }

    if (ok) {
      setState(() => _isEditingName = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          authProvider.errorMessage ??
              'Unable to update username. Please try again.',
        ),
      ),
    );
  }

  Future<void> _savePassword() async {
    final form = _passwordFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );
    if (!mounted) {
      return;
    }

    if (ok) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      setState(() => _isEditingPassword = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          authProvider.errorMessage ??
              'Unable to update password. Please try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final email = user?.email?.trim();
    final readOnlyEmail =
        (email != null && email.isNotEmpty) ? email : 'No email linked';
    final displayName = _resolveDisplayName(user?.displayName, user?.email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Account information'),
                subtitle: Text('Manage your username and password.'),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Username'),
                        subtitle: Text(displayName),
                        trailing: TextButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () {
                                  _displayNameController.text = displayName;
                                  setState(() => _isEditingName = !_isEditingName);
                                },
                          child: Text(_isEditingName ? 'Cancel' : 'Edit'),
                        ),
                      ),
                      if (_isEditingName) ...[
                        const Divider(),
                        Form(
                          key: _nameFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _displayNameController,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                  labelText: 'New username',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) {
                                    return 'Username is required.';
                                  }
                                  if (text.length < 2) {
                                    return 'Username must be at least 2 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _saveDisplayName,
                                  icon: const Icon(Icons.save_outlined),
                                  label: const Text('Save username'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(readOnlyEmail),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Email is fixed and cannot be edited for any user role.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Password'),
                        subtitle: const Text('Last password is hidden for security.'),
                        trailing: TextButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () {
                                  if (_isEditingPassword) {
                                    _currentPasswordController.clear();
                                    _newPasswordController.clear();
                                    _confirmPasswordController.clear();
                                  }
                                  setState(
                                    () => _isEditingPassword = !_isEditingPassword,
                                  );
                                },
                          child: Text(_isEditingPassword ? 'Cancel' : 'Change'),
                        ),
                      ),
                      if (_isEditingPassword) ...[
                        const Divider(),
                        Form(
                          key: _passwordFormKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _currentPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Current password',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if ((value ?? '').isEmpty) {
                                    return 'Current password is required.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'New password',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final text = value ?? '';
                                  if (text.isEmpty) {
                                    return 'New password is required.';
                                  }
                                  if (text.length < 6) {
                                    return 'Password must be at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm new password',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if ((value ?? '') != _newPasswordController.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : _savePassword,
                                  icon: const Icon(Icons.lock_reset_outlined),
                                  label: const Text('Update password'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
