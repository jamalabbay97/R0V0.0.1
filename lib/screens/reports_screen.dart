import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/services/time_calculation_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:uuid/uuid.dart';
import 'package:r0/data/r0_arrets_data.dart';

class _ShiftWindow {
  final String poste;
  final DateTime date;
  final DateTime start;
  final DateTime end;

  const _ShiftWindow({
    required this.poste,
    required this.date,
    required this.start,
    required this.end,
  });
}

class _ShiftPointer {
  final String poste;
  final DateTime date;

  const _ShiftPointer({required this.poste, required this.date});
}

class _CarryOverShift {
  final String poste;
  final DateTime date;
  final List<Map<String, dynamic>> arrets;

  _CarryOverShift({
    required this.poste,
    required this.date,
    List<Map<String, dynamic>>? arrets,
  }) : arrets = arrets ?? [];
}

class _CarryOverResult {
  final Report baseReport;
  final List<int> deleteIds;
  final List<Report> updateReports;
  final List<Report> insertReports;

  const _CarryOverResult({
    required this.baseReport,
    required this.deleteIds,
    required this.updateReports,
    required this.insertReports,
  });
}

/// ReportsScreen displays all saved reports with filtering capabilities.
///
/// Features:
/// - View all reports with details
/// - Filter reports by poste (3ème, 1er, 2ème)
/// - Edit and delete reports
/// - View detailed report information
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Report> _reports = [];
  List<Report> _filteredReports = [];
  bool _isLoading = true;
  String? _selectedPosteFilter;

  // Selection state management

  int? _selectedStopIndex;
  int? _selectedCounterIndex;
  int? _selectedStockIndex;

  // Available postes for filtering
  List<String> _availablePostes = [
    '3ème',
    '1er',
    '2ème',
  ];

  // Predefined truck numbers
  static const List<String> predefinedTrucks = [
    'W17',
    'W19',
    'TEREX 24',
    'TEREX 25',
    'TEREX 26',
    'TEREX 27',
    'TEREX 28',
    'TEREX 29',
    'TEREX 30',
    'TEREX 31',
    'TEREX 32',
  ];

  Map<String, List<String>> _arretsForReport(Map<String, dynamic> data) {
    return R0ArretsData.arretsForType(data['Type']?.toString());
  }

  final posteOrder = const ["3ème", "1er", "2ème"];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await _databaseHelper.getReports();
      setState(() {
        _reports = reports;
        _filterReports();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.errorSavingReport)),
        );
      }
    }
  }

  void _filterReports() {
    if (_selectedPosteFilter == null) {
      _filteredReports = _reports;
    } else {
      _filteredReports = _reports.where((report) {
        final additionalData = report.additionalData;
        if (additionalData == null) return false;

        // Check for different poste field names used in different report types
        final poste = additionalData['selectedPoste'] ??
            additionalData['poste'] ??
            additionalData['posteSelected'];

        // Debug: log the poste value for debugging (only in debug mode)
        if (kDebugMode && report.type == 'Suivi Camion') {
          debugPrint(
              'Report ${report.id}: type=${report.type}, poste=$poste, filter=$_selectedPosteFilter');
        }

        return poste == _selectedPosteFilter;
      }).toList();
    }

    // Update available postes based on existing reports
    _updateAvailablePostes();
  }

  void _updateAvailablePostes() {
    final Set<String> foundPostes = <String>{};

    for (final report in _reports) {
      final additionalData = report.additionalData;
      if (additionalData != null) {
        final poste = additionalData['selectedPoste'] ??
            additionalData['poste'] ??
            additionalData['posteSelected'];
        if (poste != null && poste.isNotEmpty) {
          foundPostes.add(poste);
        }
      }
    }

    // Add default postes if not found in reports
    foundPostes.addAll(['3ème', '1er', '2ème']);

    setState(() {
      _availablePostes = foundPostes.toList()..sort();
    });
  }

  void _onPosteFilterChanged(String? newValue) {
    setState(() {
      _selectedPosteFilter = newValue;
      _filterReports();
    });
  }

  // Helper function to recalculate H.A from Arrets for R0 reports
  double _parseNumeric(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  DateTime _getDateTimeFromTimeString(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]),
        int.parse(parts[1]));
  }

  DateTime _getDateTimeForShift(
    DateTime date,
    String timeStr,
    String poste,
  ) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    var targetDate = date;

    if (poste == "3ème") {
      final timeMinutes = hour * 60 + minute;
      const thirdShiftStartMinutes = 22 * 60 + 30;
      if (timeMinutes >= thirdShiftStartMinutes) {
        targetDate = date.subtract(const Duration(days: 1));
      }
    }

    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );
  }

  String _formatDateTimeToTimeString(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  _ShiftWindow _shiftWindow(String poste, DateTime date) {
    switch (poste) {
      case "3ème":
        final startDate = date.subtract(const Duration(days: 1));
        final start = _getDateTimeFromTimeString(startDate, "22:30");
        final end = _getDateTimeFromTimeString(date, "06:30");
        return _ShiftWindow(poste: poste, date: date, start: start, end: end);
      case "1er":
        return _ShiftWindow(
          poste: poste,
          date: date,
          start: _getDateTimeFromTimeString(date, "06:30"),
          end: _getDateTimeFromTimeString(date, "14:30"),
        );
      case "2ème":
      default:
        return _ShiftWindow(
          poste: poste,
          date: date,
          start: _getDateTimeFromTimeString(date, "14:30"),
          end: _getDateTimeFromTimeString(date, "22:30"),
        );
    }
  }

  int _posteOrderIndex(String poste) {
    return posteOrder.indexOf(poste);
  }

  _ShiftPointer _nextShift(_ShiftPointer current) {
    switch (current.poste) {
      case "3ème":
        return _ShiftPointer(poste: "1er", date: current.date);
      case "1er":
        return _ShiftPointer(poste: "2ème", date: current.date);
      case "2ème":
      default:
        return _ShiftPointer(
            poste: "3ème", date: current.date.add(const Duration(days: 1)));
    }
  }

  double _calculateDowntimeForShift(
    List<dynamic> arrets,
    _ShiftWindow shift,
    DateTime reportDate,
  ) {
    final ranges = <TimeRange>[];

    for (final arret in arrets) {
      if (arret is! Map) continue;
      final debut =
          (arret['OriginalStart'] ?? arret['Début'])?.toString() ?? '';
      final fin = (arret['OriginalEnd'] ?? arret['Fin'])?.toString() ?? '';
      if (debut.isEmpty || fin.isEmpty) continue;

      DateTime arretStart =
          _getDateTimeForShift(reportDate, debut, shift.poste);
      DateTime arretEnd = _getDateTimeForShift(reportDate, fin, shift.poste);

      if (arretEnd.isBefore(arretStart)) {
        arretEnd = arretEnd.add(const Duration(days: 1));
      }

      final effectiveStart =
          arretStart.isBefore(shift.start) ? shift.start : arretStart;
      final effectiveEnd = arretEnd.isAfter(shift.end) ? shift.end : arretEnd;

      if (effectiveStart.isBefore(effectiveEnd)) {
        final startMin = effectiveStart.difference(shift.start).inMinutes;
        final endMin = effectiveEnd.difference(shift.start).inMinutes;
        ranges.add(TimeRange(startMin, endMin));
      }
    }

    return TimeCalculationService.calculateTotalDowntime(ranges);
  }

  double _calculateR0Downtime(Map<String, dynamic> data, DateTime reportDate) {
    final poste =
        data['selectedPoste'] ?? data['poste'] ?? data['posteSelected'];
    final arrets = data['Arrets'] as List? ?? [];

    if (poste is String && poste.isNotEmpty) {
      final shift = _shiftWindow(poste, reportDate);
      return _calculateDowntimeForShift(arrets, shift, reportDate);
    }

    final rawRanges = <Map<String, String>>[];
    for (var arret in arrets) {
      if (arret is Map && arret['Début'] != null && arret['Fin'] != null) {
        final debut = arret['Début'].toString();
        final fin = arret['Fin'].toString();
        if (debut.isNotEmpty && fin.isNotEmpty) {
          rawRanges.add({'start': debut, 'end': fin});
        }
      }
    }

    final ranges = TimeCalculationService.parseTimeRanges(rawRanges);
    return TimeCalculationService.calculateTotalDowntime(ranges);
  }

  _CarryOverResult _prepareR0CarryOverUpdates(Report report) {
    final data = Map<String, dynamic>.from(report.additionalData ?? {});
    if (data['carryOverFrom'] != null) {
      return _CarryOverResult(
        baseReport: report,
        deleteIds: const [],
        updateReports: const [],
        insertReports: const [],
      );
    }

    final poste =
        data['selectedPoste'] ?? data['poste'] ?? data['posteSelected'];
    if (poste is! String || poste.isEmpty) {
      return _CarryOverResult(
        baseReport: report,
        deleteIds: const [],
        updateReports: const [],
        insertReports: const [],
      );
    }

    final currentShift = _shiftWindow(poste, report.date);
    final shiftStart = currentShift.start;
    final shiftEnd = currentShift.end;
    final arrets = data['Arrets'] as List? ?? [];

    final currentShiftArrets = <Map<String, dynamic>>[];
    final Map<String, _CarryOverShift> carryOverByShift = {};

    for (final arret in arrets) {
      if (arret is! Map) continue;
      final debut =
          (arret['OriginalStart'] ?? arret['Début'])?.toString() ?? '';
      final fin = (arret['OriginalEnd'] ?? arret['Fin'])?.toString() ?? '';
      if (debut.isEmpty || fin.isEmpty) continue;

      DateTime arretStart =
          _getDateTimeForShift(report.date, debut, currentShift.poste);
      DateTime arretEnd =
          _getDateTimeForShift(report.date, fin, currentShift.poste);

      if (arretEnd.isBefore(arretStart)) {
        arretEnd = arretEnd.add(const Duration(days: 1));
      }

      final effectiveStart =
          arretStart.isBefore(shiftStart) ? shiftStart : arretStart;
      final effectiveEnd = arretEnd.isAfter(shiftEnd) ? shiftEnd : arretEnd;

      if (effectiveStart.isBefore(effectiveEnd) &&
          effectiveStart.isBefore(shiftEnd) &&
          effectiveEnd.isAfter(shiftStart)) {
        currentShiftArrets.add({
          'Catégorie': arret['Catégorie'] ?? '',
          'Arret': arret['Arret'] ?? '',
          'Début': _formatDateTimeToTimeString(effectiveStart),
          'Fin': _formatDateTimeToTimeString(effectiveEnd),
          'OriginalStart': arret['OriginalStart'] ?? debut,
          'OriginalEnd': arret['OriginalEnd'] ?? fin,
        });
      }

      if (arretEnd.isAfter(shiftEnd)) {
        DateTime carryStart =
            arretStart.isBefore(shiftEnd) ? shiftEnd : arretStart;
        var pointer = _nextShift(
            _ShiftPointer(poste: currentShift.poste, date: currentShift.date));

        while (carryStart.isBefore(arretEnd)) {
          final nextShift = _shiftWindow(pointer.poste, pointer.date);
          final segmentStart = carryStart.isAfter(nextShift.start)
              ? carryStart
              : nextShift.start;
          final segmentEnd =
              arretEnd.isBefore(nextShift.end) ? arretEnd : nextShift.end;

          if (segmentStart.isBefore(segmentEnd)) {
            final key =
                '${nextShift.poste}-${nextShift.date.toIso8601String().split('T').first}';
            carryOverByShift.putIfAbsent(
                key,
                () => _CarryOverShift(
                      poste: nextShift.poste,
                      date: nextShift.date,
                    ));
            carryOverByShift[key]!.arrets.add({
              'Catégorie': arret['Catégorie'] ?? '',
              'Arret': arret['Arret'] ?? '',
              'Début': _formatDateTimeToTimeString(segmentStart),
              'Fin': _formatDateTimeToTimeString(segmentEnd),
              'OriginalStart': debut,
              'OriginalEnd': fin,
              'CarryOver': true,
            });
          }

          carryStart = segmentEnd;
          if (carryStart.isBefore(arretEnd)) {
            pointer = _nextShift(pointer);
          }
        }
      }
    }

    data['Arrets'] = currentShiftArrets;
    _recalculateR0Hours(data, report.date);

    final updatedReport = report.copyWith(additionalData: data);

    final carryOverReports = carryOverByShift.values.toList()
      ..sort((a, b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) return dateCompare;
        return _posteOrderIndex(a.poste).compareTo(_posteOrderIndex(b.poste));
      });

    final existingCarryOvers = _reports.where((existing) {
      if (existing.id == report.id) return false;
      if (existing.type != report.type) return false;
      final existingData = existing.additionalData;
      if (existingData == null) return false;
      if (existingData['carryOverFrom'] != poste) return false;
      if (existingData['Model'] != data['Model']) return false;
      if (existingData['Type'] != data['Type']) return false;
      if (existingData['mine'] != data['mine']) return false;
      if (existingData['zone'] != data['zone']) return false;
      if (existingData['sortie'] != data['sortie']) return false;
      return true;
    }).toList();

    final existingByKey = <String, Report>{};
    for (final existing in existingCarryOvers) {
      final key =
          '${existing.group}-${existing.date.toIso8601String().split('T').first}';
      existingByKey[key] = existing;
    }

    final createdCarryOvers =
        carryOverReports.where((shift) => shift.arrets.isNotEmpty).map((shift) {
      final key =
          '${shift.poste}-${shift.date.toIso8601String().split('T').first}';
      final existing = existingByKey.remove(key);
      return Report(
        id: existing?.id,
        description: 'Rapport R0 - ${shift.poste} (Carry Over)',
        date: shift.date,
        type: report.type,
        group: shift.poste,
        additionalData: {
          'mine': data['mine'] ?? '',
          'zone': data['zone'] ?? '',
          'sortie': data['sortie'] ?? '',
          'selectedPoste': shift.poste,
          'Category': data['Category'] ?? '',
          'Type': data['Type'] ?? '',
          'Model': data['Model'] ?? '',
          'Compteurs': {'duree': '', 'note': ''},
          'Arrets': shift.arrets,
          'exploitation': {
            'H.M': '0.00',
            'H.A': _calculateR0Downtime({'Arrets': shift.arrets}, shift.date)
                .toStringAsFixed(2),
            'Tonnage': '0',
            'metrage fore': '',
            'Nr de Trous Fores': '',
            'Nr de Voyages': '',
            'M³ Decapages': '',
            'Nombre T.K.U': '',
            'Rendement %': '0.00',
          },
          'repartition': {
            'Chantier': '',
            'Temps': '',
            'Imputation': '',
          },
          'personnel': {'conductr': '', 'graisseur': '', 'matricules': ''},
          'consommation': {'tricone': '', 'gasoil': ''},
          'carryOverFrom': poste,
        },
      );
    }).toList();

    final deleteIds = existingByKey.values
        .map((report) => report.id)
        .whereType<int>()
        .toList();

    final updateReports =
        createdCarryOvers.where((report) => report.id != null).toList();
    final insertReports =
        createdCarryOvers.where((report) => report.id == null).toList();

    return _CarryOverResult(
      baseReport: updatedReport,
      deleteIds: deleteIds,
      updateReports: updateReports,
      insertReports: insertReports,
    );
  }

  void _recalculateR0Hours(Map<String, dynamic> data, DateTime reportDate) {
    // 1. Calculate H.A (Total Stoppage Hours) with interval merging
    final totalStoppageHours = _calculateR0Downtime(data, reportDate);

    // 2. Calculate H.M (Working Hours) using TimeCalculationService
    double totalGrossHours = 0;
    final compteursData = data['Compteurs'];

    bool hasDefect = false;
    double? start;
    double? end;

    if (compteursData is List && compteursData.isNotEmpty) {
      // Handle potential list format for counters
      for (var compteur in compteursData) {
        if (compteur is Map) {
          if (compteur['dureeDefaut'] == true ||
              compteur['noteDefaut'] == true) {
            hasDefect = true;
            break;
          }
          final s = _parseNumeric(compteur['duree']?.toString() ?? '');
          final e = _parseNumeric(compteur['note']?.toString() ?? '');
          if (e > s) {
            totalGrossHours += (e - s);
          }
        }
      }
      // If we have multiple counters, simple sum might be used, but usually R0 has one pair.
      // If defect was found in any, we use the fallback.
    } else if (compteursData is Map) {
      hasDefect = compteursData['dureeDefaut'] == true ||
          compteursData['noteDefaut'] == true;
      if (!hasDefect) {
        start = _parseNumeric(compteursData['duree']?.toString() ?? '');
        end = _parseNumeric(compteursData['note']?.toString() ?? '');
      }
    }

    double hm = hasDefect
        ? TimeCalculationService.calculateWorkingHours(
            hasDefect: true, totalStoppageHours: totalStoppageHours)
        : (compteursData is List
            ? totalGrossHours
            : TimeCalculationService.calculateWorkingHours(
                startCounter: start,
                endCounter: end,
                hasDefect: false,
                totalStoppageHours: totalStoppageHours,
              ));

    // 3. Apply Rules
    if (data['exploitation'] == null) {
      data['exploitation'] = {};
    }

    if (data['exploitation'] is Map) {
      data['exploitation']['H.A'] = totalStoppageHours.toStringAsFixed(2);
      data['exploitation']['H.M'] = hm.toStringAsFixed(2);

      // Also update Rendement if needed
      double tonnage =
          _parseNumeric(data['exploitation']['Tonnage']?.toString() ?? '0');
      if (hm > 0) {
        data['exploitation']['Rendement %'] = (tonnage / hm).toStringAsFixed(2);
      } else {
        data['exploitation']['Rendement %'] = '0.00';
      }
    }
  }

  Future<void> _deleteReport(Report report) async {
    try {
      await _databaseHelper.deleteReport(report.id!);
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reportDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.errorDeletingReport)),
        );
      }
    }
  }

  Future<void> _editReport(Report report) async {
    if (!mounted) return;
    final context = this.context;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Close the details dialog if it's open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show the appropriate editing interface based on report type
    final typeLower = report.type.toLowerCase();

    if (typeLower == 'activity tnb') {
      await _showActivityReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'daily tsud') {
      await _showDailyReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'machine/engin arrêtés') {
      await _showMachinesEquipmentStoppedEditor(
          report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'suivi camion' ||
        typeLower.contains('chargeuse') ||
        typeLower.contains('pelle') ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('truckData'))) {
      await _showTruckTrackingEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'r0' ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('mine') &&
            report.additionalData!.containsKey('selectedPoste'))) {
      await _showR0ReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else {
      await _showGenericEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    }
  }

  // Activity Report Editor
  Future<void> _showActivityReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.editActivityTnb,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: l10n.description,
                                  isEditable: false,
                                  value: report.description,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: l10n.date,
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stops Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.stopsLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStopDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['Arrets'] is List &&
                                    (data['Arrets'] as List).isNotEmpty)
                                  ...List.from(data['Arrets'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stop = entry.value;
                                    final isSelected =
                                        _selectedStopIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.green.withValues(alpha: 0.1),
                                        title: Text(l10n.arretTitle(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${l10n.dureeLabel}: ${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))}'),
                                            Text(
                                                '${l10n.natureLabel}: ${stop['nature'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStopIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.editArret,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.deleteArret,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.aucunArret,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Vibreurs Counters Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.cvibrLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAddVibratorCounterDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['vibrator Counters'] is List &&
                                    (data['vibrator Counters'] as List)
                                        .isNotEmpty)
                                  ...List.from(data['vibrator Counters'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final counter = entry.value;
                                    final isSelected =
                                        _selectedCounterIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.orange
                                            .withValues(alpha: 0.1),
                                        title: Text(l10n.cvibrTitle(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${l10n.poste}: ${_getPosteString(counter['poste'], l10n)}'),
                                            Text(
                                                '${l10n.start}: ${counter['start'] ?? '-'}'),
                                            Text(
                                                '${l10n.end}: ${counter['end'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.orange)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedCounterIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditVibratorCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.editCounter,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteVibratorCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.deleteCounter,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.aucunCompteurVibr,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Liaison Counters Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.cliaisonLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAddLiaisonCounterDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['liaison Counters'] is List &&
                                    (data['liaison Counters'] as List)
                                        .isNotEmpty)
                                  ...List.from(data['liaison Counters'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final counter = entry.value;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title:
                                            Text(l10n.cliaisonTitle(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${l10n.poste}: ${_getPosteString(counter['poste'], l10n)}'),
                                            Text(
                                                '${l10n.start}: ${counter['start'] ?? '-'}'),
                                            Text(
                                                '${l10n.end}: ${counter['end'] ?? '-'}'),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditLiaisonCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.editCounter,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteLiaisonCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.deleteCounter,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.noLiaisonCountersAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stock Entries Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.stocksLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStockEntryDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['stock'] is List &&
                                    (data['stock'] as List).isNotEmpty)
                                  ...List.from(data['stock'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stock = entry.value;
                                    final isSelected =
                                        _selectedStockIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.purple
                                            .withValues(alpha: 0.1),
                                        title: Text(
                                            l10n.stockTitleIndex(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(stock['poste'], l10n)}'),
                                            Text(
                                                'Parc: ${_getParkString(stock['park'], l10n)}'),
                                            Text(
                                                'Type: ${_getStockTypeString(stock['type'], l10n)}'),
                                            Text(
                                                'Quantité: ${stock['quantity'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.purple)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStockIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: l10n.editStockEntryTitle,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  l10n.deleteStockEntryTitle,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.noStockEntriesAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add Stop Dialog for Activity Report
  Future<void> _showAddStopDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final natureDisplayMap = {
      'Manque Produit': l10n.missingProduct,
      'Attente Saturation Silo': l10n.waitingSaturationSilo,
      'Vidange Extraction 2': l10n.extraction2Drainage,
      'Arret Mécanique sur:': l10n.mechanicalStop,
      'Dèfout Élèctrique sur:': l10n.electricalFault,
      'Arret d\'instalation sur:': l10n.installationStop,
      'Travoux Mècanique sur:': l10n.mechanicalWork,
      'Travoux Elèctrique sur:': l10n.electricalWork,
      'Travoux dans l\'instalation sur:': l10n.installationWork,
      'Autre:': l10n.other,
    };
    final predefinedNatures = natureDisplayMap.keys.toList();

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = '';
    final customNatureController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addStopTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedNature,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.predefinedNatureLabel,
                  border: const OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map(
                      (nature) => DropdownMenuItem(
                        value: nature,
                        child: Text(
                          natureDisplayMap[nature] ?? nature,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.durationLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: InputDecoration(
                    labelText: l10n.complementLabel,
                    border: const OutlineInputBorder(),
                    hintText: l10n.maxCharactersHint,
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['Arrets'] == null) {
                    updatedData['Arrets'] = [];
                  }
                  (updatedData['Arrets'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'duration': tempStopDuration,
                    'nature': finalNature,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stop Dialog for Activity Report
  Future<void> _showEditStopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final stop = (data['Arrets'] as List)[index];
    final natureDisplayMap = {
      'Manque Produit': l10n.missingProduct,
      'Attente Saturation Silo': l10n.waitingSaturationSilo,
      'Vidange Extraction 2': l10n.extraction2Drainage,
      'Arret Mécanique sur:': l10n.mechanicalStop,
      'Dèfout Élèctrique sur:': l10n.electricalFault,
      'Arret d\'instalation sur:': l10n.installationStop,
      'Travoux Mècanique sur:': l10n.mechanicalWork,
      'Travoux Elèctrique sur:': l10n.electricalWork,
      'Travoux dans l\'instalation sur:': l10n.installationWork,
      'Autre:': l10n.other,
    };
    final predefinedNatures = natureDisplayMap.keys.toList();

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = stop['duration']?.toString() ?? '';
    final customNatureController = TextEditingController();
    final durationController = TextEditingController(text: tempStopDuration);

    // Parse the nature to determine selected nature and custom part
    String currentNature = stop['nature']?.toString() ?? '';
    for (String nature in predefinedNatures) {
      if (currentNature.startsWith(nature)) {
        selectedNature = nature;
        if (nature.endsWith(':')) {
          customNature = currentNature.substring(nature.length).trim();
          customNatureController.text = customNature;
        }
        break;
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editStopTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedNature,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.predefinedNatureLabel,
                  border: const OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map(
                      (nature) => DropdownMenuItem(
                        value: nature,
                        child: Text(
                          natureDisplayMap[nature] ?? nature,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
                hint: Text(l10n.selectNature),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.durationLabel,
                  border: const OutlineInputBorder(),
                ),
                controller: durationController,
                onChanged: (value) => setState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: InputDecoration(
                    labelText: l10n.complementLabel,
                    border: const OutlineInputBorder(),
                    hintText: l10n.maxCharactersHint,
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['Arrets'] as List)[index] = {
                    'id': stop['id'],
                    'duration': tempStopDuration,
                    'nature': finalNature,
                  };

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Stop Dialog for Activity Report
  Future<void> _showDeleteStopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteStopTitle),
        content: Text(l10n.deleteStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['Arrets'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Add Vibreur Counter Dialog for Activity Report
  Future<void> _showAddVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    String startIndex = '';
    String endIndex = '';
    bool startDefect = false;
    bool endDefect = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addVibratorCounterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.startCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: !startDefect,
                      controller: startDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                      onChanged: (value) => setState(() => startIndex = value),
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: startDefect,
                        onChanged: (val) => setState(() {
                          startDefect = val ?? false;
                          if (startDefect) startIndex = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.endCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: !endDefect,
                      controller: endDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                      onChanged: (value) => setState(() => endIndex = value),
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: endDefect,
                        onChanged: (val) => setState(() {
                          endDefect = val ?? false;
                          if (endDefect) endIndex = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startIndex.isNotEmpty &&
                    endIndex.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['vibrator Counters'] == null) {
                    updatedData['vibrator Counters'] = [];
                  }
                  (updatedData['vibrator Counters'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'start': startIndex,
                    'end': endIndex,
                    'startDefect': startDefect,
                    'endDefect': endDefect,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Vibreur Counter Dialog for Activity Report
  Future<void> _showEditVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final counter = (data['vibrator Counters'] as List)[index];
    int? selectedPoste;
    final rawPoste = counter['poste'];
    if (rawPoste is int) {
      selectedPoste = rawPoste;
    } else if (rawPoste is String) {
      if (rawPoste == '3ème Poste') {
        selectedPoste = 0;
      } else if (rawPoste == '1er Poste') {
        selectedPoste = 1;
      } else if (rawPoste == '2ème Poste') {
        selectedPoste = 2;
      }
    }
    final startController = TextEditingController(text: counter['start'] ?? '');
    final endController = TextEditingController(text: counter['end'] ?? '');
    bool startDefect = counter['startDefect'] ?? false;
    bool endDefect = counter['endDefect'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editVibratorCounterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.startCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      controller: startDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : startController,
                      enabled: !startDefect,
                      onChanged: (v) {
                        // Controller handles text, but we might need explicit state update if validation relies on it
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: startDefect,
                        onChanged: (val) => setState(() {
                          startDefect = val ?? false;
                          if (startDefect) startController.text = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.endCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      controller: endDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : endController,
                      enabled: !endDefect,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: endDefect,
                        onChanged: (val) => setState(() {
                          endDefect = val ?? false;
                          if (endDefect) endController.text = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startController.text.isNotEmpty &&
                    endController.text.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['vibrator Counters'] as List)[index] = {
                    'id': counter['id'],
                    'poste': selectedPoste,
                    'start': startController.text,
                    'end': endController.text,
                    'startDefect': startDefect,
                    'endDefect': endDefect,
                  };

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Vibreur Counter Dialog for Activity Report
  Future<void> _showDeleteVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteVibratorCounterTitle),
        content: Text(l10n.deleteCounterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['vibrator Counters'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Add Liaison Counter Dialog for Activity Report
  Future<void> _showAddLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    String startIndex = '';
    String endIndex = '';
    bool startDefect = false;
    bool endDefect = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addLiaisonCounterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.startCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: !startDefect,
                      controller: startDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                      onChanged: (value) => setState(() => startIndex = value),
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: startDefect,
                        onChanged: (val) => setState(() {
                          startDefect = val ?? false;
                          if (startDefect) startIndex = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.endCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      enabled: !endDefect,
                      controller: endDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                      onChanged: (value) => setState(() => endIndex = value),
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: endDefect,
                        onChanged: (val) => setState(() {
                          endDefect = val ?? false;
                          if (endDefect) endIndex = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startIndex.isNotEmpty &&
                    endIndex.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['liaison Counters'] == null) {
                    updatedData['liaison Counters'] = [];
                  }
                  (updatedData['liaison Counters'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'start': startIndex,
                    'end': endIndex,
                    'startDefect': startDefect,
                    'endDefect': endDefect,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Liaison Counter Dialog for Activity Report
  Future<void> _showEditLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final counter = (data['liaison Counters'] as List)[index];
    int? selectedPoste;
    final rawPoste = counter['poste'];
    if (rawPoste is int) {
      selectedPoste = rawPoste;
    } else if (rawPoste is String) {
      if (rawPoste == '3ème Poste') {
        selectedPoste = 0;
      } else if (rawPoste == '1er Poste') {
        selectedPoste = 1;
      } else if (rawPoste == '2ème Poste') {
        selectedPoste = 2;
      }
    }
    final startController = TextEditingController(text: counter['start'] ?? '');
    final endController = TextEditingController(text: counter['end'] ?? '');
    bool startDefect = counter['startDefect'] ?? false;
    bool endDefect = counter['endDefect'] ?? false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editLiaisonCounterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.startCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      controller: startDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : startController,
                      enabled: !startDefect,
                      onChanged: (v) {
                        // Controller handles text
                      },
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: startDefect,
                        onChanged: (val) => setState(() {
                          startDefect = val ?? false;
                          if (startDefect) startController.text = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: l10n.endCounterLabel,
                        border: const OutlineInputBorder(),
                      ),
                      controller: endDefect
                          ? TextEditingController(text: l10n.defautLabel)
                          : endController,
                      enabled: !endDefect,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: endDefect,
                        onChanged: (val) => setState(() {
                          endDefect = val ?? false;
                          if (endDefect) endController.text = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startController.text.isNotEmpty &&
                    endController.text.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['liaison Counters'] as List)[index] = {
                    'id': counter['id'],
                    'poste': selectedPoste,
                    'start': startController.text,
                    'end': endController.text,
                    'startDefect': startDefect,
                    'endDefect': endDefect,
                  };

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Liaison Counter Dialog for Activity Report
  Future<void> _showDeleteLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteLiaisonCounterTitle),
        content: Text(l10n.deleteCounterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['liaison Counters'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Add Stock Entry Dialog for Activity Report
  Future<void> _showAddStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    int? selectedPark;
    int? selectedType;
    String quantity = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addStockEntryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedPark,
                decoration: InputDecoration(
                  labelText: l10n.parkLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.park1)),
                  DropdownMenuItem(value: 1, child: Text(l10n.park2)),
                  DropdownMenuItem(value: 2, child: Text(l10n.park3)),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: l10n.type,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.stockTypeNormal)),
                  DropdownMenuItem(value: 1, child: Text(l10n.stockTypeOceane)),
                  DropdownMenuItem(value: 2, child: Text(l10n.stockTypePb30)),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.quantityLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => quantity = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['stock'] == null) {
                    updatedData['stock'] = [];
                  }
                  (updatedData['stock'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'park': selectedPark,
                    'type': selectedType,
                    'quantity': quantity,
                  });

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stock Entry Dialog for Activity Report
  Future<void> _showEditStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final stock = (data['stock'] as List)[index];
    int? selectedPoste = stock['poste'];
    int? selectedPark = stock['park'];
    int? selectedType = stock['type'];
    String quantity = stock['quantity'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editStockEntryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: l10n.poste,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.poste3eme)),
                  DropdownMenuItem(value: 1, child: Text(l10n.poste1er)),
                  DropdownMenuItem(value: 2, child: Text(l10n.poste2eme)),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedPark,
                decoration: InputDecoration(
                  labelText: l10n.parkLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.park1)),
                  DropdownMenuItem(value: 1, child: Text(l10n.park2)),
                  DropdownMenuItem(value: 2, child: Text(l10n.park3)),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: l10n.type,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(value: 0, child: Text(l10n.stockTypeNormal)),
                  DropdownMenuItem(value: 1, child: Text(l10n.stockTypeOceane)),
                  DropdownMenuItem(value: 2, child: Text(l10n.stockTypePb30)),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: l10n.quantityLabel,
                  border: const OutlineInputBorder(),
                ),
                controller: TextEditingController(text: quantity),
                onChanged: (value) => setState(() => quantity = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['stock'] as List)[index] = {
                    'id': stock['id'],
                    'poste': selectedPoste,
                    'park': selectedPark,
                    'type': selectedType,
                    'quantity': quantity,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Stock Entry Dialog for Activity Report
  Future<void> _showDeleteStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteStockEntryTitle),
        content: Text(l10n.deleteStockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['stock'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required BuildContext context,
    required String label,
    required String value,
    required Future<void> Function(String) onSave,
    bool isEditable = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(value.isEmpty ? '-' : value),
              ),
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final TextEditingController controller =
                        TextEditingController(text: value);
                    await showDialog(
                      context: context,
                      builder: (editContext) => AlertDialog(
                        title: Text(l10n.editLabel(label)),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: label,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: null,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(editContext),
                            child: Text(l10n.cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(editContext);
                              await onSave(controller.text);
                            },
                            child: Text(l10n.save),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: l10n.editLabel(label),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableDateField({
    required BuildContext context,
    required String label,
    required DateTime value,
    required Future<void> Function(DateTime) onSave,
    bool isEditable = true,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(value)),
              ),
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    await _editDate(
                      context: context,
                      initialDate: value,
                      onSave: onSave,
                    );
                  },
                  tooltip: l10n.editLabel(label),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editDate({
    required BuildContext context,
    required DateTime initialDate,
    required Future<void> Function(DateTime) onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    DateTime selectedDate = initialDate;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.date),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title:
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(selectedDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    if (!dialogContext.mounted) return;
                    final DateTime? picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && dialogContext.mounted) {
                      final TimeOfDay? time = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null && dialogContext.mounted) {
                        final newDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                        setState(() {
                          selectedDate = newDate;
                        });
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await onSave(selectedDate);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  // Machines Equipment Stopped Editor
  Future<void> _showMachinesEquipmentStoppedEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    // Equipment data structure matching machines_equipment_stopped_screen.dart
    final Map<String, Map<String, List<String>>> equipmentData = {
      'Camions Servitude': {
        'Camion Citerne': ['16979-A-68', '17492-A-68', 'TEXAS'],
        'Camion DCI': ['19164-A-68', '5636-A-68'],
        'Camion de Ravitaillmenet': ['1462443', '93292-D-8'],
        'Camion Grue': ['12097-A-68'],
        'Camion Nacelle': ['17080-A-68'],
        'Camion Ridelle': ['11053-A-68', '15836-A-68', '34866-A-54'],
        'Vehicule DC': ['513714'],
      },
      'Engins': {
        'Bulldozers': [
          'BULL D9R 76',
          'BULL D9R 79',
          'BULL D9R 80',
          'BULL D9R 81',
          'BULL D9R 82',
          'BULL D9R 83',
          'BULL LIB 84',
          'BULL LIB 85',
          'BULL D9R 86',
          'BULL D9R 87'
        ],
        'Camions': [
          'CAMION T24',
          'CAMION T25',
          'CAMION T26',
          'CAMION T27',
          'CAMION T28',
          'CAMION T29',
          'CAMION T30',
          'CAMION T31',
          'CAMION T32',
          'CAMION T33',
          'WABCO 13',
          'WABCO 19'
        ],
        'Chargeuses': ['CHRG 992C', 'CHRG 992K', 'CHRG 994H'],
        'Niveleuses': ['NIV 14G', 'NIV 16H', 'NIV KOM01', 'NIV KOM02'],
        'Paydozers': ['PAY CAT03', 'PAY KOM04', 'PAY KOM05'],
        'Pelle Hydraulique': ['PH365-C', 'PH5130'],
      },
      'Machines': {
        'Draglines': ['1370 W1', '1370 W2'],
        'Pelle Electrique': ['195 P1', '195 P2'],
        'Sondeuses': ['PV275-1', 'PV275-2', 'PV275-3'],
      },
    };

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Modifier - Machines et Engins Arrêtés',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.reportDateLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text(
                                  '${report.date.day.toString().padLeft(2, '0')}/${report.date.month.toString().padLeft(2, '0')}/${report.date.year}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Equipment List Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.machinesStoppedLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add),
                                      onPressed: () =>
                                          _showAddMachineEquipmentDialog(
                                              report,
                                              data,
                                              equipmentData,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      tooltip: l10n.addEquipment,
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['equipmentList'] is List &&
                                    (data['equipmentList'] as List).isNotEmpty)
                                  ...List.from(data['equipmentList'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final equipment = entry.value;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Card(
                                        elevation: 1,
                                        child: ListTile(
                                          title: Text(
                                              '${l10n.equipmentLabelWithIndex(index + 1)} ${equipment['equipmentType'] ?? '-'}'),
                                          subtitle: Text(
                                              '${l10n.reason}: ${equipment['Reason'] ?? '-'}'),
                                          trailing: PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_horiz,
                                                size: 20),
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            position: PopupMenuPosition.under,
                                            itemBuilder:
                                                (BuildContext context) => [
                                              PopupMenuItem<String>(
                                                value: 'edit',
                                                height: 36,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.edit,
                                                        size: 18,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Modifier',
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'delete',
                                                height: 36,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.delete_outline,
                                                        size: 18,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Supprimer',
                                                      style: TextStyle(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _showEditMachineEquipmentDialog(
                                                    report,
                                                    data,
                                                    index,
                                                    equipmentData,
                                                    setDialogState,
                                                    scaffoldMessenger,
                                                    l10n);
                                              } else if (value == 'delete') {
                                                _showDeleteMachineEquipmentDialog(
                                                    report,
                                                    data,
                                                    index,
                                                    setDialogState,
                                                    scaffoldMessenger,
                                                    l10n);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(
                                    l10n.noMachinesStopped,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add Machine Equipment Dialog
  Future<void> _showAddMachineEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      Map<String, Map<String, List<String>>> equipmentData,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    String selectedMainCategory = '';
    String selectedSubCategory = '';
    String selectedEquipment = '';
    String selectedEquipmentType = '';
    String stopReason = '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          type: MaterialType.card,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setInnerDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.addEquipment,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMainCategory.isEmpty
                            ? null
                            : selectedMainCategory,
                        decoration: InputDecoration(
                            labelText: l10n.mainCategoryLabel,
                            border: const OutlineInputBorder()),
                        items: equipmentData.keys.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setInnerDialogState(() {
                            selectedMainCategory = newValue ?? '';
                            selectedSubCategory = '';
                            selectedEquipment = '';
                            selectedEquipmentType = '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubCategory.isEmpty
                            ? null
                            : selectedSubCategory,
                        decoration: InputDecoration(
                            labelText: l10n.subCategoryLabel,
                            border: const OutlineInputBorder()),
                        items: (selectedMainCategory.isNotEmpty
                                ? equipmentData[selectedMainCategory]!.keys
                                : <String>[])
                            .map((String subCategory) {
                          return DropdownMenuItem<String>(
                            value: subCategory,
                            child: Text(subCategory),
                          );
                        }).toList(),
                        onChanged: selectedMainCategory.isNotEmpty
                            ? (String? newValue) {
                                setInnerDialogState(() {
                                  selectedSubCategory = newValue ?? '';
                                  selectedEquipment = '';
                                  selectedEquipmentType = '';
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEquipment.isEmpty
                            ? null
                            : selectedEquipment,
                        decoration: InputDecoration(
                            labelText: l10n.equipmentLabel,
                            border: const OutlineInputBorder()),
                        items: (selectedSubCategory.isNotEmpty
                                ? equipmentData[selectedMainCategory]![
                                    selectedSubCategory]!
                                : <String>[])
                            .map((String equipment) {
                          return DropdownMenuItem<String>(
                            value: equipment,
                            child: Text(equipment),
                          );
                        }).toList(),
                        onChanged: selectedSubCategory.isNotEmpty
                            ? (String? newValue) {
                                setInnerDialogState(() {
                                  selectedEquipment = newValue ?? '';
                                  selectedEquipmentType =
                                      '$selectedMainCategory - $selectedSubCategory - $selectedEquipment';
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: InputDecoration(
                          labelText: l10n.stopReasonLabel,
                          border: const OutlineInputBorder(),
                          hintText: l10n.enterStopReasonHint,
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          setInnerDialogState(() {
                            stopReason = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: selectedEquipment.isNotEmpty &&
                                    stopReason.isNotEmpty
                                ? () {
                                    Navigator.pop(context, {
                                      'equipmentType': selectedEquipmentType,
                                      'Reason': stopReason,
                                    });
                                  }
                                : null,
                            child: Text(l10n.finishButton),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      if (data['equipmentList'] == null) {
        data['equipmentList'] = [];
      }
      (data['equipmentList'] as List).add(result);

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Edit Machine Equipment Dialog
  Future<void> _showEditMachineEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      Map<String, Map<String, List<String>>> equipmentData,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final equipment = (data['equipmentList'] as List)[index];
    final equipmentType = equipment['equipmentType'] ?? '';
    final parts = equipmentType.split(' - ');

    String selectedMainCategory = parts.length >= 1 ? parts[0] : '';
    String selectedSubCategory = parts.length >= 2 ? parts[1] : '';
    String selectedEquipment = parts.length >= 3 ? parts[2] : '';
    String selectedEquipmentType = equipmentType;
    String stopReason = equipment['Reason'] ?? '';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Material(
          type: MaterialType.card,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setInnerDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modifier l\'équipement',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMainCategory.isEmpty
                            ? null
                            : selectedMainCategory,
                        decoration: const InputDecoration(
                            labelText: 'Catégorie principale',
                            border: OutlineInputBorder()),
                        items: equipmentData.keys.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setInnerDialogState(() {
                            selectedMainCategory = newValue ?? '';
                            selectedSubCategory = '';
                            selectedEquipment = '';
                            selectedEquipmentType = '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSubCategory.isEmpty
                            ? null
                            : selectedSubCategory,
                        decoration: const InputDecoration(
                            labelText: 'Sous-catégorie',
                            border: OutlineInputBorder()),
                        items: (selectedMainCategory.isNotEmpty
                                ? equipmentData[selectedMainCategory]!.keys
                                : <String>[])
                            .map((String subCategory) {
                          return DropdownMenuItem<String>(
                            value: subCategory,
                            child: Text(subCategory),
                          );
                        }).toList(),
                        onChanged: selectedMainCategory.isNotEmpty
                            ? (String? newValue) {
                                setInnerDialogState(() {
                                  selectedSubCategory = newValue ?? '';
                                  selectedEquipment = '';
                                  selectedEquipmentType = '';
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedEquipment.isEmpty
                            ? null
                            : selectedEquipment,
                        decoration: const InputDecoration(
                            labelText: 'Équipement',
                            border: OutlineInputBorder()),
                        items: (selectedSubCategory.isNotEmpty
                                ? equipmentData[selectedMainCategory]![
                                    selectedSubCategory]!
                                : <String>[])
                            .map((String equipment) {
                          return DropdownMenuItem<String>(
                            value: equipment,
                            child: Text(equipment),
                          );
                        }).toList(),
                        onChanged: selectedSubCategory.isNotEmpty
                            ? (String? newValue) {
                                setInnerDialogState(() {
                                  selectedEquipment = newValue ?? '';
                                  selectedEquipmentType =
                                      '$selectedMainCategory - $selectedSubCategory - $selectedEquipment';
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopReason,
                        decoration: const InputDecoration(
                          labelText: 'Raison de l\'arrêt',
                          border: OutlineInputBorder(),
                          hintText: 'Entrez la raison de l\'arrêt...',
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          setInnerDialogState(() {
                            stopReason = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: selectedEquipment.isNotEmpty &&
                                    stopReason.isNotEmpty
                                ? () {
                                    Navigator.pop(context, {
                                      'equipmentType': selectedEquipmentType,
                                      'Reason': stopReason,
                                    });
                                  }
                                : null,
                            child: Text(l10n.finishButton),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    if (result != null) {
      (data['equipmentList'] as List)[index] = result;

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Delete Machine Equipment Dialog
  Future<void> _showDeleteMachineEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEquipment),
        content: Text(l10n.deleteEquipmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              (data['equipmentList'] as List).removeAt(index);

              setDialogState(() {});

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: data,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportDetails(Report report) async {
    // Debug: print the report type and additionalData
    // ignore: avoid_print
    print('Clicked report type: ${report.type}');
    // ignore: avoid_print
    print('Clicked report additionalData: ${report.additionalData}');
    final l10n = AppLocalizations.of(context)!;

    final typeLower = report.type.toLowerCase();

    // Special handling for Activity TNB report (case-insensitive)
    if (typeLower == 'activity tnb') {
      final data = report.additionalData ?? {};
      final maxHeight = MediaQuery.of(context).size.height * 0.8;
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) {
            Report currentReport = report;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: maxHeight,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              l10n.dataVerification,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await _editReport(currentReport);
                                },
                                tooltip: l10n.editReport,
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(dialogContext),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.date,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    Text(
                                        '${report.date.day}/${report.date.month}/${report.date.year}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Activity Summary Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.dataSummary,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    _buildSummaryRow(
                                        'T H.A:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.A'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.M:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.M'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.V:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.V'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.L:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.L'] ?? 0)),
                                    const SizedBox(height: 8),
                                    _buildSummaryRow(
                                        'T Nr.A:',
                                        (data['Arrets'] is List
                                                ? (data['Arrets'] as List)
                                                    .length
                                                : 0)
                                            .toString()),
                                    _buildSummaryRow(
                                        'T Nr.V:',
                                        (data['vibrator Counters'] is List
                                                ? (data['vibrator Counters']
                                                        as List)
                                                    .length
                                                : 0)
                                            .toString()),
                                    _buildSummaryRow(
                                        'T Nr.L:',
                                        (data['liaison Counters'] is List
                                                ? (data['liaison Counters']
                                                        as List)
                                                    .length
                                                : 0)
                                            .toString()),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Stops Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Arrêts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    if (data['Arrets'] is List &&
                                        (data['Arrets'] as List).isNotEmpty)
                                      ...List.from(data['Arrets'])
                                          .map((stop) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Text(
                                                    '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                                              ))
                                    else if (data['Arrets'] is List &&
                                        (data['Arrets'] as List).isEmpty)
                                      Text(l10n.aucunArret,
                                          style: const TextStyle(
                                              color: Colors.grey))
                                    else
                                      Text(l10n.stopDataNotAvailable,
                                          style: const TextStyle(
                                              color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Vibreurs Counters Card
                            if (data['vibrator Counters'] is List &&
                                (data['vibrator Counters'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.vibratorCountersLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['vibrator Counters'])
                                          .map((counter) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '• ${l10n.poste}: ${_getPosteString(counter['poste'], l10n)}'),
                                                    if (counter['start'] !=
                                                            null &&
                                                        counter['start']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  ${l10n.start}: ${counter['start']}'),
                                                    if (counter['end'] !=
                                                            null &&
                                                        counter['end']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  ${l10n.end}: ${counter['end']}'),
                                                  ],
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ),
                            if (data['vibrator Counters'] is List &&
                                (data['vibrator Counters'] as List).isNotEmpty)
                              const SizedBox(height: 16),
                            // Liaison Counters Card
                            if (data['liaison Counters'] is List &&
                                (data['liaison Counters'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.liaisonCountersLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['liaison Counters'])
                                          .map((counter) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '• ${l10n.poste}: ${_getPosteString(counter['poste'], l10n)}'),
                                                    if (counter['start'] !=
                                                            null &&
                                                        counter['start']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  ${l10n.start}: ${counter['start']}'),
                                                    if (counter['end'] !=
                                                            null &&
                                                        counter['end']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  ${l10n.end}: ${counter['end']}'),
                                                  ],
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ),
                            if (data['liaison Counters'] is List &&
                                (data['liaison Counters'] as List).isNotEmpty)
                              const SizedBox(height: 16),
                            // Stock Card
                            if (data['stock'] is List &&
                                (data['stock'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.stockLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['stock'])
                                          .map((entry) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Text(
                                                  '${l10n.poste}: ${_getPosteString(entry['poste'], l10n)} | ${l10n.parkLabel}: ${_getParkString(entry['park'], l10n)} | ${l10n.type}: ${_getStockTypeString(entry['type'], l10n)} | ${l10n.quantityLabel}: ${entry['quantity'] ?? '-'} |',
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      return;
    }

    // Special handling for daily TSUD report (case-insensitive)
    if (typeLower == 'daily tsud') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(l10n.dataVerification)),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editReport(report),
                tooltip: 'Modifier le rapport',
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.date,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Module 1 Card
                Builder(
                  builder: (context) {
                    final module1Stops = (data['module1Stops'] is List)
                        ? List.from(data['module1Stops'])
                        : [];
                    final module1Downtime =
                        _calculateDowntimeFromStops(module1Stops);
                    const int totalPeriod = 24 * 60; // 24 hours in minutes
                    final module1OperatingTime =
                        (totalPeriod - module1Downtime).clamp(0, totalPeriod);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.module1Label,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                '${l10n.operatingTime}: ${_formatMinutesToHoursMinutes(module1OperatingTime)}'),
                            Text(
                                '${l10n.stopTime}: ${_formatMinutesToHoursMinutes(module1Downtime)}'),
                            if (module1Stops.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('${l10n.stopsLabel}:',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              ...module1Stops.map((stop) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                        '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Module 2 Card
                Builder(
                  builder: (context) {
                    final module2Stops = (data['module2Stops'] is List)
                        ? List.from(data['module2Stops'])
                        : [];
                    final module2Downtime =
                        _calculateDowntimeFromStops(module2Stops);
                    const int totalPeriod = 24 * 60; // 24 hours in minutes
                    final module2OperatingTime =
                        (totalPeriod - module2Downtime).clamp(0, totalPeriod);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.module2Label,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                '${l10n.operatingTime}: ${_formatMinutesToHoursMinutes(module2OperatingTime)}'),
                            Text(
                                '${l10n.stopTime}: ${_formatMinutesToHoursMinutes(module2Downtime)}'),
                            if (module2Stops.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(l10n.stopsLabel,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              ...module2Stops.map((stop) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                        '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Stocks Card (if any)
                if (data['stock'] is List && (data['stock'] as List).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.stockLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...List.from(data['stock']).map((entry) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '${l10n.poste}: ${_getPosteString(entry['poste'], l10n)} | ${l10n.parkLabel}: ${_getParkString(entry['park'], l10n)} | ${l10n.type}: ${_getStockTypeString(entry['type'], l10n)} | ${l10n.quantityLabel}: ${entry['quantity'] ?? '-'} |',
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return;
    }

    // Special handling for Machine/Engin Arrêtés report (case-insensitive)
    if (typeLower == 'machine/engin arrêtés') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(l10n.dataVerification)),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editReport(report),
                tooltip: 'Modifier le rapport',
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.dateLabel,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Équipements arrêtés Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.machinesStoppedLabel,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (data['equipmentList'] is List &&
                            (data['equipmentList'] as List).isNotEmpty) ...[
                          ...List.from(data['equipmentList'])
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final equipment = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${l10n.equipmentIndex(index + 1)}:',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${l10n.type}: ${equipment['equipmentType'] ?? '-'}'),
                                  Text(
                                      '${l10n.reasonLabel}: ${equipment['Reason'] ?? '-'}'),
                                  if (index <
                                      (data['equipmentList'] as List).length -
                                          1)
                                    const Divider(),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          Text(l10n.noEquipmentStopped,
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return;
    }

    // Special handling for R0 report (case-insensitive)
    if (typeLower == 'r0' ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('mine') &&
            report.additionalData!.containsKey('selectedPoste') &&
            !report.additionalData!.containsKey('truckData'))) {
      final data = report.additionalData ?? {};
      final maxHeight = MediaQuery.of(context).size.height * 0.8;

      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dataVerification,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editReport(report),
                            tooltip: 'Modifier le rapport',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.dateLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text(
                                    '${report.date.day}/${report.date.month}/${report.date.year}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Info OIB/EE Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.infoOibEeLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(l10n.mine, data['mine'] ?? '-'),
                                _buildInfoRow(l10n.zone, data['zone'] ?? '-'),
                                _buildInfoRow(l10n.exit, data['sortie'] ?? '-'),
                                _buildInfoRow(l10n.categoryLabel,
                                    data['Category'] ?? '-'),
                                _buildInfoRow(l10n.type, data['Type'] ?? '-'),
                                _buildInfoRow(
                                    l10n.modelLabel, data['Model'] ?? '-'),
                                _buildInfoRow(
                                    l10n.poste,
                                    data['selectedPoste'] ??
                                        data['poste'] ??
                                        data['Poste'] ??
                                        '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Compteurs Card
                        if ((data['Compteurs'] is List &&
                                (data['Compteurs'] as List).isNotEmpty) ||
                            (data['Compteurs'] is Map))
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.counter,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  if (data['Compteurs'] is List)
                                    ...List.generate(
                                        (data['Compteurs'] as List).length,
                                        (index) {
                                      final compteur =
                                          (data['Compteurs'] as List)[index];
                                      if (compteur['duree'] == null &&
                                          compteur['note'] == null) {
                                        return const SizedBox.shrink();
                                      }
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          _buildInfoRow(l10n.start,
                                              compteur['duree'] ?? '-'),
                                          _buildInfoRow(l10n.end,
                                              compteur['note'] ?? '-'),
                                          if (index <
                                              (data['Compteurs'] as List)
                                                      .length -
                                                  1)
                                            const Divider(height: 16),
                                        ],
                                      );
                                    })
                                  else if (data['Compteurs'] is Map)
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildInfoRow(l10n.start,
                                            data['Compteurs']['duree'] ?? '-'),
                                        _buildInfoRow(l10n.end,
                                            data['Compteurs']['note'] ?? '-'),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if ((data['Compteurs'] is List &&
                                (data['Compteurs'] as List).isNotEmpty) ||
                            (data['Compteurs'] is Map))
                          const SizedBox(height: 16),
                        // Arrêts Card
                        if (data['Arrets'] is List &&
                            (data['Arrets'] as List).isNotEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.stopsLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  ...List.from(data['Arrets'])
                                      .map((arret) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${l10n.type}: ${arret['Arret'] ?? '-'}'),
                                                _buildInfoRow(l10n.start,
                                                    arret['Début'] ?? '-'),
                                                _buildInfoRow(l10n.end,
                                                    arret['Fin'] ?? '-'),
                                                const Divider(height: 8),
                                              ],
                                            ),
                                          )),
                                ],
                              ),
                            ),
                          ),
                        if (data['Arrets'] is List &&
                            (data['Arrets'] as List).isNotEmpty)
                          const SizedBox(height: 16),
                        // Exploitation Card
                        if (data['exploitation'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.stepExploit,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(l10n.heuresMarche,
                                      data['exploitation']['H.M'] ?? '-'),
                                  _buildInfoRow(l10n.heuresArret,
                                      data['exploitation']['H.A'] ?? '-'),
                                  _buildInfoRow(
                                      l10n.metrageFore,
                                      data['exploitation']['metrage fore'] ??
                                          '-'),
                                  _buildInfoRow(
                                      l10n.nrTrousFores,
                                      data['exploitation']
                                              ['Nr de Trous Fores'] ??
                                          '-'),
                                  _buildInfoRow(
                                      l10n.nrVoyages,
                                      data['exploitation']['Nr de Voyages'] ??
                                          '-'),
                                  _buildInfoRow(
                                      l10n.m3Decapage,
                                      data['exploitation']['M³ Decapages'] ??
                                          '-'),
                                  _buildInfoRow(l10n.tonnageLabel,
                                      data['exploitation']['Tonnage'] ?? '-'),
                                  _buildInfoRow(
                                      l10n.nombreTKU,
                                      data['exploitation']['Nombre T.K.U'] ??
                                          '-'),
                                  _buildInfoRow(
                                      l10n.rendementLabel,
                                      data['exploitation']['Rendement %'] ??
                                          data['exploitation']['Rendeme'] ??
                                          '-'),
                                ],
                              ),
                            ),
                          ),
                        if (data['exploitation'] is Map)
                          const SizedBox(height: 16),
                        // Répartition Card
                        if ((data['Répartition Travail'] is List &&
                                (data['Répartition Travail'] as List)
                                    .isNotEmpty) ||
                            (data['repartition'] is Map))
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.repartitionLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  if (data['Répartition Travail'] is List)
                                    ...List.from(data['Répartition Travail'])
                                        .map((repartition) => Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildInfoRow(
                                                      l10n.chantierLabel,
                                                      repartition['Chantier'] ??
                                                          repartition[
                                                              'chantier'] ??
                                                          '-'),
                                                  _buildInfoRow(
                                                      l10n.timeLabel,
                                                      repartition['Temps'] ??
                                                          repartition[
                                                              'temps'] ??
                                                          '-'),
                                                  _buildInfoRow(
                                                      l10n.imputationLabel,
                                                      repartition[
                                                              'Imputation'] ??
                                                          repartition[
                                                              'imputation'] ??
                                                          '-'),
                                                  const Divider(height: 8),
                                                ],
                                              ),
                                            ))
                                  else if (data['repartition'] is Map)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildInfoRow(
                                              'Chantier',
                                              data['repartition']['Chantier'] ??
                                                  data['repartition']
                                                      ['chantier'] ??
                                                  '-'),
                                          _buildInfoRow(
                                              'Temps',
                                              data['repartition']['Temps'] ??
                                                  data['repartition']
                                                      ['temps'] ??
                                                  '-'),
                                          _buildInfoRow(
                                              'Imputat',
                                              data['repartition']
                                                      ['Imputation'] ??
                                                  data['repartition']
                                                      ['imputation'] ??
                                                  '-'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if ((data['Répartition Travail'] is List &&
                                (data['Répartition Travail'] as List)
                                    .isNotEmpty) ||
                            (data['repartition'] is Map))
                          const SizedBox(height: 16),
                        // Personnel Card
                        if (data['personnel'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.personnelLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(l10n.conductorLabel,
                                      data['personnel']['conductr'] ?? '-'),
                                  _buildInfoRow(l10n.graisseurLabel,
                                      data['personnel']['graisseur'] ?? '-'),
                                  _buildInfoRow(l10n.matriculeLabel,
                                      data['personnel']['matricules'] ?? '-'),
                                ],
                              ),
                            ),
                          ),
                        if (data['personnel'] is Map)
                          const SizedBox(height: 16),
                        // Consommation Card
                        if (data['consommation'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.consommationLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(l10n.triconeLabel,
                                      data['consommation']['tricone'] ?? '-'),
                                  _buildInfoRow(l10n.gasoilLabel,
                                      data['consommation']['gasoil'] ?? '-'),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Special handling for Suivi Camion, Chargeuse, Pelle, or truckData (case-insensitive)
    if (typeLower == 'suivi camion' ||
        typeLower.contains('chargeuse') ||
        typeLower.contains('pelle') ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('truckData'))) {
      final data = report.additionalData ?? {};
      final truckData =
          (data['truckData'] is List) ? List.from(data['truckData']) : [];

      // Calculate summary data
      final allTrips = truckData
          .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
          .toList();
      final Map<String, int> equipmentCounts = {};

      if (data['equipmentTrips'] != null && data['equipmentTrips'] is Map) {
        (data['equipmentTrips'] as Map).forEach((key, value) {
          equipmentCounts[key.toString()] = int.tryParse(value.toString()) ?? 0;
        });
      } else {
        for (var trip in allTrips) {
          final eq = trip['equipment'] ?? '-';
          equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
        }
      }
      final maxHeight = MediaQuery.of(context).size.height * 0.8;

      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dataVerification,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editReport(report),
                            tooltip: 'Modifier le rapport',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.date,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text(
                                    '${report.date.day}/${report.date.month}/${report.date.year}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(l10n.mine, data['mine'] ?? '-'),
                                _buildInfoRow(l10n.zone, data['zone'] ?? '-'),
                                _buildInfoRow(l10n.exit, data['sortie'] ?? '-'),
                                _buildInfoRow(
                                    l10n.poste,
                                    data['poste'] ??
                                        data['selectedPoste'] ??
                                        '-'),
                                _buildInfoRow(l10n.operationLabel,
                                    data['operationType'] ?? '-'),
                                _buildInfoRow(
                                    l10n.equipmentLabel,
                                    data['equipment'] ??
                                        data['selectedEquipment'] ??
                                        '-'),
                                if (data['selectedQualiteType'] != null)
                                  _buildInfoRow(l10n.qualityLabel,
                                      data['selectedQualiteType']),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Camions Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camions',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                if (truckData.isEmpty)
                                  Text(l10n.noTrucksAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                if (truckData.isNotEmpty)
                                  ...truckData.map((truck) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'C ${truck['truckNumber']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Chauffeur: ${truck['driver1'] ?? '-'}'),
                                          if (truck['counts'] != null &&
                                              (truck['counts'] is List) &&
                                              (truck['counts'] as List)
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Voyages',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                            ),
                                            ...List.generate(
                                                (truck['counts'] as List)
                                                    .length, (index) {
                                              final count = (truck['counts']
                                                  as List)[index];
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 16, top: 4),
                                                child: Row(
                                                  children: [
                                                    Text(
                                                      'v${index + 1}: ',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                    Text(
                                                      count['time'] ?? '-',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    const Text('|'),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      count['equipment'] ?? '-',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium,
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),
                                          ],
                                          if (truck != truckData.last)
                                            const Divider(),
                                        ],
                                      )),
                              ],
                            ),
                          ),
                        ),
                        // Résumé Card
                        Builder(
                          builder: (context) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Card(
                                color: Colors.grey[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.summaryLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Total de voyages: ${data['totalTrips'] ?? allTrips.length}'),
                                      const SizedBox(height: 8),
                                      ...equipmentCounts.entries.map((e) => Text(
                                          'Total pour ${e.key}: ${e.value}')),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                l10n.dataVerification,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editReport(report),
              tooltip: 'Modifier le rapport',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main fields
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.description,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(report.description.isNotEmpty
                          ? report.description
                          : 'Not filled'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.additionalData,
                  style: Theme.of(context).textTheme.titleLarge),
              _buildAdditionalDataView(report),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDataView(Report report) {
    final data = report.additionalData ?? {};
    final l10n = AppLocalizations.of(context)!;
    switch (report.type) {
      case 'Activity TNB':
        return _buildActivityReportAdditionalData(data, l10n);
      case 'daily TSUD':
        return _buildDailyReportAdditionalData(data, l10n);
      case 'Machine/Engin Arrêtés':
        return _buildMachinesEquipmentStoppedAdditionalData(data, l10n);
      case 'Suivi Camion':
        return _buildTruckTrackingAdditionalData(data, l10n);
      case 'R0':
        return _buildR0ReportAdditionalData(data, l10n);
      default:
        // Check if this is an R0 report by looking for mine and selectedPoste
        if (data.containsKey('mine') &&
            data.containsKey('selectedPoste') &&
            !data.containsKey('truckData')) {
          return _buildR0ReportAdditionalData(data, l10n);
        }
        // Check if this is a truck tracking report by looking for truckData
        if (data.containsKey('truckData')) {
          return _buildTruckTrackingAdditionalData(data, l10n);
        }
        // Fallback: show all additionalData key-value pairs
        if (data.isEmpty) return Text(l10n.noAdditionalData);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries
              .map<Widget>((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${entry.key}: ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(entry.value.toString())),
                      ],
                    ),
                  ))
              .toList(),
        );
    }
  }

  Widget _buildActivityReportAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) {
      return Text(l10n.noActivityData);
    }

    final stops = (data['stops'] is List) ? List.from(data['stops']) : [];
    final vibratorCounters = (data['vibrator Counters'] is List)
        ? List.from(data['vibrator Counters'])
        : [];
    final liaisonCounters = (data['liaison Counters'] is List)
        ? List.from(data['liaison Counters'])
        : [];
    final stockEntries =
        (data['stock'] is List) ? List.from(data['stock']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résumé des données',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(
                    'T H.A:',
                    _formatMinutesToHoursMinutes(
                        data['T H.A'] is int ? data['T H.A'] : 0)),
                _buildSummaryRow(
                    'T H.M:',
                    _formatMinutesToHoursMinutes(
                        data['T H.M'] is int ? data['T H.M'] : 0)),
                _buildSummaryRow(
                    'T H.V:',
                    _formatMinutesToHoursMinutes(
                        data['T H.V'] is int ? data['T H.V'] : 0)),
                _buildSummaryRow(
                    'T H.L:',
                    _formatMinutesToHoursMinutes(
                        data['T H.L'] is int ? data['T H.L'] : 0)),
                const SizedBox(height: 8),
                _buildSummaryRow('T Nr.A:', stops.length.toString()),
                _buildSummaryRow('T Nr.V:', vibratorCounters.length.toString()),
                _buildSummaryRow('T Nr.L:', liaisonCounters.length.toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stops.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.arretsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (vibratorCounters.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.vibrTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...vibratorCounters.map((counter) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: ${_getPosteString(counter['poste'], l10n)}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (liaisonCounters.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.liaisonTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...liaisonCounters.map((counter) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: \t${_getPosteString(counter['poste'], l10n)}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (stockEntries.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.stocksLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...stockEntries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: ${_getPosteString(entry['poste'], l10n)}, Parc: ${_getParkString(entry['park'], l10n)}, Type: ${_getStockTypeString(entry['type'], l10n)}, Qté: ${entry['quantity'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatMinutesToHoursMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return "0h 00m";
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
  }

  // Calculate downtime from stops list
  int _calculateDowntimeFromStops(List stops) {
    if (stops.isEmpty) return 0;
    final hasTimeRanges = stops.any((stop) =>
        (stop is Map && stop['start'] != null && stop['end'] != null) ||
        (stop is Map && stop['Début'] != null && stop['Fin'] != null));
    if (hasTimeRanges) {
      final rawRanges = stops
          .whereType<Map>()
          .map((stop) {
            final start = stop['start'] ?? stop['Début'];
            final end = stop['end'] ?? stop['Fin'];
            if (start == null || end == null) return null;
            return {
              'start': start.toString(),
              'end': end.toString(),
            };
          })
          .whereType<Map<String, String>>()
          .toList();
      final ranges = TimeCalculationService.parseTimeRanges(rawRanges);
      return TimeCalculationService.calculateTotalDowntimeMinutes(ranges);
    }
    return stops
        .map((stop) => _parseDurationToMinutes(stop['duration'] ?? ''))
        .fold(0, (a, b) => a + b);
  }

  // Parse duration string to minutes
  int _parseDurationToMinutes(String duration) {
    if (duration.isEmpty) return 0;
    final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
    final regex1 = RegExp(r'^(?:(\d{1,2})\s?[Hh:·]\s?)?(\d{1,2})$');
    final regex2 = RegExp(r'^(\d{1,2})\s?[Hh]$');
    final regex3 = RegExp(r'^(\d+)$');
    var match = regex1.firstMatch(cleaned);
    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      return hours * 60 + minutes;
    }
    match = regex2.firstMatch(cleaned);
    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      return hours * 60;
    }
    match = regex3.firstMatch(cleaned);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  // Validate and parse counter value
  double? _validateAndParseCounterValue(String value) {
    if (value.isEmpty) return 0;
    final cleaned =
        value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    if (cleaned == '' || cleaned == '.' || cleaned == ',') return null;
    return double.tryParse(cleaned);
  }

  // Calculate total counter minutes
  int _calculateTotalCounterMinutes(List counters) {
    double totalHours = 0;
    for (var counter in counters) {
      if (counter['startDefect'] == true || counter['endDefect'] == true) {
        continue;
      }
      var startVal = _validateAndParseCounterValue(counter['start'] ?? '');
      var endVal = _validateAndParseCounterValue(counter['end'] ?? '');
      if (startVal != null && endVal != null && endVal >= startVal) {
        totalHours += (endVal - startVal);
      }
    }
    return (totalHours * 60).round();
  }

  // Recalculate totals for Activity TNB reports
  Map<String, dynamic> _recalculateActivityTotals(Map<String, dynamic> data) {
    final updatedData = Map<String, dynamic>.from(data);

    final stops =
        (updatedData['Arrets'] is List) ? List.from(updatedData['Arrets']) : [];
    final vibratorCounters = (updatedData['vibrator Counters'] is List)
        ? List.from(updatedData['vibrator Counters'])
        : [];
    final liaisonCounters = (updatedData['liaison Counters'] is List)
        ? List.from(updatedData['liaison Counters'])
        : [];

    final totalDowntime = _calculateDowntimeFromStops(stops);
    const int totalPeriodMinutes = 24 * 60; // 24 hours in minutes
    final operatingTime =
        (totalPeriodMinutes - totalDowntime).clamp(0, totalPeriodMinutes);
    final totalVibratorMinutes =
        _calculateTotalCounterMinutes(vibratorCounters);
    final totalLiaisonMinutes = _calculateTotalCounterMinutes(liaisonCounters);

    updatedData['T H.A'] = totalDowntime;
    updatedData['T H.M'] = operatingTime;
    updatedData['T H.V'] = totalVibratorMinutes;
    updatedData['T H.L'] = totalLiaisonMinutes;

    return updatedData;
  }

  String _getPosteString(dynamic posteIndex, AppLocalizations l10n) {
    if (posteIndex == null) return '-';
    switch (posteIndex) {
      case 0:
        return l10n.poste3eme;
      case 1:
        return l10n.poste1er;
      case 2:
        return l10n.poste2eme;
      default:
        return '-';
    }
  }

  String _getParkString(dynamic parkIndex, AppLocalizations l10n) {
    if (parkIndex == null) return '-';
    switch (parkIndex) {
      case 0:
        return l10n.park1;
      case 1:
        return l10n.park2;
      case 2:
        return l10n.park3;
      default:
        return '-';
    }
  }

  String _getStockTypeString(dynamic typeIndex, AppLocalizations l10n) {
    if (typeIndex == null) return '-';
    switch (typeIndex) {
      case 0:
        return l10n.stockTypeNormal;
      case 1:
        return l10n.stockTypeOceane;
      case 2:
        return l10n.stockTypePb30;
      default:
        return '-';
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowSimple(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'Non renseigné' : value),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) {
      return Text(l10n.noDailyData);
    }

    final module1Stops =
        (data['module1Stops'] is List) ? List.from(data['module1Stops']) : [];
    final module2Stops =
        (data['module2Stops'] is List) ? List.from(data['module2Stops']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['secteur'] != null) Text('${l10n.sector}: ${data['secteur']}'),
        if (data['rapportNo'] != null)
          Text('${l10n.reportNo}: ${data['rapportNo']}'),
        if (data['machineEngins'] != null)
          Text('${l10n.machinesEquipment}: ${data['machineEngins']}'),
        const SizedBox(height: 16),
        // Module 1 Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.module1Label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    '${l10n.operatingTime}: ${_formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    '${l10n.stopTime}: ${_formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module1Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.stopsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...module1Stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Module 2 Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.module2Label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    '${l10n.operatingTime}: ${_formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    '${l10n.stopTime}: ${_formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module2Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l10n.stopsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...module2Stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachinesEquipmentStoppedAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) {
      return Text(l10n.noEquipmentStopped);
    }
    final equipmentList =
        (data['equipmentList'] is List) ? List.from(data['equipmentList']) : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reportDateLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (data['date'] != null) Text(data['date'].toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.stoppedEquipment,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (equipmentList.isEmpty)
                  Text(l10n.noEquipmentAdded,
                      style: const TextStyle(color: Colors.grey)),
                if (equipmentList.isNotEmpty)
                  ...equipmentList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final equipment = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.equipmentLabelWithIndex(index + 1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(l10n
                              .typeParam(equipment['equipmentType'] ?? '-')),
                          Text(l10n.reasonParam(equipment['Reason'] ?? '-')),
                          if (index < equipmentList.length - 1) const Divider(),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        if (equipmentList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${equipmentList.length} équipement${equipmentList.length > 1 ? 's' : ''} prêt${equipmentList.length > 1 ? 's' : ''} à être soumis',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTruckTrackingAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) {
      return Text(l10n.noTruckTrackingData);
    }
    final truckData =
        (data['truckData'] is List) ? List.from(data['truckData']) : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.infoLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                _buildInfoRowSimple('Mine', data['mine'] ?? '-'),
                _buildInfoRowSimple('Zone', data['zone'] ?? '-'),
                _buildInfoRowSimple('Sortie', data['sortie'] ?? '-'),
                _buildInfoRowSimple(
                    'Poste', data['poste'] ?? data['selectedPoste'] ?? '-'),
                _buildInfoRowSimple('Opération', data['operationType'] ?? '-'),
                _buildInfoRowSimple('Equip',
                    data['equipment'] ?? data['selectedEquipment'] ?? '-'),
                if (data['selectedQualiteType'] != null)
                  _buildInfoRowSimple('Qualité', data['selectedQualiteType']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.camionsLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (truckData.isEmpty) Text(l10n.noTrucksAdded),
                if (truckData.isNotEmpty)
                  ...truckData.map((truck) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.truckParam(truck['truckNumber'] ?? '-'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(l10n.driverParam(truck['driver1'] ?? '-')),
                          if (truck['counts'] != null &&
                              (truck['counts'] is List) &&
                              (truck['counts'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(l10n.tripsWithColon,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...List.generate((truck['counts'] as List).length,
                                (index) {
                              final count = (truck['counts'] as List)[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 4),
                                child: Row(
                                  children: [
                                    Text(l10n.tripLabelWithIndex(index + 1)),
                                    Text(count['time'] ?? '-'),
                                    const SizedBox(width: 12),
                                    const Text('|'),
                                    const SizedBox(width: 12),
                                    Text(count['equipment'] ?? '-'),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const Divider(),
                        ],
                      )),
              ],
            ),
          ),
        ),
        if (truckData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tripsSummary,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        'Total de voyages: ${data['totalTrips'] ?? truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).length}'),
                    const SizedBox(height: 8),
                    ...(data['equipmentTrips'] != null &&
                            data['equipmentTrips'] is Map)
                        ? (data['equipmentTrips'] as Map).entries.map((e) =>
                            Text(l10n.totalFor(
                                e.key.toString(), e.value.toString())))
                        : _buildEquipmentCounts(truckData, l10n),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildEquipmentCounts(List truckData, AppLocalizations l10n) {
    final allTrips = truckData
        .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
        .toList();
    final Map<String, int> equipmentCounts = {};
    for (var trip in allTrips) {
      final eq = trip['equipment'] ?? '-';
      equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
    }
    return equipmentCounts.entries
        .map((e) => Text(l10n.totalFor(e.key.toString(), e.value.toString())))
        .toList();
  }

  Widget _buildR0ReportAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) return Text(l10n.noR0Data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info OIB/EE Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.infoOibEeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                _buildSummaryItem('Mine', data['mine'] ?? ''),
                _buildSummaryItem('Zone', data['zone'] ?? ''),
                _buildSummaryItem('Sortie', data['sortie'] ?? ''),
                _buildSummaryItem('Catégorie', data['Category'] ?? ''),
                _buildSummaryItem('Type', data['Type'] ?? ''),
                _buildSummaryItem('Modèle', data['Model'] ?? ''),
                _buildSummaryItem(
                    'Poste', data['selectedPoste'] ?? data['poste'] ?? ''),
                if (data['carryOverFrom'] != null)
                  _buildSummaryItem(l10n.carryOver,
                      l10n.carriedOverFrom(data['carryOverFrom'])),
              ],
            ),
          ),
        ),
        // Compteurs Section
        if (data['Compteurs'] != null)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.counter,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  if (data['Compteurs'] is List)
                    ...List.generate((data['Compteurs'] as List).length,
                        (index) {
                      final compteur = (data['Compteurs'] as List)[index];
                      if (compteur['duree'] == null &&
                          compteur['note'] == null) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryItem(
                              'Début', compteur['duree']?.toString() ?? ''),
                          _buildSummaryItem(
                              'Fin', compteur['note']?.toString() ?? ''),
                          if (index < (data['Compteurs'] as List).length - 1)
                            const Divider(height: 12),
                        ],
                      );
                    })
                  else if (data['Compteurs'] is Map)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryItem('Début',
                            data['Compteurs']['duree']?.toString() ?? ''),
                        _buildSummaryItem(
                            'Fin', data['Compteurs']['note']?.toString() ?? ''),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (data['Compteurs'] != null) const SizedBox(height: 16),
        // Arrêts Section
        if (data['Arrets'] is List && (data['Arrets'] as List).isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.arretsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  ...List.from(data['Arrets']).map((arret) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.typeParam(arret['Arret'] ?? '-'),
                                style: TextStyle(
                                    color: arret['CarryOver'] == true
                                        ? Colors.orange
                                        : null,
                                    fontWeight: arret['CarryOver'] == true
                                        ? FontWeight.bold
                                        : null)),
                            _buildSummaryItem('Début', arret['Début'] ?? ''),
                            _buildSummaryItem('Fin', arret['Fin'] ?? ''),
                            if (arret['CarryOver'] == true)
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text("(${l10n.carryOver})",
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            const Divider(height: 8),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        if (data['Arrets'] is List && (data['Arrets'] as List).isNotEmpty)
          const SizedBox(height: 16),
        // Exploitation Section
        if (data['exploitation'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.exploitationLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem('H.M', data['exploitation']['H.M'] ?? ''),
                  _buildSummaryItem('H.A', data['exploitation']['H.A'] ?? ''),
                  _buildSummaryItem(l10n.metrageFore,
                      data['exploitation']['metrage fore'] ?? ''),
                  _buildSummaryItem(l10n.nrTrousFores,
                      data['exploitation']['Nr de Trous Fores'] ?? ''),
                  _buildSummaryItem(l10n.nrVoyages,
                      data['exploitation']['Nr de Voyages'] ?? ''),
                  _buildSummaryItem(l10n.m3Decapage,
                      data['exploitation']['M³ Decapages'] ?? ''),
                  _buildSummaryItem(
                      l10n.tonnageLabel, data['exploitation']['Tonnage'] ?? ''),
                  _buildSummaryItem(l10n.nombreTKU,
                      data['exploitation']['Nombre T.K.U'] ?? ''),
                  _buildSummaryItem(
                      l10n.rendementLabel,
                      data['exploitation']['Rendement %']?.toString() ??
                          data['exploitation']['Rendeme']?.toString() ??
                          ''),
                ],
              ),
            ),
          ),
        if (data['exploitation'] is Map) const SizedBox(height: 16),
        // Répartition Section
        if ((data['Répartition Travail'] != null &&
                data['Répartition Travail'] is List &&
                (data['Répartition Travail'] as List).isNotEmpty) ||
            (data['repartition'] != null && data['repartition'] is Map))
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.workDistributionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  if (data['Répartition Travail'] is List)
                    ...List.from(data['Répartition Travail'])
                        .map((repartition) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryItem(
                                      'Chantier',
                                      repartition['Chantier'] ??
                                          repartition['chantier'] ??
                                          ''),
                                  _buildSummaryItem(
                                      'Temps',
                                      repartition['temps'] ??
                                          repartition['Temps'] ??
                                          ''),
                                  _buildSummaryItem(
                                      'Imputation',
                                      repartition['imputation'] ??
                                          repartition['Imputation'] ??
                                          ''),
                                  const Divider(height: 8),
                                ],
                              ),
                            ))
                  else if (data['repartition'] is Map)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryItem(
                              'Chantier',
                              data['repartition']['Chantier'] ??
                                  data['repartition']['chantier'] ??
                                  ''),
                          _buildSummaryItem(
                              'Temps',
                              data['repartition']['Temps'] ??
                                  data['repartition']['temps'] ??
                                  ''),
                          _buildSummaryItem(
                              'Imputation',
                              data['repartition']['Imputation'] ??
                                  data['repartition']['imputation'] ??
                                  ''),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if ((data['Répartition Travail'] != null &&
                data['Répartition Travail'] is List &&
                (data['Répartition Travail'] as List).isNotEmpty) ||
            (data['repartition'] != null && data['repartition'] is Map))
          const SizedBox(height: 16),
        // Personnel Section
        if (data['personnel'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.personnelLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem(
                      'Conductr',
                      data['personnel']['conductr'] ??
                          data['personnel']['conductr'] ??
                          ''),
                  _buildSummaryItem(
                      'Graisseur', data['personnel']['graisseur'] ?? ''),
                  _buildSummaryItem(
                      'Matricules', data['personnel']['matricules'] ?? ''),
                ],
              ),
            ),
          ),
        if (data['personnel'] is Map) const SizedBox(height: 16),
        // Consommation Section
        if (data['consommation'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.consommationLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem(
                      'Tricone', data['consommation']['tricone'] ?? ''),
                  _buildSummaryItem(
                      'Gasoil', data['consommation']['gasoil'] ?? ''),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveReportUpdate(
    Report updatedReport,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n,
  ) async {
    try {
      final carryOverResult = _prepareR0CarryOverUpdates(updatedReport);
      await _databaseHelper.updateReport(carryOverResult.baseReport);
      for (final id in carryOverResult.deleteIds) {
        await _databaseHelper.deleteReport(id);
      }
      for (final report in carryOverResult.updateReports) {
        await _databaseHelper.updateReport(report);
      }
      for (final report in carryOverResult.insertReports) {
        await _databaseHelper.insertReport(report);
      }
      await _loadReports();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.reportUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.errorUpdatingReport)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedPosteFilter != null
            ? '${l10n.reports} - $_selectedPosteFilter'
            : l10n.reports),
        actions: [
          // Poste Filter Dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _selectedPosteFilter,
              hint: Text(l10n.allPostes,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: Container(),
              icon: Icon(Icons.filter_list,
                  color: Theme.of(context).colorScheme.onPrimary),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(l10n.allPostes),
                ),
                ..._availablePostes.map((poste) => DropdownMenuItem<String>(
                      value: poste,
                      child: Text(poste),
                    )),
              ],
              onChanged: _onPosteFilterChanged,
            ),
          ),
          // Clear filter button when filter is active
          if (_selectedPosteFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _onPosteFilterChanged(null),
              tooltip: l10n.clearFilter,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredReports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.description_outlined,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _selectedPosteFilter != null
                                ? l10n.noReportsFoundForPoste(
                                    _selectedPosteFilter!)
                                : l10n.noDataMessage,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_selectedPosteFilter != null) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => _onPosteFilterChanged(null),
                              child: Text(l10n.seeAllReports),
                            ),
                          ],
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Filter summary
                        if (_selectedPosteFilter != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.06),
                            child: Row(
                              children: [
                                Icon(Icons.filter_list,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.reportsFound(_filteredReports.length,
                                      _selectedPosteFilter!),
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = _filteredReports[index];
                                // Logic to determine title
                                String title = report.description;
                                final typeLower = report.type.toLowerCase();
                                if (typeLower == 'activity tnb') {
                                  title = l10n.activityReport;
                                } else if (typeLower == 'daily tsud') {
                                  title = l10n.dailyReport;
                                } else if (typeLower == 'suivi camion') {
                                  title = l10n.truckTracking;
                                } else if (typeLower ==
                                    'machine/engin arrêtés') {
                                  title =
                                      l10n.machinesEquipmentStoppedTitleShort;
                                } else if (typeLower == 'r0') {
                                  title = l10n.r0Report;
                                }

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: ListTile(
                                    title: Text(title),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${l10n.type}: ${report.type}'),
                                        Text(
                                            '${l10n.date}: ${DateFormat('yyyy-MM-dd HH:mm').format(report.date)}'),
                                        Text('${l10n.group}: ${report.group}'),
                                        if (report.additionalData != null &&
                                            (typeLower == 'suivi camion' ||
                                                typeLower
                                                    .contains('chargeuse') ||
                                                typeLower.contains('pelle') ||
                                                report.additionalData!
                                                    .containsKey(
                                                        'truckData'))) ...[
                                          const SizedBox(height: 4),
                                          if (report.additionalData!['mine'] !=
                                              null)
                                            Text(
                                                '${l10n.mine}: ${report.additionalData!['mine']} ${report.additionalData!['zone'] ?? ''}'),
                                          if (report.additionalData![
                                                  'totalTrips'] !=
                                              null)
                                            Text(
                                                '${l10n.totalVoyages}: ${report.additionalData!['totalTrips']}'),
                                        ],
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Popup menu for additional actions
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_horiz,
                                              size: 20),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          position: PopupMenuPosition.under,
                                          itemBuilder: (BuildContext context) =>
                                              [
                                            PopupMenuItem<String>(
                                              value: 'delete',
                                              height: 36,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.delete_outline,
                                                      size: 18,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    l10n.delete,
                                                    style: TextStyle(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onSelected: (String value) {
                                            if (value == 'delete') {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title:
                                                      Text(l10n.confirmDelete),
                                                  content:
                                                      Text(l10n.confirmDelete),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: Text(l10n.cancel),
                                                    ),
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                        _deleteReport(report);
                                                      },
                                                      child: Text(l10n.delete),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      _showReportDetails(report);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  // Daily Report Editor
  Future<void> _showDailyReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.editDailyTsud,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: l10n.description,
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: l10n.date,
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Module 1 Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.module1Label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showEditModuleDialog(
                                          report,
                                          data,
                                          'module1',
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.edit),
                                      label: Text(l10n.edit),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['module1Stops'] is List &&
                                    (data['module1Stops'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(l10n.stopsLabel,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  ...List.from(data['module1Stops'])
                                      .map((stop) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 4),
                                            child: Text(
                                                '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                                          )),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Module 2 Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.module2Label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showEditModuleDialog(
                                          report,
                                          data,
                                          'module2',
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.edit),
                                      label: Text(l10n.modifyLabel),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['module2Stops'] is List &&
                                    (data['module2Stops'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(l10n.stopsWithColon,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  ...List.from(data['module2Stops'])
                                      .map((stop) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 4),
                                            child: Text(
                                                '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                                          )),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stock Entries Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'stock',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStockEntryDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['stock'] is List &&
                                    (data['stock'] as List).isNotEmpty)
                                  ...List.from(data['stock'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stock = entry.value;
                                    final isSelected =
                                        _selectedStockIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.purple
                                            .withValues(alpha: 0.1),
                                        title: Text('Stock ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(stock['poste'], l10n)}'),
                                            Text(
                                                'Parc: ${_getParkString(stock['park'], l10n)}'),
                                            Text(
                                                'Type: ${_getStockTypeString(stock['type'], l10n)}'),
                                            Text(
                                                'Quantité: ${stock['quantity'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.purple)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStockIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Modifier l\'entrée de stock',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Supprimer l\'entrée de stock',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.noStockAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Edit Module Dialog for Daily Report
  Future<void> _showEditModuleDialog(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    List stops = List.from(data['${modulePrefix}Stops'] ?? []);

    // Ensure totals are calculated
    int totalDowntime = data['${modulePrefix}TotalDowntime'] ??
        _calculateDowntimeFromStops(stops);
    int operatingTime = data['${modulePrefix}OperatingTime'] ??
        ((24 * 60) - totalDowntime).clamp(0, 24 * 60);

    // Update data with calculated values
    data['${modulePrefix}TotalDowntime'] = totalDowntime;
    data['${modulePrefix}OperatingTime'] = operatingTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
              'Modifier ${modulePrefix.replaceFirst('module', 'Module ')}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arrêts (${stops.length})'),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _showAddStopDialogForModule(
                          report,
                          data,
                          modulePrefix,
                          stops,
                          setState,
                          setDialogState,
                          scaffoldMessenger,
                          l10n, (int newTotal) {
                        setState(() {
                          totalDowntime = newTotal;
                          operatingTime =
                              (24 * 60 - newTotal).clamp(0, 24 * 60);
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addButton),
                  ),
                ],
              ),
              if (stops.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...stops.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stop = entry.value;
                  return ListTile(
                    title: Text('Arrêt ${index + 1}'),
                    subtitle: Text(
                        '${_formatMinutesToHoursMinutes(_parseDurationToMinutes(stop['duration'] ?? ''))} - ${stop['nature'] ?? '-'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () async {
                            await _showEditStopDialogForModule(
                                report,
                                data,
                                modulePrefix,
                                stops,
                                index,
                                setState,
                                setDialogState,
                                scaffoldMessenger,
                                l10n, (int newTotal) {
                              setState(() {
                                totalDowntime = newTotal;
                                operatingTime =
                                    (24 * 60 - newTotal).clamp(0, 24 * 60);
                              });
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              stops.removeAt(index);
                              totalDowntime =
                                  _calculateDowntimeFromStops(stops);
                              operatingTime =
                                  (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                            });
                            // Update data
                            data['${modulePrefix}TotalDowntime'] =
                                totalDowntime;
                            data['${modulePrefix}OperatingTime'] =
                                operatingTime;
                            data['${modulePrefix}Stops'] = stops;
                            setDialogState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedData = Map<String, dynamic>.from(data);
                updatedData['${modulePrefix}OperatingTime'] = operatingTime;
                updatedData['${modulePrefix}TotalDowntime'] = totalDowntime;
                updatedData['${modulePrefix}Stops'] = stops;

                final updatedReport = Report(
                  id: report.id,
                  description: report.description,
                  type: report.type,
                  group: report.group,
                  date: report.date,
                  additionalData: updatedData,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  // Add Stop Dialog for Module
  Future<void> _showAddStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    String tempNature = '';
    String tempStopDuration = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(l10n.addStopTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setLocalState(() => tempStopDuration = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nature',
                  border: OutlineInputBorder(),
                  hintText: 'Maximum 20 caractères par ligne',
                ),
                maxLines: 5,
                onChanged: (value) {
                  // Split text into lines of max 20 characters
                  final words = value.split(' ');
                  final lines = <String>[];
                  String currentLine = '';

                  for (var word in words) {
                    if (('$currentLine $word').trim().length <= 20) {
                      currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                    } else {
                      if (currentLine.isNotEmpty) {
                        lines.add(currentLine);
                      }
                      currentLine = word;
                    }
                  }
                  if (currentLine.isNotEmpty) {
                    lines.add(currentLine);
                  }

                  setLocalState(() => tempNature = lines.join('\n'));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempStopDuration.isNotEmpty && tempNature.isNotEmpty) {
                  setState(() {
                    stops.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'duration': tempStopDuration,
                      'nature': tempNature,
                    });
                    final totalDowntime = _calculateDowntimeFromStops(stops);
                    data['${modulePrefix}TotalDowntime'] = totalDowntime;
                    data['${modulePrefix}OperatingTime'] =
                        (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                    data['${modulePrefix}Stops'] = stops;
                    setDialogState(() {});
                    onTotalDowntimeChanged(totalDowntime);
                    Navigator.pop(context);
                  });
                }
              },
              child: Text(l10n.addButton),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stop Dialog for Module
  Future<void> _showEditStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      int index,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    final stop = stops[index];
    String tempNature = stop['nature']?.toString() ?? '';
    String tempStopDuration = stop['duration']?.toString() ?? '';

    final durationController = TextEditingController(text: tempStopDuration);
    final natureController = TextEditingController(text: tempNature);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(l10n.editStopTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                controller: durationController,
                onChanged: (value) =>
                    setLocalState(() => tempStopDuration = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nature',
                  border: OutlineInputBorder(),
                  hintText: 'Maximum 20 caractères par ligne',
                ),
                controller: natureController,
                maxLines: 5,
                onChanged: (value) {
                  // Split text into lines of max 20 characters
                  final words = value.split(' ');
                  final lines = <String>[];
                  String currentLine = '';

                  for (var word in words) {
                    if (('$currentLine $word').trim().length <= 20) {
                      currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                    } else {
                      if (currentLine.isNotEmpty) {
                        lines.add(currentLine);
                      }
                      currentLine = word;
                    }
                  }
                  if (currentLine.isNotEmpty) {
                    lines.add(currentLine);
                  }

                  setLocalState(() => tempNature = lines.join('\n'));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempStopDuration.isNotEmpty && tempNature.isNotEmpty) {
                  setState(() {
                    stops[index] = {
                      'id': stop['id'],
                      'duration': tempStopDuration,
                      'nature': tempNature,
                    };
                    final totalDowntime = _calculateDowntimeFromStops(stops);
                    data['${modulePrefix}TotalDowntime'] = totalDowntime;
                    data['${modulePrefix}OperatingTime'] =
                        (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                    data['${modulePrefix}Stops'] = stops;
                    setDialogState(() {});
                    onTotalDowntimeChanged(totalDowntime);
                  });
                  Navigator.pop(context);
                }
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Truck Tracking Editor
  Future<void> _showTruckTrackingEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Modifier - R Camion',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: 'Date',
                                  value: report.date,
                                  isEditable: true,
                                  onSave: (value) async {
                                    final newDescription =
                                        "Truck Tracking - ${DateFormat('yyyy-MM-dd').format(value)} - ${report.group}";
                                    final updatedReport = report.copyWith(
                                      date: value,
                                      description: newDescription,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Mine',
                                  value: data['mine'] ?? '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['mine'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Zone',
                                  value: data['zone'] ?? '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['zone'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Sortie',
                                  value: data['sortie'] ?? '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['sortie'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Poste',
                                  value: data['selectedPoste'] ??
                                      data['poste'] ??
                                      '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['selectedPoste'] = value;
                                    final newDescription =
                                        "Truck Tracking - ${DateFormat('yyyy-MM-dd').format(report.date)} - $value";
                                    final updatedReport = report.copyWith(
                                      group: value,
                                      description: newDescription,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'équipement',
                                  value: data['equipment'] ??
                                      data['selectedEquipment'] ??
                                      '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['equipment'] = value;
                                    updatedData['selectedEquipment'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Opération',
                                  value: data['operationType'] ?? '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['operationType'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Type Qualité',
                                  value: data['selectedQualiteType'] ?? '',
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['selectedQualiteType'] = value;
                                    final updatedReport = report.copyWith(
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trucks Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Camions',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showDetailedTruckDialog(
                                          report,
                                          data,
                                          null,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.ajButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['truckData'] is List &&
                                    (data['truckData'] as List).isNotEmpty)
                                  ...List.from(data['truckData'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final truck = entry.value;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                            '${truck['truckNumber'] ?? index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${l10n.driverLabel}: ${truck['driver1'] ?? '-'}'),
                                            if (truck['counts'] is List &&
                                                (truck['counts'] as List)
                                                    .isNotEmpty)
                                              Text(
                                                  'Voyages: ${(truck['counts'] as List).length}'),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showDetailedTruckDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le camion',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteTruckDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le camion',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.noTrucksAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Detailed Truck Dialog (Add/Edit)
  Future<void> _showDetailedTruckDialog(
      Report report,
      Map<String, dynamic> data,
      int? index,
      StateSetter
          setReportState, // Used to trigger rebuilds in parent if needed, though Navigator.pop usually suffices.
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final isEditing = index != null;
    final truck =
        isEditing ? (data['truckData'] as List)[index] : <String, dynamic>{};
    final truckId = truck['id'] ?? const Uuid().v4();

    // Initialize temporary state
    String truckNumber = truck['truckNumber'] ?? '';
    String driver1 = truck['driver1'] ?? '';
    List<Map<String, dynamic>> counts = List<Map<String, dynamic>>.from(
        (truck['counts'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ??
            []);

    // Controllers
    final driverController = TextEditingController(text: driver1);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void addTrip() {
            var timeController = TextEditingController();
            String? selectedEquipment;
            DateTime selectedTripTime = DateTime.now();

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l10n.addButton),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.tripTime,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TimePickerSpinner(
                      is24HourMode: true,
                      isShowSeconds: false,
                      normalTextStyle:
                          const TextStyle(fontSize: 18, color: Colors.black54),
                      highlightedTextStyle:
                          const TextStyle(fontSize: 24, color: Colors.black),
                      spacing: 50,
                      itemHeight: 60,
                      isForce2Digits: true,
                      time: selectedTripTime,
                      onTimeChange: (dateTime) {
                        selectedTripTime = dateTime;
                        timeController.text =
                            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedEquipment,
                      decoration: const InputDecoration(
                        labelText:
                            'Heure', // This seems like a typo, should be l10n.equipmentLabel
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                            value: 'Chargeuse 992K',
                            child: Text(l10n.loader992k)),
                        DropdownMenuItem(
                            value: 'Chargeuse 994H',
                            child: Text(l10n.loader994h)),
                        DropdownMenuItem(
                            value: 'Pelle Hy',
                            child: Text(l10n.hydraulicShovel)),
                        DropdownMenuItem(
                            value: 'Pelle B1',
                            child: Text(l10n.electricShovelB1)),
                      ],
                      onChanged: (value) => selectedEquipment = value,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (timeController.text.isNotEmpty &&
                          selectedEquipment != null) {
                        setState(() {
                          counts.add({
                            'time': timeController.text,
                            'equipment': selectedEquipment,
                          });
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text(l10n.addButton),
                  ),
                ],
              ),
            );
          }

          void viewTrips() {
            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setTripState) => AlertDialog(
                  title: Text(l10n.tripDetails),
                  content: counts.isEmpty
                      ? Text(l10n.noTripsAdded)
                      : SizedBox(
                          width: 300,
                          height: 400,
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: counts.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, i) {
                                    final trip = counts[i];
                                    return ListTile(
                                      title: Text('v${i + 1}'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${l10n.tempsLabel}: ${trip['time']}'),
                                          Text(
                                              '${l10n.equipmentLabel}: ${trip['equipment'] ?? '-'}'),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          setTripState(() {
                                            counts.removeAt(i);
                                          });
                                          // Also update parent state to ensure sync
                                          setState(() {});
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.close),
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isEditing
                                ? l10n.editTruckTitle
                                : l10n.newTruckTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.selectTruckLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: predefinedTrucks.contains(truckNumber)
                                ? truckNumber
                                : null,
                            decoration: const InputDecoration(
                              labelText:
                                  'Chauffeur', // This seems like a typo, should be l10n.truckLabel
                              border: OutlineInputBorder(),
                            ),
                            items: predefinedTrucks.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => truckNumber = value);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(l10n.driverInfoLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextField(
                            controller: driverController,
                            decoration: InputDecoration(
                              labelText: l10n.driverLabel,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (value) => driver1 = value,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: Text(l10n.addTrip),
                                  onPressed: addTrip,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list),
                                  label: Text(l10n.viewTrips),
                                  onPressed: viewTrips,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (truckNumber.isNotEmpty && driver1.isNotEmpty) {
                              final updatedData =
                                  Map<String, dynamic>.from(data);
                              if (updatedData['truckData'] == null) {
                                updatedData['truckData'] = [];
                              }

                              final newTruck = {
                                'id': truckId,
                                'truckNumber': truckNumber,
                                'driver1': driver1,
                                'counts': counts,
                              };

                              if (isEditing) {
                                (updatedData['truckData'] as List)[index] =
                                    newTruck;
                              } else {
                                (updatedData['truckData'] as List)
                                    .add(newTruck);
                              }

                              final updatedReport = Report(
                                id: report.id,
                                description: report.description,
                                type: report.type,
                                group: report.group,
                                date: report.date,
                                additionalData: updatedData,
                              );

                              Navigator.pop(context);
                              _saveReportUpdate(
                                  updatedReport, scaffoldMessenger, l10n);
                              setReportState(() {});
                            }
                          },
                          child: Text(l10n.save),
                        ),
                      ],
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

  // Delete Truck Dialog for Truck Tracking
  Future<void> _showDeleteTruckDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteTruckTitle),
        content: Text(l10n.deleteTruckConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['truckData'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // R0 Report Editor
  Future<void> _showR0ReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    Map<String, dynamic> data = Map.from(report.additionalData ?? {});
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.editR0Title,
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: dialogContext,
                                  label: 'Date',
                                  value: report.date,
                                  isEditable: true,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Info OIB/EE Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Info OIB/EE',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _buildSummaryItem('Mine', data['mine'] ?? ''),
                                _buildSummaryItem('Zone', data['zone'] ?? ''),
                                _buildSummaryItem(
                                    'Sortie', data['sortie'] ?? ''),
                                _buildSummaryItem(
                                    'Catégorie', data['Category'] ?? ''),
                                _buildSummaryItem('Type', data['Type'] ?? ''),
                                _buildSummaryItem(
                                    'Modèle', data['Model'] ?? ''),
                                _buildSummaryItem(
                                    'Poste',
                                    data['selectedPoste'] ??
                                        data['poste'] ??
                                        ''),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Compteurs Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Compteurs',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (!((data['Compteurs'] is List &&
                                            (data['Compteurs'] as List)
                                                .isNotEmpty) ||
                                        (data['Compteurs'] is Map)))
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showAddR0CounterDialog(
                                                report,
                                                data,
                                                setDialogState,
                                                scaffoldMessenger,
                                                l10n),
                                        icon: const Icon(Icons.add),
                                        label: Text(l10n.addButton),
                                      ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if ((data['Compteurs'] is List &&
                                        (data['Compteurs'] as List)
                                            .isNotEmpty) ||
                                    (data['Compteurs'] is Map))
                                  if (data['Compteurs'] is List)
                                    ...List.from(data['Compteurs'])
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final compteur = entry.value;
                                      final isSelected =
                                          _selectedCounterIndex == index;
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : null,
                                        elevation: isSelected ? 4 : 1,
                                        child: ListTile(
                                          selected: isSelected,
                                          selectedTileColor: Colors.blue
                                              .withValues(alpha: 0.1),
                                          title: Text(l10n
                                              .genericCounterTitle(index + 1)),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Début: ${compteur['duree'] ?? '-'}'),
                                              Text(
                                                  'Fin: ${compteur['note'] ?? '-'}'),
                                            ],
                                          ),
                                          leading: isSelected
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.blue)
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _selectedCounterIndex =
                                                  isSelected ? null : index;
                                            });
                                          },
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                onPressed: () =>
                                                    _showEditR0CounterDialog(
                                                        report,
                                                        data,
                                                        index,
                                                        setDialogState,
                                                        scaffoldMessenger,
                                                        l10n),
                                                tooltip: l10n.editCounter,
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    size: 18,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _showDeleteR0CounterDialog(
                                                        report,
                                                        data,
                                                        index,
                                                        setDialogState,
                                                        scaffoldMessenger,
                                                        l10n),
                                                tooltip:
                                                    l10n.deleteCounterTooltip,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    })
                                  else if (data['Compteurs'] is Map)
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(l10n.counter),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Début: ${data['Compteurs']['duree'] ?? '-'}'),
                                            Text(
                                                'Fin: ${data['Compteurs']['note'] ?? '-'}'),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon:
                                              const Icon(Icons.edit, size: 18),
                                          onPressed: () => _showEditR0CounterDialog(
                                              report,
                                              data,
                                              0, // Map is treated as single item
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                          tooltip: l10n.editCounterTooltip,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(l10n.noCountersAdded,
                                        style: const TextStyle(
                                            color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Arrêts Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Arrêts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddR0StopDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.addButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['Arrets'] is List &&
                                    (data['Arrets'] as List).isNotEmpty)
                                  ...List.from(data['Arrets'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final arret = entry.value;
                                    final isSelected =
                                        _selectedStopIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.blue.withValues(alpha: 0.1),
                                        title: Text(l10n.stopIndex(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Type: ${arret['Arret'] ?? '-'}'),
                                            Text(
                                                'Début: ${arret['Début'] ?? '-'}'),
                                            Text('Fin: ${arret['Fin'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.blue)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStopIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditR0StopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier l\'arrêt',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteR0StopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer l\'arrêt',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(l10n.noStopsAdded,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Exploitation Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Exploitation',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0ExploitationDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      tooltip: 'Modifier l\'exploitation',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['exploitation'] is Map) ...[
                                  _buildSummaryItem(
                                      'H.M', data['exploitation']['H.M'] ?? ''),
                                  _buildSummaryItem(
                                      'H.A', data['exploitation']['H.A'] ?? ''),
                                  _buildSummaryItem(
                                      l10n.metrageFore,
                                      data['exploitation']['metrage fore'] ??
                                          ''),
                                  _buildSummaryItem(
                                      l10n.nrTrousFores,
                                      data['exploitation']
                                              ['Nr de Trous Fores'] ??
                                          ''),
                                  _buildSummaryItem(
                                      l10n.nrVoyages,
                                      data['exploitation']['Nr de Voyages'] ??
                                          ''),
                                  _buildSummaryItem(
                                      l10n.m3Decapage,
                                      data['exploitation']['M³ Decapages'] ??
                                          ''),
                                  _buildSummaryItem(l10n.tonnageLabel,
                                      data['exploitation']['Tonnage'] ?? ''),
                                  _buildSummaryItem(
                                      l10n.nombreTKU,
                                      data['exploitation']['Nombre T.K.U'] ??
                                          ''),
                                  _buildSummaryItem(
                                      l10n.rendementLabel,
                                      data['exploitation']['Rendement %'] ??
                                          data['exploitation']['Rendeme'] ??
                                          ''),
                                ] else
                                  Text(l10n.noExploitationData,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Répartition Travail Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Répartition Travail',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddR0WorkDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: Text(l10n.addButton),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if ((data['Répartition Travail'] is List &&
                                        (data['Répartition Travail'] as List)
                                            .isNotEmpty) ||
                                    (data['repartition'] is Map))
                                  if (data['Répartition Travail'] is List)
                                    ...List.from(data['Répartition Travail'])
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final index = entry.key;
                                      final repartition = entry.value;
                                      final isSelected =
                                          _selectedStockIndex == index;
                                      return Card(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        color: isSelected
                                            ? Colors.blue.withValues(alpha: 0.1)
                                            : null,
                                        elevation: isSelected ? 4 : 1,
                                        child: ListTile(
                                          selected: isSelected,
                                          selectedTileColor: Colors.blue
                                              .withValues(alpha: 0.1),
                                          title: Text('Travail ${index + 1}'),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  'Chantier: ${repartition['Chantier'] ?? repartition['chantier'] ?? '-'}'),
                                              Text(
                                                  'Temps: ${repartition['temps'] ?? repartition['Temps'] ?? '-'}'),
                                              Text(
                                                  'Imputation: ${repartition['imputation'] ?? repartition['Imputation'] ?? '-'}'),
                                            ],
                                          ),
                                          leading: isSelected
                                              ? const Icon(Icons.check_circle,
                                                  color: Colors.blue)
                                              : null,
                                          onTap: () {
                                            setState(() {
                                              _selectedStockIndex =
                                                  isSelected ? null : index;
                                            });
                                          },
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 18),
                                                onPressed: () =>
                                                    _showEditR0WorkDialog(
                                                        report,
                                                        data,
                                                        index,
                                                        setDialogState,
                                                        scaffoldMessenger,
                                                        l10n),
                                                tooltip: 'Modifier le travail',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    size: 18,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _showDeleteR0WorkDialog(
                                                        report,
                                                        data,
                                                        index,
                                                        setDialogState,
                                                        scaffoldMessenger,
                                                        l10n),
                                                tooltip: 'Supprimer le travail',
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    })
                                  else if (data['repartition'] is Map)
                                    Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(l10n.workDistributionLabel),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Chantier: ${data['repartition']['Chantier'] ?? data['repartition']['chantier'] ?? '-'}'),
                                            Text(
                                                'Temps: ${data['repartition']['Temps'] ?? data['repartition']['temps'] ?? '-'}'),
                                            Text(
                                                'Imputation: ${data['repartition']['Imputation'] ?? data['repartition']['imputation'] ?? '-'}'),
                                          ],
                                        ),
                                        trailing: IconButton(
                                          icon:
                                              const Icon(Icons.edit, size: 18),
                                          onPressed: () => _showEditR0WorkDialog(
                                              report,
                                              data,
                                              -1, // Special index for 'repartition' map
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                          tooltip: 'Modifier le travail',
                                        ),
                                      ),
                                    )
                                  else
                                    const Text(
                                        'Aucune répartition de travail ajoutée',
                                        style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Personnel Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Personnel',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0PersonnelDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      tooltip: 'Modifier le personnel',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['personnel'] is Map) ...[
                                  _buildSummaryItem(
                                      'Conductr',
                                      data['personnel']['conductr'] ??
                                          data['personnel']['conductr'] ??
                                          ''),
                                  _buildSummaryItem('Graisseur',
                                      data['personnel']['graisseur'] ?? ''),
                                  _buildSummaryItem('Matricules',
                                      data['personnel']['matricules'] ?? ''),
                                ] else
                                  Text(l10n.noPersonnelData,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Consommation Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Consommation',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0ConsumptionDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      tooltip: 'Modifier la consommation',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['consommation'] is Map) ...[
                                  _buildSummaryItem('Tricone',
                                      data['consommation']['tricone'] ?? ''),
                                  _buildSummaryItem('Gasoil',
                                      data['consommation']['gasoil'] ?? ''),
                                ] else
                                  Text(l10n.noConsumptionData,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add R0 Counter Dialog
  Future<void> _showAddR0CounterDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    String duree = '';
    String note = '';
    bool dureeDefaut = false;
    bool noteDefaut = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addCounterTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Début'),
                      onChanged: (value) => setState(() => duree = value),
                      enabled: !dureeDefaut,
                      controller: dureeDefaut
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: dureeDefaut,
                        onChanged: (val) => setState(() {
                          dureeDefaut = val ?? false;
                          if (dureeDefaut) duree = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(labelText: 'Fin'),
                      onChanged: (value) => setState(() => note = value),
                      enabled: !noteDefaut,
                      controller: noteDefaut
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: noteDefaut,
                        onChanged: (val) => setState(() {
                          noteDefaut = val ?? false;
                          if (noteDefaut) note = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (duree.isNotEmpty ||
                    note.isNotEmpty ||
                    dureeDefaut ||
                    noteDefaut) {
                  if (data['Compteurs'] == null) {
                    data['Compteurs'] = [];
                  }
                  (data['Compteurs'] as List).add({
                    'duree': duree,
                    'note': note,
                    'dureeDefaut': dureeDefaut,
                    'noteDefaut': noteDefaut,
                  });

                  // Recalculate hours
                  _recalculateR0Hours(data, report.date);

                  final updatedReport = report.copyWith(
                    additionalData: data,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit R0 Counter Dialog
  Future<void> _showEditR0CounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final dynamic compteurData = (data['Compteurs'] is List)
        ? (data['Compteurs'] as List)[index]
        : data['Compteurs'];
    String duree = compteurData['duree'] ?? '';
    String note = compteurData['note'] ?? '';
    bool dureeDefaut = compteurData['dureeDefaut'] == true;
    bool noteDefaut = compteurData['noteDefaut'] == true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier le compteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: dureeDefaut ? null : duree,
                      decoration: const InputDecoration(labelText: 'Début'),
                      onChanged: (value) => setState(() => duree = value),
                      enabled: !dureeDefaut,
                      controller: dureeDefaut
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: dureeDefaut,
                        onChanged: (val) => setState(() {
                          dureeDefaut = val ?? false;
                          if (dureeDefaut) duree = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: noteDefaut ? null : note,
                      decoration: const InputDecoration(labelText: 'Fin'),
                      onChanged: (value) => setState(() => note = value),
                      enabled: !noteDefaut,
                      controller: noteDefaut
                          ? TextEditingController(text: l10n.defautLabel)
                          : null,
                    ),
                  ),
                  Column(
                    children: [
                      Checkbox(
                        value: noteDefaut,
                        onChanged: (val) => setState(() {
                          noteDefaut = val ?? false;
                          if (noteDefaut) note = '';
                        }),
                      ),
                      Text(l10n.defautLabel,
                          style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final newCompteur = {
                  'duree': duree,
                  'note': note,
                  'dureeDefaut': dureeDefaut,
                  'noteDefaut': noteDefaut,
                };
                if (data['Compteurs'] is List) {
                  (data['Compteurs'] as List)[index] = newCompteur;
                } else {
                  data['Compteurs'] = newCompteur;
                }

                // Recalculate hours
                _recalculateR0Hours(data, report.date);

                final updatedReport = Report(
                  id: report.id,
                  description: report.description,
                  type: report.type,
                  group: report.group,
                  date: report.date,
                  additionalData: data,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete R0 Counter Dialog
  Future<void> _showDeleteR0CounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compteur'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce compteur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              (data['Compteurs'] as List).removeAt(index);

              // Recalculate hours
              _recalculateR0Hours(data, report.date);

              final updatedReport = report.copyWith(
                additionalData: data,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Build Add/Edit R0 Stop Dialog (same as in R0 creation)
  Widget _buildAddR0StopDialog(
    BuildContext context,
    AppLocalizations l10n, {
    required Map<String, List<String>> arretCategories,
    Map<String, String>? initialItem,
  }) {
    int step = 0;
    String? selectedCategory = initialItem?['Catégorie'];
    if (selectedCategory == null || selectedCategory.isEmpty) {
      selectedCategory = initialItem != null
          ? arretCategories.keys.firstWhere(
              (cat) => arretCategories[cat]!.contains(initialItem['Arret']),
              orElse: () => '')
          : null;
    }
    if (selectedCategory != null && selectedCategory.isEmpty) {
      selectedCategory = null;
    }
    String? selectedType = initialItem?['Arret'];
    String startTime = initialItem?['Début'] ?? '';
    String endTime = initialItem?['Fin'] ?? '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        Widget content;
        if (step == 0) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: InputDecoration(
                      labelText: l10n.category,
                      border: const OutlineInputBorder()),
                  items: arretCategories.keys
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value;
                      selectedType = null;
                    });
                  },
                ),
              ),
            ],
          );
        } else if (step == 1 && selectedCategory != null) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText: l10n.selectStopTypeStep,
                      border: const OutlineInputBorder()),
                  items: arretCategories[selectedCategory]!
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value;
                    });
                  },
                ),
              ),
            ],
          );
        } else if (step == 2 && selectedType != null) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.category}: $selectedCategory'),
              Text('${l10n.type}: $selectedType'),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.startTimeLabel),
                subtitle:
                    Text(startTime.isEmpty ? l10n.selectTimeTitle : startTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title: Text(l10n.selectTimeTitle),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('start_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: const TextStyle(
                                fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(
                                fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(
                                  hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: Text(l10n.okButton),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.endTimeLabel),
                subtitle:
                    Text(endTime.isEmpty ? l10n.selectTimeTitle : endTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title: Text(l10n.selectTimeTitle),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('end_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: const TextStyle(
                                fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(
                                fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(
                                  hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: Text(l10n.okButton),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
            ],
          );
        } else {
          content = const SizedBox();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step == 0) ...[
              Text(l10n.selectCategoryStep,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 1) ...[
              Text(l10n.selectStopTypeStep,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 2) ...[
              Text(l10n.enterDetailsStep,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (step > 0)
                  OutlinedButton(
                    onPressed: () => setDialogState(() => step--),
                    child: Text(l10n.previous),
                  ),
                if ((step == 0 && selectedCategory != null) ||
                    (step == 1 && selectedType != null))
                  ElevatedButton(
                    onPressed: () {
                      setDialogState(() => step++);
                    },
                    child: Text(l10n.next),
                  ),
                if (step == 2 && selectedType != null)
                  ElevatedButton(
                    onPressed: startTime.isNotEmpty && endTime.isNotEmpty
                        ? () {
                            Navigator.of(context).pop({
                              'Catégorie': selectedCategory ?? '',
                              'Arret': selectedType!,
                              'Début': startTime,
                              'Fin': endTime,
                            });
                          }
                        : null,
                    child: Text(l10n.finishButton),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  // Add R0 Stop Dialog
  Future<void> _showAddR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final arretCategories = _arretsForReport(data);
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addStopTitle),
        content: SingleChildScrollView(
          child: _buildAddR0StopDialog(context, l10n,
              arretCategories: arretCategories),
        ),
      ),
    );

    if (result != null) {
      if (data['Arrets'] == null) {
        data['Arrets'] = [];
      }
      (data['Arrets'] as List).add({
        ...result,
        'OriginalStart': result['Début'] ?? '',
        'OriginalEnd': result['Fin'] ?? '',
      });

      // Recalculate hours
      _recalculateR0Hours(data, report.date);

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Edit R0 Stop Dialog
  Future<void> _showEditR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final arret = (data['Arrets'] as List)[index] as Map<String, dynamic>;
    final initialItem = {
      'Catégorie': (arret['Catégorie'] ?? '').toString(),
      'Arret': (arret['Arret'] ?? '').toString(),
      'Début': (arret['OriginalStart'] ?? arret['Début'] ?? '').toString(),
      'Fin': (arret['OriginalEnd'] ?? arret['Fin'] ?? '').toString(),
    };
    final arretCategories = _arretsForReport(data);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.editStopTitle),
        content: SingleChildScrollView(
          child: _buildAddR0StopDialog(context, l10n,
              arretCategories: arretCategories, initialItem: initialItem),
        ),
      ),
    );

    if (result != null) {
      final updatedArret = Map<String, dynamic>.from(arret);
      updatedArret['Catégorie'] = result['Catégorie'] ?? '';
      updatedArret['Arret'] = result['Arret'] ?? '';
      updatedArret['Début'] = result['Début'] ?? '';
      updatedArret['Fin'] = result['Fin'] ?? '';
      updatedArret['OriginalStart'] = result['Début'] ?? '';
      updatedArret['OriginalEnd'] = result['Fin'] ?? '';
      (data['Arrets'] as List)[index] = updatedArret;

      // Recalculate hours
      _recalculateR0Hours(data, report.date);

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Delete R0 Stop Dialog
  Future<void> _showDeleteR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteStopTitle),
        content: Text(l10n.deleteStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              (data['Arrets'] as List).removeAt(index);

              // Recalculate hours
              _recalculateR0Hours(data, report.date);

              setDialogState(() {});

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: data,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Edit R0 Exploitation Dialog
  Future<void> _showEditR0ExploitationDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final exploitation = data['exploitation'] ?? {};
    final hmController = TextEditingController(text: exploitation['H.M'] ?? '');
    final haController = TextEditingController(text: exploitation['H.A'] ?? '');
    final metrageForeController =
        TextEditingController(text: exploitation['metrage fore'] ?? '');
    final nrTrousForesController =
        TextEditingController(text: exploitation['Nr de Trous Fores'] ?? '');
    final nrVoyagesController =
        TextEditingController(text: exploitation['Nr de Voyages'] ?? '');
    final m3DecapageController =
        TextEditingController(text: exploitation['M³ Decapages'] ?? '');
    final tonnageController =
        TextEditingController(text: exploitation['Tonnage'] ?? '');
    final nombreTKUController =
        TextEditingController(text: exploitation['Nombre T.K.U'] ?? '');
    final rendementPctController = TextEditingController(
        text: data['exploitation']['Rendement %']?.toString() ??
            data['exploitation']['Rendeme']?.toString() ??
            '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editExploitationTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.hmLabel,
                    helperText: l10n.calculatedAutomatically,
                  ),
                  controller: hmController,
                  enabled: false, // Read-only
                  style: const TextStyle(color: Colors.grey),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.haLabel,
                    helperText: l10n.calculatedAutomatically,
                  ),
                  controller: haController,
                  enabled: false, // Read-only
                  style: const TextStyle(color: Colors.grey),
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.metrageFore),
                  controller: metrageForeController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.nrTrousFores),
                  controller: nrTrousForesController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.nrVoyages),
                  controller: nrVoyagesController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.m3Decapage),
                  controller: m3DecapageController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.tonnageLabel),
                  controller: tonnageController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.nombreTKU),
                  controller: nombreTKUController,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: l10n.rendementLabel,
                    helperText: l10n.calculatedAutomatically,
                  ),
                  controller: rendementPctController,
                  enabled: false,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                // Recalculate H.M and H.A from Arrets and Compteurs
                _recalculateR0Hours(data, report.date);

                // Update the fields
                if (data['exploitation'] == null) {
                  data['exploitation'] = {};
                }
                data['exploitation']['metrage fore'] =
                    metrageForeController.text;
                data['exploitation']['Nr de Trous Fores'] =
                    nrTrousForesController.text;
                data['exploitation']['Nr de Voyages'] =
                    nrVoyagesController.text;
                data['exploitation']['M³ Decapages'] =
                    m3DecapageController.text;
                data['exploitation']['Tonnage'] = tonnageController.text;
                data['exploitation']['Nombre T.K.U'] = nombreTKUController.text;
                // Rendement % remains as is (calculated or previous value)

                final updatedReport = report.copyWith(
                  additionalData: data,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Add R0 Work Dialog
  Future<void> _showAddR0WorkDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    String chantier = '';
    String temps = '';
    String imputation = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.addWorkDistributionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: l10n.chantierLabel),
                onChanged: (value) => setState(() => chantier = value),
              ),
              TextField(
                decoration: InputDecoration(labelText: l10n.tempsLabel),
                onChanged: (value) => setState(() => temps = value),
              ),
              TextField(
                decoration: InputDecoration(labelText: l10n.imputationLabel),
                onChanged: (value) => setState(() => imputation = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (chantier.isNotEmpty ||
                    temps.isNotEmpty ||
                    imputation.isNotEmpty) {
                  // Migration: If repartition (Map) exists and Répartition Travail (List) doesn't, migrate it
                  if (data['repartition'] is Map &&
                      (data['Répartition Travail'] == null ||
                          (data['Répartition Travail'] as List).isEmpty)) {
                    data['Répartition Travail'] = [data['repartition']];
                    data.remove(
                        'repartition'); // Remove old key to avoid confusion
                  }

                  if (data['Répartition Travail'] == null) {
                    data['Répartition Travail'] = [];
                  }
                  (data['Répartition Travail'] as List).add({
                    'Chantier': chantier,
                    'Temps': temps,
                    'Imputation': imputation,
                  });

                  final updatedReport = report.copyWith(
                    additionalData: data,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }

  // Edit R0 Work Dialog
  Future<void> _showEditR0WorkDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final dynamic repartition = (index == -1)
        ? data['repartition']
        : (data['Répartition Travail'] as List)[index];
    final chantierController = TextEditingController(
        text: repartition['Chantier'] ?? repartition['chantier'] ?? '');
    final tempsController = TextEditingController(
        text: repartition['Temps'] ?? repartition['temps'] ?? '');
    final imputationController = TextEditingController(
        text: repartition['Imputation'] ?? repartition['imputation'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editWorkDistributionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: l10n.chantierLabel),
                  controller: chantierController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.tempsLabel),
                  controller: tempsController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.imputationLabel),
                  controller: imputationController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (index == -1) {
                  data['repartition'] = {
                    'Chantier': chantierController.text,
                    'Temps': tempsController.text,
                    'Imputation': imputationController.text,
                  };
                } else {
                  (data['Répartition Travail'] as List)[index] = {
                    'Chantier': chantierController.text,
                    'Temps': tempsController.text,
                    'Imputation': imputationController.text,
                  };
                }

                final updatedReport = report.copyWith(
                  additionalData: data,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Delete R0 Work Dialog
  Future<void> _showDeleteR0WorkDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteWorkDistributionTitle),
        content: Text(l10n.deleteWorkDistributionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              (data['Répartition Travail'] as List).removeAt(index);

              final updatedReport = report.copyWith(
                additionalData: data,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  // Edit R0 Personnel Dialog
  Future<void> _showEditR0PersonnelDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final personnel = data['personnel'] ?? {};
    final conductrController =
        TextEditingController(text: personnel['conductr'] ?? '');
    final graisseurController =
        TextEditingController(text: personnel['graisseur'] ?? '');
    final matriculesController =
        TextEditingController(text: personnel['matricules'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editPersonnelTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: l10n.conductrLabel),
                  controller: conductrController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.graisseurLabel),
                  controller: graisseurController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.matriculesLabel),
                  controller: matriculesController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                data['personnel'] = {
                  'conductr': conductrController.text,
                  'graisseur': graisseurController.text,
                  'matricules': matriculesController.text,
                };

                final updatedReport = report.copyWith(
                  additionalData: data,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Edit R0 Consumption Dialog
  Future<void> _showEditR0ConsumptionDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final consommation = data['consommation'] ?? {};
    final triconeController =
        TextEditingController(text: consommation['tricone'] ?? '');
    final gasoilController =
        TextEditingController(text: consommation['gasoil'] ?? '');

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.editConsumptionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: l10n.triconeLabel),
                  controller: triconeController,
                ),
                TextField(
                  decoration: InputDecoration(labelText: l10n.gasoilLabel),
                  controller: gasoilController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                data['consommation'] = {
                  'tricone': triconeController.text,
                  'gasoil': gasoilController.text,
                };

                final updatedReport = report.copyWith(
                  additionalData: data,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                setDialogState(() {});
              },
              child: Text(l10n.modifyLabel),
            ),
          ],
        ),
      ),
    );
  }

  // Generic Editor
  Future<void> _showGenericEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    final bool isTruckOrR0 = report.type.toLowerCase() == 'r0' ||
        report.type.toLowerCase().contains('camion');

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Modifier - ${report.type}',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: l10n.description,
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: dialogContext,
                                  label: l10n.date,
                                  value: report.date,
                                  isEditable: !isTruckOrR0,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: l10n.type,
                                  value: report.type,
                                  isEditable: !isTruckOrR0,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: value,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: l10n.groupLabel,
                                  value: report.group,
                                  isEditable: !isTruckOrR0,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: value,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Additional Data Card (if any)
                        if (report.additionalData != null &&
                            report.additionalData!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.additionalDataLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildGenericAdditionalData(
                                      report.additionalData!),
                                ],
                              ),
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
      ),
    );
  }

  // Helper method to display generic additional data
  Widget _buildGenericAdditionalData(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${entry.key}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
