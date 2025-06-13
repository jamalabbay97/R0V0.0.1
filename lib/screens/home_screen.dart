import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:r0_app/screens/r0_report_screen.dart';
import 'package:r0_app/screens/reports_screen.dart';
import 'package:r0_app/screens/settings_screen.dart';
import 'package:r0_app/screens/activity_report_screen.dart';
import 'package:r0_app/screens/daily_report_screen.dart';
import 'package:r0_app/screens/truck_tracking_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.home),
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16.0),
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
                  selectedDate: DateTime.now(),
                  formKey: GlobalKey<FormState>(),
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