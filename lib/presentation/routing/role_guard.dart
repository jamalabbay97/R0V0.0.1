import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/providers/role_provider.dart';

/// Screen protection based on user role.
class RoleGuard extends StatelessWidget {
  const RoleGuard({
    super.key,
    required this.allowedRoles,
    required this.child,
    this.fallback,
  });

  final Set<String> allowedRoles;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final roleProvider = context.watch<RoleProvider>();

    if (roleProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final role = roleProvider.role;
    if (role != null && allowedRoles.contains(role)) {
      return child;
    }

    return fallback ?? const _UnauthorizedScreen();
  }
}

class _UnauthorizedScreen extends StatelessWidget {
  const _UnauthorizedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'You do not have permission to access this page.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
