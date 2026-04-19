import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/domain/models/report.dart';
import 'package:provider/provider.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/data/services/google_sheets_service.dart';
import 'package:r0/domain/services/time_calculation_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:uuid/uuid.dart';
import 'package:r0/data/constants/r0_arrets_data.dart';
import 'package:r0/presentation/theme.dart';
import 'package:r0/presentation/widgets/spinner_time_picker_dialog.dart';
import 'dart:math' as math;

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

class _TnbStopCategory {
  final String label;
  final List<String> types;

  const _TnbStopCategory({required this.label, required this.types});
}

class _TnbStopLocation {
  final String code;
  final String label;

  const _TnbStopLocation({required this.code, required this.label});
}

class _StopTimeSelectionResult {
  final TimeOfDay start;
  final TimeOfDay? end;

  const _StopTimeSelectionResult({required this.start, required this.end});
}

class _GroupedStopEntry {
  final String type;
  final int totalDurationMinutes;
  final List<int> sourceIndexes;
  final bool hasPendingStop;

  const _GroupedStopEntry({
    required this.type,
    required this.totalDurationMinutes,
    required this.sourceIndexes,
    required this.hasPendingStop,
  });
}

class _StopTimeEntryPage extends StatefulWidget {
  final String titleSuffix;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final bool initialPending;
  final String? assignedPoste;

  const _StopTimeEntryPage({
    required this.titleSuffix,
    this.initialStartTime,
    this.initialEndTime,
    this.initialPending = false,
    this.assignedPoste,
  });

  @override
  State<_StopTimeEntryPage> createState() => _StopTimeEntryPageState();
}

class _StopTimeEntryPageState extends State<_StopTimeEntryPage> {
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime ?? TimeOfDay.now();
    _endTime = widget.initialEndTime ?? _startTime;
    _isPending = widget.initialPending;
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay value) => (value.hour * 60) + value.minute;

  int _toCycleMinutes(TimeOfDay value) {
    final minutes = _toMinutes(value);
    return minutes < _cycleAnchorMinutes ? minutes + (24 * 60) : minutes;
  }

  String? _normalizedPoste() {
    final raw = widget.assignedPoste?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw
        .toLowerCase()
        .replaceAll('poste', '')
        .replaceAll('ème', 'eme')
        .replaceAll('er', 'e')
        .replaceAll(RegExp(r'[^0-9a-z]'), '');
    if (normalized == '0' || normalized.startsWith('3')) return '3';
    if (normalized == '1' || normalized.startsWith('1')) return '1';
    if (normalized == '2' || normalized.startsWith('2')) return '2';
    return null;
  }

  bool _isTimeWithinAssignedPoste(TimeOfDay value) {
    final normalizedPoste = _normalizedPoste();
    if (normalizedPoste == null) return true;

    final minutes = _toMinutes(value);
    switch (normalizedPoste) {
      case '3':
        return minutes >= (22 * 60 + 30) || minutes < (6 * 60 + 30);
      case '1':
        return minutes >= (6 * 60 + 30) && minutes < (14 * 60 + 30);
      case '2':
        return minutes >= (14 * 60 + 30) && minutes < (22 * 60 + 30);
      default:
        return true;
    }
  }

  String _assignedPosteWindowLabel() {
    switch (_normalizedPoste()) {
      case '3':
        return '22:30 → 06:30';
      case '1':
        return '06:30 → 14:30';
      case '2':
        return '14:30 → 22:30';
      default:
        return '';
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _startTime,
      title: AppLocalizations.of(context)!.startTimeLabel,
    );
    if (picked == null) return;

    if (!_isTimeWithinAssignedPoste(picked)) {
      if (!mounted) return;
      final assignedWindow = _assignedPosteWindowLabel();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignedWindow.isEmpty
                ? AppLocalizations.of(context)!.startTimeInShiftError
                : "${AppLocalizations.of(context)!.startTimeInShiftError} ($assignedWindow).",
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _endTime,
      title: AppLocalizations.of(context)!.endTimeLabel,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes =
        _toCycleMinutes(_endTime) - _toCycleMinutes(_startTime);
    final hasValidRange =
        _isPending || (durationMinutes > 0 && durationMinutes <= 24 * 60);
    final hasValidStartForPoste = _isTimeWithinAssignedPoste(_startTime);
    final canSubmit = hasValidRange && hasValidStartForPoste;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF202820), Color(0xFF1C211D)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.addStopWithSuffix(widget.titleSuffix),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      AppLocalizations.of(context)!.timeEntryTitle,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        AppLocalizations.of(context)!.startTimeLabel,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      subtitle: Text(
                        _formatTime(_startTime),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 34,
                      ),
                      onTap: _pickStartTime,
                    ),
                    if (_assignedPosteWindowLabel().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          AppLocalizations.of(context)!.allowedStartRange(_assignedPosteWindowLabel()),
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        AppLocalizations.of(context)!.endTimeLabel,
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      subtitle: Text(
                        _isPending ? 'Pending' : _formatTime(_endTime),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 34,
                      ),
                      onTap: _isPending ? null : _pickEndTime,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Arrêt en cours',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        AppLocalizations.of(context)!.stopInProgressDescription,
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: _isPending,
                      onChanged: (value) => setState(() => _isPending = value),
                    ),
                    const SizedBox(height: 16),
                    if (!hasValidRange)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          AppLocalizations.of(context)!.stopTimeRangeError,
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    if (!hasValidStartForPoste)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _assignedPosteWindowLabel().isEmpty
                              ? AppLocalizations.of(context)!.startTimeInShiftError
                              : "${AppLocalizations.of(context)!.startTimeInShiftError} (${_assignedPosteWindowLabel()}).",
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            AppLocalizations.of(context)!.previous,
                            style: TextStyle(
                                color: AppColors.success, fontSize: 22),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(150, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: canSubmit
                              ? () {
                                  Navigator.of(context).pop(
                                    _StopTimeSelectionResult(
                                      start: _startTime,
                                      end: _isPending ? null : _endTime,
                                    ),
                                  );
                                }
                              : null,
                          child: const Text(
                            AppLocalizations.of(context)!.add,
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _getLocalizedCategoryLabel(BuildContext context, String internalLabel) {
  final l10n = AppLocalizations.of(context)!;
  if (internalLabel == 'Arrêts Extérieures') {
    return l10n.externalStopsCategory;
  }
  if (internalLabel == 'Arrêts Materiel' || internalLabel == 'Arrêts Matériel') {
    return l10n.equipmentStopsCategory;
  }
  if (internalLabel == "Arrêts d'Exploitation") {
    return l10n.exploitationStopsCategory;
  }
  return internalLabel;
}

class _StopActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _StopActionMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}

const List<_TnbStopCategory> _tnbStopCategories = [
  _TnbStopCategory(
    label: 'Arrêts Extérieures',
    types: [
      'MP - Manque Produit',
      'CC - Coupure De Courant',
      'AD - Arrêts Décidés',
      'STS - Stock Saturée',
      'DS - Attente Dégagement Stérile',
      'MB - Manque Bull',
      'Aut - Autre',
    ],
  ),
  _TnbStopCategory(
    label: 'Arrêts Materiel',
    types: [
      'AE - Arrêts Éléctrique',
      'AM - Arrêts Mécanique',
      'AI - Arrêts Installateur',
      'AESYS - Arrêts Entretien Systématique',
    ],
  ),
  _TnbStopCategory(
    label: "Arrêts d'Exploitation",
    types: [
      'NET - Nettoyage',
      'NETG - Nettoyage Général',
      'SURCH - Surcharge',
      'Attente Vidange Extracteur',
      'Attente Vidange Silo',
      'DEC - Décolmatage',
      'MO - Manque Opérateur',
    ],
  ),
];

const List<_TnbStopCategory> _tsudStopCategories = [
  _TnbStopCategory(
    label: 'Arrêts Extérieures',
    types: [
      'MP - Manque Produit',
      'CC - Coupure De Courant',
      'AD - Arrêts Décidés',
      'STS - Stock Saturée',
      'DS - Attente Dégagement Stérile',
      'MB - Manque Bull',
      'Aut - Autre',
    ],
  ),
  _TnbStopCategory(
    label: 'Arrêts Materiel',
    types: [
      'AE - Arrêts Éléctrique',
      'AM - Arrêts Mécanique',
      'AI - Arrêts Installateur',
      'AESYS - Arrêts Entretien Systématique',
    ],
  ),
  _TnbStopCategory(
    label: "Arrêts d'Exploitation",
    types: [
      'NET - Nettoyage',
      'NETG - Nettoyage Général',
      'SURCH - Surcharge',
      'DEC - Décolmatage',
      'MO - Manque Opérateur',
    ],
  ),
];

String _normalizeTnbStopValue(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _extractTnbStopTypeCode(String? type) {
  final rawType = type?.trim() ?? '';
  if (rawType.isEmpty) {
    return '';
  }

  return rawType.split(' - ').first.trim().toUpperCase();
}

bool _tnbStopTypeRequiresLocation(String? type) {
  final rawType = type?.trim() ?? '';
  if (rawType.isEmpty) {
    return false;
  }

  final typeCode = _extractTnbStopTypeCode(rawType);
  if (const {'AE', 'AM', 'AI', 'AESYS', 'SURCH', 'DEC', 'NET'}
      .contains(typeCode)) {
    return true;
  }

  final normalizedType = _normalizeTnbStopValue(rawType);
  return normalizedType == 'attentevidangeextracteur' ||
      normalizedType == 'attentevidangesilo';
}

bool _tnbStopTypeRequiresDetail(String? type) =>
    const {'AE', 'AM', 'AI', 'AESYS'}.contains(_extractTnbStopTypeCode(type));

bool _tnbStopTypeAlwaysMirrors(String? type) {
  final typeCode = _extractTnbStopTypeCode(type);
  return const {'MP', 'CC', 'AD', 'STS', 'DS', 'MB', 'NETG', 'AUT'}
      .contains(typeCode);
}

const List<_TnbStopLocation> _tnbStopLocations = [
  _TnbStopLocation(code: 'TR', label: 'tremie'),
  _TnbStopLocation(code: 'VIB1', label: 'vibreur 1'),
  _TnbStopLocation(code: 'VIB2', label: 'vibreur 2'),
  _TnbStopLocation(code: 'EXT2', label: 'extracteur 2'),
  _TnbStopLocation(code: 'C0', label: 'convoyeur'),
  _TnbStopLocation(code: 'C1', label: 'convoyeur'),
  _TnbStopLocation(code: 'EP', label: 'épierreur'),
  _TnbStopLocation(code: 'C2', label: 'convoyeur'),
  _TnbStopLocation(code: 'SILO', label: 'silo'),
  _TnbStopLocation(code: 'AL1', label: 'alimentateur 01'),
  _TnbStopLocation(code: 'AL2', label: 'alimentateur 02'),
  _TnbStopLocation(code: 'AL3', label: 'alimentateur 03'),
  _TnbStopLocation(code: 'AL4', label: 'alimentateur 04'),
  _TnbStopLocation(code: 'CR1', label: 'crible'),
  _TnbStopLocation(code: 'CR2', label: 'crible'),
  _TnbStopLocation(code: 'CR3', label: 'crible'),
  _TnbStopLocation(code: 'CR4', label: 'crible'),
  _TnbStopLocation(code: 'C3', label: 'convoyeur'),
  _TnbStopLocation(code: 'S2', label: 'convoyeur'),
  _TnbStopLocation(code: 'S3', label: 'convoyeur'),
  _TnbStopLocation(code: 'S4', label: 'convoyeur'),
  _TnbStopLocation(code: 'S5', label: 'convoyeur'),
  _TnbStopLocation(code: 'S6', label: 'convoyeur'),
  _TnbStopLocation(code: 'MTS', label: 'mise à térill secours'),
  _TnbStopLocation(code: 'MTP', label: 'mise à térill principal'),
  _TnbStopLocation(code: 'LN', label: 'convoyeur ln'),
  _TnbStopLocation(code: 'L', label: 'convoyeur Ln'),
  _TnbStopLocation(code: 'L1', label: 'convoyeur L1'),
  _TnbStopLocation(code: 'L2', label: 'convoyeur L2'),
  _TnbStopLocation(code: 'G3', label: 'convoyeur g3'),
  _TnbStopLocation(code: 'G6', label: 'convoyeur G4'),
  _TnbStopLocation(code: 'STK1', label: 'stockeuse 1'),
  _TnbStopLocation(code: 'STK2', label: 'stockeuse 2'),
  _TnbStopLocation(code: 'PE3', label: 'PE3'),
  _TnbStopLocation(code: 'PET', label: 'PET'),
  _TnbStopLocation(code: 'PEI', label: 'PEI'),
  _TnbStopLocation(code: 'BAR', label: 'Barre de raclage'),
  _TnbStopLocation(code: 'AUT', label: 'AUT'),
  _TnbStopLocation(code: 'TNB', label: 'tremie nord boucraa'),
];

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
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  static const int _maxCycleMinutes = 24 * 60;
  ReportRepository get _reportRepository => context.read<ReportRepository>();
  List<Report> _reports = [];
  List<Report> _filteredReports = [];
  bool _isLoading = true;
  String? _selectedPosteFilter;
  bool _isSelectionMode = false;
  final Set<int> _selectedReportIds = <int>{};

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

  int _toCycleMinutesFromTimeOfDay(TimeOfDay value) {
    final minutes = (value.hour * 60) + value.minute;
    return minutes < _cycleAnchorMinutes ? minutes + _maxCycleMinutes : minutes;
  }

  int _durationMinutesInCycle(TimeOfDay start, TimeOfDay end) =>
      _toCycleMinutesFromTimeOfDay(end) - _toCycleMinutesFromTimeOfDay(start);

  int _currentShiftTabIndex() {
    final now = DateTime.now();
    final totalMinutes = (now.hour * 60) + now.minute;

    if (totalMinutes >= 1350 || totalMinutes < 390) {
      return 0; // 3ème (22:30 - 06:30)
    }

    if (totalMinutes < 870) {
      return 1; // 1er (06:30 - 14:30)
    }

    return 2; // 2ème (14:30 - 22:30)
  }

  int _minutesFromStopStart(dynamic rawValue) {
    if (rawValue == null) return (24 * 60) + 1;
    final value = rawValue.toString();
    if (!value.contains(':')) return (24 * 60) + 1;
    final split = value.split(':');
    if (split.length != 2) return (24 * 60) + 1;
    final hour = int.tryParse(split[0]);
    final minute = int.tryParse(split[1]);
    if (hour == null || minute == null) return (24 * 60) + 1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (24 * 60) + 1;
    }
    return (hour * 60) + minute;
  }

  void _sortArretsByStartTime(List<dynamic> arrets) {
    arrets.sort((a, b) {
      final aMap = a is Map ? a : const {};
      final bMap = b is Map ? b : const {};
      final aMinutes = _minutesFromStopStart(
        aMap['OriginalStart'] ?? aMap['startTime'] ?? aMap['Début'],
      );
      final bMinutes = _minutesFromStopStart(
        bMap['OriginalStart'] ?? bMap['startTime'] ?? bMap['Début'],
      );
      return aMinutes.compareTo(bMinutes);
    });
  }

  int _tripTimeToMinutes(dynamic rawTime) {
    final value = rawTime?.toString() ?? '';
    final parts = value.split(':');
    if (parts.length != 2) return (24 * 60) + 1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return (24 * 60) + 1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (24 * 60) + 1;
    }
    return (hour * 60) + minute;
  }

  void _sortTripCountsByTime(List<Map<String, dynamic>> counts) {
    counts.sort((a, b) =>
        _tripTimeToMinutes(a['time']).compareTo(_tripTimeToMinutes(b['time'])));
  }

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
      final reports = await _reportRepository.getReports();
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
      await _reportRepository.deleteReport(report.id!);
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

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedReportIds.clear();
      }
    });
  }

  void _toggleReportSelection(Report report) {
    final reportId = report.id;
    if (reportId == null) return;

    setState(() {
      if (_selectedReportIds.contains(reportId)) {
        _selectedReportIds.remove(reportId);
      } else {
        _selectedReportIds.add(reportId);
      }
    });
  }

  void _selectAllFilteredReports() {
    final selectableIds =
        _filteredReports.map((report) => report.id).whereType<int>().toSet();

    setState(() {
      if (_selectedReportIds.length == selectableIds.length) {
        _selectedReportIds.clear();
      } else {
        _selectedReportIds
          ..clear()
          ..addAll(selectableIds);
      }
    });
  }

  Future<void> _deleteSelectedReports() async {
    if (_selectedReportIds.isEmpty || !mounted) return;

    final count = _selectedReportIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.delete),
        content:
            Text(AppLocalizations.of(context)!.deleteSelectedReports(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final count = _selectedReportIds.length;
      for (final reportId in _selectedReportIds) {
        await _reportRepository.deleteReport(reportId);
      }

      if (!mounted) return;
      setState(() {
        _isSelectionMode = false;
        _selectedReportIds.clear();
      });
      await _loadReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .reportsDeletedSuccessfully(count))),
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

    if (report.isSentToSheets) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.reportSentToSheetsReadOnly)),
      );
      return;
    }

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

  Future<void> _sendReportToSheets(Report report) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (report.isSentToSheets) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.reportAlreadySentToSheets)),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _reportRepository.sendReportToSheets(report);
      await _loadReports();
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.reportSentToSheets)),
        );
      }
    } catch (e) {
      if (mounted) {
        final duplicateMessage = e is DuplicateReportDateException
            ? e.message
            : AppLocalizations.of(context)!.reportSendToSheetsFailed;
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(duplicateMessage)),
        );
      }
    } finally {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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
                          AppLocalizations.of(context)!.editActivityTnb,
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
                  child: DefaultTabController(
                    initialIndex: _currentShiftTabIndex(),
                    length: 4,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.thirdPoste),
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.firstPoste),
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .secondPoste),
                              Tab(text: AppLocalizations.of(context)!.global),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildActivityEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '3',
                              ),
                              _buildActivityEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '1',
                              ),
                              _buildActivityEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '2',
                              ),
                              _buildTnbReportDetailsPage(
                                data: data,
                                reportDate: report.date,
                                l10n: l10n,
                              ),
                            ],
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

  Widget _buildActivityEditorTabContent({
    required Report report,
    required Map<String, dynamic> data,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
    String? shiftKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.infoLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  _buildEditableField(
                    context: context,
                    label: AppLocalizations.of(context)!.description,
                    isEditable: false,
                    value: report.description,
                    onSave: (value) async {},
                  ),
                  const SizedBox(height: 8),
                  _buildEditableDateField(
                    context: context,
                    label: AppLocalizations.of(context)!.date,
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
          _buildTnbStopsManagementCard(
            report,
            data,
            setDialogState,
            scaffoldMessenger,
            l10n,
            shiftKey: shiftKey,
          ),
          const SizedBox(height: 16),
          _buildTnbCounterManagementCard(
            report,
            data,
            setDialogState,
            scaffoldMessenger,
            l10n,
            shiftKey: shiftKey,
          ),
          const SizedBox(height: 16),
          _buildTnbStockManagementCard(
            report,
            data,
            setDialogState,
            scaffoldMessenger,
            l10n,
            shiftKey: shiftKey,
          ),
        ],
      ),
    );
  }

  // Add Stop Dialog for Activity Report
  Future<void> _showAddStopDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      {String? shiftKey}) async {
    _TnbStopCategory? selectedCategory;
    String? selectedType;
    _TnbStopLocation? selectedLocation;
    String stopDetail = '';

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedType);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedType);
          final previewLocation = requiresLocation && selectedLocation != null
              ? '${selectedLocation!.code} - ${selectedLocation!.label}'
              : '';
          final previewStop = <String, dynamic>{
            'nature': selectedType ?? '',
            'detail': requiresDetail ? stopDetail.trim() : '',
            'location': previewLocation,
            'startTime': '',
            'endTime': '',
            'duration': '',
          };
          final canSubmit = selectedCategory != null &&
              selectedType != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.addStopTitle),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_TnbStopCategory>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: _tnbStopCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(_getLocalizedCategoryLabel(context, category.label)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedType = null;
                          selectedLocation = null;
                          stopDetail = '';
                        });
                      },
                      hint: Text(
                          AppLocalizations.of(context)!.selectStopCategory),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Type d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value;
                            selectedLocation = null;
                            stopDetail = '';
                          });
                        },
                        hint: const Text('Sélectionner le type d\'arrêt'),
                      ),
                    ],
                    if (requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<_TnbStopLocation>(
                        initialValue: selectedLocation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: _tnbStopLocations
                            .map(
                              (location) => DropdownMenuItem<_TnbStopLocation>(
                                value: location,
                                child: Text(
                                    '${location.code} - ${location.label}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLocation = value;
                          });
                        },
                        hint:
                            Text(AppLocalizations.of(context)!.selectLocation),
                      ),
                    ],
                    if (requiresDetail) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopDetail,
                        decoration: const InputDecoration(
                          labelText: "Détail de l'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            stopDetail = value;
                          });
                        },
                      ),
                    ],
                    if (selectedType != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _formatTnbActivityStopSummary(
                          previewStop,
                          index: ((data['Arrets'] as List?)?.length ?? 0) + 1,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final assignedPoste = _assignedPosteForStopDialog(
                          data,
                          shiftKey: shiftKey,
                        );
                        final selectedTimeResult =
                            await _showStopTimeEntryDialog(
                          titleSuffix: selectedType ?? '',
                          assignedPoste: assignedPoste,
                        );
                        if (selectedTimeResult == null) {
                          return;
                        }
                        final posteValidation =
                            _validateStopStartInAssignedPoste(
                          selectedTimeResult.start,
                          assignedPoste,
                        );
                        if (posteValidation != null) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text(posteValidation),
                                  backgroundColor: AppColors.error),
                            );
                          }
                          return;
                        }

                        final durationMinutes = selectedTimeResult.end == null
                            ? null
                            : _durationMinutesInCycle(
                                selectedTimeResult.start,
                                selectedTimeResult.end!,
                              );
                        final durationText = durationMinutes == null
                            ? 'Pending'
                            : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
                        final formattedLocation = requiresLocation
                            ? '${selectedLocation!.code} - ${selectedLocation!.label}'
                            : '';

                        final updatedData = Map<String, dynamic>.from(data);
                        if (updatedData['Arrets'] == null) {
                          updatedData['Arrets'] = [];
                        }
                        (updatedData['Arrets'] as List).add({
                          'id':
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          'duration': durationText,
                          'category': selectedCategory!.label,
                          'Catégorie': selectedCategory!.label,
                          'nature': selectedType!,
                          'Arret': selectedType!,
                          'location': formattedLocation,
                          'detail': requiresDetail ? stopDetail.trim() : '',
                          'Lieu': formattedLocation,
                          'Détail': requiresDetail ? stopDetail.trim() : '',
                          'startTime':
                              formatTimeOfDay(selectedTimeResult.start),
                          'endTime': selectedTimeResult.end == null
                              ? 'Pending'
                              : formatTimeOfDay(selectedTimeResult.end!),
                          'Début': formatTimeOfDay(selectedTimeResult.start),
                          'Fin': selectedTimeResult.end == null
                              ? 'Pending'
                              : formatTimeOfDay(selectedTimeResult.end!),
                          'shiftKey': shiftKey ?? '',
                        });
                        _sortArretsByStartTime(updatedData['Arrets'] as List);

                        final recalculatedData = _recalculateActivityTotals(
                          updatedData,
                          reportDate: report.date,
                        );

                        final updatedReport = Report(
                          id: report.id,
                          description: report.description,
                          type: report.type,
                          group: report.group,
                          date: report.date,
                          additionalData: recalculatedData,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        _applyUpdatedReportDataToDialog(data, updatedReport);
                        _saveReportUpdate(
                            updatedReport, scaffoldMessenger, l10n);
                        setDialogState(() {
                          _selectedStopIndex = null;
                        });
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.next),
              ),
            ],
          );
        },
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
      AppLocalizations l10n,
      {String? shiftKey}) async {
    final rawStop = (data['Arrets'] as List)[index];
    final stop = rawStop is Map
        ? Map<String, dynamic>.from(rawStop)
        : <String, dynamic>{};

    String normalizeValue(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    _TnbStopCategory? findCategory() {
      final storedCategory =
          (stop['category'] ?? stop['Catégorie'] ?? '').toString().trim();
      if (storedCategory.isNotEmpty) {
        for (final category in _tnbStopCategories) {
          if (normalizeValue(category.label) ==
              normalizeValue(storedCategory)) {
            return category;
          }
        }
      }

      final storedType =
          (stop['nature'] ?? stop['Arret'] ?? '').toString().trim();
      if (storedType.isNotEmpty) {
        for (final category in _tnbStopCategories) {
          if (category.types.any(
              (type) => normalizeValue(type) == normalizeValue(storedType))) {
            return category;
          }
        }
      }
      return null;
    }

    _TnbStopLocation? findLocation() {
      final locationValue =
          (stop['location'] ?? stop['Lieu'] ?? '').toString().trim();
      for (final location in _tnbStopLocations) {
        final candidate = '${location.code} - ${location.label}';
        if (locationValue == candidate ||
            locationValue == location.code ||
            locationValue.startsWith('${location.code} -')) {
          return location;
        }
      }
      return null;
    }

    TimeOfDay? parseTime(dynamic value) {
      if (value == null) return null;
      final raw = value.toString().trim();
      final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(raw);
      if (match == null) return null;
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour == null || minute == null) return null;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
      return TimeOfDay(hour: hour, minute: minute);
    }

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    _TnbStopCategory? selectedCategory = findCategory();
    final storedType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '')
            .toString()
            .trim();
    String? selectedType = selectedCategory != null &&
            selectedCategory.types.any(
                (type) => normalizeValue(type) == normalizeValue(storedType))
        ? selectedCategory.types.firstWhere(
            (type) => normalizeValue(type) == normalizeValue(storedType),
          )
        : null;
    _TnbStopLocation? selectedLocation = findLocation();
    String stopDetail = (stop['detail'] ?? stop['Détail'] ?? '').toString();
    TimeOfDay? selectedStart = parseTime(stop['startTime'] ?? stop['Début']);
    TimeOfDay? selectedEnd = parseTime(stop['endTime'] ?? stop['Fin']);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedType);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedType);
          final canSubmit = selectedCategory != null &&
              selectedType != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.editStopTitle),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_TnbStopCategory>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: _tnbStopCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(_getLocalizedCategoryLabel(context, category.label)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedType = null;
                          selectedLocation = null;
                          stopDetail = '';
                        });
                      },
                      hint: const Text('Sélectionner la catégorie d\'arrêt'),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Type d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedType = value;
                            selectedLocation = null;
                            stopDetail = '';
                          });
                        },
                        hint:
                            Text(AppLocalizations.of(context)!.selectStopType),
                      ),
                    ],
                    if (requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<_TnbStopLocation>(
                        initialValue: selectedLocation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: _tnbStopLocations
                            .map(
                              (location) => DropdownMenuItem<_TnbStopLocation>(
                                value: location,
                                child: Text(
                                    '${location.code} - ${location.label}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLocation = value;
                          });
                        },
                        hint:
                            Text(AppLocalizations.of(context)!.selectLocation),
                      ),
                    ],
                    if (requiresDetail) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopDetail,
                        decoration: const InputDecoration(
                          labelText: "Détail de l'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            stopDetail = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final selectedTimeResult =
                            await _showStopTimeEntryDialog(
                          titleSuffix: selectedType ?? '',
                          initialStart: selectedStart,
                          initialEnd: selectedEnd,
                          assignedPoste: _assignedPosteForStopDialog(
                            data,
                            shiftKey: shiftKey,
                          ),
                        );
                        if (selectedTimeResult == null) {
                          return;
                        }

                        selectedStart = selectedTimeResult.start;
                        selectedEnd = selectedTimeResult.end;

                        final durationMinutes = selectedEnd == null
                            ? null
                            : _durationMinutesInCycle(
                                selectedStart!,
                                selectedEnd!,
                              );
                        final durationText = durationMinutes == null
                            ? 'Pending'
                            : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';

                        final formattedLocation = requiresLocation
                            ? '${selectedLocation!.code} - ${selectedLocation!.label}'
                            : '';

                        final updatedData = Map<String, dynamic>.from(data);
                        final updatedStop = Map<String, dynamic>.from(stop);
                        updatedStop['id'] = stop['id'] ?? const Uuid().v4();
                        updatedStop['duration'] = durationText;
                        updatedStop['category'] = selectedCategory!.label;
                        updatedStop['Catégorie'] = selectedCategory!.label;
                        updatedStop['nature'] = selectedType!;
                        updatedStop['Arret'] = selectedType!;
                        updatedStop['location'] = formattedLocation;
                        updatedStop['detail'] =
                            requiresDetail ? stopDetail.trim() : '';
                        updatedStop['Lieu'] = formattedLocation;
                        updatedStop['Détail'] =
                            requiresDetail ? stopDetail.trim() : '';
                        updatedStop['startTime'] =
                            formatTimeOfDay(selectedStart!);
                        updatedStop['endTime'] = selectedEnd == null
                            ? 'Pending'
                            : formatTimeOfDay(selectedEnd!);
                        updatedStop['Début'] = formatTimeOfDay(selectedStart!);
                        updatedStop['Fin'] = selectedEnd == null
                            ? 'Pending'
                            : formatTimeOfDay(selectedEnd!);
                        if (shiftKey != null && shiftKey.isNotEmpty) {
                          updatedStop['shiftKey'] = shiftKey;
                        }

                        (updatedData['Arrets'] as List)[index] = updatedStop;
                        _sortArretsByStartTime(updatedData['Arrets'] as List);

                        final recalculatedData = _recalculateActivityTotals(
                          updatedData,
                          reportDate: report.date,
                        );

                        final updatedReport = Report(
                          id: report.id,
                          description: report.description,
                          type: report.type,
                          group: report.group,
                          date: report.date,
                          additionalData: recalculatedData,
                        );

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                        _applyUpdatedReportDataToDialog(data, updatedReport);
                        _saveReportUpdate(
                            updatedReport, scaffoldMessenger, l10n);
                        setDialogState(() {
                          _selectedStopIndex = null;
                        });
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.next),
              ),
            ],
          );
        },
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
    final rawStop = (data['Arrets'] as List)[index];
    final stop = rawStop is Map
        ? Map<String, dynamic>.from(rawStop)
        : <String, dynamic>{};
    final stopType = _getTnbStopTypeLabel(stop);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          stopType.isNotEmpty
              ? '${AppLocalizations.of(context)!.deleteStopTitle} - $stopType'
              : AppLocalizations.of(context)!.deleteStopTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.deleteStopConfirm),
            const SizedBox(height: 12),
            Text(_formatTnbActivityStopSummary(stop, index: index + 1)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['Arrets'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(
                updatedData,
                reportDate: report.date,
              );

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _applyUpdatedReportDataToDialog(data, updatedReport);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {
                _selectedStopIndex = null;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildTnbStopsManagementCard(
    Report report,
    Map<String, dynamic> data,
    StateSetter setDialogState,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n, {
    String? shiftKey,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.stopsLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddStopDialog(
                    report,
                    data,
                    setDialogState,
                    scaffoldMessenger,
                    l10n,
                    shiftKey: shiftKey,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.ajButton),
                ),
              ],
            ),
            const Divider(height: 16),
            if (data['Arrets'] is List && (data['Arrets'] as List).isNotEmpty)
              ...List.from(data['Arrets']).asMap().entries.where((entry) {
                if (shiftKey == null) return true;
                final raw = entry.value;
                if (raw is! Map) return false;
                return _stopMatchesShift(
                  stop: Map<String, dynamic>.from(raw),
                  baseDate: report.date,
                  shiftKey: shiftKey,
                );
              }).map((entry) {
                final index = entry.key;
                final stop = entry.value is Map
                    ? Map<String, dynamic>.from(entry.value)
                    : <String, dynamic>{};
                final isSelected = _selectedStopIndex == index;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color:
                      isSelected ? Colors.green.withValues(alpha: 0.1) : null,
                  elevation: isSelected ? 4 : 1,
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.green.withValues(alpha: 0.1),
                    title: Text(
                      _formatTnbActivityStopSummary(stop, index: index + 1),
                    ),
                    subtitle: _isPendingStop(stop)
                        ? const Text(
                            'Arrêt en cours',
                            style: TextStyle(color: AppColors.success),
                          )
                        : null,
                    leading: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedStopIndex = isSelected ? null : index;
                      });
                    },
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Actions arrêt',
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      position: PopupMenuPosition.under,
                      onSelected: (value) {
                        switch (value) {
                          case 'end':
                            _endPendingActivityStop(
                              report,
                              data,
                              index,
                              setDialogState,
                              scaffoldMessenger,
                              l10n,
                            );
                            break;
                          case 'edit':
                            _showEditStopDialog(
                              report,
                              data,
                              index,
                              setDialogState,
                              scaffoldMessenger,
                              l10n,
                            );
                            break;
                          case 'delete':
                            _showDeleteStopDialog(
                              report,
                              data,
                              index,
                              setDialogState,
                              scaffoldMessenger,
                              l10n,
                            );
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        if (_isPendingStop(stop))
                          PopupMenuItem<String>(
                            value: 'end',
                            child: ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.stop_circle_outlined,
                                color: AppColors.success,
                              ),
                              title: Text(
                                  AppLocalizations.of(context)!.finishLabel),
                            ),
                          ),
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              Icons.edit_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title:
                                Text(AppLocalizations.of(context)!.modifyLabel),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            title: Text(AppLocalizations.of(context)!.delete),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              Text(AppLocalizations.of(context)!.aucunArret,
                  style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTnbCounterManagementCard(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      {String? shiftKey}) {
    final counters = _buildTnbCounterDisplayList(data);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Compteurs TNB',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              "Ajout, modification et suppression s'appliquent aux cinq compteurs fixes.",
            ),
            const Divider(height: 16),
            ...counters.map((counter) {
              final label = counter['label'] ?? '';
              final segments = _buildTnbCounterShiftSegments(
                data: data,
                label: label,
                baseDate: report.date,
              );
              final selectedSegment = shiftKey == null
                  ? null
                  : segments.firstWhere(
                      (segment) => segment['shiftKey'] == shiftKey,
                      orElse: () => const {'start': '', 'end': ''},
                    );
              final displayStart =
                  (selectedSegment?['start'] ?? counter['start'] ?? '').trim();
              final displayEnd =
                  (selectedSegment?['end'] ?? counter['end'] ?? '').trim();
              final hasDisplayValue = displayStart.isNotEmpty;
              final operatingHours = hasDisplayValue
                  ? _counterShiftHours(displayStart, displayEnd)
                  : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(label),
                  subtitle: Text(
                    '${AppLocalizations.of(context)!.start}: ${hasDisplayValue ? displayStart : '-'}\n'
                    'End: ${hasDisplayValue ? (displayEnd.isNotEmpty ? displayEnd : '-') : '-'}\n'
                    'Heures de marche: ${hasDisplayValue ? _formatTnbCounterNumber(operatingHours) : '0'} h',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(hasDisplayValue ? Icons.edit : Icons.add,
                            size: 18),
                        onPressed: () => _showTnbCounterValueDialog(
                          report: report,
                          data: data,
                          label: label,
                          initialValue: counter['start'] ?? '',
                          isEditing: hasDisplayValue,
                          shiftKey: shiftKey,
                          setDialogState: setDialogState,
                          scaffoldMessenger: scaffoldMessenger,
                          l10n: l10n,
                        ),
                        tooltip: hasDisplayValue
                            ? AppLocalizations.of(context)!.editCounter
                            : AppLocalizations.of(context)!.ajButton,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 18, color: Colors.red),
                        onPressed: hasDisplayValue
                            ? () => _showDeleteTnbCounterDialog(
                                  report: report,
                                  data: data,
                                  label: label,
                                  shiftKey: shiftKey,
                                  setDialogState: setDialogState,
                                  scaffoldMessenger: scaffoldMessenger,
                                  l10n: l10n,
                                )
                            : null,
                        tooltip: AppLocalizations.of(context)!.deleteCounter,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTnbStockManagementCard(
    Report report,
    Map<String, dynamic> data,
    StateSetter setDialogState,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n, {
    String? shiftKey,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${AppLocalizations.of(context)!.stocksLabel} & ${AppLocalizations.of(context)!.voyagesLabel}',
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _availableStockPostesFromData(data).isEmpty
                      ? null
                      : () => _showAddStockEntryDialog(report, data,
                          setDialogState, scaffoldMessenger, l10n),
                  icon: const Icon(Icons.add),
                  label: Text(
                      '${AppLocalizations.of(context)!.add} ${AppLocalizations.of(context)!.stocksLabel} & ${AppLocalizations.of(context)!.voyagesLabel}'),
                ),
              ],
            ),
            const Divider(height: 16),
            if (data['stock'] is List && (data['stock'] as List).isNotEmpty)
              ...List.from(data['stock']).asMap().entries.where((entry) {
                if (shiftKey == null) return true;
                return _normalizePosteKey(entry.value['poste']?.toString()) ==
                    shiftKey;
              }).map((entry) {
                final index = entry.key;
                final stock = entry.value;
                final isSelected = _selectedStockIndex == index;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color:
                      isSelected ? Colors.purple.withValues(alpha: 0.1) : null,
                  elevation: isSelected ? 4 : 1,
                  child: ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.purple.withValues(alpha: 0.1),
                    title: Text(AppLocalizations.of(context)!
                        .stockTitleIndex(index + 1)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Poste: ${_getPosteString(stock['poste'], l10n)}'),
                        Text('Voyages GAT: ${stock['gatTrips'] ?? '-'}'),
                        Text('Voyages TEREX: ${stock['terexTrips'] ?? '-'}'),
                        Text(
                            'Quantité: ${_getComputedStockQuantity(Map<String, dynamic>.from(stock))}'),
                        Text('Parc: ${_getParkString(stock['park'], l10n)}'),
                        Text(
                            'Type: ${_getStockTypeString(stock['type'], l10n)}'),
                      ],
                    ),
                    leading: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.purple)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedStockIndex = isSelected ? null : index;
                      });
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _showEditStockEntryDialog(
                              report,
                              data,
                              index,
                              setDialogState,
                              scaffoldMessenger,
                              l10n),
                          tooltip:
                              AppLocalizations.of(context)!.editStockEntryTitle,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          onPressed: () => _showDeleteStockEntryDialog(
                              report,
                              data,
                              index,
                              setDialogState,
                              scaffoldMessenger,
                              l10n),
                          tooltip: AppLocalizations.of(context)!
                              .deleteStockEntryTitle,
                        ),
                      ],
                    ),
                  ),
                );
              })
            else
              Text(AppLocalizations.of(context)!.noStockEntriesAdded,
                  style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  List<String> get _tnbShiftKeys => const ['3', '1', '2'];

  List<Map<String, String>> _buildTnbCounterShiftSegments({
    required Map<String, dynamic> data,
    required String label,
    required DateTime baseDate,
  }) {
    final storedByCounter = data['tnbShiftCounters'] is Map
        ? Map<String, dynamic>.from(data['tnbShiftCounters'])
        : <String, dynamic>{};
    final storedSegmentsRaw = storedByCounter[label];
    if (storedSegmentsRaw is List && storedSegmentsRaw.isNotEmpty) {
      return storedSegmentsRaw
          .whereType<Map>()
          .map((raw) => Map<String, String>.from({
                'shiftKey': (raw['shiftKey'] ?? '').toString(),
                'shiftLabel': (raw['shiftLabel'] ?? '').toString(),
                'start': (raw['start'] ?? '').toString(),
                'end': (raw['end'] ?? '').toString(),
              }))
          .toList(growable: false);
    }

    final counter = _buildTnbCounterDisplayList(data).firstWhere(
      (entry) => entry['label'] == label,
      orElse: () => {'label': label, 'start': '', 'end': ''},
    );
    final parsedStart =
        double.tryParse((counter['start'] ?? '').replaceAll(',', '.').trim());
    if (parsedStart == null) {
      return _tnbShiftKeys.map((shiftKey) {
        final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
        return {
          'shiftKey': shiftKey,
          'shiftLabel': shift?.label ?? '-',
          'start': '',
          'end': '',
        };
      }).toList(growable: false);
    }

    final stops = (data['Arrets'] is List) ? List.from(data['Arrets']) : [];
    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));
    var running = parsedStart;
    return _tnbShiftKeys.map((shiftKey) {
      final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
      if (shift == null) {
        return {
          'shiftKey': shiftKey,
          'shiftLabel': '-',
          'start': '',
          'end': '',
        };
      }
      final downtime = _calculateTnbDowntimeMinutesInWindow(
        stops: stops,
        windowStart: shift.start,
        windowEnd: shift.end,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
      );
      final operatingHours = math.max(0, 480 - downtime) / 60.0;
      final next = running + operatingHours;
      final segment = {
        'shiftKey': shiftKey,
        'shiftLabel': shift.label,
        'start': _formatTnbCounterNumber(running),
        'end': _formatTnbCounterNumber(next),
      };
      running = next;
      return segment;
    }).toList(growable: false);
  }

  double _counterShiftHours(String startValue, String endValue) {
    final start = double.tryParse(startValue.replaceAll(',', '.').trim());
    final end = double.tryParse(endValue.replaceAll(',', '.').trim());
    if (start == null || end == null || end < start) return 0;
    return end - start;
  }

  Map<String, double> _tnbOperatingHoursByShiftKey({
    required Map<String, dynamic> data,
    required DateTime baseDate,
  }) {
    final stops = (data['Arrets'] is List) ? List.from(data['Arrets']) : [];
    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));
    final operatingByShift = <String, double>{};

    for (final key in _tnbShiftKeys) {
      final shift = _cycleShiftWindowByKey(baseDate, key);
      if (shift == null) {
        operatingByShift[key] = 0;
        continue;
      }
      final downtime = _calculateTnbDowntimeMinutesInWindow(
        stops: stops,
        windowStart: shift.start,
        windowEnd: shift.end,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
      );
      operatingByShift[key] = math.max(0, 480 - downtime) / 60.0;
    }

    return operatingByShift;
  }

  List<Map<String, String>> _normalizeTnbSegments({
    required List<Map<String, String>> segments,
    required Map<String, double> operatingByShift,
  }) {
    final normalized = segments
        .map((segment) => Map<String, String>.from(segment))
        .toList(growable: false);

    for (var i = 0; i < normalized.length; i++) {
      final current = normalized[i];
      if (i > 0) {
        final previousEnd = (normalized[i - 1]['end'] ?? '').trim();
        if (previousEnd.isNotEmpty) {
          current['start'] = previousEnd;
        }
      }

      final startText = (current['start'] ?? '').trim();
      final endText = (current['end'] ?? '').trim();
      if (startText.isEmpty) {
        current['end'] = '';
        continue;
      }

      final start = double.tryParse(startText.replaceAll(',', '.'));
      if (start == null) continue;

      final shiftKey = current['shiftKey'] ?? '';
      final maxHours = operatingByShift[shiftKey] ?? 0;
      final maxEnd = start + maxHours;
      var end = double.tryParse(endText.replaceAll(',', '.')) ?? start;
      if (end < start) {
        end = start;
      }
      if (end > maxEnd) {
        end = maxEnd;
      }
      current['start'] = _formatTnbCounterNumber(start);
      current['end'] = _formatTnbCounterNumber(end);
    }

    return normalized;
  }

  void _syncTnbControllerValues({
    required List<TextEditingController> startControllers,
    required List<TextEditingController> endControllers,
    required List<Map<String, String>> normalizedSegments,
  }) {
    for (var i = 0; i < normalizedSegments.length; i++) {
      final normalizedStart = (normalizedSegments[i]['start'] ?? '').trim();
      final normalizedEnd = (normalizedSegments[i]['end'] ?? '').trim();
      if (startControllers[i].text.trim() != normalizedStart) {
        startControllers[i].text = normalizedStart;
      }
      if (endControllers[i].text.trim() != normalizedEnd) {
        endControllers[i].text = normalizedEnd;
      }
    }
  }

  bool _validateTnbSegmentsMaxHours(
    List<Map<String, String>> segments, {
    required String label,
    required Map<String, double> operatingByShift,
    required ScaffoldMessengerState scaffoldMessenger,
  }) {
    const double roundingToleranceHours = 0.01;
    for (final segment in segments) {
      final startValue = (segment['start'] ?? '').trim();
      final endValue = (segment['end'] ?? '').trim();
      if (startValue.isEmpty || endValue.isEmpty) continue;

      final shiftHours = _counterShiftHours(startValue, endValue);
      final maxShiftHours = operatingByShift[segment['shiftKey'] ?? ''] ?? 8;
      if ((shiftHours - maxShiftHours) > roundingToleranceHours) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              'Le compteur "${segment['shiftLabel'] ?? '-'}" pour $label dépasse la marche autorisée (${_formatTnbCounterNumber(maxShiftHours)} h, arrêt déduit).',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _showTnbCounterValueDialog({
    required Report report,
    required Map<String, dynamic> data,
    required String label,
    required String initialValue,
    required bool isEditing,
    String? shiftKey,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
  }) async {
    final allSegments = _buildTnbCounterShiftSegments(
      data: data,
      label: label,
      baseDate: report.date,
    ).map((e) => Map<String, String>.from(e)).toList(growable: false);
    final segments = shiftKey == null
        ? allSegments
        : allSegments
            .where((segment) => segment['shiftKey'] == shiftKey)
            .toList(growable: false);
    if (segments.isEmpty) return;
    final startControllers = segments
        .map((segment) => TextEditingController(text: segment['start'] ?? ''))
        .toList(growable: false);
    final endControllers = segments
        .map((segment) => TextEditingController(text: segment['end'] ?? ''))
        .toList(growable: false);
    final operatingByShift = _tnbOperatingHoursByShiftKey(
      data: data,
      baseDate: report.date,
    );

    void propagateStartsFromEnds() {
      for (var i = 1; i < startControllers.length; i++) {
        final previousEnd = endControllers[i - 1].text.trim();
        if (previousEnd.isNotEmpty &&
            startControllers[i].text.trim() != previousEnd) {
          startControllers[i].text = previousEnd;
        }
      }
    }

    void normalizeAndSyncControllers() {
      final rawSegments = List.generate(segments.length, (index) {
        return {
          'shiftKey': segments[index]['shiftKey'] ?? '',
          'shiftLabel': segments[index]['shiftLabel'] ?? '',
          'start': startControllers[index].text.trim(),
          'end': endControllers[index].text.trim(),
        };
      });
      final normalized = _normalizeTnbSegments(
        segments: rawSegments,
        operatingByShift: operatingByShift,
      );
      _syncTnbControllerValues(
        startControllers: startControllers,
        endControllers: endControllers,
        normalizedSegments: normalized,
      );
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
                title: Text(isEditing ? 'Modifier $label' : 'Ajouter $label'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(segments.length, (index) {
                      final segment = segments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                segment['shiftLabel'] ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: startControllers[index],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Start',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) {
                                  setStateDialog(() {});
                                },
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: endControllers[index],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'End',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (_) {
                                  propagateStartsFromEnds();
                                  setStateDialog(() {});
                                },
                                onEditingComplete: () {
                                  normalizeAndSyncControllers();
                                  setStateDialog(() {});
                                },
                                onSubmitted: (_) {
                                  normalizeAndSyncControllers();
                                  setStateDialog(() {});
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Heures de marche: ${_formatTnbCounterNumber(_counterShiftHours(startControllers[index].text, endControllers[index].text))} h',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      var normalizedSegments = <Map<String, String>>[];
                      for (var i = 0; i < segments.length; i++) {
                        final startValue = startControllers[i].text.trim();
                        final endValue = endControllers[i].text.trim();
                        if (startValue.isNotEmpty &&
                            double.tryParse(startValue.replaceAll(',', '.')) ==
                                null) {
                          return;
                        }
                        if (endValue.isNotEmpty &&
                            double.tryParse(endValue.replaceAll(',', '.')) ==
                                null) {
                          return;
                        }
                        if (startValue.isNotEmpty &&
                            endValue.isNotEmpty &&
                            (double.tryParse(endValue.replaceAll(',', '.')) ??
                                    0) <
                                (double.tryParse(
                                        startValue.replaceAll(',', '.')) ??
                                    0)) {
                          return;
                        }
                        normalizedSegments.add({
                          'shiftKey': segments[i]['shiftKey'] ?? '',
                          'shiftLabel': segments[i]['shiftLabel'] ?? '',
                          'start': startValue,
                          'end': endValue,
                        });
                      }
                      normalizedSegments = _normalizeTnbSegments(
                        segments: normalizedSegments,
                        operatingByShift: operatingByShift,
                      );
                      final mergedSegments = allSegments
                          .map((e) => Map<String, String>.from(e))
                          .toList();
                      for (final edited in normalizedSegments) {
                        final editedIndex = mergedSegments.indexWhere(
                            (segment) =>
                                segment['shiftKey'] == edited['shiftKey']);
                        if (editedIndex != -1) {
                          mergedSegments[editedIndex] = edited;
                        }
                      }
                      final normalizedMergedSegments = _normalizeTnbSegments(
                        segments: mergedSegments,
                        operatingByShift: operatingByShift,
                      );
                      if (!_validateTnbSegmentsMaxHours(
                        normalizedMergedSegments,
                        label: label,
                        operatingByShift: operatingByShift,
                        scaffoldMessenger: scaffoldMessenger,
                      )) {
                        return;
                      }
                      final counters = _buildTnbCounterDisplayList(data)
                          .map((counter) => Map<String, String>.from(counter))
                          .toList(growable: false);
                      final index = counters
                          .indexWhere((counter) => counter['label'] == label);
                      if (index == -1) {
                        return;
                      }
                      counters[index]['start'] =
                          normalizedMergedSegments.first['start']?.trim() ?? '';
                      counters[index]['end'] =
                          normalizedMergedSegments.last['end']?.trim() ?? '';
                      final updatedReport =
                          _buildUpdatedActivityReportWithTnbCounters(
                        report: report,
                        data: data,
                        counters: counters,
                        shiftSegmentsByCounter: {
                          label: normalizedMergedSegments,
                        },
                      );
                      final refreshedData = updatedReport.additionalData ?? {};
                      data
                        ..clear()
                        ..addAll(refreshedData);
                      Navigator.pop(context);
                      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                      setDialogState(() {});
                    },
                    child: Text(isEditing
                        ? AppLocalizations.of(context)!.modifyLabel
                        : AppLocalizations.of(context)!.add),
                  ),
                ],
              )),
    );
  }

  Future<void> _showDeleteTnbCounterDialog({
    required Report report,
    required Map<String, dynamic> data,
    required String label,
    String? shiftKey,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteLabel(label)),
        content: Text(AppLocalizations.of(context)!.deleteCounterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final counters = _buildTnbCounterDisplayList(data)
                  .map((counter) => Map<String, String>.from(counter))
                  .toList(growable: false);
              final index =
                  counters.indexWhere((counter) => counter['label'] == label);
              if (index == -1) {
                Navigator.pop(context);
                return;
              }
              final segments = _buildTnbCounterShiftSegments(
                data: data,
                label: label,
                baseDate: report.date,
              ).map((e) => Map<String, String>.from(e)).toList();
              if (shiftKey == null) {
                counters[index]['start'] = '';
                counters[index]['end'] = '';
              } else {
                final segmentIndex = segments
                    .indexWhere((segment) => segment['shiftKey'] == shiftKey);
                if (segmentIndex != -1) {
                  segments[segmentIndex]['start'] = '';
                  segments[segmentIndex]['end'] = '';
                }
                for (var i = 1; i < segments.length; i++) {
                  final previousEnd = (segments[i - 1]['end'] ?? '').trim();
                  if (previousEnd.isNotEmpty) {
                    segments[i]['start'] = previousEnd;
                  }
                }
                counters[index]['start'] =
                    segments.first['start']?.trim() ?? '';
                counters[index]['end'] = segments.last['end']?.trim() ?? '';
              }
              final updatedReport = _buildUpdatedActivityReportWithTnbCounters(
                report: report,
                data: data,
                counters: counters,
                shiftSegmentsByCounter:
                    shiftKey == null ? const {} : {label: segments},
              );
              final refreshedData = updatedReport.additionalData ?? {};
              data
                ..clear()
                ..addAll(refreshedData);
              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  Report _buildUpdatedActivityReportWithTnbCounters({
    required Report report,
    required Map<String, dynamic> data,
    required List<Map<String, String>> counters,
    Map<String, List<Map<String, String>>> shiftSegmentsByCounter = const {},
  }) {
    final updatedData = Map<String, dynamic>.from(data);
    final filledCounters = counters
        .where((counter) => (counter['start'] ?? '').trim().isNotEmpty)
        .toList(growable: false);

    updatedData['vibrator Counters'] = filledCounters
        .where((counter) => counter['label'] == 'Vibreur')
        .map((counter) => {
              'id': 'tnb-vibreur',
              'poste': counter['label'],
              'start': counter['start'],
              'end': counter['end'],
            })
        .toList(growable: false);

    updatedData['liaison Counters'] = filledCounters
        .where((counter) => counter['label'] != 'Vibreur')
        .map((counter) => {
              'id': 'tnb-${counter['label']}',
              'poste': counter['label'],
              'start': counter['start'],
              'end': counter['end'],
            })
        .toList(growable: false);

    final shiftCountersRaw = updatedData['tnbShiftCounters'] is Map
        ? Map<String, dynamic>.from(updatedData['tnbShiftCounters'])
        : <String, dynamic>{};
    for (final entry in shiftSegmentsByCounter.entries) {
      shiftCountersRaw[entry.key] = entry.value
          .map((segment) => {
                'shiftKey': segment['shiftKey'],
                'shiftLabel': segment['shiftLabel'],
                'start': segment['start'],
                'end': segment['end'],
                'workingHours': _counterShiftHours(
                    segment['start'] ?? '', segment['end'] ?? ''),
              })
          .toList(growable: false);
    }
    for (final counter in counters) {
      final label = (counter['label'] ?? '').trim();
      if (label.isEmpty) continue;
      final hasStart = (counter['start'] ?? '').trim().isNotEmpty;
      if (!hasStart) {
        shiftCountersRaw.remove(label);
      }
    }
    updatedData['tnbShiftCounters'] = shiftCountersRaw;

    final recalculatedData = _recalculateActivityTotals(
      updatedData,
      reportDate: report.date,
    );
    recalculatedData['T Nr.C'] = filledCounters.length;

    return Report(
      id: report.id,
      description: report.description,
      type: report.type,
      group: report.group,
      date: report.date,
      additionalData: recalculatedData,
    );
  }

  String _calculateTnbQuantity(String gatTrips, String terexTrips) {
    final gat = int.tryParse(gatTrips) ?? 0;
    final terex = int.tryParse(terexTrips) ?? 0;
    return ((gat * 78) + (terex * 58)).toString();
  }

  String _getComputedStockQuantity(Map<String, dynamic> stock) {
    return _calculateTnbQuantity(
      (stock['gatTrips'] ?? '').toString(),
      (stock['terexTrips'] ?? '').toString(),
    );
  }

  int _getTnbQuantityTotal(List<Map<String, dynamic>> stockEntries) {
    return stockEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + (int.tryParse(_getComputedStockQuantity(entry)) ?? 0),
    );
  }

  double _getCounterShiftHoursByLabel({
    required Map<String, dynamic> data,
    required DateTime baseDate,
    required String shiftKey,
    required String counterLabel,
  }) {
    final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
    if (shift == null) return 0;

    final segments = _buildTnbCounterShiftSegments(
      data: data,
      label: counterLabel,
      baseDate: baseDate,
    );
    final segment = segments.firstWhere(
      (s) =>
          (s['shiftKey'] ?? '').toString() == shiftKey ||
          (s['shiftLabel'] ?? '').toString() == shift.label,
      orElse: () => const {'start': '', 'end': ''},
    );

    final start = (segment['start'] ?? '').trim();
    final end = (segment['end'] ?? '').trim();
    if (start.isEmpty || end.isEmpty) return 0;

    return _counterShiftHours(start, end);
  }

  double _getCounterDailyOperatingHoursByLabel({
    required Map<String, dynamic> data,
    required DateTime baseDate,
    required String counterLabel,
  }) {
    return _tnbShiftKeys.fold<double>(
      0,
      (sum, key) =>
          sum +
          _getCounterShiftHoursByLabel(
            data: data,
            baseDate: baseDate,
            shiftKey: key,
            counterLabel: counterLabel,
          ),
    );
  }

  String _formatTnbRendement(int quantity, double workingHours) {
    if (workingHours <= 0) return '-';
    return '${(quantity / workingHours).toStringAsFixed(2)} t/h';
  }

  Set<int> _usedStockPostesFromData(
    Map<String, dynamic> data, {
    int? excludingIndex,
  }) {
    final stockEntries = (data['stock'] as List?) ?? const [];
    final usedPostes = <int>{};
    for (var i = 0; i < stockEntries.length; i++) {
      if (excludingIndex != null && i == excludingIndex) continue;
      final entry = stockEntries[i];
      if (entry is! Map) continue;
      final poste = _normalizePosteIndex(entry['poste']);
      if (poste != null) {
        usedPostes.add(poste);
      }
    }
    return usedPostes;
  }

  List<int> _availableStockPostesFromData(
    Map<String, dynamic> data, {
    int? excludingIndex,
  }) {
    final usedPostes =
        _usedStockPostesFromData(data, excludingIndex: excludingIndex);
    return [0, 1, 2].where((poste) => !usedPostes.contains(poste)).toList();
  }

  // Add Stock Entry Dialog for Activity Report
  Future<void> _showAddStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final availablePostes = _availableStockPostesFromData(data);
    if (availablePostes.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text(
              "Vous ne pouvez ajouter que 3 stocks (un seul par poste).")));
      return;
    }

    int? selectedPoste;
    String gatTrips = '';
    String terexTrips = '';
    int? selectedPark;
    int? selectedType;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.addStockEntryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.poste,
                  border: const OutlineInputBorder(),
                ),
                items: availablePostes
                    .map((poste) => DropdownMenuItem(
                        value: poste,
                        child: Text(_getPosteString(poste, l10n))))
                    .toList(),
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de voyages GAT',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => gatTrips = value.trim()),
              ),
              const SizedBox(height: 16),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de voyages TEREX',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => terexTrips = value.trim()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedPark,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.parkLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 0,
                      child: Text(AppLocalizations.of(context)!.park1)),
                  DropdownMenuItem(
                      value: 1,
                      child: Text(AppLocalizations.of(context)!.park2)),
                  DropdownMenuItem(
                      value: 2,
                      child: Text(AppLocalizations.of(context)!.park3)),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.type,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 0,
                      child:
                          Text(AppLocalizations.of(context)!.stockTypeNormal)),
                  DropdownMenuItem(
                      value: 1,
                      child:
                          Text(AppLocalizations.of(context)!.stockTypeOceane)),
                  DropdownMenuItem(
                      value: 2,
                      child: Text(AppLocalizations.of(context)!.stockTypePb30)),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.quantityLabel,
                  border: const OutlineInputBorder(),
                ),
                child: Text(_calculateTnbQuantity(gatTrips, terexTrips)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  if (_usedStockPostesFromData(data).contains(selectedPoste)) {
                    scaffoldMessenger.showSnackBar(SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .shiftHasStockAlready)));
                    return;
                  }
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['stock'] == null) {
                    updatedData['stock'] = [];
                  }
                  (updatedData['stock'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'gatTrips': gatTrips,
                    'terexTrips': terexTrips,
                    'quantity': _calculateTnbQuantity(gatTrips, terexTrips),
                    'park': selectedPark,
                    'type': selectedType,
                  });

                  final syncedData =
                      _syncTruckTripsFromStockEntries(updatedData);
                  final recalculatedData = _recalculateActivityTotals(
                    syncedData,
                    reportDate: report.date,
                  );

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _applyUpdatedReportDataToDialog(data, updatedReport);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(AppLocalizations.of(context)!.add),
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
    int? selectedPoste = _normalizePosteIndex(stock['poste']);
    final availablePostes =
        _availableStockPostesFromData(data, excludingIndex: index);
    if (selectedPoste != null && !availablePostes.contains(selectedPoste)) {
      availablePostes.add(selectedPoste);
      availablePostes.sort();
    }
    String gatTrips = (stock['gatTrips'] ?? '').toString();
    String terexTrips = (stock['terexTrips'] ?? '').toString();
    final gatTripsController = TextEditingController(text: gatTrips);
    final terexTripsController = TextEditingController(text: terexTrips);
    int? selectedPark = _normalizeParkIndex(stock['park']);
    int? selectedType = _normalizeStockTypeIndex(stock['type']);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.editStockEntryTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedPoste,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.poste,
                  border: const OutlineInputBorder(),
                ),
                items: availablePostes
                    .map((poste) => DropdownMenuItem(
                        value: poste,
                        child: Text(_getPosteString(poste, l10n))))
                    .toList(),
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gatTripsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de voyages GAT',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => gatTrips = value.trim()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: terexTripsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de voyages TEREX',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => terexTrips = value.trim()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedPark,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.parkLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 0,
                      child: Text(AppLocalizations.of(context)!.park1)),
                  DropdownMenuItem(
                      value: 1,
                      child: Text(AppLocalizations.of(context)!.park2)),
                  DropdownMenuItem(
                      value: 2,
                      child: Text(AppLocalizations.of(context)!.park3)),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: selectedType,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.type,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                      value: 0,
                      child:
                          Text(AppLocalizations.of(context)!.stockTypeNormal)),
                  DropdownMenuItem(
                      value: 1,
                      child:
                          Text(AppLocalizations.of(context)!.stockTypeOceane)),
                  DropdownMenuItem(
                      value: 2,
                      child: Text(AppLocalizations.of(context)!.stockTypePb30)),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.quantityLabel,
                  border: const OutlineInputBorder(),
                ),
                child: Text(_calculateTnbQuantity(gatTrips, terexTrips)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  if (_usedStockPostesFromData(data, excludingIndex: index)
                      .contains(selectedPoste)) {
                    scaffoldMessenger.showSnackBar(SnackBar(
                        content: Text(AppLocalizations.of(context)!
                            .shiftHasStockAlready)));
                    return;
                  }
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['stock'] as List)[index] = {
                    'id': stock['id'],
                    'poste': selectedPoste,
                    'gatTrips': gatTrips,
                    'terexTrips': terexTrips,
                    'quantity': _calculateTnbQuantity(gatTrips, terexTrips),
                    'park': selectedPark,
                    'type': selectedType,
                  };

                  final syncedData =
                      _syncTruckTripsFromStockEntries(updatedData);
                  final recalculatedData = _recalculateActivityTotals(
                    syncedData,
                    reportDate: report.date,
                  );

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _applyUpdatedReportDataToDialog(data, updatedReport);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  setDialogState(() {});
                }
              },
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
        title: Text(AppLocalizations.of(context)!.deleteStockEntryTitle),
        content: Text(AppLocalizations.of(context)!.deleteStockConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['stock'] as List).removeAt(index);

              final syncedData = _syncTruckTripsFromStockEntries(updatedData);
              final recalculatedData = _recalculateActivityTotals(
                syncedData,
                reportDate: report.date,
              );

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _applyUpdatedReportDataToDialog(data, updatedReport);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              setDialogState(() {});
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.delete),
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
                        title: Text(
                            AppLocalizations.of(context)!.editLabel(label)),
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
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(editContext);
                              await onSave(controller.text);
                            },
                            child: Text(AppLocalizations.of(context)!.save),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: AppLocalizations.of(context)!.editLabel(label),
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
                  tooltip: AppLocalizations.of(context)!.editLabel(label),
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
    DateTime selectedDate = initialDate;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.date),
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
                      final TimeOfDay? time = await showSpinnerTimePickerDialog(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                        title: AppLocalizations.of(context)!.timeLabel,
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
              child: Text(AppLocalizations.of(context)!.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await onSave(selectedDate);
              },
              child: Text(AppLocalizations.of(context)!.save),
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
    Report editableReport = report;
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
                  child: DefaultTabController(
                    initialIndex: _currentShiftTabIndex(),
                    length: 4,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.thirdPoste),
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.firstPoste),
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .secondPoste),
                              Tab(text: AppLocalizations.of(context)!.global),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildTsudReportDetailsPage(
                                data: data,
                                reportDate: report.date,
                                l10n: l10n,
                                shiftKey: '3',
                              ),
                              _buildTsudReportDetailsPage(
                                data: data,
                                reportDate: report.date,
                                l10n: l10n,
                                shiftKey: '1',
                              ),
                              _buildTsudReportDetailsPage(
                                data: data,
                                reportDate: report.date,
                                l10n: l10n,
                                shiftKey: '2',
                              ),
                              SingleChildScrollView(
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(context)!
                                                  .reportDateLabel,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
                                            const Divider(height: 16),
                                            ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                '${editableReport.date.day.toString().padLeft(2, '0')}/${editableReport.date.month.toString().padLeft(2, '0')}/${editableReport.date.year}',
                                                style: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                              trailing: IconButton(
                                                icon: const Icon(
                                                    Icons.calendar_today),
                                                onPressed: () async {
                                                  final pickedDate =
                                                      await showDatePicker(
                                                    context: dialogContext,
                                                    initialDate:
                                                        editableReport.date,
                                                    firstDate: DateTime(2000),
                                                    lastDate: DateTime.now(),
                                                  );

                                                  if (pickedDate == null) {
                                                    return;
                                                  }

                                                  final updatedDate = DateTime(
                                                    pickedDate.year,
                                                    pickedDate.month,
                                                    pickedDate.day,
                                                    editableReport.date.hour,
                                                    editableReport.date.minute,
                                                    editableReport.date.second,
                                                    editableReport
                                                        .date.millisecond,
                                                    editableReport
                                                        .date.microsecond,
                                                  );

                                                  final updatedReport =
                                                      editableReport.copyWith(
                                                    date: updatedDate,
                                                    additionalData: data,
                                                  );

                                                  await _saveReportUpdate(
                                                      updatedReport,
                                                      scaffoldMessenger,
                                                      l10n);

                                                  if (!mounted) return;
                                                  setDialogState(() {
                                                    editableReport =
                                                        updatedReport;
                                                  });
                                                },
                                                tooltip: AppLocalizations.of(
                                                        context)!
                                                    .dateLabel,
                                              ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .machinesStoppedLabel,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add),
                                                  onPressed: () =>
                                                      _showAddMachineEquipmentDialog(
                                                          editableReport,
                                                          data,
                                                          equipmentData,
                                                          setDialogState,
                                                          scaffoldMessenger,
                                                          l10n),
                                                  tooltip: AppLocalizations.of(
                                                          context)!
                                                      .addEquipment,
                                                ),
                                              ],
                                            ),
                                            const Divider(height: 16),
                                            if (data['equipmentList'] is List &&
                                                (data['equipmentList'] as List)
                                                    .isNotEmpty)
                                              ...List.from(
                                                      data['equipmentList'])
                                                  .asMap()
                                                  .entries
                                                  .map((entry) {
                                                final index = entry.key;
                                                final equipment = entry.value;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8.0),
                                                  child: Card(
                                                    elevation: 1,
                                                    child: ListTile(
                                                      title: Text(
                                                          '${AppLocalizations.of(context)!.equipmentLabelWithIndex(index + 1)} ${equipment['equipmentType'] ?? '-'}'),
                                                      subtitle: Text(
                                                          '${AppLocalizations.of(context)!.reason}: ${equipment['Reason'] ?? '-'}'),
                                                      trailing: PopupMenuButton<
                                                          String>(
                                                        icon: const Icon(
                                                            Icons.more_horiz,
                                                            size: 20),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        position:
                                                            PopupMenuPosition
                                                                .under,
                                                        itemBuilder:
                                                            (BuildContext
                                                                    context) =>
                                                                [
                                                          PopupMenuItem<String>(
                                                            value: 'edit',
                                                            height: 36,
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(Icons.edit,
                                                                    size: 18,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                  AppLocalizations.of(
                                                                          context)!
                                                                      .modifyLabel,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary,
                                                                    fontSize:
                                                                        14,
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
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .delete_outline,
                                                                    size: 18,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                  AppLocalizations.of(
                                                                          context)!
                                                                      .delete,
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                        onSelected: (value) {
                                                          if (value == 'edit') {
                                                            _showEditMachineEquipmentDialog(
                                                                editableReport,
                                                                data,
                                                                index,
                                                                equipmentData,
                                                                setDialogState,
                                                                scaffoldMessenger,
                                                                l10n);
                                                          } else if (value ==
                                                              'delete') {
                                                            _showDeleteMachineEquipmentDialog(
                                                                editableReport,
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
                                                AppLocalizations.of(context)!
                                                    .noMachinesStopped,
                                                style: const TextStyle(
                                                    color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                      Text(AppLocalizations.of(context)!.addEquipment,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMainCategory.isEmpty
                            ? null
                            : selectedMainCategory,
                        decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.mainCategoryLabel,
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
                            labelText:
                                AppLocalizations.of(context)!.subCategoryLabel,
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
                            labelText:
                                AppLocalizations.of(context)!.equipmentLabel,
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
                          labelText:
                              AppLocalizations.of(context)!.stopReasonLabel,
                          border: const OutlineInputBorder(),
                          hintText:
                              AppLocalizations.of(context)!.enterStopReasonHint,
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
                            child: Text(AppLocalizations.of(context)!.cancel),
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
                            child: Text(
                                AppLocalizations.of(context)!.finishButton),
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
                      Text(AppLocalizations.of(context)!.editEquipment,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedMainCategory.isEmpty
                            ? null
                            : selectedMainCategory,
                        decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.mainCategoryLabel,
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
                            labelText:
                                AppLocalizations.of(context)!.subCategoryLabel,
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
                            labelText:
                                AppLocalizations.of(context)!.equipmentLabel,
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
                        initialValue: stopReason,
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)!.stopReasonLabel,
                          border: const OutlineInputBorder(),
                          hintText:
                              AppLocalizations.of(context)!.enterStopReasonHint,
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
                            child: Text(AppLocalizations.of(context)!.cancel),
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
                            child: Text(
                                AppLocalizations.of(context)!.finishButton),
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
        title: Text(AppLocalizations.of(context)!.deleteEquipment),
        content: Text(AppLocalizations.of(context)!.deleteEquipmentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.delete),
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
                              AppLocalizations.of(context)!.dataVerification,
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
                                tooltip:
                                    AppLocalizations.of(context)!.editReport,
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
                    Expanded(
                      child: DefaultTabController(
                        initialIndex: _currentShiftTabIndex(),
                        length: 4,
                        child: Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: TabBar(
                                isScrollable: true,
                                tabs: [
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .thirdPoste),
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .firstPoste),
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .secondPoste),
                                  Tab(
                                      text:
                                          AppLocalizations.of(context)!.global),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildTnbReportDetailsPage(
                                    data: data,
                                    reportDate: report.date,
                                    l10n: l10n,
                                    shiftKey: '3',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTnbReportDetailsPage(
                                    data: data,
                                    reportDate: report.date,
                                    l10n: l10n,
                                    shiftKey: '1',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTnbReportDetailsPage(
                                    data: data,
                                    reportDate: report.date,
                                    l10n: l10n,
                                    shiftKey: '2',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTnbReportDetailsPage(
                                    data: data,
                                    reportDate: report.date,
                                    l10n: l10n,
                                    report: currentReport,
                                  ),
                                ],
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
                              AppLocalizations.of(context)!.dataVerification,
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
                    Expanded(
                      child: DefaultTabController(
                        initialIndex: _currentShiftTabIndex(),
                        length: 4,
                        child: Column(
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: TabBar(
                                isScrollable: true,
                                tabs: [
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .thirdPoste),
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .firstPoste),
                                  Tab(
                                      text: AppLocalizations.of(context)!
                                          .secondPoste),
                                  Tab(
                                      text:
                                          AppLocalizations.of(context)!.global),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _buildTsudReportDetailsPage(
                                    data: data,
                                    reportDate: currentReport.date,
                                    l10n: l10n,
                                    shiftKey: '3',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTsudReportDetailsPage(
                                    data: data,
                                    reportDate: currentReport.date,
                                    l10n: l10n,
                                    shiftKey: '1',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTsudReportDetailsPage(
                                    data: data,
                                    reportDate: currentReport.date,
                                    l10n: l10n,
                                    shiftKey: '2',
                                    report: currentReport,
                                    setDialogState: setState,
                                  ),
                                  _buildTsudReportDetailsPage(
                                    data: data,
                                    reportDate: currentReport.date,
                                    l10n: l10n,
                                    report: currentReport,
                                  ),
                                ],
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

    // Special handling for Machine/Engin Arrêtés report (case-insensitive)
    if (typeLower == 'machine/engin arrêtés') {
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
                          AppLocalizations.of(context)!.dataVerification,
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
                                Text(AppLocalizations.of(context)!.dateLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 4),
                                Text(DateFormat('yyyy-MM-dd')
                                    .format(report.date)),
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
                                Text(
                                    AppLocalizations.of(context)!
                                        .machinesStoppedLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 4),
                                if (data['equipmentList'] is List &&
                                    (data['equipmentList'] as List)
                                        .isNotEmpty) ...[
                                  ...List.from(data['equipmentList'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final equipment = entry.value;
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${AppLocalizations.of(context)!.equipmentIndex(index + 1)}:',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text(
                                              '${AppLocalizations.of(context)!.type}: ${equipment['equipmentType'] ?? '-'}'),
                                          Text(
                                              '${AppLocalizations.of(context)!.reasonLabel}: ${equipment['Reason'] ?? '-'}'),
                                          if (index <
                                              (data['equipmentList'] as List)
                                                      .length -
                                                  1)
                                            const Divider(),
                                        ],
                                      ),
                                    );
                                  }),
                                ] else ...[
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noEquipmentStopped,
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                ],
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
                          AppLocalizations.of(context)!.dataVerification,
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
                                  AppLocalizations.of(context)!.dateLabel,
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
                                  AppLocalizations.of(context)!.infoOibEeLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.mine,
                                    data['mine'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.zone,
                                    data['zone'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.exit,
                                    data['sortie'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.categoryLabel,
                                    data['Category'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.type,
                                    data['Type'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.modelLabel,
                                    data['Model'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.poste,
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
                                    AppLocalizations.of(context)!.counter,
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
                                          _buildInfoRow(
                                              AppLocalizations.of(context)!
                                                  .start,
                                              compteur['duree'] ?? '-'),
                                          _buildInfoRow(
                                              AppLocalizations.of(context)!.end,
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
                                        _buildInfoRow(
                                            AppLocalizations.of(context)!.start,
                                            data['Compteurs']['duree'] ?? '-'),
                                        _buildInfoRow(
                                            AppLocalizations.of(context)!.end,
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
                                    AppLocalizations.of(context)!.stopsLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  ...List.from(data['Arrets']).map((arret) =>
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 2),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_formatDailyStopLine(arret)),
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
                                    AppLocalizations.of(context)!.stepExploit,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .heuresMarche,
                                      data['exploitation']['H.M'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.heuresArret,
                                      data['exploitation']['H.A'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.metrageFore,
                                      data['exploitation']['metrage fore'] ??
                                          '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .nrTrousFores,
                                      data['exploitation']
                                              ['Nr de Trous Fores'] ??
                                          '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.nrVoyages,
                                      data['exploitation']['Nr de Voyages'] ??
                                          '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.m3Decapage,
                                      data['exploitation']['M³ Decapages'] ??
                                          '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .tonnageLabel,
                                      data['exploitation']['Tonnage'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.nombreTKU,
                                      data['exploitation']['Nombre T.K.U'] ??
                                          '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .rendementLabel,
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
                                    AppLocalizations.of(context)!
                                        .repartitionLabel,
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
                                                      AppLocalizations.of(
                                                              context)!
                                                          .chantierLabel,
                                                      repartition['Chantier'] ??
                                                          repartition[
                                                              'chantier'] ??
                                                          '-'),
                                                  _buildInfoRow(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .timeLabel,
                                                      repartition['Temps'] ??
                                                          repartition[
                                                              'temps'] ??
                                                          '-'),
                                                  _buildInfoRow(
                                                      AppLocalizations.of(
                                                              context)!
                                                          .imputationLabel,
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
                                              'Imputation',
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
                                    AppLocalizations.of(context)!
                                        .personnelLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .conductorLabel,
                                      data['personnel']['conductr'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .graisseurLabel,
                                      data['personnel']['graisseur'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .matriculeLabel,
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
                                    AppLocalizations.of(context)!
                                        .consommationLabel,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .triconeLabel,
                                      data['consommation']['tricone'] ?? '-'),
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!.gasoilLabel,
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
      final Map<String, Map<String, int>> equipmentQualityTrips = {};
      final Map<String, int> qualityTrips = {};

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
      for (var trip in allTrips) {
        final eq =
            trip['equipment'] ?? AppLocalizations.of(context)!.unknownLabel;
        final qualityLabel =
            _resolveQualityLabel(trip['productQualityType'], l10n);
        equipmentQualityTrips.putIfAbsent(eq, () => {});
        equipmentQualityTrips[eq]![qualityLabel] =
            (equipmentQualityTrips[eq]![qualityLabel] ?? 0) + 1;
        qualityTrips[qualityLabel] = (qualityTrips[qualityLabel] ?? 0) + 1;
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
                          AppLocalizations.of(context)!.dataVerification,
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
                                  AppLocalizations.of(context)!.date,
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
                                  AppLocalizations.of(context)!.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.mine,
                                    data['mine'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.zone,
                                    data['zone'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.exit,
                                    data['sortie'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.distance,
                                    data['distance'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!.poste,
                                    data['poste'] ??
                                        data['selectedPoste'] ??
                                        '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!
                                        .operationLabel,
                                    data['operationType'] ?? '-'),
                                _buildInfoRow(
                                    AppLocalizations.of(context)!
                                        .equipmentLabel,
                                    data['equipment'] ??
                                        data['selectedEquipment'] ??
                                        '-'),
                                if (data['selectedQualiteType'] != null)
                                  _buildInfoRow(
                                      AppLocalizations.of(context)!
                                          .qualityLabel,
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
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noTrucksAdded,
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
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
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
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            count['equipment'] ??
                                                                '-',
                                                            style: Theme.of(
                                                                    context)
                                                                .textTheme
                                                                .bodyMedium,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          if (count[
                                                                  'productQualityType'] !=
                                                              null)
                                                            Text(
                                                              _resolveQualityLabel(
                                                                  count[
                                                                      'productQualityType'],
                                                                  l10n),
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .bodyMedium
                                                                  ?.copyWith(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurfaceVariant,
                                                                  ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                        ],
                                                      ),
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
                                color: Theme.of(context).colorScheme.surface,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          AppLocalizations.of(context)!
                                              .summaryLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Total de voyages: ${data['totalTrips'] ?? allTrips.length}'),
                                      const SizedBox(height: 8),
                                      Text(
                                          AppLocalizations.of(context)!
                                              .tripsByEquipment,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      ..._buildTripsPerEquipmentSummary(
                                          equipmentCounts,
                                          equipmentQualityTrips),
                                      const SizedBox(height: 12),
                                      Text(
                                          '${AppLocalizations.of(context)!.total} ${AppLocalizations.of(context)!.qualityLabel}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      ...qualityTrips.entries.map(
                                          (e) => Text('${e.key} - ${e.value}')),
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
                AppLocalizations.of(context)!.dataVerification,
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
                      Text(AppLocalizations.of(context)!.description,
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
              Text(AppLocalizations.of(context)!.additionalData,
                  style: Theme.of(context).textTheme.titleLarge),
              _buildAdditionalDataView(report),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.close),
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
        if (data.isEmpty) {
          return Text(AppLocalizations.of(context)!.noAdditionalData);
        }
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

  List<Map<String, String>> _buildTnbCounterDisplayList(
    Map<String, dynamic> data,
  ) {
    const labels = ['Vibreur', 'LN', 'L', 'G3', 'G6'];
    final counterMap = {
      for (final label in labels)
        label: <String, String>{'label': label, 'start': '', 'end': ''},
    };

    final vibratorCounters = data['vibrator Counters'] is List
        ? List.from(data['vibrator Counters'])
        : [];
    if (vibratorCounters.isNotEmpty) {
      final firstCounter = Map<String, dynamic>.from(vibratorCounters.first);
      counterMap['Vibreur'] = {
        'label': 'Vibreur',
        'start': firstCounter['start']?.toString() ?? '',
        'end': firstCounter['end']?.toString() ?? '',
      };
    }

    final liaisonCounters = data['liaison Counters'] is List
        ? List.from(data['liaison Counters'])
        : [];
    for (var i = 0; i < liaisonCounters.length && i < labels.length - 1; i++) {
      final counter = Map<String, dynamic>.from(liaisonCounters[i]);
      final rawLabel = counter['poste']?.toString().trim();
      final fallbackLabel = labels[i + 1];
      final label = rawLabel != null && labels.contains(rawLabel)
          ? rawLabel
          : fallbackLabel;
      counterMap[label] = {
        'label': label,
        'start': counter['start']?.toString() ?? '',
        'end': counter['end']?.toString() ?? '',
      };
    }

    return labels.map((label) => counterMap[label]!).toList(growable: false);
  }

  DateTime? _parseTnbStopDateTimeForCycle(
    String raw,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final sameDay = DateTime(
      cycleStart.year,
      cycleStart.month,
      cycleStart.day,
      hour,
      minute,
    );
    final nextDay = sameDay.add(const Duration(days: 1));

    if (!sameDay.isBefore(cycleStart) && !sameDay.isAfter(cycleEnd)) {
      return sameDay;
    }
    if (!nextDay.isBefore(cycleStart) && !nextDay.isAfter(cycleEnd)) {
      return nextDay;
    }
    return sameDay.isBefore(cycleStart) ? nextDay : sameDay;
  }

  int _calculateTnbDowntimeMinutesInWindow({
    required List stops,
    required DateTime windowStart,
    required DateTime windowEnd,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    final now = DateTime.now();
    final ranges = <TimeRange>[];

    for (final rawStop in stops) {
      if (rawStop is! Map) continue;
      final stop = Map<String, dynamic>.from(rawStop);
      final rawStart = (stop['startTime'] ?? stop['Début'] ?? '').toString();
      final rawEnd = (stop['endTime'] ?? stop['Fin'] ?? '').toString();

      final start =
          _parseTnbStopDateTimeForCycle(rawStart, cycleStart, cycleEnd);
      if (start == null) continue;

      DateTime? end =
          _parseTnbStopDateTimeForCycle(rawEnd, cycleStart, cycleEnd);
      end ??= now;
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      final effectiveStart = start.isBefore(windowStart) ? windowStart : start;
      final effectiveEnd = end.isAfter(windowEnd) ? windowEnd : end;
      if (effectiveEnd.isAfter(effectiveStart)) {
        ranges.add(TimeRange(
          effectiveStart.difference(windowStart).inMinutes,
          effectiveEnd.difference(windowStart).inMinutes,
        ));
      }
    }

    return TimeCalculationService.calculateTotalDowntimeMinutes(
      ranges,
      maxMinutes: windowEnd.difference(windowStart).inMinutes,
    );
  }

  String _formatTnbCounterNumber(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  List<({String label, DateTime start, DateTime end})> _cycleShiftWindows(
      DateTime baseDate) {
    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    return [
      (
        label: '3ème poste (22:30 - 06:30)',
        start: cycleStart,
        end: cycleStart.add(const Duration(hours: 8)),
      ),
      (
        label: '1er poste (06:30 - 14:30)',
        start: cycleStart.add(const Duration(hours: 8)),
        end: cycleStart.add(const Duration(hours: 16)),
      ),
      (
        label: '2ème poste (14:30 - 22:30)',
        start: cycleStart.add(const Duration(hours: 16)),
        end: cycleStart.add(const Duration(hours: 24)),
      ),
    ];
  }

  ({String key, String label, DateTime start, DateTime end})?
      _cycleShiftWindowByKey(
    DateTime baseDate,
    String shiftKey,
  ) {
    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    switch (shiftKey) {
      case '3':
        return (
          key: '3',
          label: '3ème poste (22:30 - 06:30)',
          start: cycleStart,
          end: cycleStart.add(const Duration(hours: 8)),
        );
      case '1':
        return (
          key: '1',
          label: '1er poste (06:30 - 14:30)',
          start: cycleStart.add(const Duration(hours: 8)),
          end: cycleStart.add(const Duration(hours: 16)),
        );
      case '2':
        return (
          key: '2',
          label: '2ème poste (14:30 - 22:30)',
          start: cycleStart.add(const Duration(hours: 16)),
          end: cycleStart.add(const Duration(hours: 24)),
        );
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> _filterTnbStopsForShift(
    List<dynamic> stops,
    DateTime baseDate,
    String shiftKey,
  ) {
    final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
    if (shift == null) return [];

    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));

    return stops
        .asMap()
        .entries
        .where((entry) => entry.value is Map)
        .map((entry) {
          final sourceIndex = entry.key;
          final stop = Map<String, dynamic>.from(entry.value as Map);
          final rawStart =
              (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '')
                  .toString();
          if (rawStart.isEmpty) return null;
          final start =
              _parseTnbStopDateTimeForCycle(rawStart, cycleStart, cycleEnd);
          if (start == null) return null;

          final rawEnd =
              (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
          final isPending =
              rawEnd.trim().isEmpty || rawEnd.toLowerCase() == 'pending';
          DateTime? end =
              _parseTnbStopDateTimeForCycle(rawEnd, cycleStart, cycleEnd);
          end ??= isPending ? cycleEnd : DateTime.now();
          if (end.isBefore(start)) {
            end = end.add(const Duration(days: 1));
          }

          if (!end.isAfter(shift.start) || !start.isBefore(shift.end)) {
            return null;
          }

          final clippedStart =
              start.isBefore(shift.start) ? shift.start : start;
          final clippedEnd = end.isAfter(shift.end) ? shift.end : end;
          if (!clippedEnd.isAfter(clippedStart)) {
            return null;
          }

          final clippedDurationMinutes =
              clippedEnd.difference(clippedStart).inMinutes;
          final clippedDurationText =
              '${clippedDurationMinutes ~/ 60}h ${(clippedDurationMinutes % 60).toString().padLeft(2, '0')}';
          final clippedStartText = _formatDateTimeToTimeString(clippedStart);
          final clippedEndText = _formatDateTimeToTimeString(clippedEnd);
          final scopedStop = Map<String, dynamic>.from(stop);
          scopedStop['startTime'] = clippedStartText;
          scopedStop['start'] = clippedStartText;
          scopedStop['Début'] = clippedStartText;
          if (isPending) {
            scopedStop['endTime'] = 'Pending';
            scopedStop['end'] = 'Pending';
            scopedStop['Fin'] = 'Pending';
          } else {
            scopedStop['endTime'] = clippedEndText;
            scopedStop['end'] = clippedEndText;
            scopedStop['Fin'] = clippedEndText;
          }
          scopedStop['duration'] = clippedDurationText;
          scopedStop['_sourceIndex'] = sourceIndex;
          return scopedStop;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  bool _stopMatchesShift({
    required Map<String, dynamic> stop,
    required DateTime baseDate,
    required String shiftKey,
  }) {
    final explicitShift = _normalizePosteKey(stop['shiftKey']?.toString());
    if (explicitShift != null) {
      return explicitShift == shiftKey;
    }

    final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
    if (shift == null) return false;
    final cycleStart =
        DateTime(baseDate.year, baseDate.month, baseDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));
    final rawStart =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    if (rawStart.isEmpty) return false;
    final start = _parseTnbStopDateTimeForCycle(rawStart, cycleStart, cycleEnd);
    if (start == null) return false;

    return !start.isBefore(shift.start) && start.isBefore(shift.end);
  }

  List<Map<String, dynamic>> _filterTnbTripsForShift(
    List<dynamic> trips,
    String shiftKey,
  ) {
    return trips.whereType<Map>().map(Map<String, dynamic>.from).where((trip) {
      final tripPosteKey = _normalizePosteKey(trip['poste']?.toString());
      if (tripPosteKey != null) {
        return tripPosteKey == shiftKey;
      }
      return _isTripTimeWithinPoste(trip['time']?.toString(), shiftKey);
    }).toList();
  }

  List<Map<String, dynamic>> _filterTnbStockForShift(
    List<dynamic> stockEntries,
    String shiftKey,
  ) {
    return stockEntries
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where((entry) =>
            _normalizePosteKey(entry['poste']?.toString()) == shiftKey)
        .toList();
  }

  List<Widget> _buildTnbCounterRowsForShift(
    Map<String, dynamic> data, {
    required DateTime baseDate,
    required String shiftKey,
  }) {
    final counters = _buildTnbCounterDisplayList(data)
        .where((counter) => (counter['start'] ?? '').trim().isNotEmpty)
        .toList();
    if (counters.isEmpty) {
      return const [Text('-')];
    }

    final shift = _cycleShiftWindowByKey(baseDate, shiftKey);
    if (shift == null) {
      return const [Text('-')];
    }

    final rows = <Widget>[
      Text(shift.label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
    ];

    for (final counter in counters) {
      final segments = _buildTnbCounterShiftSegments(
        data: data,
        label: counter['label'] ?? '',
        baseDate: baseDate,
      );
      final segment = segments.firstWhere(
        (s) => (s['shiftKey'] ?? '') == shiftKey,
        orElse: () => const {'start': '', 'end': ''},
      );
      final start = (segment['start'] ?? '').trim();
      final end = (segment['end'] ?? '').trim();
      if (start.isEmpty || end.isEmpty) {
        continue;
      }
      final shiftHours = _counterShiftHours(start, end);
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '• ${counter['label']} : $start → $end (${_formatTnbCounterNumber(shiftHours)} h)',
          ),
        ),
      );
    }
    if (rows.length <= 2) {
      rows.add(const Text('-'));
    }
    return rows;
  }

  Widget _buildTnbReportDetailsPage({
    required Map<String, dynamic> data,
    required DateTime reportDate,
    required AppLocalizations l10n,
    String? shiftKey,
    Report? report,
    StateSetter? setDialogState,
  }) {
    final allStops =
        (data['Arrets'] is List) ? List.from(data['Arrets']) : <dynamic>[];
    final allStock =
        (data['stock'] is List) ? List.from(data['stock']) : <dynamic>[];
    final allTrips = (data['truckTrips'] is List)
        ? List.from(data['truckTrips'])
        : <dynamic>[];

    final shift =
        shiftKey == null ? null : _cycleShiftWindowByKey(reportDate, shiftKey);
    final stops = shiftKey == null
        ? allStops
            .asMap()
            .entries
            .where((entry) => entry.value is Map)
            .map((entry) {
            final stop = Map<String, dynamic>.from(entry.value as Map);
            stop['_sourceIndex'] = entry.key;
            return stop;
          }).toList()
        : _filterTnbStopsForShift(allStops, reportDate, shiftKey);
    final stockEntries = shiftKey == null
        ? allStock.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : _filterTnbStockForShift(allStock, shiftKey);
    final trips = shiftKey == null
        ? allTrips.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : _filterTnbTripsForShift(allTrips, shiftKey);
    final quantity = _getTnbQuantityTotal(stockEntries);
    final totalTrips = _getTnbTotalVoyagesForSummary(
      stockEntries: stockEntries,
      trips: trips,
    );
    final vibreurHours = shiftKey == null
        ? _getCounterDailyOperatingHoursByLabel(
            data: data,
            baseDate: reportDate,
            counterLabel: 'Vibreur',
          )
        : _getCounterShiftHoursByLabel(
            data: data,
            baseDate: reportDate,
            shiftKey: shiftKey,
            counterLabel: 'Vibreur',
          );
    final lnHours = shiftKey == null
        ? _getCounterDailyOperatingHoursByLabel(
            data: data,
            baseDate: reportDate,
            counterLabel: 'LN',
          )
        : _getCounterShiftHoursByLabel(
            data: data,
            baseDate: reportDate,
            shiftKey: shiftKey,
            counterLabel: 'LN',
          );

    final totalDowntime = shift == null
        ? (data['T H.A'] is int ? data['T H.A'] as int : 0)
        : _calculateTnbDowntimeMinutesInWindow(
            stops: allStops,
            windowStart: shift.start,
            windowEnd: shift.end,
            cycleStart: DateTime(
                reportDate.year, reportDate.month, reportDate.day, 22, 30),
            cycleEnd: DateTime(
                    reportDate.year, reportDate.month, reportDate.day, 22, 30)
                .add(const Duration(hours: 24)),
          );
    final totalOperating = shift == null
        ? (data['T H.M'] is int ? data['T H.M'] as int : 0)
        : math.max(0, 480 - totalDowntime);
    final groupedTnbStops = shiftKey == null ? _groupStopsByType(stops) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.date,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 16),
                  Text(
                      '${reportDate.day}/${reportDate.month}/${reportDate.year}'),
                  if (shift != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      shift.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
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
                  Text(AppLocalizations.of(context)!.dataSummary,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 16),
                  _buildSummaryRow(
                      'T H.A:', _formatMinutesToHoursMinutes(totalDowntime)),
                  _buildSummaryRow(
                      'T H.M:', _formatMinutesToHoursMinutes(totalOperating)),
                  const SizedBox(height: 8),
                  _buildSummaryRow('T Nr.A:', stops.length.toString()),
                  _buildSummaryRow(
                    'T Nr.C:',
                    '${_filledTnbCounterCount(data)} / ${_buildTnbCounterDisplayList(data).length}',
                  ),
                  _buildSummaryRow('T Nr.V:', totalTrips.toString()),
                  if (shiftKey == null) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow('T. Qty:', quantity.toString()),
                    _buildSummaryRow(
                      'Rendement Vibreur:',
                      _formatTnbRendement(quantity, vibreurHours),
                    ),
                    _buildSummaryRow(
                      'Rendement LN:',
                      _formatTnbRendement(quantity, lnHours),
                    ),
                  ],
                  if (shiftKey != null) ...[
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'Rendement Vibreur:',
                      _formatTnbRendement(quantity, vibreurHours),
                    ),
                    _buildSummaryRow(
                      'Rendement LN:',
                      _formatTnbRendement(quantity, lnHours),
                    ),
                  ],
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
                  Text('Arrêts',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 16),
                  if (shiftKey == null && groupedTnbStops != null)
                    ...groupedTnbStops.asMap().entries.map((entry) {
                      final groupedStop = entry.value;
                      final canEndHere = report != null &&
                          groupedStop.hasPendingStop &&
                          groupedStop.sourceIndexes.length == 1;
                      final sourceIndex = groupedStop.sourceIndexes.isEmpty
                          ? -1
                          : groupedStop.sourceIndexes.first;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.key + 1} • ${groupedStop.type.isEmpty ? '-' : groupedStop.type}\n'
                                '     ${_formatMinutesToHoursMinutes(groupedStop.totalDurationMinutes)}',
                              ),
                            ),
                            if (canEndHere && sourceIndex >= 0) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingActivityStopFromVerification(
                                    report: report,
                                    data: data,
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    })
                  else if (stops.isNotEmpty)
                    ...stops.asMap().entries.map((entry) {
                      final stop = entry.value;
                      final sourceIndex = _sourceStopIndex(stop, entry.key);
                      final canEndHere = report != null && _isPendingStop(stop);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(_formatTnbActivityStopSummary(stop)),
                            ),
                            if (canEndHere) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingActivityStopFromVerification(
                                    report: report,
                                    data: data,
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    })
                  else
                    Text(AppLocalizations.of(context)!.aucunArret,
                        style: const TextStyle(color: Colors.grey)),
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
                  Text('Compteurs TNB',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 16),
                  if (shiftKey == null)
                    ..._buildTnbShiftCounterRows(
                      data,
                      baseDate: reportDate,
                      bullet: '• ',
                    )
                  else
                    ..._buildTnbCounterRowsForShift(
                      data,
                      baseDate: reportDate,
                      shiftKey: shiftKey,
                    ),
                ],
              ),
            ),
          ),
          if (stockEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.stockLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(height: 16),
                    ...stockEntries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${AppLocalizations.of(context)!.poste}: ${_getPosteString(entry['poste'], l10n)} | Voyages GAT: ${entry['gatTrips'] ?? '-'} | Voyages TEREX: ${entry['terexTrips'] ?? '-'} | ${AppLocalizations.of(context)!.parkLabel}: ${_getParkString(entry['park'], l10n)} | ${AppLocalizations.of(context)!.type}: ${_getStockTypeString(entry['type'], l10n)} | ${AppLocalizations.of(context)!.quantityLabel}: ${_getComputedStockQuantity(Map<String, dynamic>.from(entry))} |',
                          ),
                        )),
                  ],
                ),
              ),
            ),
          ],
          if (shiftKey == null && report != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: report.isSentToSheets
                    ? null
                    : () => _sendReportToSheets(report),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(AppLocalizations.of(context)!.sendToSheets),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTsudReportDetailsPage({
    required Map<String, dynamic> data,
    required DateTime reportDate,
    required AppLocalizations l10n,
    String? shiftKey,
    Report? report,
    StateSetter? setDialogState,
  }) {
    final allModule1Stops =
        (data['module1Stops'] is List) ? List.from(data['module1Stops']) : [];
    final allModule2Stops =
        (data['module2Stops'] is List) ? List.from(data['module2Stops']) : [];
    final allStock = (data['stock'] is List) ? List.from(data['stock']) : [];
    final shift =
        shiftKey == null ? null : _cycleShiftWindowByKey(reportDate, shiftKey);
    final cycleStart =
        DateTime(reportDate.year, reportDate.month, reportDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));

    final module1Stops = shiftKey == null
        ? allModule1Stops
            .asMap()
            .entries
            .where((entry) => entry.value is Map)
            .map((entry) {
            final stop = Map<String, dynamic>.from(entry.value as Map);
            stop['_sourceIndex'] = entry.key;
            return stop;
          }).toList()
        : _filterTnbStopsForShift(allModule1Stops, reportDate, shiftKey);
    final module2Stops = shiftKey == null
        ? allModule2Stops
            .asMap()
            .entries
            .where((entry) => entry.value is Map)
            .map((entry) {
            final stop = Map<String, dynamic>.from(entry.value as Map);
            stop['_sourceIndex'] = entry.key;
            return stop;
          }).toList()
        : _filterTnbStopsForShift(allModule2Stops, reportDate, shiftKey);
    final stockEntries = shiftKey == null
        ? allStock
        : _filterTnbStockForShift(allStock, shiftKey);

    final module1Downtime = shift == null
        ? _calculateDowntimeFromStops(module1Stops)
        : _calculateTnbDowntimeMinutesInWindow(
            stops: allModule1Stops,
            windowStart: shift.start,
            windowEnd: shift.end,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
          );
    final module2Downtime = shift == null
        ? _calculateDowntimeFromStops(module2Stops)
        : _calculateTnbDowntimeMinutesInWindow(
            stops: allModule2Stops,
            windowStart: shift.start,
            windowEnd: shift.end,
            cycleStart: cycleStart,
            cycleEnd: cycleEnd,
          );

    final totalPeriodMinutes = shift == null ? 24 * 60 : 8 * 60;
    final module1OperatingTime =
        (totalPeriodMinutes - module1Downtime).clamp(0, totalPeriodMinutes);
    final module2OperatingTime =
        (totalPeriodMinutes - module2Downtime).clamp(0, totalPeriodMinutes);
    final groupedModule1Stops =
        shiftKey == null ? _groupStopsByType(module1Stops) : null;
    final groupedModule2Stops =
        shiftKey == null ? _groupStopsByType(module2Stops) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.date,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(DateFormat('yyyy-MM-dd').format(reportDate)),
                  if (shift != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      shift.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.module1Label,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      '${AppLocalizations.of(context)!.operatingTime}: ${_formatMinutesToHoursMinutes(module1OperatingTime)}'),
                  Text(
                      '${AppLocalizations.of(context)!.stopTime}: ${_formatMinutesToHoursMinutes(module1Downtime)}'),
                  if (shiftKey == null && groupedModule1Stops != null) ...[
                    const SizedBox(height: 8),
                    Text('${AppLocalizations.of(context)!.stopsLabel}:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...groupedModule1Stops.asMap().entries.map((entry) {
                      final groupedStop = entry.value;
                      final canEndHere = report != null &&
                          groupedStop.hasPendingStop &&
                          groupedStop.sourceIndexes.length == 1;
                      final sourceIndex = groupedStop.sourceIndexes.isEmpty
                          ? -1
                          : groupedStop.sourceIndexes.first;
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.key + 1} • ${groupedStop.type.isEmpty ? '-' : groupedStop.type}\n'
                                '    ${_formatMinutesToHoursMinutes(groupedStop.totalDurationMinutes)}',
                              ),
                            ),
                            if (canEndHere && sourceIndex >= 0) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingDailyStopFromVerification(
                                    report: report,
                                    data: data,
                                    modulePrefix: 'module1',
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ] else if (module1Stops.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${AppLocalizations.of(context)!.stopsLabel}:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...module1Stops.asMap().entries.map((entry) {
                      final stop = entry.value;
                      final sourceIndex = _sourceStopIndex(stop, entry.key);
                      final canEndHere = report != null && _isPendingStop(stop);
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(_formatDailyModuleStopLine(
                                stop,
                                index: entry.key + 1,
                              )),
                            ),
                            if (canEndHere) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingDailyStopFromVerification(
                                    report: report,
                                    data: data,
                                    modulePrefix: 'module1',
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.module2Label,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      '${AppLocalizations.of(context)!.operatingTime}: ${_formatMinutesToHoursMinutes(module2OperatingTime)}'),
                  Text(
                      '${AppLocalizations.of(context)!.stopTime}: ${_formatMinutesToHoursMinutes(module2Downtime)}'),
                  if (shiftKey == null && groupedModule2Stops != null) ...[
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.stopsLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...groupedModule2Stops.asMap().entries.map((entry) {
                      final groupedStop = entry.value;
                      final canEndHere = report != null &&
                          groupedStop.hasPendingStop &&
                          groupedStop.sourceIndexes.length == 1;
                      final sourceIndex = groupedStop.sourceIndexes.isEmpty
                          ? -1
                          : groupedStop.sourceIndexes.first;
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${entry.key + 1} • ${groupedStop.type.isEmpty ? '-' : groupedStop.type}\n'
                                '    ${_formatMinutesToHoursMinutes(groupedStop.totalDurationMinutes)}',
                              ),
                            ),
                            if (canEndHere && sourceIndex >= 0) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingDailyStopFromVerification(
                                    report: report,
                                    data: data,
                                    modulePrefix: 'module2',
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ] else if (module2Stops.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.stopsLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ...module2Stops.asMap().entries.map((entry) {
                      final stop = entry.value;
                      final sourceIndex = _sourceStopIndex(stop, entry.key);
                      final canEndHere = report != null && _isPendingStop(stop);
                      return Padding(
                        padding:
                            const EdgeInsets.only(left: 16, top: 4, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(_formatDailyModuleStopLine(
                                stop,
                                index: entry.key + 1,
                              )),
                            ),
                            if (canEndHere) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final didEnd =
                                      await _endPendingDailyStopFromVerification(
                                    report: report,
                                    data: data,
                                    modulePrefix: 'module2',
                                    sourceIndex: sourceIndex,
                                    l10n: l10n,
                                  );
                                  if (didEnd) {
                                    setDialogState?.call(() {});
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_circle_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                    AppLocalizations.of(context)!.finishLabel),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          if (stockEntries.isNotEmpty)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.stockLabel,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    ...stockEntries.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${AppLocalizations.of(context)!.poste}: ${_getPosteString(entry['poste'], l10n)} | ${AppLocalizations.of(context)!.parkLabel}: ${_getParkString(entry['park'], l10n)} | ${AppLocalizations.of(context)!.type}: ${_getStockTypeString(entry['type'], l10n)} | ${AppLocalizations.of(context)!.quantityLabel}: ${_getComputedStockQuantity(Map<String, dynamic>.from(entry))} |',
                          ),
                        )),
                  ],
                ),
              ),
            ),
          if (shiftKey == null && report != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: report.isSentToSheets
                    ? null
                    : () => _sendReportToSheets(report),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(AppLocalizations.of(context)!.sendToSheets),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildTnbShiftCounterRows(
    Map<String, dynamic> data, {
    required DateTime baseDate,
    TextStyle? shiftTitleStyle,
    EdgeInsetsGeometry rowPadding = const EdgeInsets.symmetric(vertical: 2),
    String bullet = '',
  }) {
    final counters = _buildTnbCounterDisplayList(data)
        .where((counter) => (counter['start'] ?? '').trim().isNotEmpty)
        .toList();
    if (counters.isEmpty) {
      return const [Text('-')];
    }

    final shifts = _cycleShiftWindows(baseDate);

    final rows = <Widget>[];
    for (final shift in shifts) {
      rows.add(Text(
        shift.label,
        style: shiftTitleStyle ?? const TextStyle(fontWeight: FontWeight.w600),
      ));
      rows.add(const SizedBox(height: 6));

      for (final counter in counters) {
        final counterLabel = counter['label'] ?? '';
        final storedSegments = _buildTnbCounterShiftSegments(
          data: data,
          label: counterLabel,
          baseDate: baseDate,
        );
        final segment = storedSegments.firstWhere(
          (s) => s['shiftLabel'] == shift.label,
          orElse: () => const {
            'start': '',
            'end': '',
          },
        );
        if ((segment['start'] ?? '').isEmpty ||
            (segment['end'] ?? '').isEmpty) {
          continue;
        }
        final hours =
            _counterShiftHours(segment['start'] ?? '', segment['end'] ?? '');
        rows.add(Padding(
          padding: rowPadding,
          child: Text(
            '$bullet$counterLabel : ${segment['start']} → ${segment['end']} (${_formatTnbCounterNumber(hours)} h)',
          ),
        ));
      }
      rows.add(const SizedBox(height: 10));
    }

    return rows;
  }

  int _filledTnbCounterCount(Map<String, dynamic> data) {
    final savedCount = data['T Nr.C'];
    if (savedCount is int) {
      return savedCount;
    }
    return _buildTnbCounterDisplayList(data)
        .where((counter) => (counter['start'] ?? '').trim().isNotEmpty)
        .length;
  }

  Widget _buildActivityReportAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) {
      return Text(AppLocalizations.of(context)!.noActivityData);
    }

    final stops = (data['Arrets'] is List)
        ? List.from(data['Arrets'])
        : (data['stops'] is List)
            ? List.from(data['stops'])
            : [];
    final tnbCounters = _buildTnbCounterDisplayList(data);
    final stockEntries =
        (data['stock'] is List) ? List.from(data['stock']) : [];
    final truckTrips =
        (data['truckTrips'] is List) ? List.from(data['truckTrips']) : [];
    final totalTrips = _getTnbTotalVoyagesForSummary(
      stockEntries:
          stockEntries.whereType<Map>().map(Map<String, dynamic>.from).toList(),
      trips:
          truckTrips.whereType<Map>().map(Map<String, dynamic>.from).toList(),
    );

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
                const SizedBox(height: 8),
                _buildSummaryRow('T Nr.A:', stops.length.toString()),
                _buildSummaryRow(
                  'T Nr.C:',
                  '${_filledTnbCounterCount(data)} / ${tnbCounters.length}',
                ),
                _buildSummaryRow('T Nr.V:', totalTrips.toString()),
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
                  Text(AppLocalizations.of(context)!.arretsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...stops.asMap().entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                          _formatTnbActivityStopSummary(
                            Map<String, dynamic>.from(
                              entry.value is Map
                                  ? entry.value
                                  : <String, dynamic>{},
                            ),
                            index: entry.key + 1,
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Compteurs TNB',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._buildTnbShiftCounterRows(
                  data,
                  baseDate: DateTime.now(),
                  rowPadding: const EdgeInsets.only(left: 16, top: 4),
                ),
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
                  Text(
                      '${AppLocalizations.of(context)!.stocksLabel} & ${AppLocalizations.of(context)!.voyagesLabel}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...stockEntries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: ${_getPosteString(entry['poste'], l10n)}, Voyages GAT: ${entry['gatTrips'] ?? '-'}, Voyages TEREX: ${entry['terexTrips'] ?? '-'}, Qté: ${_getComputedStockQuantity(Map<String, dynamic>.from(entry))}, Parc: ${_getParkString(entry['park'], l10n)}, Type: ${_getStockTypeString(entry['type'], l10n)}'),
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

  String _getTnbStopTypeLabel(Map<String, dynamic> stop) =>
      (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '')
          .toString()
          .trim();

  String _getTnbStopLocationLabel(Map<String, dynamic> stop) =>
      (stop['location'] ?? stop['Lieu'] ?? stop['stopLocation'] ?? '')
          .toString()
          .trim();

  String _getTnbStopDetailLabel(Map<String, dynamic> stop) =>
      (stop['detail'] ?? stop['Détail'] ?? '').toString().trim();

  String _formatTnbActivityStopSummary(
    Map<String, dynamic> stop, {
    int? index,
  }) {
    final type = _getTnbStopTypeLabel(stop);
    final location = _getTnbStopLocationLabel(stop);
    final detail = _getTnbStopDetailLabel(stop);
    final showLocation = _tnbStopTypeRequiresLocation(type);
    final showDetail = _tnbStopTypeRequiresDetail(type);
    final start =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    final end =
        (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
    final parsedDurationMinutes =
        _parseDurationToMinutes((stop['duration'] ?? '').toString());
    final durationMinutes = parsedDurationMinutes > 0
        ? parsedDurationMinutes
        : _calculateDurationMinutesFromRange(start, end);
    final duration = _formatMinutesToHoursMinutes(durationMinutes);

    final stopLabelSegments = <String>[
      if (index != null) '$index',
      type.isNotEmpty ? type : '-',
      if (showDetail && detail.isNotEmpty) detail,
      if (showLocation && location.isNotEmpty) location,
    ];
    final timeRangeLabel =
        'De ${start.isEmpty ? '--:--' : start} a ${end.isEmpty ? 'Pending' : end}';
    return '${stopLabelSegments.join(' • ')}\n     $timeRangeLabel ($duration)';
  }

  static const Map<int, Map<String, String>> _dailyModuleLocations = {
    1: {
      'M1_TR01': 'Tremie',
      'M1_VIB01': 'Vibreur 01',
      'M1_VIB02': 'Vibreur 02',
      'M1_CV73': 'Convoyeur 73',
      'M1_cv77': 'Convoyeur 77',
      'M1_CRIBLE1': 'Crible 01',
      'M1_CV84': 'Convoyeur 84',
      'M1_CV86': 'Convoyeur 86',
      'CV_G0': 'Convoyeur G0',
      'CV_G2': 'Convoyeur G2',
      'CV_G0_G2': 'Convoyeurs G0 + G2 (panne totale)',
      'CV_G4': 'Convoyeur G4',
    },
    2: {
      'M2_TR01': 'Tremie',
      'M2_VIB01': 'Vibreur 01',
      'M2_VIB02': 'Vibreur 02',
      'M2_CV73': 'Convoyeur 73',
      'M2_cv77': 'Convoyeur 77',
      'M2_CRIBLE1': 'Crible 01',
      'M2_CV84': 'Convoyeur 84',
      'M2_CV86': 'Convoyeur 86',
      'CV_G0': 'Convoyeur G0',
      'CV_G2': 'Convoyeur G2',
      'CV_G0_G2': 'Convoyeurs G0 + G2 (panne totale)',
      'CV_G5': 'Convoyeur G5',
    },
  };
  static const Set<String> _sharedDailyConveyorLocationKeys = {
    'CV_G0_G2',
  };

  String _formatDailyStopLine(dynamic rawStop) {
    final stop = rawStop is Map ? rawStop : <String, dynamic>{};
    final stopType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '-')
            .toString()
            .trim();
    final stopLocation =
        (stop['location'] ?? stop['stopLocation'] ?? stop['Lieu'] ?? '')
            .toString()
            .trim();
    final stopDetail = _getTnbStopDetailLabel(Map<String, dynamic>.from(stop));
    final start =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    final end =
        (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
    final parsedDurationMinutes =
        _parseDurationToMinutes((stop['duration'] ?? '').toString());
    final durationMinutes = parsedDurationMinutes > 0
        ? parsedDurationMinutes
        : _calculateDurationMinutesFromRange(start, end);
    final duration = _formatMinutesToHoursMinutes(durationMinutes);
    final segments = <String>[
      stopType.isNotEmpty ? stopType : '-',
      if (stopDetail.isNotEmpty) stopDetail,
      if (stopLocation.isNotEmpty) stopLocation,
      'De ${start.isEmpty ? '--:--' : start} a ${end.isEmpty ? '--:--' : end}',
      duration,
    ];
    return segments.join('\n');
  }

  List<Widget> _buildDailyModuleStops(
    List<dynamic> stops, {
    double leftPadding = 0,
  }) {
    return stops.asMap().entries.map((entry) {
      return Padding(
        padding: EdgeInsets.only(left: leftPadding, top: 4, bottom: 4),
        child: Text(
          _formatDailyModuleStopLine(entry.value, index: entry.key + 1),
        ),
      );
    }).toList();
  }

  String _formatDailyModuleStopLine(
    dynamic rawStop, {
    required int index,
  }) {
    final stop = rawStop is Map ? rawStop : <String, dynamic>{};
    final stopType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '-')
            .toString()
            .trim();
    final stopLocation =
        (stop['location'] ?? stop['stopLocation'] ?? stop['Lieu'] ?? '')
            .toString()
            .trim();
    final stopDetail = _getTnbStopDetailLabel(Map<String, dynamic>.from(stop));
    final start =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    final end =
        (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
    final parsedDurationMinutes =
        _parseDurationToMinutes((stop['duration'] ?? '').toString());
    final durationMinutes = parsedDurationMinutes > 0
        ? parsedDurationMinutes
        : _calculateDurationMinutesFromRange(start, end);
    final duration = _formatMinutesToHoursMinutes(durationMinutes);

    final labelSegments = <String>[
      stopType.isNotEmpty ? stopType : '-',
      if (stopDetail.isNotEmpty) stopDetail,
      if (stopLocation.isNotEmpty) stopLocation,
    ];

    final startLabel = start.isEmpty ? '--:--' : start;
    final endLabel = end.isEmpty ? '--:--' : end;

    return '$index • ${labelSegments.join(' - ')}\n'
        '    De $startLabel a $endLabel ($duration)';
  }

  String _formatDailyModuleStopTitle(dynamic rawStop, int index) {
    final stop = rawStop is Map ? rawStop : <String, dynamic>{};
    final stopType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '-')
            .toString()
            .trim();
    final stopLocation =
        (stop['location'] ?? stop['stopLocation'] ?? stop['Lieu'] ?? '')
            .toString()
            .trim();
    final stopDetail = _getTnbStopDetailLabel(Map<String, dynamic>.from(stop));
    final labelSegments = <String>[
      stopType.isNotEmpty ? stopType : '-',
      if (stopDetail.isNotEmpty) stopDetail,
      if (stopLocation.isNotEmpty) stopLocation,
    ];
    return '$index • ${labelSegments.join(' - ')}';
  }

  String _formatDailyModuleStopTimeline(dynamic rawStop) {
    final stop = rawStop is Map ? rawStop : <String, dynamic>{};
    final start =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    final end =
        (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
    final parsedDurationMinutes =
        _parseDurationToMinutes((stop['duration'] ?? '').toString());
    final durationMinutes = parsedDurationMinutes > 0
        ? parsedDurationMinutes
        : _calculateDurationMinutesFromRange(start, end);
    final duration = _formatMinutesToHoursMinutes(durationMinutes);
    final startLabel = start.isEmpty ? '--:--' : start;
    final endLabel = end.isEmpty ? '--:--' : end;
    return 'De $startLabel a $endLabel ($duration)';
  }

  List<_GroupedStopEntry> _groupStopsByType(List<dynamic> rawStops) {
    final grouped = <String, _GroupedStopEntry>{};
    for (final entry in rawStops) {
      if (entry is! Map) continue;
      final stop = Map<String, dynamic>.from(entry);
      final stopType = _getTnbStopTypeLabel(stop);
      final normalizedType =
          stopType.isEmpty ? '-' : stopType.toLowerCase().trim();
      final start = (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '')
          .toString();
      final end =
          (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
      final parsedDurationMinutes =
          _parseDurationToMinutes((stop['duration'] ?? '').toString());
      final durationMinutes = parsedDurationMinutes > 0
          ? parsedDurationMinutes
          : _calculateDurationMinutesFromRange(start, end);
      final sourceIndex = _sourceStopIndex(stop, -1);
      final previous = grouped[normalizedType];

      if (previous == null) {
        grouped[normalizedType] = _GroupedStopEntry(
          type: stopType.isEmpty ? '-' : stopType,
          totalDurationMinutes: durationMinutes,
          sourceIndexes: sourceIndex >= 0 ? [sourceIndex] : <int>[],
          hasPendingStop: _isPendingStop(stop),
        );
      } else {
        final updatedIndexes = List<int>.from(previous.sourceIndexes);
        if (sourceIndex >= 0) {
          updatedIndexes.add(sourceIndex);
        }
        grouped[normalizedType] = _GroupedStopEntry(
          type: previous.type,
          totalDurationMinutes: previous.totalDurationMinutes + durationMinutes,
          sourceIndexes: updatedIndexes,
          hasPendingStop: previous.hasPendingStop || _isPendingStop(stop),
        );
      }
    }
    return grouped.values.toList();
  }

  int _calculateDurationMinutesFromRange(String start, String end) {
    final startMinutes = _toMinutes(start);
    final endMinutes = _toMinutes(end);
    if (startMinutes == null || endMinutes == null) {
      return 0;
    }
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    }
    return (24 * 60 - startMinutes) + endMinutes;
  }

  int? _toMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool _isSharedDailyConveyorLocation(String? locationKey) =>
      locationKey != null &&
      _sharedDailyConveyorLocationKeys.contains(locationKey);

  String _otherModulePrefix(String modulePrefix) =>
      modulePrefix == 'module1' ? 'module2' : 'module1';

  void _deleteMirroredDailyStopIfLinked(Map<String, dynamic> data,
      String modulePrefix, Map<String, dynamic> stop) {
    final sharedMirrorId = (stop['sharedMirrorId'] ?? '').toString();
    if (sharedMirrorId.isEmpty) return;

    final otherModulePrefix = _otherModulePrefix(modulePrefix);
    final otherStopsKey = '${otherModulePrefix}Stops';
    final otherStops = (data[otherStopsKey] is List)
        ? List.from(data[otherStopsKey])
        : <dynamic>[];
    otherStops.removeWhere((entry) =>
        entry is Map &&
        (entry['sharedMirrorId'] ?? '').toString() == sharedMirrorId);
    data[otherStopsKey] = otherStops;
    _updateDailyTotalsForModule(data, otherModulePrefix, otherStops);
  }

  String _dailyStopTypeValue(Map<String, dynamic> stop) =>
      (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '')
          .toString()
          .trim();

  bool _areDailyStopsEquivalent(dynamic entry, Map<String, dynamic> reference) {
    if (entry is! Map) return false;

    String value(dynamic mapValue) => (mapValue ?? '').toString().trim();

    final mapped = Map<String, dynamic>.from(entry);
    return value(mapped['category']) == value(reference['category']) &&
        value(mapped['nature'] ?? mapped['stopType']) ==
            value(reference['nature'] ?? reference['stopType']) &&
        value(mapped['location'] ?? mapped['stopLocation']) ==
            value(reference['location'] ?? reference['stopLocation']) &&
        value(mapped['detail']) == value(reference['detail']) &&
        value(mapped['startTime'] ?? mapped['start'] ?? mapped['Début']) ==
            value(reference['startTime'] ??
                reference['start'] ??
                reference['Début']) &&
        value(mapped['endTime'] ?? mapped['end'] ?? mapped['Fin']) ==
            value(reference['endTime'] ?? reference['end'] ?? reference['Fin']);
  }

  void _deleteMirroredDailyStopByTypeFallback(Map<String, dynamic> data,
      String modulePrefix, Map<String, dynamic> stop) {
    if (!_tnbStopTypeAlwaysMirrors(_dailyStopTypeValue(stop))) return;
    final otherModulePrefix = _otherModulePrefix(modulePrefix);
    final otherStopsKey = '${otherModulePrefix}Stops';
    final otherStops = (data[otherStopsKey] is List)
        ? List.from(data[otherStopsKey])
        : <dynamic>[];
    final mirroredIndex =
        otherStops.indexWhere((entry) => _areDailyStopsEquivalent(entry, stop));
    if (mirroredIndex < 0) return;

    otherStops.removeAt(mirroredIndex);
    data[otherStopsKey] = otherStops;
    _updateDailyTotalsForModule(data, otherModulePrefix, otherStops);
  }

  void _upsertMirroredDailyStop(Map<String, dynamic> data, String modulePrefix,
      Map<String, dynamic> sourceStop, String sharedMirrorId,
      {Map<String, dynamic>? legacyMatchStop}) {
    final otherModulePrefix = _otherModulePrefix(modulePrefix);
    final otherStopsKey = '${otherModulePrefix}Stops';
    final otherStops = (data[otherStopsKey] is List)
        ? List.from(data[otherStopsKey])
        : <dynamic>[];

    final mirroredStop = {
      ...sourceStop,
      'id': '${const Uuid().v4()}_$otherModulePrefix',
      'sharedMirrorId': sharedMirrorId,
      'sharedSourceModule': modulePrefix,
    };

    final existingIndex = otherStops.indexWhere((entry) =>
        entry is Map &&
        (entry['sharedMirrorId'] ?? '').toString() == sharedMirrorId);
    if (existingIndex >= 0) {
      final existing = otherStops[existingIndex];
      final existingId = existing is Map
          ? (existing['id'] ?? mirroredStop['id'])
          : mirroredStop['id'];
      otherStops[existingIndex] = {
        ...mirroredStop,
        'id': existingId,
      };
    } else {
      final legacyReference = legacyMatchStop ?? sourceStop;
      final legacyIndex = otherStops.indexWhere((entry) =>
          _areDailyStopsEquivalent(
              entry, Map<String, dynamic>.from(legacyReference)));
      if (legacyIndex >= 0) {
        final existing = otherStops[legacyIndex];
        final existingId = existing is Map
            ? (existing['id'] ?? mirroredStop['id'])
            : mirroredStop['id'];
        otherStops[legacyIndex] = {
          ...mirroredStop,
          'id': existingId,
        };
      } else {
        otherStops.add(mirroredStop);
      }
    }

    data[otherStopsKey] = otherStops;
    _updateDailyTotalsForModule(data, otherModulePrefix, otherStops);
  }

  DateTime? _parseDailyTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  int? _durationMinutesFromTimeStrings(String start, String end) {
    final parsedStart = _parseDailyTime(start);
    final parsedEnd = _parseDailyTime(end);
    if (parsedStart == null || parsedEnd == null) return null;
    final startTimeOfDay = TimeOfDay.fromDateTime(parsedStart);
    final endTimeOfDay = TimeOfDay.fromDateTime(parsedEnd);
    final durationMinutes =
        _durationMinutesInCycle(startTimeOfDay, endTimeOfDay);
    if (durationMinutes <= 0 || durationMinutes > _maxCycleMinutes) return null;
    return durationMinutes;
  }

  String _formatTimeOfDay(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String? _normalizeAssignedPoste(dynamic posteValue) {
    if (posteValue == null) return null;
    final raw = posteValue.toString().trim();
    if (raw.isEmpty) return null;

    final normalized = raw
        .toLowerCase()
        .replaceAll('poste', '')
        .replaceAll('ème', 'eme')
        .replaceAll('er', 'e')
        .replaceAll(RegExp(r'[^0-9a-z]'), '');

    if (normalized == '0' || normalized.startsWith('3')) return '3ème';
    if (normalized == '1' || normalized.startsWith('1')) return '1er';
    if (normalized == '2' || normalized.startsWith('2')) return '2ème';
    return raw;
  }

  String? _assignedPosteForStopDialog(
    Map<String, dynamic> data, {
    String? shiftKey,
  }) {
    final normalizedShiftKey = _normalizePosteKey(shiftKey);
    if (normalizedShiftKey == '3') return '3ème';
    if (normalizedShiftKey == '1') return '1er';
    if (normalizedShiftKey == '2') return '2ème';

    final raw = data['selectedPoste'] ?? data['poste'] ?? data['posteSelected'];
    return _normalizeAssignedPoste(raw);
  }

  bool _isStartTimeWithinAssignedPoste(
    TimeOfDay startTime,
    String? assignedPoste,
  ) {
    final normalizedPoste = _normalizePosteKey(assignedPoste);
    if (normalizedPoste == null) return true;

    final minutes = (startTime.hour * 60) + startTime.minute;
    switch (normalizedPoste) {
      case '3':
        return minutes >= (22 * 60 + 30) || minutes < (6 * 60 + 30);
      case '1':
        return minutes >= (6 * 60 + 30) && minutes < (14 * 60 + 30);
      case '2':
        return minutes >= (14 * 60 + 30) && minutes < (22 * 60 + 30);
      default:
        return true;
    }
  }

  String _assignedPosteWindowLabel(String? assignedPoste) {
    switch (_normalizePosteKey(assignedPoste)) {
      case '3':
        return '22:30 → 06:30';
      case '1':
        return '06:30 → 14:30';
      case '2':
        return '14:30 → 22:30';
      default:
        return '';
    }
  }

  String? _validateStopStartInAssignedPoste(
    TimeOfDay startTime,
    String? assignedPoste,
  ) {
    if (_isStartTimeWithinAssignedPoste(startTime, assignedPoste)) {
      return null;
    }

    final assignedWindow = _assignedPosteWindowLabel(assignedPoste);
    if (assignedWindow.isEmpty) {
      return "L'heure de début doit être dans le poste affecté.";
    }
    return "L'heure de début doit être comprise dans le poste affecté ($assignedWindow).";
  }

  Future<_StopTimeSelectionResult?> _showStopTimeEntryDialog({
    required String titleSuffix,
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
    String? assignedPoste,
  }) async {
    return showDialog<_StopTimeSelectionResult>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _StopTimeEntryPage(
        titleSuffix: titleSuffix,
        initialStartTime: initialStart,
        initialEndTime: initialEnd,
        initialPending: initialEnd == null,
        assignedPoste: assignedPoste,
      ),
    );
  }

  bool _isPendingStop(Map<String, dynamic> stop) {
    final endTime =
        (stop['endTime'] ?? stop['Fin'] ?? stop['end'] ?? '').toString().trim();
    final normalized = endTime.toLowerCase();
    return normalized.isEmpty || normalized == 'pending';
  }

  TimeOfDay? _parseStopTimeOfDay(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _sourceStopIndex(Map<String, dynamic> stop, int fallbackIndex) {
    final sourceIndex = stop['_sourceIndex'];
    if (sourceIndex is int) return sourceIndex;
    if (sourceIndex is String) {
      final parsed = int.tryParse(sourceIndex);
      if (parsed != null) return parsed;
    }
    return fallbackIndex;
  }

  Future<bool> _endPendingActivityStopFromVerification({
    required Report report,
    required Map<String, dynamic> data,
    required int sourceIndex,
    required AppLocalizations l10n,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final arrets =
        (data['Arrets'] is List) ? List.from(data['Arrets']) : <dynamic>[];
    if (sourceIndex < 0 || sourceIndex >= arrets.length) return false;
    final stop = arrets[sourceIndex] is Map
        ? Map<String, dynamic>.from(arrets[sourceIndex])
        : <String, dynamic>{};
    if (!_isPendingStop(stop)) return false;

    final start = _parseStopTimeOfDay(stop['startTime'] ?? stop['Début']);
    if (start == null) return false;

    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return false;
    if (!mounted) return false;

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    if (durationMinutes <= 0 || durationMinutes > _maxCycleMinutes) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.stopMustRemainInWindow),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    final endTime = _formatTimeOfDay(selectedEnd);
    stop['endTime'] = endTime;
    stop['Fin'] = endTime;
    stop['duration'] =
        '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
    arrets[sourceIndex] = stop;

    final updatedData = Map<String, dynamic>.from(data);
    updatedData['Arrets'] = arrets;
    final recalculatedData = _recalculateActivityTotals(
      updatedData,
      reportDate: report.date,
    );

    data
      ..clear()
      ..addAll(recalculatedData);
    final updatedReport = report.copyWith(additionalData: recalculatedData);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    if (!mounted) return false;
    scaffoldMessenger.showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.stopFinishedSuccessfully)),
    );
    return true;
  }

  Future<bool> _endPendingDailyStopFromVerification({
    required Report report,
    required Map<String, dynamic> data,
    required String modulePrefix,
    required int sourceIndex,
    required AppLocalizations l10n,
  }) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final stops = (data['${modulePrefix}Stops'] is List)
        ? List.from(data['${modulePrefix}Stops'])
        : <dynamic>[];
    if (sourceIndex < 0 || sourceIndex >= stops.length) return false;

    final stop = stops[sourceIndex] is Map
        ? Map<String, dynamic>.from(stops[sourceIndex])
        : <String, dynamic>{};
    if (!_isPendingStop(stop)) return false;

    final start = _parseStopTimeOfDay(
        stop['startTime'] ?? stop['start'] ?? stop['Début']);
    if (start == null) return false;

    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return false;
    if (!mounted) return false;

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    if (durationMinutes <= 0 || durationMinutes > _maxCycleMinutes) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.stopMustRemainInWindow),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    final endTime = _formatTimeOfDay(selectedEnd);
    stop['endTime'] = endTime;
    stop['Fin'] = endTime;
    stop['end'] = endTime;
    stop['duration'] =
        '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
    stops[sourceIndex] = stop;

    final updatedData = Map<String, dynamic>.from(data);
    updatedData['${modulePrefix}Stops'] = stops;
    _updateDailyTotalsForModule(updatedData, modulePrefix, stops);

    data
      ..clear()
      ..addAll(updatedData);
    final updatedReport = report.copyWith(additionalData: updatedData);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    if (!mounted) return false;
    scaffoldMessenger.showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.stopFinishedSuccessfully)),
    );
    return true;
  }

  Future<void> _endPendingActivityStop(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final arrets =
        (data['Arrets'] is List) ? List.from(data['Arrets']) : <dynamic>[];
    if (index < 0 || index >= arrets.length) return;
    final stop = arrets[index] is Map
        ? Map<String, dynamic>.from(arrets[index])
        : <String, dynamic>{};
    if (!_isPendingStop(stop)) return;

    final start = _parseStopTimeOfDay(stop['startTime'] ?? stop['Début']);
    if (start == null) return;

    final stopWindowMsg = AppLocalizations.of(context)!.stopMustRemainInWindow;
    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return;

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    if (durationMinutes <= 0 || durationMinutes > _maxCycleMinutes) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(stopWindowMsg),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final durationText =
        '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
    final endTime = _formatTimeOfDay(selectedEnd);
    stop['endTime'] = endTime;
    stop['Fin'] = endTime;
    stop['duration'] = durationText;
    arrets[index] = stop;

    final updatedData = Map<String, dynamic>.from(data);
    updatedData['Arrets'] = arrets;
    final recalculatedData = _recalculateActivityTotals(
      updatedData,
      reportDate: report.date,
    );
    data
      ..clear()
      ..addAll(recalculatedData);
    final updatedReport = report.copyWith(additionalData: recalculatedData);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    setDialogState(() {});
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.stopFinishedSuccessfully)),
    );
  }

  Future<void> _endPendingDailyStopForModule(
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
    if (index < 0 || index >= stops.length) return;
    final stop = stops[index] is Map
        ? Map<String, dynamic>.from(stops[index])
        : <String, dynamic>{};
    if (!_isPendingStop(stop)) return;

    final start = _parseStopTimeOfDay(
        stop['startTime'] ?? stop['start'] ?? stop['Début']);
    if (start == null) return;

    final stopWindowMsg2 = AppLocalizations.of(context)!.stopMustRemainInWindow;
    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return;

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    if (durationMinutes <= 0 || durationMinutes > _maxCycleMinutes) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(stopWindowMsg2),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final endTime = _formatTimeOfDay(selectedEnd);
    stop['endTime'] = endTime;
    stop['Fin'] = endTime;
    stop['end'] = endTime;
    stop['duration'] =
        '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
    stops[index] = stop;

    setState(() {
      _updateDailyTotalsForModule(data, modulePrefix, stops);
      setDialogState(() {});
      onTotalDowntimeChanged(data['${modulePrefix}TotalDowntime'] ?? 0);
    });

    final updatedReport = report.copyWith(additionalData: data);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    if (!mounted) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
          content:
              Text(AppLocalizations.of(context)!.stopFinishedSuccessfully)),
    );
  }

  int _moduleNumberFromPrefix(String modulePrefix) =>
      modulePrefix == 'module1' ? 1 : 2;

  _TnbStopCategory? _findDailyStopCategory(Map<String, dynamic> stop) {
    String normalizeValue(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    final storedCategory =
        (stop['category'] ?? stop['Catégorie'] ?? '').toString().trim();
    if (storedCategory.isNotEmpty) {
      for (final category in _tsudStopCategories) {
        if (normalizeValue(category.label) == normalizeValue(storedCategory)) {
          return category;
        }
      }
    }

    final storedType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '')
            .toString()
            .trim();
    if (storedType.isEmpty) return null;

    for (final category in _tsudStopCategories) {
      if (category.types
          .any((type) => normalizeValue(type) == normalizeValue(storedType))) {
        return category;
      }
    }

    return null;
  }

  String? _validateDailyStopFields(
      {required _TnbStopCategory? category,
      required String? type,
      required String? location,
      required String detail,
      required String startTime,
      required String endTime}) {
    if (category == null) {
      return "La catégorie d'arrêt est obligatoire.";
    }
    if (type == null || type.isEmpty) return "Le type d'arrêt est obligatoire.";
    if (_tnbStopTypeRequiresLocation(type) &&
        (location == null || location.isEmpty)) {
      return "Le lieu d'arrêt est obligatoire.";
    }
    if (_tnbStopTypeRequiresDetail(type) && detail.trim().isEmpty) {
      return "Le détail d'arrêt est obligatoire.";
    }
    final start = _parseDailyTime(startTime);
    if (start == null) {
      return "L'heure de début est obligatoire.";
    }
    final normalizedEnd = endTime.trim().toLowerCase();
    if (normalizedEnd.isEmpty || normalizedEnd == 'pending') {
      return null;
    }
    final end = _parseDailyTime(endTime);
    final durationMinutes = (end == null)
        ? null
        : _durationMinutesInCycle(
            TimeOfDay.fromDateTime(start),
            TimeOfDay.fromDateTime(end),
          );
    if (durationMinutes == null ||
        durationMinutes <= 0 ||
        durationMinutes > _maxCycleMinutes) {
      return "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max).";
    }
    return null;
  }

  void _updateDailyTotalsForModule(
      Map<String, dynamic> data, String modulePrefix, List stops) {
    final totalDowntime = _calculateDowntimeFromStops(stops);
    final operatingTime = (24 * 60 - totalDowntime).clamp(0, 24 * 60);
    data['${modulePrefix}TotalDowntime'] = totalDowntime;
    data['${modulePrefix}OperatingTime'] = operatingTime;
    if (modulePrefix == 'module1') {
      data['T H.A1'] = totalDowntime;
      data['T H.M1'] = operatingTime;
    } else {
      data['T H.A2'] = totalDowntime;
      data['T H.M2'] = operatingTime;
    }
    data['${modulePrefix}Stops'] = stops;
  }

  // Calculate downtime from stops list
  int _calculateDowntimeFromStops(List stops) {
    if (stops.isEmpty) return 0;
    final hasTimeRanges = stops.any((stop) =>
        (stop is Map && stop['startTime'] != null && stop['endTime'] != null) ||
        (stop is Map && stop['start'] != null && stop['end'] != null) ||
        (stop is Map && stop['Début'] != null && stop['Fin'] != null));
    if (hasTimeRanges) {
      final ranges = stops
          .whereType<Map>()
          .map((stop) {
            final startRaw =
                (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '')
                    .toString();
            final endRaw = (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '')
                .toString();
            final start = _parseDailyTime(startRaw);
            final end = _parseDailyTime(endRaw);
            if (start == null || end == null) return null;

            final startMinutes = _toCycleMinutesFromTimeOfDay(
              TimeOfDay.fromDateTime(start),
            );
            final endMinutes = _toCycleMinutesFromTimeOfDay(
              TimeOfDay.fromDateTime(end),
            );
            if (endMinutes <= startMinutes) return null;

            return TimeRange(startMinutes, endMinutes);
          })
          .whereType<TimeRange>()
          .toList();
      return TimeCalculationService.calculateTotalDowntimeMinutes(
        ranges,
        maxMinutes: _maxCycleMinutes,
      );
    }
    return stops
        .map((stop) => _parseDurationToMinutes(stop['duration'] ?? ''))
        .fold(0, (a, b) => a + b)
        .clamp(0, _maxCycleMinutes);
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

  String _calculateTnbCounterEndValue({
    required String startValue,
    required List<dynamic> stops,
    required DateTime reportDate,
  }) {
    final parsedStart = double.tryParse(startValue.replaceAll(',', '.').trim());
    if (parsedStart == null) return '';

    final cycleStart =
        DateTime(reportDate.year, reportDate.month, reportDate.day, 22, 30);
    final cycleEnd = cycleStart.add(const Duration(hours: 24));
    final shifts = _cycleShiftWindows(reportDate);

    var runningValue = parsedStart;
    for (final shift in shifts) {
      final downtime = _calculateTnbDowntimeMinutesInWindow(
        stops: stops,
        windowStart: shift.start,
        windowEnd: shift.end,
        cycleStart: cycleStart,
        cycleEnd: cycleEnd,
      );
      final shiftDurationMinutes = shift.end.difference(shift.start).inMinutes;
      final operatingHours = math.max(0, shiftDurationMinutes - downtime) / 60;
      runningValue += operatingHours;
    }

    return _formatTnbCounterNumber(runningValue);
  }

  List<Map<String, dynamic>> _rebuildTnbCountersWithComputedEndValues({
    required List<dynamic> counters,
    required List<dynamic> stops,
    required DateTime reportDate,
    Map<String, dynamic> shiftSegmentsByCounter = const {},
  }) {
    return counters.map((rawCounter) {
      final counter = rawCounter is Map
          ? Map<String, dynamic>.from(rawCounter)
          : <String, dynamic>{};
      final counterLabel = (counter['poste'] ?? '').toString().trim();
      final storedSegmentsRaw = shiftSegmentsByCounter[counterLabel];
      if (storedSegmentsRaw is List && storedSegmentsRaw.isNotEmpty) {
        final storedSegments = storedSegmentsRaw.whereType<Map>().toList();
        final startValue =
            (storedSegments.first['start'] ?? '').toString().trim();
        final endValue = (storedSegments.last['end'] ?? '').toString().trim();
        counter['start'] = startValue;
        counter['end'] = endValue;
      } else {
        final startValue = (counter['start'] ?? '').toString().trim();
        counter['start'] = startValue;
        counter['end'] = startValue.isEmpty
            ? ''
            : _calculateTnbCounterEndValue(
                startValue: startValue,
                stops: stops,
                reportDate: reportDate,
              );
      }
      return counter;
    }).toList(growable: false);
  }

  // Recalculate totals for Activity TNB reports
  int _parseTripCount(dynamic value) {
    final parsed = int.tryParse((value ?? '').toString().trim());
    return parsed ?? 0;
  }

  int _getTnbTotalVoyagesForSummary({
    required List<Map<String, dynamic>> stockEntries,
    required List<Map<String, dynamic>> trips,
  }) {
    final totalFromStock = stockEntries.fold<int>(
      0,
      (sum, entry) =>
          sum +
          _parseTripCount(entry['gatTrips']) +
          _parseTripCount(entry['terexTrips']),
    );
    if (totalFromStock > 0) {
      return totalFromStock;
    }

    return trips.fold<int>(
      0,
      (sum, entry) => sum + _parseTripCount(entry['tripCount']),
    );
  }

  Map<String, dynamic> _syncTruckTripsFromStockEntries(
      Map<String, dynamic> data) {
    final updatedData = Map<String, dynamic>.from(data);
    final stockEntries =
        (updatedData['stock'] is List) ? List.from(updatedData['stock']) : [];

    final totalGatTrips = stockEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + _parseTripCount(entry is Map ? entry['gatTrips'] : null),
    );
    final totalTerexTrips = stockEntries.fold<int>(
      0,
      (sum, entry) =>
          sum + _parseTripCount(entry is Map ? entry['terexTrips'] : null),
    );

    updatedData['truckTrips'] = [
      {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'truckType': 0,
        'tripCount': totalGatTrips.toString(),
      },
      {
        'id': '${DateTime.now().millisecondsSinceEpoch}_terex',
        'truckType': 1,
        'tripCount': totalTerexTrips.toString(),
      },
    ];

    return updatedData;
  }

  Map<String, dynamic> _recalculateActivityTotals(
    Map<String, dynamic> data, {
    DateTime? reportDate,
  }) {
    final updatedData = Map<String, dynamic>.from(data);
    final effectiveReportDate = reportDate ?? DateTime.now();

    final stops =
        (updatedData['Arrets'] is List) ? List.from(updatedData['Arrets']) : [];
    final rawVibratorCounters = (updatedData['vibrator Counters'] is List)
        ? List.from(updatedData['vibrator Counters'])
        : [];
    final rawLiaisonCounters = (updatedData['liaison Counters'] is List)
        ? List.from(updatedData['liaison Counters'])
        : [];
    final truckTrips = (updatedData['truckTrips'] is List)
        ? List.from(updatedData['truckTrips'])
        : [];
    final shiftSegmentsByCounter = updatedData['tnbShiftCounters'] is Map
        ? Map<String, dynamic>.from(updatedData['tnbShiftCounters'])
        : <String, dynamic>{};

    final vibratorCounters = _rebuildTnbCountersWithComputedEndValues(
      counters: rawVibratorCounters,
      stops: stops,
      reportDate: effectiveReportDate,
      shiftSegmentsByCounter: shiftSegmentsByCounter,
    );
    final liaisonCounters = _rebuildTnbCountersWithComputedEndValues(
      counters: rawLiaisonCounters,
      stops: stops,
      reportDate: effectiveReportDate,
      shiftSegmentsByCounter: shiftSegmentsByCounter,
    );

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
    updatedData['vibrator Counters'] = vibratorCounters;
    updatedData['liaison Counters'] = liaisonCounters;
    updatedData['T Nr.V'] = vibratorCounters.length;
    updatedData['T Nr.L'] = liaisonCounters.length;
    updatedData['T Nr.C'] = vibratorCounters.length + liaisonCounters.length;
    final totalTripsFromList = truckTrips.fold<int>(
      0,
      (sum, entry) =>
          sum + _parseTripCount(entry is Map ? entry['tripCount'] : null),
    );
    updatedData['T Nr.T'] = totalTripsFromList;

    return updatedData;
  }

  String _getPosteString(dynamic posteIndex, AppLocalizations l10n) {
    if (posteIndex == null) return '-';
    final normalizedPoste = _normalizePosteIndex(posteIndex);
    if (normalizedPoste != null) {
      switch (normalizedPoste) {
        case 0:
          return AppLocalizations.of(context)!.poste3eme;
        case 1:
          return AppLocalizations.of(context)!.poste1er;
        case 2:
          return AppLocalizations.of(context)!.poste2eme;
      }
    }
    if (posteIndex is String && posteIndex.trim().isNotEmpty) {
      return posteIndex.trim();
    }
    return '-';
  }

  String _getParkString(dynamic parkIndex, AppLocalizations l10n) {
    if (parkIndex == null) return '-';
    switch (_normalizeParkIndex(parkIndex)) {
      case 0:
        return AppLocalizations.of(context)!.park1;
      case 1:
        return AppLocalizations.of(context)!.park2;
      case 2:
        return AppLocalizations.of(context)!.park3;
      default:
        return '-';
    }
  }

  String _getStockTypeString(dynamic typeIndex, AppLocalizations l10n) {
    if (typeIndex == null) return '-';
    switch (_normalizeStockTypeIndex(typeIndex)) {
      case 0:
        return AppLocalizations.of(context)!.stockTypeNormal;
      case 1:
        return AppLocalizations.of(context)!.stockTypeOceane;
      case 2:
        return AppLocalizations.of(context)!.stockTypePb30;
      default:
        return '-';
    }
  }

  int? _normalizePosteIndex(dynamic posteValue) {
    if (posteValue == null) return null;
    final raw = posteValue.toString().trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (raw == '0' || raw.contains('3')) return 0;
    if (raw == '1' || raw.contains('1')) return 1;
    if (raw == '2' || raw.contains('2')) return 2;
    return null;
  }

  int? _normalizeParkIndex(dynamic parkValue) {
    if (parkValue == null) return null;
    final raw = parkValue.toString().trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (raw == '0' || raw.contains('park 1')) return 0;
    if (raw == '1' || raw.contains('park 2')) return 1;
    if (raw == '2' || raw.contains('park 3')) return 2;
    return null;
  }

  int? _normalizeStockTypeIndex(dynamic typeValue) {
    if (typeValue == null) return null;
    final raw = typeValue.toString().trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (raw == '0' || raw.contains('normal')) return 0;
    if (raw == '1' || raw.contains('oceane')) return 1;
    if (raw == '2' || raw.contains('pb30')) return 2;
    return null;
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
            width: 130,
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
      return Text(AppLocalizations.of(context)!.noDailyData);
    }

    final module1Stops =
        (data['module1Stops'] is List) ? List.from(data['module1Stops']) : [];
    final module2Stops =
        (data['module2Stops'] is List) ? List.from(data['module2Stops']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['secteur'] != null)
          Text('${AppLocalizations.of(context)!.sector}: ${data['secteur']}'),
        if (data['rapportNo'] != null)
          Text(
              '${AppLocalizations.of(context)!.reportNo}: ${data['rapportNo']}'),
        if (data['machineEngins'] != null)
          Text(
              '${AppLocalizations.of(context)!.machinesEquipment}: ${data['machineEngins']}'),
        const SizedBox(height: 16),
        // Module 1 Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.module1Label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    '${AppLocalizations.of(context)!.operatingTime}: ${_formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    '${AppLocalizations.of(context)!.stopTime}: ${_formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module1Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.stopsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ..._buildDailyModuleStops(module1Stops, leftPadding: 16),
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
                Text(AppLocalizations.of(context)!.module2Label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    '${AppLocalizations.of(context)!.operatingTime}: ${_formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    '${AppLocalizations.of(context)!.stopTime}: ${_formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module2Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(AppLocalizations.of(context)!.stopsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ..._buildDailyModuleStops(module2Stops, leftPadding: 16),
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
      return Text(AppLocalizations.of(context)!.noEquipmentStopped);
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
                Text(AppLocalizations.of(context)!.reportDateLabel,
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
                Text(AppLocalizations.of(context)!.stoppedEquipment,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (equipmentList.isEmpty)
                  Text(AppLocalizations.of(context)!.noEquipmentAdded,
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
                          Text(
                              AppLocalizations.of(context)!
                                  .equipmentLabelWithIndex(index + 1),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(l10n
                              .typeParam(equipment['equipmentType'] ?? '-')),
                          Text(AppLocalizations.of(context)!
                              .reasonParam(equipment['Reason'] ?? '-')),
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
      return Text(AppLocalizations.of(context)!.noTruckTrackingData);
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
                Text(AppLocalizations.of(context)!.infoLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                _buildInfoRowSimple('Mine', data['mine'] ?? '-'),
                _buildInfoRowSimple('Zone', data['zone'] ?? '-'),
                _buildInfoRowSimple('Sortie', data['sortie'] ?? '-'),
                _buildInfoRowSimple(
                    'Poste', data['poste'] ?? data['selectedPoste'] ?? '-'),
                _buildInfoRowSimple('Distance', data['distance'] ?? '-'),
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
                Text(AppLocalizations.of(context)!.camionsLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (truckData.isEmpty)
                  Text(AppLocalizations.of(context)!.noTrucksAdded),
                if (truckData.isNotEmpty)
                  ...truckData.map((truck) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              AppLocalizations.of(context)!
                                  .truckParam(truck['truckNumber'] ?? '-'),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(AppLocalizations.of(context)!
                              .driverParam(truck['driver1'] ?? '-')),
                          if (truck['counts'] != null &&
                              (truck['counts'] is List) &&
                              (truck['counts'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(AppLocalizations.of(context)!.tripsWithColon,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            ...List.generate((truck['counts'] as List).length,
                                (index) {
                              final count = (truck['counts'] as List)[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context)!
                                        .tripLabelWithIndex(index + 1)),
                                    Text(count['time'] ?? '-'),
                                    const SizedBox(width: 12),
                                    const Text('|'),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            count['equipment'] ?? '-',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (count['productQualityType'] !=
                                              null)
                                            Text(
                                              _resolveQualityLabel(
                                                  count['productQualityType'],
                                                  l10n),
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
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
                    Text(AppLocalizations.of(context)!.tripsSummary,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        'Total de voyages: ${data['totalTrips'] ?? truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).length}'),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.tripsByEquipment,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._buildTripsPerEquipmentSummary(
                        _buildEquipmentCountsMap(truckData, data),
                        _buildEquipmentQualityTrips(truckData, l10n)),
                    const SizedBox(height: 12),
                    Text(
                        '${AppLocalizations.of(context)!.total} ${AppLocalizations.of(context)!.qualityLabel}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._buildQualityTotals(truckData, l10n)
                        .entries
                        .map((e) => Text('${e.key} - ${e.value}')),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Map<String, int> _buildEquipmentCountsMap(
      List truckData, Map<String, dynamic> data) {
    if (data['equipmentTrips'] != null && data['equipmentTrips'] is Map) {
      return Map<String, int>.fromEntries((data['equipmentTrips'] as Map)
          .entries
          .map((e) => MapEntry(
              e.key.toString(), int.tryParse(e.value.toString()) ?? 0)));
    }
    final Map<String, int> equipmentCounts = {};
    final allTrips = truckData
        .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
        .toList();
    for (var trip in allTrips) {
      final eq = trip['equipment'] ?? '-';
      equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
    }
    return equipmentCounts;
  }

  Map<String, Map<String, int>> _buildEquipmentQualityTrips(
      List truckData, AppLocalizations l10n) {
    final Map<String, Map<String, int>> equipmentQualityTrips = {};
    final allTrips = truckData
        .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
        .toList();
    for (var trip in allTrips) {
      final eq =
          trip['equipment'] ?? AppLocalizations.of(context)!.unknownLabel;
      final qualityLabel =
          _resolveQualityLabel(trip['productQualityType'], l10n);
      equipmentQualityTrips.putIfAbsent(eq, () => {});
      equipmentQualityTrips[eq]![qualityLabel] =
          (equipmentQualityTrips[eq]![qualityLabel] ?? 0) + 1;
    }
    return equipmentQualityTrips;
  }

  Map<String, int> _buildQualityTotals(List truckData, AppLocalizations l10n) {
    final Map<String, int> qualityTrips = {};
    final allTrips = truckData
        .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
        .toList();
    for (var trip in allTrips) {
      final qualityLabel =
          _resolveQualityLabel(trip['productQualityType'], l10n);
      qualityTrips[qualityLabel] = (qualityTrips[qualityLabel] ?? 0) + 1;
    }
    return qualityTrips;
  }

  DateTime? _parseTripTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  String? _normalizePosteKey(String? poste) {
    if (poste == null || poste.isEmpty) return null;
    final normalized = poste.toLowerCase();
    if (normalized == '0') return '3';
    if (normalized.contains('3')) return '3';
    if (normalized.contains('1')) return '1';
    if (normalized.contains('2')) return '2';
    return null;
  }

  bool _isTripTimeWithinPoste(String? timeStr, String? posteKey) {
    if (timeStr == null || timeStr.isEmpty || posteKey == null) return false;
    final time = _parseTripTime(timeStr);
    if (time == null) return false;
    final minutes = time.hour * 60 + time.minute;
    const startThird = 22 * 60 + 30;
    const endThird = 6 * 60 + 30;
    const startFirst = 6 * 60 + 30;
    const endFirst = 14 * 60 + 30;
    const startSecond = 14 * 60 + 30;
    const endSecond = 22 * 60 + 30;

    switch (posteKey) {
      case '3':
        return minutes >= startThird || minutes < endThird;
      case '1':
        return minutes >= startFirst && minutes < endFirst;
      case '2':
        return minutes >= startSecond && minutes < endSecond;
      default:
        return false;
    }
  }

  bool _areAllTripTimesWithinPoste(
      List<Map<String, dynamic>> trips, String? posteKey) {
    if (posteKey == null) return false;
    for (final trip in trips) {
      if (!_isTripTimeWithinPoste(trip['time']?.toString(), posteKey)) {
        return false;
      }
    }
    return true;
  }

  void _recalculateTruckSummary(
      Map<String, dynamic> data, AppLocalizations l10n) {
    final truckData =
        (data['truckData'] is List) ? List.from(data['truckData']) : [];
    int totalTrips = 0;
    final Map<String, int> equipmentTrips = {};
    for (final truck in truckData) {
      final counts = truck['counts'] as List?;
      if (counts == null) continue;
      totalTrips += counts.length;
      for (final trip in counts) {
        final eq =
            trip['equipment'] ?? AppLocalizations.of(context)!.unknownLabel;
        equipmentTrips[eq] = (equipmentTrips[eq] ?? 0) + 1;
      }
    }
    data['totalTrips'] = totalTrips;
    data['camionsCount'] = truckData.length;
    data['equipmentTrips'] = equipmentTrips;
  }

  List<Widget> _buildTripsPerEquipmentSummary(Map<String, int> equipmentCounts,
      Map<String, Map<String, int>> equipmentQualityTrips) {
    return equipmentCounts.entries.map((entry) {
      final qualityBreakdown = equipmentQualityTrips[entry.key] ?? {};
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(entry.key)),
            const SizedBox(width: 8),
            Text(entry.value.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: qualityBreakdown.entries
                    .map((q) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${q.key} - ${q.value}',
                              textAlign: TextAlign.right),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _resolveQualityLabel(dynamic value, AppLocalizations l10n) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) {
      return AppLocalizations.of(context)!.unknownLabel;
    }
    final normalized = raw.toUpperCase();
    if (normalized.contains('NORMAL')) {
      return AppLocalizations.of(context)!.normal;
    }
    if (normalized.contains('OCEANE')) {
      return AppLocalizations.of(context)!.oceane;
    }
    if (normalized.contains('PB30')) {
      return AppLocalizations.of(context)!.pb30;
    }
    return raw;
  }

  Widget _buildR0ReportAdditionalData(
      Map<String, dynamic> data, AppLocalizations l10n) {
    if (data.isEmpty) return Text(AppLocalizations.of(context)!.noR0Data);

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
                Text(AppLocalizations.of(context)!.infoOibEeLabel,
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
                  _buildSummaryItem(
                      AppLocalizations.of(context)!.carryOver,
                      AppLocalizations.of(context)!
                          .carriedOverFrom(data['carryOverFrom'])),
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
                  Text(AppLocalizations.of(context)!.counter,
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
                  Text(AppLocalizations.of(context)!.arretsLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  ...List.from(data['Arrets']).map((arret) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_formatDailyStopLine(arret),
                                style: TextStyle(
                                    color: arret['CarryOver'] == true
                                        ? Colors.orange
                                        : null,
                                    fontWeight: arret['CarryOver'] == true
                                        ? FontWeight.bold
                                        : null)),
                            if (arret['CarryOver'] == true)
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Text(
                                    "(${AppLocalizations.of(context)!.carryOver})",
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
                  Text(AppLocalizations.of(context)!.exploitationLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem('H.M', data['exploitation']['H.M'] ?? ''),
                  _buildSummaryItem('H.A', data['exploitation']['H.A'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.metrageFore,
                      data['exploitation']['metrage fore'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.nrTrousFores,
                      data['exploitation']['Nr de Trous Fores'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.nrVoyages,
                      data['exploitation']['Nr de Voyages'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.m3Decapage,
                      data['exploitation']['M³ Decapages'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.tonnageLabel,
                      data['exploitation']['Tonnage'] ?? ''),
                  _buildSummaryItem(AppLocalizations.of(context)!.nombreTKU,
                      data['exploitation']['Nombre T.K.U'] ?? ''),
                  _buildSummaryItem(
                      AppLocalizations.of(context)!.rendementLabel,
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
                  Text(AppLocalizations.of(context)!.workDistributionLabel,
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
                  Text(AppLocalizations.of(context)!.personnelLabel,
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
                  Text(AppLocalizations.of(context)!.consommationLabel,
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
      await _reportRepository.updateReport(carryOverResult.baseReport);
      for (final id in carryOverResult.deleteIds) {
        await _reportRepository.deleteReport(id);
      }
      for (final report in carryOverResult.updateReports) {
        await _reportRepository.updateReport(report);
      }
      for (final report in carryOverResult.insertReports) {
        await _reportRepository.insertReport(report);
      }
      await _loadReports();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.reportUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdatingReport)),
      );
    }
  }

  void _applyUpdatedReportDataToDialog(
    Map<String, dynamic> currentData,
    Report updatedReport,
  ) {
    final refreshedData = updatedReport.additionalData ?? {};
    currentData
      ..clear()
      ..addAll(refreshedData);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedReportIds.length} selected'
              : _selectedPosteFilter != null
                  ? '${AppLocalizations.of(context)!.reports} - $_selectedPosteFilter'
                  : AppLocalizations.of(context)!.reports,
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAllFilteredReports,
              tooltip: 'Select all',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  _selectedReportIds.isEmpty ? null : _deleteSelectedReports,
              tooltip: AppLocalizations.of(context)!.delete,
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSelectionMode,
              tooltip: AppLocalizations.of(context)!.cancel,
            ),
          ] else ...[
            // Poste Filter Dropdown
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: DropdownButton<String>(
                value: _selectedPosteFilter,
                hint: Text(AppLocalizations.of(context)!.allPostes,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                dropdownColor: Theme.of(context).colorScheme.surface,
                underline: Container(),
                icon: Icon(Icons.filter_list,
                    color: Theme.of(context).colorScheme.onPrimary),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.allPostes),
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
                tooltip: AppLocalizations.of(context)!.clearFilter,
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadReports,
              tooltip: AppLocalizations.of(context)!.refresh,
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: 'Select reports',
            ),
          ],
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
                                ? AppLocalizations.of(context)!
                                    .noReportsFoundForPoste(
                                        _selectedPosteFilter!)
                                : AppLocalizations.of(context)!.noDataMessage,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (_selectedPosteFilter != null) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => _onPosteFilterChanged(null),
                              child: Text(
                                  AppLocalizations.of(context)!.seeAllReports),
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
                                  AppLocalizations.of(context)!.reportsFound(
                                      _filteredReports.length,
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
                                final isSentToSheets = report.isSentToSheets;
                                // Logic to determine title
                                String title = report.description;
                                final typeLower = report.type.toLowerCase();
                                if (typeLower == 'activity tnb') {
                                  title = AppLocalizations.of(context)!
                                      .activityReport;
                                } else if (typeLower == 'daily tsud') {
                                  title =
                                      AppLocalizations.of(context)!.dailyReport;
                                } else if (typeLower == 'suivi camion') {
                                  title = AppLocalizations.of(context)!
                                      .truckTracking;
                                } else if (typeLower ==
                                    'machine/engin arrêtés') {
                                  title = AppLocalizations.of(context)!
                                      .machinesEquipmentStoppedTitleShort;
                                } else if (typeLower == 'r0') {
                                  title =
                                      AppLocalizations.of(context)!.r0Report;
                                }

                                return Slidable(
                                  key: ValueKey(report.id ?? index),
                                  startActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.22,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) {
                                          if (isSentToSheets) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(l10n
                                                    .reportAlreadySentToSheets),
                                              ),
                                            );
                                            return;
                                          }
                                          _sendReportToSheets(report);
                                        },
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        foregroundColor: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                        icon: Icons.send,
                                        label: AppLocalizations.of(context)!
                                            .sendToSheets,
                                      ),
                                    ],
                                  ),
                                  child: Opacity(
                                    opacity: isSentToSheets ? 0.6 : 1,
                                    child: Card(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      child: ListTile(
                                        title: Text(title),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${AppLocalizations.of(context)!.type}: ${report.type}'),
                                            Text(
                                                '${AppLocalizations.of(context)!.date}: ${DateFormat('yyyy-MM-dd HH:mm').format(report.date)}'),
                                            Text(
                                                '${AppLocalizations.of(context)!.group}: ${report.group}'),
                                            if (report.additionalData != null &&
                                                (typeLower == 'suivi camion' ||
                                                    typeLower.contains(
                                                        'chargeuse') ||
                                                    typeLower
                                                        .contains('pelle') ||
                                                    report.additionalData!
                                                        .containsKey(
                                                            'truckData'))) ...[
                                              const SizedBox(height: 4),
                                              if (report.additionalData![
                                                      'mine'] !=
                                                  null)
                                                Text(
                                                    '${AppLocalizations.of(context)!.mine}: ${report.additionalData!['mine']} ${report.additionalData!['zone'] ?? ''}'),
                                              if (report.additionalData![
                                                      'totalTrips'] !=
                                                  null)
                                                Text(
                                                    '${AppLocalizations.of(context)!.totalVoyages}: ${report.additionalData!['totalTrips']}'),
                                            ],
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isSelectionMode)
                                              Checkbox(
                                                value: report.id != null &&
                                                    _selectedReportIds
                                                        .contains(report.id),
                                                onChanged: (_) =>
                                                    _toggleReportSelection(
                                                        report),
                                              ),
                                            // Popup menu for additional actions
                                            if (!_isSelectionMode)
                                              PopupMenuButton<String>(
                                                icon: const Icon(
                                                    Icons.more_horiz,
                                                    size: 20),
                                                padding: EdgeInsets.zero,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                position:
                                                    PopupMenuPosition.under,
                                                itemBuilder:
                                                    (BuildContext context) => [
                                                  PopupMenuItem<String>(
                                                    value: 'delete',
                                                    height: 36,
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                            Icons
                                                                .delete_outline,
                                                            size: 18,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .error),
                                                        const SizedBox(
                                                            width: 8),
                                                        Text(
                                                          AppLocalizations.of(
                                                                  context)!
                                                              .delete,
                                                          style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
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
                                                        title: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .confirmDelete),
                                                        content: Text(
                                                            AppLocalizations.of(
                                                                    context)!
                                                                .confirmDelete),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    context),
                                                            child: Text(
                                                                AppLocalizations.of(
                                                                        context)!
                                                                    .cancel),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                  context);
                                                              _deleteReport(
                                                                  report);
                                                            },
                                                            child: Text(
                                                                AppLocalizations.of(
                                                                        context)!
                                                                    .delete),
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
                                          if (_isSelectionMode) {
                                            _toggleReportSelection(report);
                                            return;
                                          }
                                          _showReportDetails(report);
                                        },
                                      ),
                                    ),
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
                          AppLocalizations.of(context)!.editDailyTsud,
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
                  child: DefaultTabController(
                    initialIndex: _currentShiftTabIndex(),
                    length: 4,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: TabBar(
                            isScrollable: true,
                            tabs: [
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.thirdPoste),
                              Tab(
                                  text:
                                      AppLocalizations.of(context)!.firstPoste),
                              Tab(
                                  text: AppLocalizations.of(context)!
                                      .secondPoste),
                              Tab(text: AppLocalizations.of(context)!.global),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildDailyEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '3',
                              ),
                              _buildDailyEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '1',
                              ),
                              _buildDailyEditorTabContent(
                                report: report,
                                data: data,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                                shiftKey: '2',
                              ),
                              _buildTsudReportDetailsPage(
                                data: data,
                                reportDate: report.date,
                                l10n: l10n,
                                report: report,
                              ),
                            ],
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

  Widget _buildDailyEditorTabContent({
    required Report report,
    required Map<String, dynamic> data,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
    String? shiftKey,
  }) {
    final module1Stops = (data['module1Stops'] is List)
        ? (shiftKey == null
            ? List.from(data['module1Stops'])
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList()
            : _filterTnbStopsForShift(
                List.from(data['module1Stops']),
                report.date,
                shiftKey,
              ))
        : <Map<String, dynamic>>[];
    final module2Stops = (data['module2Stops'] is List)
        ? (shiftKey == null
            ? List.from(data['module2Stops'])
                .whereType<Map>()
                .map(Map<String, dynamic>.from)
                .toList()
            : _filterTnbStopsForShift(
                List.from(data['module2Stops']),
                report.date,
                shiftKey,
              ))
        : <Map<String, dynamic>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.infoLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  _buildEditableField(
                    context: context,
                    label: AppLocalizations.of(context)!.description,
                    value: report.description,
                    isEditable: false,
                    onSave: (value) async {},
                  ),
                  const SizedBox(height: 8),
                  _buildEditableDateField(
                    context: context,
                    label: AppLocalizations.of(context)!.date,
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
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.module1Label,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddStopFromModuleCard(
                          report: report,
                          data: data,
                          modulePrefix: 'module1',
                          shiftKey: shiftKey,
                          setDialogState: setDialogState,
                          scaffoldMessenger: scaffoldMessenger,
                          l10n: l10n,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.ajButton),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (module1Stops.isNotEmpty)
                    ...module1Stops.asMap().entries.map((entry) {
                      final stop = Map<String, dynamic>.from(entry.value);
                      final sourceIndex = _sourceStopIndex(stop, entry.key);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            _formatDailyModuleStopTitle(stop, entry.key + 1),
                          ),
                          subtitle: Text(_formatDailyModuleStopTimeline(stop)),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Actions arrêt',
                            onSelected: (value) async {
                              await _handleDailyModuleStopCardAction(
                                action: value,
                                report: report,
                                data: data,
                                modulePrefix: 'module1',
                                shiftKey: shiftKey,
                                sourceIndex: sourceIndex,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                              );
                            },
                            itemBuilder: (context) {
                              final isPending = _isPendingStop(stop);
                              return [
                                if (isPending)
                                  const PopupMenuItem<String>(
                                    value: 'end',
                                    child: _StopActionMenuItem(
                                      icon: Icons.stop_circle_outlined,
                                      label: 'Terminer',
                                      iconColor: AppColors.success,
                                    ),
                                  ),
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: _StopActionMenuItem(
                                    icon: Icons.edit_outlined,
                                    label: AppLocalizations.of(context)!
                                        .modifyLabel,
                                    iconColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: _StopActionMenuItem(
                                    icon: Icons.delete_outline,
                                    label: AppLocalizations.of(context)!.delete,
                                    iconColor: AppColors.error,
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                      );
                    }),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.module2Label,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showAddStopFromModuleCard(
                          report: report,
                          data: data,
                          modulePrefix: 'module2',
                          shiftKey: shiftKey,
                          setDialogState: setDialogState,
                          scaffoldMessenger: scaffoldMessenger,
                          l10n: l10n,
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)!.ajButton),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (module2Stops.isNotEmpty)
                    ...module2Stops.asMap().entries.map((entry) {
                      final stop = Map<String, dynamic>.from(entry.value);
                      final sourceIndex = _sourceStopIndex(stop, entry.key);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            _formatDailyModuleStopTitle(stop, entry.key + 1),
                          ),
                          subtitle: Text(_formatDailyModuleStopTimeline(stop)),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            tooltip: 'Actions arrêt',
                            onSelected: (value) async {
                              await _handleDailyModuleStopCardAction(
                                action: value,
                                report: report,
                                data: data,
                                modulePrefix: 'module2',
                                shiftKey: shiftKey,
                                sourceIndex: sourceIndex,
                                setDialogState: setDialogState,
                                scaffoldMessenger: scaffoldMessenger,
                                l10n: l10n,
                              );
                            },
                            itemBuilder: (context) {
                              final isPending = _isPendingStop(stop);
                              return [
                                if (isPending)
                                  const PopupMenuItem<String>(
                                    value: 'end',
                                    child: _StopActionMenuItem(
                                      icon: Icons.stop_circle_outlined,
                                      label: 'Terminer',
                                      iconColor: AppColors.success,
                                    ),
                                  ),
                                PopupMenuItem<String>(
                                  value: 'edit',
                                  child: _StopActionMenuItem(
                                    icon: Icons.edit_outlined,
                                    label: AppLocalizations.of(context)!
                                        .modifyLabel,
                                    iconColor:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: _StopActionMenuItem(
                                    icon: Icons.delete_outline,
                                    label: AppLocalizations.of(context)!.delete,
                                    iconColor: AppColors.error,
                                  ),
                                ),
                              ];
                            },
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTnbStockManagementCard(
            report,
            data,
            setDialogState,
            scaffoldMessenger,
            l10n,
            shiftKey: shiftKey,
          ),
        ],
      ),
    );
  }

  Future<void> _handleDailyModuleStopCardAction({
    required String action,
    required Report report,
    required Map<String, dynamic> data,
    required String modulePrefix,
    String? shiftKey,
    required int sourceIndex,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
  }) async {
    if (data['${modulePrefix}Stops'] is! List) return;
    final stops = List.from(data['${modulePrefix}Stops'] as List);
    if (sourceIndex < 0 || sourceIndex >= stops.length) return;

    if (action == 'end') {
      await _endPendingDailyStopForModule(
        report,
        data,
        modulePrefix,
        stops,
        sourceIndex,
        setDialogState,
        setDialogState,
        scaffoldMessenger,
        l10n,
        (_) {},
      );
      await _persistDailyModuleStopsChanges(
        report: report,
        data: data,
        setDialogState: setDialogState,
        scaffoldMessenger: scaffoldMessenger,
        l10n: l10n,
      );
      return;
    }

    if (action == 'edit') {
      await _showEditStopDialogForModule(
        report,
        data,
        modulePrefix,
        stops,
        sourceIndex,
        shiftKey,
        setDialogState,
        setDialogState,
        scaffoldMessenger,
        l10n,
        (_) {},
      );
      await _persistDailyModuleStopsChanges(
        report: report,
        data: data,
        setDialogState: setDialogState,
        scaffoldMessenger: scaffoldMessenger,
        l10n: l10n,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteStopTitle),
        content: Text(AppLocalizations.of(context)!.deleteStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final removedStop = stops[sourceIndex] is Map
        ? Map<String, dynamic>.from(stops[sourceIndex])
        : <String, dynamic>{};
    stops.removeAt(sourceIndex);
    data['${modulePrefix}Stops'] = stops;
    _deleteMirroredDailyStopIfLinked(data, modulePrefix, removedStop);
    _deleteMirroredDailyStopByTypeFallback(data, modulePrefix, removedStop);
    _updateDailyTotalsForModule(data, modulePrefix, stops);
    setDialogState(() {});
    await _persistDailyModuleStopsChanges(
      report: report,
      data: data,
      setDialogState: setDialogState,
      scaffoldMessenger: scaffoldMessenger,
      l10n: l10n,
    );
  }

  Future<void> _persistDailyModuleStopsChanges({
    required Report report,
    required Map<String, dynamic> data,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
  }) async {
    final updatedReport = Report(
      id: report.id,
      description: report.description,
      type: report.type,
      group: report.group,
      date: report.date,
      additionalData: Map<String, dynamic>.from(data),
    );
    _applyUpdatedReportDataToDialog(data, updatedReport);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    setDialogState(() {});
  }

  Future<void> _showAddStopFromModuleCard({
    required Report report,
    required Map<String, dynamic> data,
    required String modulePrefix,
    String? shiftKey,
    required StateSetter setDialogState,
    required ScaffoldMessengerState scaffoldMessenger,
    required AppLocalizations l10n,
  }) async {
    if (data['${modulePrefix}Stops'] is! List) {
      data['${modulePrefix}Stops'] = <Map<String, dynamic>>[];
    }

    final moduleStops = List.from(data['${modulePrefix}Stops'] as List);
    final didAddStop = await _showAddStopDialogForModule(
      report,
      data,
      modulePrefix,
      moduleStops,
      shiftKey,
      setDialogState,
      setDialogState,
      scaffoldMessenger,
      l10n,
      (_) {},
    );

    if (!didAddStop) return;

    data['${modulePrefix}Stops'] = moduleStops;
    final updatedReport = Report(
      id: report.id,
      description: report.description,
      type: report.type,
      group: report.group,
      date: report.date,
      additionalData: Map<String, dynamic>.from(data),
    );
    _applyUpdatedReportDataToDialog(data, updatedReport);
    await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    setDialogState(() {});
  }

  // Add Stop Dialog for Module
  Future<bool> _showAddStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      String? shiftKey,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    bool didAddStop = false;
    _TnbStopCategory? selectedCategory;
    String? selectedType;
    String? selectedLocation;
    String stopDetail = '';
    bool applyToBothModules = true;

    final moduleNumber = _moduleNumberFromPrefix(modulePrefix);
    final locations =
        _dailyModuleLocations[moduleNumber] ?? const <String, String>{};
    const categories = _tsudStopCategories;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedType);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedType);
          final canSubmit = selectedCategory != null &&
              selectedType != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.addStopTitle),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_TnbStopCategory>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ))
                          .toList(),
                      onChanged: (value) => setLocalState(() {
                        selectedCategory = value;
                        selectedType = null;
                        selectedLocation = null;
                        stopDetail = '';
                        applyToBothModules = true;
                      }),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Type d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map((entry) => DropdownMenuItem(
                                  value: entry,
                                  child: Text(entry),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          selectedType = value;
                          selectedLocation = null;
                          stopDetail = '';
                          applyToBothModules = true;
                        }),
                      ),
                    ],
                    if (selectedType != null && requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLocation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: locations.entries
                            .map((entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text('${entry.key} - ${entry.value}'),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          selectedLocation = value;
                          applyToBothModules =
                              _isSharedDailyConveyorLocation(value);
                        }),
                      ),
                    ],
                    if (requiresLocation &&
                        _isSharedDailyConveyorLocation(selectedLocation))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            AppLocalizations.of(context)!.applyToBothModules),
                        subtitle: const Text(
                            'Utiliser pour les pannes convoyeurs partagés (G0/G2).'),
                        value: applyToBothModules,
                        onChanged: (value) =>
                            setLocalState(() => applyToBothModules = value),
                      ),
                    if (requiresDetail) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopDetail,
                        decoration: const InputDecoration(
                          labelText: "Détail de l'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setLocalState(() => stopDetail = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final assignedPoste = _assignedPosteForStopDialog(
                          data,
                          shiftKey: shiftKey ?? report.group,
                        );
                        final selectedTimeResult =
                            await _showStopTimeEntryDialog(
                          titleSuffix: selectedType ?? '',
                          assignedPoste: assignedPoste,
                        );
                        if (selectedTimeResult == null) return;
                        final posteValidation =
                            _validateStopStartInAssignedPoste(
                          selectedTimeResult.start,
                          assignedPoste,
                        );
                        if (posteValidation != null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(posteValidation),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                          return;
                        }

                        final validation = _validateDailyStopFields(
                          category: selectedCategory,
                          type: selectedType,
                          location: selectedLocation,
                          detail: stopDetail,
                          startTime: _formatTimeOfDay(selectedTimeResult.start),
                          endTime: selectedTimeResult.end == null
                              ? 'Pending'
                              : _formatTimeOfDay(selectedTimeResult.end!),
                        );
                        if (validation != null) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text(validation),
                                  backgroundColor: AppColors.error),
                            );
                          }
                          return;
                        }

                        final durationMinutes = selectedTimeResult.end == null
                            ? null
                            : _durationMinutesInCycle(
                                selectedTimeResult.start,
                                selectedTimeResult.end!,
                              );
                        final durationText = durationMinutes == null
                            ? 'Pending'
                            : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
                        final locationLabel = requiresLocation &&
                                selectedLocation != null
                            ? '$selectedLocation - ${locations[selectedLocation] ?? ''}'
                            : '';

                        setState(() {
                          final shouldMirrorByType =
                              _tnbStopTypeAlwaysMirrors(selectedType);
                          final shouldMirrorBySharedLocation =
                              requiresLocation &&
                                  applyToBothModules &&
                                  _isSharedDailyConveyorLocation(
                                      selectedLocation);
                          final shouldMirror = shouldMirrorByType ||
                              shouldMirrorBySharedLocation;
                          final sharedMirrorId =
                              shouldMirror ? const Uuid().v4() : '';
                          final stopEntry = {
                            'id': DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            'category': selectedCategory!.label,
                            'duration': durationText,
                            'nature': selectedType!,
                            'location': locationLabel,
                            'detail': stopDetail.trim(),
                            'stopType': selectedType,
                            'stopLocation': locationLabel,
                            'startTime':
                                _formatTimeOfDay(selectedTimeResult.start),
                            'endTime': selectedTimeResult.end == null
                                ? 'Pending'
                                : _formatTimeOfDay(selectedTimeResult.end!),
                            'Catégorie': selectedCategory!.label,
                          };
                          if (sharedMirrorId.isNotEmpty) {
                            stopEntry['sharedMirrorId'] = sharedMirrorId;
                            stopEntry['sharedSourceModule'] = modulePrefix;
                          }
                          stops.add(stopEntry);

                          if (sharedMirrorId.isNotEmpty) {
                            _upsertMirroredDailyStop(
                              data,
                              modulePrefix,
                              stopEntry,
                              sharedMirrorId,
                            );
                          }

                          _updateDailyTotalsForModule(
                              data, modulePrefix, stops);
                          setDialogState(() {});
                          onTotalDowntimeChanged(
                              data['${modulePrefix}TotalDowntime'] ?? 0);
                        });
                        didAddStop = true;
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.next),
              ),
            ],
          );
        },
      ),
    );
    return didAddStop;
  }

  // Edit Stop Dialog for Module
  Future<void> _showEditStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      int index,
      String? shiftKey,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    final stop = stops[index] is Map
        ? Map<String, dynamic>.from(stops[index])
        : <String, dynamic>{};

    _TnbStopCategory? selectedCategory = _findDailyStopCategory(stop);
    String? selectedType =
        (stop['stopType'] ?? stop['nature'] ?? stop['Arret'] ?? '')
            .toString()
            .trim();
    if (selectedType.isEmpty) selectedType = null;
    String? selectedLocation =
        ((stop['location'] ?? stop['stopLocation'] ?? '') as String)
            .split(' - ')
            .first;
    if (selectedLocation.isEmpty) {
      selectedLocation = null;
    }
    String stopDetail = (stop['detail'] ?? stop['Détail'] ?? '').toString();
    String startTime =
        (stop['startTime'] ?? stop['start'] ?? stop['Début'] ?? '').toString();
    String endTime =
        (stop['endTime'] ?? stop['end'] ?? stop['Fin'] ?? '').toString();
    final existingSharedMirrorId = (stop['sharedMirrorId'] ?? '').toString();
    bool applyToBothModules = existingSharedMirrorId.isNotEmpty ||
        _isSharedDailyConveyorLocation(selectedLocation);

    final moduleNumber = _moduleNumberFromPrefix(modulePrefix);
    final locations =
        _dailyModuleLocations[moduleNumber] ?? const <String, String>{};
    const categories = _tsudStopCategories;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedType);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedType);
          final canSubmit = selectedCategory != null &&
              selectedType != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.editStopTitle),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<_TnbStopCategory>(
                      initialValue: selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ))
                          .toList(),
                      onChanged: (value) => setLocalState(() {
                        selectedCategory = value;
                        selectedType = null;
                        selectedLocation = null;
                        stopDetail = '';
                      }),
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Type d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map((entry) => DropdownMenuItem(
                                  value: entry,
                                  child: Text(entry),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          selectedType = value;
                          selectedLocation = null;
                          stopDetail = '';
                        }),
                      ),
                    ],
                    if (selectedType != null && requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLocation,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: locations.entries
                            .map((entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text('${entry.key} - ${entry.value}'),
                                ))
                            .toList(),
                        onChanged: (value) => setLocalState(() {
                          selectedLocation = value;
                          applyToBothModules =
                              _isSharedDailyConveyorLocation(value);
                        }),
                      ),
                    ],
                    if (requiresLocation &&
                        _isSharedDailyConveyorLocation(selectedLocation))
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            AppLocalizations.of(context)!.applyToBothModules),
                        subtitle: const Text(
                            'Mettre à jour aussi le module miroir lié.'),
                        value: applyToBothModules,
                        onChanged: (value) =>
                            setLocalState(() => applyToBothModules = value),
                      ),
                    if (requiresDetail) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopDetail,
                        decoration: const InputDecoration(
                          labelText: "Détail de l'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) =>
                            setLocalState(() => stopDetail = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final assignedPoste = _assignedPosteForStopDialog(
                          data,
                          shiftKey: shiftKey ?? report.group,
                        );
                        final selectedTimeResult =
                            await _showStopTimeEntryDialog(
                          titleSuffix: selectedType ?? '',
                          initialStart: _parseDailyTime(startTime) != null
                              ? TimeOfDay.fromDateTime(
                                  _parseDailyTime(startTime)!)
                              : null,
                          initialEnd: _parseDailyTime(endTime) != null
                              ? TimeOfDay.fromDateTime(
                                  _parseDailyTime(endTime)!)
                              : null,
                          assignedPoste: assignedPoste,
                        );
                        if (selectedTimeResult == null) return;
                        final posteValidation =
                            _validateStopStartInAssignedPoste(
                          selectedTimeResult.start,
                          assignedPoste,
                        );
                        if (posteValidation != null) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text(posteValidation),
                                  backgroundColor: AppColors.error),
                            );
                          }
                          return;
                        }

                        startTime = _formatTimeOfDay(selectedTimeResult.start);
                        endTime = selectedTimeResult.end == null
                            ? 'Pending'
                            : _formatTimeOfDay(selectedTimeResult.end!);
                        final validation = _validateDailyStopFields(
                          category: selectedCategory,
                          type: selectedType,
                          location: selectedLocation,
                          detail: stopDetail,
                          startTime: startTime,
                          endTime: endTime,
                        );
                        if (validation != null) {
                          if (mounted) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text(validation),
                                  backgroundColor: AppColors.error),
                            );
                          }
                          return;
                        }
                        final durationMinutes =
                            _durationMinutesFromTimeStrings(startTime, endTime);
                        final durationText = durationMinutes == null
                            ? 'Pending'
                            : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
                        final locationLabel = requiresLocation &&
                                selectedLocation != null
                            ? '$selectedLocation - ${locations[selectedLocation] ?? ''}'
                            : '';

                        setState(() {
                          final shouldMirrorByType =
                              _tnbStopTypeAlwaysMirrors(selectedType);
                          final shouldMirrorBySharedLocation =
                              requiresLocation &&
                                  applyToBothModules &&
                                  _isSharedDailyConveyorLocation(
                                      selectedLocation);
                          final shouldMirror = shouldMirrorByType ||
                              shouldMirrorBySharedLocation;
                          final sharedMirrorId = shouldMirror
                              ? (existingSharedMirrorId.isNotEmpty
                                  ? existingSharedMirrorId
                                  : const Uuid().v4())
                              : '';
                          final updatedStop = {
                            'id': stop['id'] ??
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString(),
                            'category': selectedCategory!.label,
                            'duration': durationText,
                            'nature': selectedType!,
                            'location': locationLabel,
                            'detail': stopDetail.trim(),
                            'stopType': selectedType,
                            'stopLocation': locationLabel,
                            'startTime': startTime,
                            'endTime': endTime,
                            'Catégorie': selectedCategory!.label,
                          };
                          if (sharedMirrorId.isNotEmpty) {
                            updatedStop['sharedMirrorId'] = sharedMirrorId;
                            updatedStop['sharedSourceModule'] = modulePrefix;
                          }
                          stops[index] = updatedStop;

                          if (sharedMirrorId.isNotEmpty) {
                            _upsertMirroredDailyStop(
                              data,
                              modulePrefix,
                              updatedStop,
                              sharedMirrorId,
                              legacyMatchStop: stop,
                            );
                          } else if (existingSharedMirrorId.isNotEmpty) {
                            _deleteMirroredDailyStopIfLinked(
                              data,
                              modulePrefix,
                              {'sharedMirrorId': existingSharedMirrorId},
                            );
                          }
                          _updateDailyTotalsForModule(
                              data, modulePrefix, stops);
                          setDialogState(() {});
                          onTotalDowntimeChanged(
                              data['${modulePrefix}TotalDowntime'] ?? 0);
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.modifyLabel),
              ),
            ],
          );
        },
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
                                  label: AppLocalizations.of(context)!
                                      .equipmentLabel,
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
                                  label:
                                      AppLocalizations.of(context)!.operation,
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
                                  label: AppLocalizations.of(context)!
                                      .qualityTypeLabel,
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
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: AppLocalizations.of(context)!.distance,
                                  value: data['distance'] ?? '',
                                  isEditable: true,
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['distance'] = value;
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
                                        AppLocalizations.of(context)!
                                            .trucksTitle,
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
                                      label: Text(AppLocalizations.of(context)!
                                          .ajButton),
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
                                                '${AppLocalizations.of(context)!.driverLabel}: ${truck['driver1'] ?? '-'}'),
                                            if (truck['counts'] is List &&
                                                (truck['counts'] as List)
                                                    .isNotEmpty)
                                              Text(AppLocalizations.of(context)!
                                                  .tripsCountLabel(
                                                      (truck['counts'] as List)
                                                          .length)),
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
                                              tooltip:
                                                  AppLocalizations.of(context)!
                                                      .editTruckTitle,
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
                                              tooltip:
                                                  AppLocalizations.of(context)!
                                                      .deleteTruckTitle,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noTrucksAdded,
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
    _sortTripCountsByTime(counts);

    // Controllers
    final driverController = TextEditingController(text: driver1);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void showTripDialog({Map<String, dynamic>? trip, int? tripIndex}) {
            final isEditingTrip = trip != null;
            final timeController =
                TextEditingController(text: trip?['time'] ?? '');
            final initialTime = _parseTripTime(trip?['time']);
            DateTime selectedTripTime = initialTime ?? DateTime.now();
            String? selectedEquipment = trip?['equipment'];
            String? selectedQuality = trip?['productQualityType'];
            final qualityOptions = <String, String>{
              'QualiteType.normal': AppLocalizations.of(context)!.normal,
              'QualiteType.oceane': AppLocalizations.of(context)!.oceane,
              'QualiteType.pb30': AppLocalizations.of(context)!.pb30,
            };

            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setTripState) => AlertDialog(
                  title: Text(isEditingTrip
                      ? AppLocalizations.of(context)!
                          .editLabel(AppLocalizations.of(context)!.tripLabel)
                      : AppLocalizations.of(context)!.addButton),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(AppLocalizations.of(context)!.tripTime,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TimePickerSpinner(
                          is24HourMode: true,
                          isShowSeconds: false,
                          normalTextStyle: TextStyle(
                            fontSize: 18,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          highlightedTextStyle: TextStyle(
                            fontSize: 24,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.equipmentLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: 'Chargeuse 992K',
                                child: Text(
                                    AppLocalizations.of(context)!.loader992k)),
                            DropdownMenuItem(
                                value: 'Chargeuse 994H',
                                child: Text(
                                    AppLocalizations.of(context)!.loader994h)),
                            DropdownMenuItem(
                                value: 'Pelle Hy',
                                child: Text(AppLocalizations.of(context)!
                                    .hydraulicShovel)),
                            DropdownMenuItem(
                                value: 'Pelle B1',
                                child: Text(AppLocalizations.of(context)!
                                    .electricShovelB1)),
                          ],
                          onChanged: (value) => setTripState(() {
                            selectedEquipment = value;
                          }),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: selectedQuality,
                          decoration: InputDecoration(
                            labelText:
                                AppLocalizations.of(context)!.qualityLabel,
                            border: const OutlineInputBorder(),
                          ),
                          items: qualityOptions.entries
                              .map((entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ))
                              .toList(),
                          onChanged: (value) => setTripState(() {
                            selectedQuality = value;
                          }),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        if (timeController.text.isNotEmpty &&
                            selectedEquipment != null) {
                          final posteKey = _normalizePosteKey(
                              data['selectedPoste'] ??
                                  data['poste'] ??
                                  data['posteSelected']);
                          if (posteKey == null) {
                            scaffoldMessenger.showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .pleaseSelectPoste),
                                backgroundColor: AppColors.error));
                            return;
                          }
                          if (!_isTripTimeWithinPoste(
                              timeController.text, posteKey)) {
                            scaffoldMessenger.showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .invalidStopStartTimeForPoste),
                                backgroundColor: AppColors.error));
                            return;
                          }
                          final updatedTrip = {
                            'time': timeController.text,
                            'equipment': selectedEquipment,
                            if (selectedQuality != null)
                              'productQualityType': selectedQuality,
                          };
                          setState(() {
                            if (isEditingTrip && tripIndex != null) {
                              counts[tripIndex] = updatedTrip;
                            } else {
                              counts.add(updatedTrip);
                            }
                            _sortTripCountsByTime(counts);
                          });
                          Navigator.pop(context);
                        }
                      },
                      child: Text(isEditingTrip
                          ? AppLocalizations.of(context)!.save
                          : AppLocalizations.of(context)!.addButton),
                    ),
                  ],
                ),
              ),
            );
          }

          void addTrip() => showTripDialog();

          void viewTrips() {
            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setTripState) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.tripDetails),
                  content: counts.isEmpty
                      ? Text(AppLocalizations.of(context)!.noTripsAdded)
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
                                      title: Text(AppLocalizations.of(context)!
                                          .vModule(i + 1)),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${AppLocalizations.of(context)!.tempsLabel}: ${trip['time']}'),
                                          Text(
                                              '${AppLocalizations.of(context)!.equipmentLabel}: ${trip['equipment'] ?? '-'}'),
                                          if (trip['productQualityType'] !=
                                              null)
                                            Text(
                                                '${AppLocalizations.of(context)!.qualityLabel}: ${_resolveQualityLabel(trip['productQualityType'], l10n)}'),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit,
                                                size: 18),
                                            onPressed: () {
                                              Navigator.pop(context);
                                              showTripDialog(
                                                  trip: trip, tripIndex: i);
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete,
                                                color: Colors.red),
                                            onPressed: () {
                                              setTripState(() {
                                                counts.removeAt(i);
                                                _sortTripCountsByTime(counts);
                                              });
                                              setState(() {});
                                            },
                                          ),
                                        ],
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
                      child: Text(AppLocalizations.of(context)!.close),
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
                                ? AppLocalizations.of(context)!.editTruckTitle
                                : AppLocalizations.of(context)!.newTruckTitle,
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
                          Text(AppLocalizations.of(context)!.selectTruckLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: predefinedTrucks.contains(truckNumber)
                                ? truckNumber
                                : null,
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(context)!.truckLabel,
                              border: const OutlineInputBorder(),
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
                          Text(AppLocalizations.of(context)!.driverInfoLabel,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextField(
                            controller: driverController,
                            decoration: InputDecoration(
                              labelText:
                                  AppLocalizations.of(context)!.driverLabel,
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
                                  label: Text(
                                      AppLocalizations.of(context)!.addTrip),
                                  onPressed: addTrip,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list),
                                  label: Text(
                                      AppLocalizations.of(context)!.viewTrips),
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
                          child: Text(AppLocalizations.of(context)!.cancel),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (truckNumber.isNotEmpty && driver1.isNotEmpty) {
                              final posteKey = _normalizePosteKey(
                                  data['selectedPoste'] ??
                                      data['poste'] ??
                                      data['posteSelected']);
                              if (posteKey == null) {
                                scaffoldMessenger.showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .pleaseSelectPoste),
                                    backgroundColor: AppColors.error));
                                return;
                              }
                              if (!_areAllTripTimesWithinPoste(
                                  counts, posteKey)) {
                                scaffoldMessenger.showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .invalidStopStartTimeForPoste),
                                    backgroundColor: AppColors.error));
                                return;
                              }
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

                              _recalculateTruckSummary(updatedData, l10n);

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
                          child: Text(AppLocalizations.of(context)!.save),
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
        title: Text(AppLocalizations.of(context)!.deleteTruckTitle),
        content: Text(AppLocalizations.of(context)!.deleteTruckConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['truckData'] as List).removeAt(index);
              _recalculateTruckSummary(updatedData, l10n);

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
            child: Text(AppLocalizations.of(context)!.delete),
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
                          AppLocalizations.of(context)!.editR0Title,
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
                                  AppLocalizations.of(context)!.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label:
                                      AppLocalizations.of(context)!.description,
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
                                  label: AppLocalizations.of(context)!.date,
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
                                        label: Text(
                                            AppLocalizations.of(context)!
                                                .addButton),
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
                                                tooltip: AppLocalizations.of(
                                                        context)!
                                                    .editCounter,
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
                                                tooltip: AppLocalizations.of(
                                                        context)!
                                                    .deleteCounterTooltip,
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
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .counter),
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
                                          tooltip: AppLocalizations.of(context)!
                                              .editCounterTooltip,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                        AppLocalizations.of(context)!
                                            .noCountersAdded,
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
                                      label: Text(AppLocalizations.of(context)!
                                          .addButton),
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
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .stopIndex(index + 1)),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(_formatDailyStopLine(arret)),
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
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noStopsAdded,
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
                                      AppLocalizations.of(context)!.metrageFore,
                                      data['exploitation']['metrage fore'] ??
                                          ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!
                                          .nrTrousFores,
                                      data['exploitation']
                                              ['Nr de Trous Fores'] ??
                                          ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!.nrVoyages,
                                      data['exploitation']['Nr de Voyages'] ??
                                          ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!.m3Decapage,
                                      data['exploitation']['M³ Decapages'] ??
                                          ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!
                                          .tonnageLabel,
                                      data['exploitation']['Tonnage'] ?? ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!.nombreTKU,
                                      data['exploitation']['Nombre T.K.U'] ??
                                          ''),
                                  _buildSummaryItem(
                                      AppLocalizations.of(context)!
                                          .rendementLabel,
                                      data['exploitation']['Rendement %'] ??
                                          data['exploitation']['Rendeme'] ??
                                          ''),
                                ] else
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noExploitationData,
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
                                      label: Text(AppLocalizations.of(context)!
                                          .addButton),
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
                                          title: Text(
                                              AppLocalizations.of(context)!
                                                  .workLabel(index + 1)),
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
                                        title: Text(
                                            AppLocalizations.of(context)!
                                                .workDistributionLabel),
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
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noPersonnelData,
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
                                  Text(
                                      AppLocalizations.of(context)!
                                          .noConsumptionData,
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
          title: Text(AppLocalizations.of(context)!.addCounterTitle),
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
                          ? TextEditingController(
                              text: AppLocalizations.of(context)!.defautLabel)
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
                      Text(AppLocalizations.of(context)!.defautLabel,
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
                          ? TextEditingController(
                              text: AppLocalizations.of(context)!.defautLabel)
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
                      Text(AppLocalizations.of(context)!.defautLabel,
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
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.addButton),
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
          title: Text(AppLocalizations.of(context)!.editCounterTitle),
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
                          ? TextEditingController(
                              text: AppLocalizations.of(context)!.defautLabel)
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
                      Text(AppLocalizations.of(context)!.defautLabel,
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
                          ? TextEditingController(
                              text: AppLocalizations.of(context)!.defautLabel)
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
                      Text(AppLocalizations.of(context)!.defautLabel,
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
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
        title: Text(AppLocalizations.of(context)!.deleteCounterTitle),
        content: Text(AppLocalizations.of(context)!.deleteCounterConfirm),
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
            child: Text(AppLocalizations.of(context)!.delete),
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
                      labelText: AppLocalizations.of(context)!.category,
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
                      labelText:
                          AppLocalizations.of(context)!.selectStopTypeStep,
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
              Text(
                  '${AppLocalizations.of(context)!.category}: $selectedCategory'),
              Text('${AppLocalizations.of(context)!.type}: $selectedType'),
              const SizedBox(height: 16),
              ListTile(
                title: Text(AppLocalizations.of(context)!.startTimeLabel),
                subtitle: Text(startTime.isEmpty
                    ? AppLocalizations.of(context)!.selectTimeTitle
                    : startTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title:
                            Text(AppLocalizations.of(context)!.selectTimeTitle),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('start_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            highlightedTextStyle: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
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
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: Text(AppLocalizations.of(context)!.okButton),
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
                title: Text(AppLocalizations.of(context)!.endTimeLabel),
                subtitle: Text(endTime.isEmpty
                    ? AppLocalizations.of(context)!.selectTimeTitle
                    : endTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title:
                            Text(AppLocalizations.of(context)!.selectTimeTitle),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('end_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: TextStyle(
                              fontSize: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            highlightedTextStyle: TextStyle(
                              fontSize: 24,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
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
                            child: Text(AppLocalizations.of(context)!.cancel),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: Text(AppLocalizations.of(context)!.okButton),
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
              Text(AppLocalizations.of(context)!.selectCategoryStep,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 1) ...[
              Text(AppLocalizations.of(context)!.selectStopTypeStep,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 2) ...[
              Text(AppLocalizations.of(context)!.enterDetailsStep,
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
                    child: Text(AppLocalizations.of(context)!.previous),
                  ),
                if ((step == 0 && selectedCategory != null) ||
                    (step == 1 && selectedType != null))
                  ElevatedButton(
                    onPressed: () {
                      setDialogState(() => step++);
                    },
                    child: Text(AppLocalizations.of(context)!.next),
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
                    child: Text(AppLocalizations.of(context)!.finishButton),
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
        title: Text(AppLocalizations.of(context)!.addStopTitle),
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
      _sortArretsByStartTime(data['Arrets'] as List);

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
        title: Text(AppLocalizations.of(context)!.editStopTitle),
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
      _sortArretsByStartTime(data['Arrets'] as List);

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
        title: Text(AppLocalizations.of(context)!.deleteStopTitle),
        content: Text(AppLocalizations.of(context)!.deleteStopConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.delete),
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
          title: Text(AppLocalizations.of(context)!.editExploitationTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.hmLabel,
                    helperText:
                        AppLocalizations.of(context)!.calculatedAutomatically,
                  ),
                  controller: hmController,
                  enabled: false, // Read-only
                  style: const TextStyle(color: Colors.grey),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.haLabel,
                    helperText:
                        AppLocalizations.of(context)!.calculatedAutomatically,
                  ),
                  controller: haController,
                  enabled: false, // Read-only
                  style: const TextStyle(color: Colors.grey),
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.metrageFore),
                  controller: metrageForeController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.nrTrousFores),
                  controller: nrTrousForesController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.nrVoyages),
                  controller: nrVoyagesController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.m3Decapage),
                  controller: m3DecapageController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.tonnageLabel),
                  controller: tonnageController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.nombreTKU),
                  controller: nombreTKUController,
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.rendementLabel,
                    helperText:
                        AppLocalizations.of(context)!.calculatedAutomatically,
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
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
          title: Text(AppLocalizations.of(context)!.addWorkDistributionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.chantierLabel),
                onChanged: (value) => setState(() => chantier = value),
              ),
              TextField(
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.tempsLabel),
                onChanged: (value) => setState(() => temps = value),
              ),
              TextField(
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.imputationLabel),
                onChanged: (value) => setState(() => imputation = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.add),
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
          title: Text(AppLocalizations.of(context)!.editWorkDistributionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.chantierLabel),
                  controller: chantierController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.tempsLabel),
                  controller: tempsController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.imputationLabel),
                  controller: imputationController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
        title: Text(AppLocalizations.of(context)!.deleteWorkDistributionTitle),
        content:
            Text(AppLocalizations.of(context)!.deleteWorkDistributionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
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
            child: Text(AppLocalizations.of(context)!.delete),
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
          title: Text(AppLocalizations.of(context)!.editPersonnelTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.conductrLabel),
                  controller: conductrController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.graisseurLabel),
                  controller: graisseurController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.matriculesLabel),
                  controller: matriculesController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
          title: Text(AppLocalizations.of(context)!.editConsumptionTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.triconeLabel),
                  controller: triconeController,
                ),
                TextField(
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.gasoilLabel),
                  controller: gasoilController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancel),
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
              child: Text(AppLocalizations.of(context)!.modifyLabel),
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
                                  AppLocalizations.of(context)!.infoLabel,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label:
                                      AppLocalizations.of(context)!.description,
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
                                  label: AppLocalizations.of(context)!.date,
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
                                  label: AppLocalizations.of(context)!.type,
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
                                  label:
                                      AppLocalizations.of(context)!.groupLabel,
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
                                    AppLocalizations.of(context)!
                                        .additionalDataLabel,
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
