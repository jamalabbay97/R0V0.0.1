import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/access_control/access_control_definitions.dart';
import 'package:r0/presentation/providers/auth_provider.dart';
import 'package:r0/presentation/providers/language_provider.dart';
import 'package:r0/presentation/providers/role_provider.dart';
import 'package:r0/presentation/routing/app_router.dart';
import 'package:r0/presentation/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    final roleProvider = context.watch<RoleProvider>();
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.user;
    final displayName = currentUser?.displayName?.trim();
    final fallbackEmail = currentUser?.email?.trim();
    final profileName = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (fallbackEmail != null && fallbackEmail.isNotEmpty)
            ? fallbackEmail
            : 'User';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settings),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            children: [
              ListTile(
                title: Text(AppLocalizations.of(context)!.language),
                trailing: DropdownButton<Locale>(
                  value: languageProvider.locale,
                  underline: Container(),
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: const Locale('en'),
                      child: Text(AppLocalizations.of(context)!.english),
                    ),
                    DropdownMenuItem(
                      value: const Locale('fr'),
                      child: Text(AppLocalizations.of(context)!.french),
                    ),
                  ],
                  onChanged: (Locale? newLocale) {
                    if (newLocale != null) {
                      languageProvider.setLocale(newLocale);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: Text(AppLocalizations.of(context)!.darkMode),
                trailing: Switch(
                  value: Provider.of<ThemeProvider>(context).themeMode ==
                      ThemeMode.dark,
                  onChanged: (value) {
                    Provider.of<ThemeProvider>(context, listen: false)
                        .toggleTheme(value);
                  },
                ),
              ),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  child: Text(
                    profileName.substring(0, 1).toUpperCase(),
                  ),
                ),
                title: const Text('Profile'),
                subtitle: const Text('Manage your personal account details.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(
                  AppRouter.profileSettingsRoute,
                ),
              ),
              const Divider(),
              if (roleProvider.isAdminOrManager)
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Store settings'),
                  subtitle: const Text(
                    'Manage users, roles, and feature visibility.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRouter.adminUsersRoute,
                  ),
                ),
              if (currentUser != null &&
                  AccessControlDefinitions.isPrimaryProtectedAccount(
                    uid: currentUser.uid,
                    email: currentUser.email,
                  ))
                const ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Primary account protection'),
                  subtitle: Text(
                    'This account is protected and cannot be modified by other admins.',
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          final ok = await authProvider.signOut();
                          if (!context.mounted) {
                            return;
                          }

                          if (ok) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => AppRouter.appEntry(),
                              ),
                              (route) => false,
                            );
                            return;
                          }

                          final message = authProvider.errorMessage ??
                              'Unable to sign out. Please try again.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                  icon: authProvider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout),
                  label: Text(
                    authProvider.isLoading ? 'Signing out...' : 'Log out',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
