import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/screens/r0_report_screen.dart';
import 'package:r0/screens/reports_screen.dart';
import 'package:r0/screens/settings_screen.dart';
import 'package:r0/screens/activity_report_screen.dart';
import 'package:r0/screens/daily_report_screen.dart';
import 'package:r0/screens/truck_tracking_screen.dart';
import 'package:r0/screens/machines_equipment_stopped_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        title: const Text("R0 Report"),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = 2;
          double maxWidth = constraints.maxWidth;
          if (maxWidth >= 900) {
            crossAxisCount = 4;
          } else if (maxWidth >= 600) {
            crossAxisCount = 3;
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: GridView.count(
                crossAxisCount: crossAxisCount,
                padding: const EdgeInsets.all(16.0),
                shrinkWrap: true,
                children: [
                  _buildMenuCard(
                    context,
                    l10n.r0Report,
                    Icons.assignment,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => R0Report(selectedDate: DateTime.now())),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.activityReport,
                    Icons.assessment,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ActivityReportScreen(selectedDate: DateTime.now())),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.dailyReport,
                    Icons.calendar_today,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DailyReportScreen()),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.truckTracking,
                    Icons.local_shipping,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TruckTrackingScreen(
                          formKey: GlobalKey<FormState>(),
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.machinesEquipmentStopped,
                    Icons.stop_circle,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MachinesEquipmentStoppedScreen(
                          selectedDate: DateTime.now(),
                        ),
                      ),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.reports,
                    Icons.list_alt,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ReportsScreen()),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    l10n.settings,
                    Icons.settings,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 