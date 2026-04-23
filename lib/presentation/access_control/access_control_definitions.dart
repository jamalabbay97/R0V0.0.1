import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:r0/presentation/providers/report_access_provider.dart';

class AccessControlDefinitions {
  static const Map<String, String> reportLabels = {
    'r0_report': 'R0 Report',
    'activity_report': 'Activity Report',
    'daily_report': 'Daily Report',
    'truck_tracking': 'Truck Tracking',
    'machines_stopped': 'Machines/Equipment Stopped',
    'reports_archive': 'Reports Archive',
  };

  static const Map<String, Set<String>> reportTypesByAccessKey = {
    'r0_report': {'R0'},
    'activity_report': {'Activity TNB'},
    'daily_report': {'daily TSUD', 'Daily TSUD'},
    'truck_tracking': {'Suivi Camion', 'Chargeuse', 'Pelle'},
    'machines_stopped': {'Machine/Engin Arrêtés'},
  };

  static const Map<String, String> capabilityLabels = {
    'can_create_reports': 'Create and submit reports',
    'can_edit_reports': 'Edit existing reports',
    'can_export_reports': 'Export reports',
    'can_manage_users': 'Manage users',
    'can_manage_visibility': 'Manage feature visibility',
  };

  static const Set<String> adminDefaultCapabilities = {
    'can_create_reports',
    'can_edit_reports',
    'can_export_reports',
    'can_manage_users',
    'can_manage_visibility',
  };

  static const Set<String> employeeDefaultCapabilities = {
    'can_create_reports',
  };

  static Set<String> effectiveCapabilities(
    String role,
    Set<String>? assignedCapabilities,
  ) {
    if (role == 'admin') {
      return adminDefaultCapabilities;
    }

    if (assignedCapabilities != null && assignedCapabilities.isNotEmpty) {
      return assignedCapabilities.intersection(capabilityLabels.keys.toSet());
    }

    return employeeDefaultCapabilities;
  }

  static bool isPrimaryProtectedAccount({
    required String uid,
    String? email,
  }) {
    final primaryUid = dotenv.env['PRIMARY_ACCOUNT_UID']?.trim() ?? '';
    final primaryEmail =
        (dotenv.env['PRIMARY_ACCOUNT_EMAIL']?.trim().toLowerCase()) ?? '';

    if (primaryUid.isNotEmpty && uid == primaryUid) {
      return true;
    }

    if (primaryEmail.isNotEmpty && (email?.toLowerCase() == primaryEmail)) {
      return true;
    }

    return false;
  }

  static List<String> get allReportKeys =>
      ReportAccessProvider.defaultReportKeys.toList(growable: false);

  static String? accessKeyForReportType(String type) {
    for (final entry in reportTypesByAccessKey.entries) {
      if (entry.value.contains(type)) {
        return entry.key;
      }
    }
    return null;
  }
}
