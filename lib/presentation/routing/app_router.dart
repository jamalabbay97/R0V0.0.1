import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/providers/auth_provider.dart';
import 'package:r0/presentation/providers/role_provider.dart';
import 'package:r0/presentation/routing/role_guard.dart';
import 'package:r0/presentation/screens/admin_users_screen.dart';
import 'package:r0/presentation/screens/home_screen.dart';
import 'package:r0/presentation/screens/login_screen.dart';
import 'package:r0/presentation/screens/profile_settings_screen.dart';

/// Entry routing after login.
class AppRouter {
  static const String adminUsersRoute = '/admin/users';
  static const String profileSettingsRoute = '/settings/profile';

  static Widget appEntry() {
    return Consumer2<AuthProvider, RoleProvider>(
      builder: (context, authProvider, roleProvider, _) {
        if (authProvider.isLoading || roleProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        return const HomeScreen();
      },
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case adminUsersRoute:
        return MaterialPageRoute(
          builder: (_) => const RoleGuard(
            allowedRoles: {'admin', 'manager'},
            child: AdminUsersScreen(),
          ),
        );
      case profileSettingsRoute:
        return MaterialPageRoute(
          builder: (_) => const ProfileSettingsScreen(),
        );
      default:
        return MaterialPageRoute(builder: (_) => appEntry());
    }
  }
}
