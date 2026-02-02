import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/screens/r0_report_screen.dart';
import 'package:r0/screens/activity_report_screen.dart';
import 'package:r0/screens/daily_report_screen.dart';
import 'package:r0/screens/truck_tracking_screen.dart';
import 'package:r0/screens/machines_equipment_stopped_screen.dart';
import 'package:r0/screens/reports_screen.dart';
import 'package:r0/screens/settings_screen.dart';
import 'package:r0/widgets/custom_widgets.dart';
import 'package:r0/widgets/logo_widget.dart';
import 'package:r0/theme.dart';

/// Home Dashboard Screen
///
/// Displays the main dashboard with navigation cards to different report types
/// and the reports archive. Follows the OCP Reports UI Design Specification.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Get current date for display
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header with OCP Logo and Title
            _buildHeader(context, theme, dateStr, l10n),

            // Scrollable report cards grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.availableReports,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildReportCardsGrid(context, l10n, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the header section with logo and title
  Widget _buildHeader(BuildContext context, ThemeData theme, String date,
      AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // OCP Logo
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const OcpLogo(size: 48),
              ),
              const SizedBox(width: 12),

              // Title and Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.ocpReports,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      date,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundLight,
                  foregroundColor: theme.colorScheme.primary,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
                tooltip: l10n.settingsTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the grid of report cards
  Widget _buildReportCardsGrid(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final reportCards = [
      _ReportCardData(
        title: l10n.r0Report,
        description: l10n.r0Description,
        icon: Icons.assignment_outlined,
        color: AppColors.primary,
        onTap: () => _navigateToR0Report(context),
      ),
      _ReportCardData(
        title: l10n.activityReport,
        description: l10n.activityReportDescription,
        icon: Icons.work_outline,
        color: AppColors.secondary,
        onTap: () => _navigateToActivityReport(context),
      ),
      _ReportCardData(
        title: l10n.dailyReport,
        description: l10n.dailyReportDescription,
        icon: Icons.today_outlined,
        color: AppColors.warning,
        onTap: () => _navigateToDailyReport(context),
      ),
      _ReportCardData(
        title: l10n.truckTracking,
        description: l10n.truckTrackingDescription,
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF1976D2), // Blue
        onTap: () => _navigateToTruckTracking(context),
      ),
      _ReportCardData(
        title: l10n.machinesStoppedTitleShort,
        description: l10n.machinesStoppedDescription,
        icon: Icons.build_outlined,
        color: AppColors.error,
        onTap: () => _navigateToMachinesStopped(context),
      ),
      _ReportCardData(
        title: l10n.reportsArchive,
        description: l10n.reportsArchiveDescription,
        icon: Icons.archive_outlined,
        color: const Color(0xFF757575), // Grey
        onTap: () => _navigateToReportsArchive(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85, // Taller cards for better info
      ),
      itemCount: reportCards.length,
      itemBuilder: (context, index) {
        return _buildReportCard(context, reportCards[index], theme);
      },
    );
  }

  /// Builds a single report card
  Widget _buildReportCard(
    BuildContext context,
    _ReportCardData cardData,
    ThemeData theme,
  ) {
    return OCPCard(
      onTap: cardData.onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with colored background
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardData.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              cardData.icon,
              size: 28,
              color: cardData.color,
            ),
          ),
          const Spacer(),

          // Title
          Text(
            cardData.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            cardData.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Navigation methods
  void _navigateToR0Report(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const R0Report(),
      ),
    );
  }

  void _navigateToActivityReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ActivityReportScreen(),
      ),
    );
  }

  void _navigateToDailyReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DailyReportScreen(),
      ),
    );
  }

  void _navigateToTruckTracking(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TruckTrackingScreen(
          formKey: GlobalKey<FormState>(),
        ),
      ),
    );
  }

  void _navigateToMachinesStopped(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MachinesEquipmentStoppedScreen(),
      ),
    );
  }

  void _navigateToReportsArchive(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportsScreen(),
      ),
    );
  }
}

/// Data class for report card configuration
class _ReportCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ReportCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
