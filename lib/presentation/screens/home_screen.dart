import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/presentation/screens/activity_report_screen.dart';
import 'package:r0/presentation/screens/daily_report_screen.dart';
import 'package:r0/presentation/screens/google_sheets_reports_screen.dart';
import 'package:r0/presentation/screens/machines_equipment_stopped_screen.dart';
import 'package:r0/presentation/screens/r0_report_screen.dart';
import 'package:r0/presentation/screens/reports_screen.dart';
import 'package:r0/presentation/screens/settings_screen.dart';
import 'package:r0/presentation/screens/shift_timeline_dashboard_screen.dart';
import 'package:r0/presentation/screens/truck_tracking_screen.dart';
import 'package:r0/presentation/widgets/custom_widgets.dart';
import 'package:r0/presentation/widgets/logo_widget.dart';
import 'package:r0/presentation/theme.dart';

/// Home Dashboard Screen with horizontal swipe navigation.
///
/// Displays the main dashboard with navigation cards to different report types
/// and the reports archive. Follows the OCP Reports UI Design Specification.
/// Swipe left on the main dashboard to open Google Sheets reports explorer.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  Future<void> _jumpToPage(int page) async {
    if (_currentPage == page) {
      return;
    }
    await _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;

    return Scaffold(
      body: Stack(
        children: [
          ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.stylus,
              },
            ),
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: const [
                _HomeDashboardPage(),
                GoogleSheetsReportsScreen(),
                ShiftTimelineDashboardScreen(),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _PageSwitcher(
                  currentPage: _currentPage,
                  onSelectPage: _jumpToPage,
                  compact: isCompact,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageSwitcher extends StatelessWidget {
  const _PageSwitcher({
    required this.currentPage,
    required this.onSelectPage,
    required this.compact,
  });

  final int currentPage;
  final ValueChanged<int> onSelectPage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final isSelected = index == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onSelectPage(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: isSelected ? 34 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    final segments = ['Dashboard', 'Archive', 'Timeline'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          segments.length,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelectPage(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: index == currentPage
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                child: Text(
                  segments[index],
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: index == currentPage
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeDashboardPage extends StatelessWidget {
  const _HomeDashboardPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";

    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildHeader(context, theme, dateStr, l10n),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.availableReports,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.swipe_left_alt_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Swipe left (or tap Sheets above) to open reports',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
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
      ),
    );
  }

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
      child: Row(
        children: [
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
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
    );
  }

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
        color: const Color(0xFF1976D2),
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
        color: const Color(0xFF757575),
        onTap: () => _navigateToReportsArchive(context),
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double childAspectRatio = 0.85;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      childAspectRatio = 1.1;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    } else if (screenWidth > 600) {
      crossAxisCount = 2;
      childAspectRatio = 0.95;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: reportCards.length,
      itemBuilder: (context, index) {
        return _buildReportCard(context, reportCards[index], theme);
      },
    );
  }

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
          Text(
            cardData.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
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
