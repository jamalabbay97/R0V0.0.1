import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/services/time_calculation_service.dart';
import 'package:r0/theme.dart';
import 'package:r0/widgets/custom_widgets.dart';
import 'package:r0/widgets/spinner_time_picker_dialog.dart';

// --- Enums and Helpers ---
enum Poste { premier, deuxieme, troisieme }

enum Park { park1, park2, park3 }

enum StockType { normal, oceane, pb30 }

String posteToString(Poste? p) {
  switch (p) {
    case Poste.premier:
      return "3ème";
    case Poste.deuxieme:
      return "1er";
    case Poste.troisieme:
      return "2ème";
    default:
      return "";
  }
}

class _StopTimeEntryPage extends StatefulWidget {
  final String titleSuffix;

  const _StopTimeEntryPage({required this.titleSuffix});

  @override
  State<_StopTimeEntryPage> createState() => _StopTimeEntryPageState();
}

class _StopTimeEntryPageState extends State<_StopTimeEntryPage> {
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime =
      TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 1)));
  bool _isPending = false;

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay value) => (value.hour * 60) + value.minute;
  int _toCycleMinutes(TimeOfDay value) {
    final minutes = _toMinutes(value);
    return minutes < _cycleAnchorMinutes ? minutes + (24 * 60) : minutes;
  }

  Future<void> _pickStartTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _startTime,
      title: 'Heure début',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _endTime,
      title: 'Heure fin',
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
                      'Ajouter Arrêt ${widget.titleSuffix}',
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
                      'Saisie des heures',
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
                        'Heure début',
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
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Heure fin',
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
                        "Enregistrer seulement l'heure de début pour terminer plus tard.",
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
                          "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max).",
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Précédent',
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
                          onPressed: hasValidRange
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
                            'Ajouter',
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

String parkToString(Park? p) {
  switch (p) {
    case Park.park1:
      return "PARK 1";
    case Park.park2:
      return "PARK 2";
    case Park.park3:
      return "PARK 3";
    default:
      return "";
  }
}

String stockTypeToString(StockType? t) {
  switch (t) {
    case StockType.normal:
      return "NORMAL";
    case StockType.oceane:
      return "OCEANE";
    case StockType.pb30:
      return "PB30";
    default:
      return "";
  }
}

// --- Data Models ---
class Stop {
  String id;
  String category;
  String duration;
  String nature;
  String location;
  String detail;
  String startTime;
  String endTime;
  Stop({
    required this.id,
    this.category = '',
    this.duration = '',
    this.nature = '',
    this.location = '',
    this.detail = '',
    this.startTime = '',
    this.endTime = '',
  });
}

class StopCategory {
  final String label;
  final List<String> types;
  const StopCategory({required this.label, required this.types});
}

class StopLocation {
  final String code;
  final String label;
  const StopLocation({required this.code, required this.label});
}

class _StopTimeSelectionResult {
  final TimeOfDay start;
  final TimeOfDay? end;

  const _StopTimeSelectionResult({required this.start, required this.end});
}

enum _StopCardAction { end, edit, delete }

const List<StopCategory> _tnbStopCategories = [
  StopCategory(
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
  StopCategory(
    label: 'Arrêts Materiel',
    types: [
      'AE - Arrêts Éléctrique',
      'AM - Arrêts Mécanique',
      'AI - Arrêts Installateur',
      'AESYS - Arrêts Entretien Systématique',
    ],
  ),
  StopCategory(
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

String _formatTnbStopResultLine(
  Stop stop, {
  int? index,
}) {
  final labelSegments = <String>[
    if (index != null) '$index',
    stop.nature.isNotEmpty ? stop.nature : '-',
    if (_tnbStopTypeRequiresDetail(stop.nature) && stop.detail.isNotEmpty)
      stop.detail,
    if (_tnbStopTypeRequiresLocation(stop.nature) && stop.location.isNotEmpty)
      stop.location,
  ];
  final start = stop.startTime.isNotEmpty ? stop.startTime : '--:--';
  final end = stop.endTime.isNotEmpty ? stop.endTime : '--:--';
  final duration = stop.duration.isNotEmpty
      ? formatMinutesToHoursMinutes(parseDurationToMinutes(stop.duration))
      : '0h 00m';
  return '${labelSegments.join(' • ')}\n     De $start a $end ($duration)';
}

const List<StopLocation> _tnbStopLocations = [
  StopLocation(code: 'TR', label: 'tremie'),
  StopLocation(code: 'VIB1', label: 'vibreur 1'),
  StopLocation(code: 'VIB2', label: 'vibreur 2'),
  StopLocation(code: 'EXT2', label: 'extracteur 2'),
  StopLocation(code: 'C0', label: 'convoyeur C0'),
  StopLocation(code: 'C1', label: 'convoyeur C1'),
  StopLocation(code: 'EP', label: 'épierreur'),
  StopLocation(code: 'C2', label: 'convoyeur C2'),
  StopLocation(code: 'SILO', label: 'silo'),
  StopLocation(code: 'AL1', label: 'alimentateur 01'),
  StopLocation(code: 'AL2', label: 'alimentateur 02'),
  StopLocation(code: 'AL3', label: 'alimentateur 03'),
  StopLocation(code: 'AL4', label: 'alimentateur 04'),
  StopLocation(code: 'CR1', label: 'crible 1'),
  StopLocation(code: 'CR2', label: 'crible 2'),
  StopLocation(code: 'CR3', label: 'crible 3'),
  StopLocation(code: 'CR4', label: 'crible 4'),
  StopLocation(code: 'C3', label: 'convoyeur C3'),
  StopLocation(code: 'S2', label: 'convoyeur S2'),
  StopLocation(code: 'S3', label: 'convoyeur S3'),
  StopLocation(code: 'S4', label: 'convoyeur S4'),
  StopLocation(code: 'S5', label: 'convoyeur S5'),
  StopLocation(code: 'S6', label: 'convoyeur S6'),
  StopLocation(code: 'MTP', label: 'mise à térill principal'),
  StopLocation(code: 'MTS', label: 'mise à térill secours'),
  StopLocation(code: 'LN', label: 'convoyeur LN'),
  StopLocation(code: 'L', label: 'convoyeur L'),
  StopLocation(code: 'L1', label: 'convoyeur L1'),
  StopLocation(code: 'L2', label: 'convoyeur L2'),
  StopLocation(code: 'G3', label: 'convoyeur G3'),
  StopLocation(code: 'G6', label: 'convoyeur G6'),
  StopLocation(code: 'STK1', label: 'stockeuse 1'),
  StopLocation(code: 'STK2', label: 'stockeuse 2'),
  StopLocation(code: 'PE3', label: 'PE3'),
  StopLocation(code: 'PET', label: 'PET'),
  StopLocation(code: 'PEI', label: 'PEI'),
  StopLocation(code: 'BAR', label: 'Barre de raclage'),
  StopLocation(code: 'AUT', label: 'AUT'),
  StopLocation(code: 'TNB', label: 'tremie nord boucraa'),
];

const List<String> _tnbCounterLabels = [
  'Vibreur',
  'LN',
  'L',
  'G3',
  'G6',
];

class TnbCounter {
  String id;
  String label;
  String start;
  TnbCounter({
    required this.id,
    required this.label,
    this.start = '',
  });
}

class _ShiftCounterSegment {
  final String shiftLabel;
  final double startValue;
  final double endValue;

  _ShiftCounterSegment({
    required this.shiftLabel,
    required this.startValue,
    required this.endValue,
  });
}

class _ShiftCounterBlock {
  final String counterLabel;
  final List<_ShiftCounterSegment> segments;

  _ShiftCounterBlock({
    required this.counterLabel,
    required this.segments,
  });
}

class StockEntry {
  String id;
  Poste? poste;
  Park? park;
  StockType? type;
  String quantity;
  String startTime;
  StockEntry(
      {required this.id,
      this.poste,
      this.park,
      this.type,
      this.quantity = '',
      this.startTime = ''});
}

// --- Logic Helpers ---
int parseDurationToMinutes(String duration) {
  if (duration.isEmpty) return 0;
  final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
  int hours = 0;
  int minutes = 0;
  final match =
      RegExp(r'^(?:(\d{1,2})\s?[Hh:·]\s?)?(\d{1,2})$').firstMatch(cleaned);
  if (match != null) {
    hours = match.group(1) != null ? int.parse(match.group(1)!) : 0;
    minutes = int.parse(match.group(2)!);
    return (hours * 60) + minutes;
  }
  final match2 = RegExp(r'^(\d{1,2})\s?[Hh]$').firstMatch(cleaned);
  if (match2 != null) {
    hours = int.parse(match2.group(1)!);
    return hours * 60;
  }
  final match3 = RegExp(r'^(\d+)$').firstMatch(cleaned);
  if (match3 != null) {
    minutes = int.parse(match3.group(1)!);
    return minutes;
  }
  if (kDebugMode) {
    debugPrint('Could not parse duration: "$duration"');
  }
  return 0;
}

String formatMinutesToHoursMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return '0h 00m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

// --- Screen ---
class ActivityReportScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final String? previousDayThirdShiftEnd;
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const ActivityReportScreen({
    super.key,
    this.selectedDate,
    this.previousDayThirdShiftEnd,
    this.initialReport,
    this.onSave,
    this.isEditing = false,
  });

  static const int totalPeriodMinutes = 24 * 60; // 24 hours in minutes
  static const int maxHoursPerPoste = 12; // Maximum hours per poste

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  List<Stop> stops = [];
  List<TnbCounter> tnbCounters = [];
  List<StockEntry> stockEntries = [];
  late DateTime _selectedDate;

  int totalDowntime = 0;
  int operatingTime = ActivityReportScreen.totalPeriodMinutes;
  int totalVibratorMinutes = 0;
  int totalLiaisonMinutes = 0;

  Map<String, String> vibratorCounterErrors = {};
  Map<String, String> liaisonCounterErrors = {};

  bool hasVibratorErrors = false;
  bool hasLiaisonErrors = false;
  bool hasStockErrors = false;

  int _currentStep = 0;
  bool _isSaving = false;

  int _toCycleMinutes(TimeOfDay value) {
    final minutes = (value.hour * 60) + value.minute;
    return minutes < _cycleAnchorMinutes ? minutes + (24 * 60) : minutes;
  }

  int _durationMinutesInCycle(TimeOfDay start, TimeOfDay end) =>
      _toCycleMinutes(end) - _toCycleMinutes(start);

  int _minutesFromTimeText(String value) {
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

  void _sortStopsByStartTime() {
    stops.sort((a, b) => _minutesFromTimeText(a.startTime)
        .compareTo(_minutesFromTimeText(b.startTime)));
  }

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialReport != null) {
      // Editing mode - load existing data
      _selectedDate = widget.initialReport!.date;
      _loadExistingData();
    } else {
      // Creation mode
      _selectedDate = widget.selectedDate ?? DateTime.now();
      stops = [];
      tnbCounters = _buildDefaultTnbCounters();
      stockEntries = [];
    }
    recalculateTimes();
  }

  void _loadExistingData() {
    tnbCounters = _buildDefaultTnbCounters();
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;

    // Load stops
    if (data['Arrets'] is List) {
      stops = (data['Arrets'] as List)
          .map((s) => Stop(
              id: s['id'] ?? const Uuid().v4(),
              category: s['category'] ?? s['Catégorie'] ?? '',
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? '',
              location: s['location'] ?? s['Lieu'] ?? '',
              detail: s['detail'] ?? s['Détail'] ?? '',
              startTime: s['startTime'] ?? s['Début'] ?? '',
              endTime: s['endTime'] ?? s['Fin'] ?? ''))
          .toList();
      _sortStopsByStartTime();
    }

    if (data['vibrator Counters'] is List) {
      final vibratorCounters = List<Map<String, dynamic>>.from(
        data['vibrator Counters'] as List,
      );
      final firstVibrator =
          vibratorCounters.isNotEmpty ? vibratorCounters.first : null;
      if (firstVibrator != null) {
        _updateCounterValue(
          'Vibreur',
          firstVibrator['start']?.toString() ?? '',
        );
      }
    }

    if (data['liaison Counters'] is List) {
      final liaisonCounters = List<Map<String, dynamic>>.from(
        data['liaison Counters'] as List,
      );
      for (var i = 0;
          i < liaisonCounters.length && i < _tnbCounterLabels.length - 1;
          i++) {
        final counter = liaisonCounters[i];
        final rawLabel = counter['poste']?.toString().trim();
        final fallbackLabel = _tnbCounterLabels[i + 1];
        final label = (rawLabel != null && rawLabel.isNotEmpty)
            ? rawLabel
            : fallbackLabel;
        _updateCounterValue(label, counter['start']?.toString() ?? '');
      }
    }
    // Load stock entries
    if (data['stock'] is List) {
      stockEntries = (data['stock'] as List)
          .map((entry) => StockEntry(
                id: entry['id'] ?? const Uuid().v4(),
                poste: _parsePosteFromString(entry['poste']),
                park: _parseParkFromString(entry['park']),
                type: _parseStockTypeFromString(entry['type']),
                quantity: entry['quantity'] ?? '',
                startTime: entry['startTime'] ?? '',
              ))
          .toList();
    }
  }

  Park? _parseParkFromString(dynamic parkValue) {
    if (parkValue == null) return null;
    final parkStr = parkValue.toString();
    switch (parkStr) {
      case '0':
      case 'PARK 1':
        return Park.park1;
      case '1':
      case 'PARK 2':
        return Park.park2;
      case '2':
      case 'PARK 3':
        return Park.park3;
      default:
        return null;
    }
  }

  Poste? _parsePosteFromString(dynamic posteValue) {
    if (posteValue == null) return null;
    final posteStr = posteValue.toString();
    switch (posteStr) {
      case '0':
      case '3ème':
        return Poste.premier;
      case '1':
      case '1er':
        return Poste.deuxieme;
      case '2':
      case '2ème':
        return Poste.troisieme;
      default:
        return null;
    }
  }

  StockType? _parseStockTypeFromString(dynamic typeValue) {
    if (typeValue == null) return null;
    final typeStr = typeValue.toString();
    switch (typeStr) {
      case '0':
      case 'NORMAL':
        return StockType.normal;
      case '1':
      case 'OCEANE':
        return StockType.pb30;
      case '2':
      case 'PB30':
        return StockType.pb30;
      default:
        return null;
    }
  }

  void recalculateTimes() {
    setState(() {
      totalDowntime = _calculateCycleDowntimeMinutes();
      operatingTime =
          max(ActivityReportScreen.totalPeriodMinutes - totalDowntime, 0);

      // Validate and calculate counters (simplified)
      totalVibratorMinutes = 0;
      totalLiaisonMinutes = 0;

      hasVibratorErrors = false;
      hasLiaisonErrors = false;
      hasStockErrors = stockEntries.any((entry) =>
          (entry.park != null ||
              entry.type != null ||
              entry.quantity.isNotEmpty ||
              entry.startTime.isNotEmpty) &&
          entry.poste == null);
    });
  }

  int _calculateCycleDowntimeMinutes() {
    final ranges = <TimeRange>[];
    final cycleStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      22,
      30,
    );
    final cycleEnd = cycleStart.add(
      const Duration(minutes: ActivityReportScreen.totalPeriodMinutes),
    );
    final now = DateTime.now();

    for (final stop in stops) {
      final start = _tryParseStopDateTime(stop.startTime, cycleStart, cycleEnd);
      if (start == null) {
        final fallback = parseDurationToMinutes(stop.duration);
        if (fallback > 0) {
          ranges.add(TimeRange(0, fallback));
        }
        continue;
      }

      DateTime? end = _tryParseStopDateTime(stop.endTime, cycleStart, cycleEnd);

      // Open stop: keep counter paused until the stop is closed.
      end ??= now;
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      final effectiveStart = start.isBefore(cycleStart) ? cycleStart : start;
      final effectiveEnd = end.isAfter(cycleEnd) ? cycleEnd : end;
      if (effectiveEnd.isAfter(effectiveStart)) {
        ranges.add(TimeRange(
          effectiveStart.difference(cycleStart).inMinutes,
          effectiveEnd.difference(cycleStart).inMinutes,
        ));
      }
    }

    return TimeCalculationService.calculateTotalDowntimeMinutes(
      ranges,
      maxMinutes: ActivityReportScreen.totalPeriodMinutes,
    );
  }

  DateTime? _tryParseStopDateTime(
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
    // Best-effort fallback for values near cycle boundaries.
    return sameDay.isBefore(cycleStart) ? nextDay : sameDay;
  }

  List<TnbCounter> _buildDefaultTnbCounters() => _tnbCounterLabels
      .map((label) => TnbCounter(id: const Uuid().v4(), label: label))
      .toList();

  void _updateCounterValue(String label, String value) {
    final normalizedValue = value.trim();
    final index = tnbCounters.indexWhere((counter) => counter.label == label);
    if (index != -1) {
      tnbCounters[index].start = normalizedValue;
    }
  }

  List<Map<String, dynamic>> _buildSavedCounters(
    Iterable<TnbCounter> counters,
  ) {
    final shiftWindows = _buildShiftWindows();
    final shiftOperatingHours = shiftWindows
        .map((shift) => _calculateShiftOperatingHours(shift.start, shift.end))
        .toList(growable: false);
    return counters
        .where((counter) => counter.start.trim().isNotEmpty)
        .map((counter) {
      final endValue = _calculateCounterEndValue(
        counter.start,
        shiftOperatingHours: shiftOperatingHours,
      );
      return {
        'id': counter.id,
        'poste': counter.label,
        'start': counter.start.trim(),
        'end': endValue,
      };
    }).toList();
  }

  String _calculateCounterEndValue(
    String startValue, {
    required List<double> shiftOperatingHours,
  }) {
    final parsedStart = double.tryParse(startValue.replaceAll(',', '.').trim());
    if (parsedStart == null) {
      return '';
    }
    final operatingHours =
        shiftOperatingHours.fold<double>(0, (sum, value) => sum + value);
    final calculatedEnd = parsedStart + operatingHours;
    final formatted = calculatedEnd.toStringAsFixed(2);
    return formatted.endsWith('.00')
        ? formatted.substring(0, formatted.length - 3)
        : formatted;
  }

  List<({String label, DateTime start, DateTime end})> _buildShiftWindows() {
    final cycleStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      22,
      30,
    );

    return <({String label, DateTime start, DateTime end})>[
      (
        label: '3ème poste',
        start: cycleStart,
        end: cycleStart.add(const Duration(hours: 8)),
      ),
      (
        label: '1er poste',
        start: cycleStart.add(const Duration(hours: 8)),
        end: cycleStart.add(const Duration(hours: 16)),
      ),
      (
        label: '2ème poste',
        start: cycleStart.add(const Duration(hours: 16)),
        end: cycleStart.add(const Duration(hours: 24)),
      ),
    ];
  }

  double _calculateShiftOperatingHours(DateTime shiftStart, DateTime shiftEnd) {
    final shiftDowntimeMinutes =
        _calculateDowntimeMinutesBetween(shiftStart, shiftEnd);
    final shiftDurationMinutes = shiftEnd.difference(shiftStart).inMinutes;
    return max(0, shiftDurationMinutes - shiftDowntimeMinutes) / 60.0;
  }

  List<_ShiftCounterBlock> _buildShiftCounterBlocks() {
    final shiftWindows = _buildShiftWindows();

    final result = <_ShiftCounterBlock>[];

    for (final counter in tnbCounters) {
      if (counter.start.trim().isEmpty) continue;
      final parsedStart =
          double.tryParse(counter.start.replaceAll(',', '.').trim());
      if (parsedStart == null) continue;

      var current = parsedStart;
      final segments = <_ShiftCounterSegment>[];

      for (final shift in shiftWindows) {
        final shiftOperatingHours =
            _calculateShiftOperatingHours(shift.start, shift.end);
        final next = current + shiftOperatingHours;
        segments.add(_ShiftCounterSegment(
          shiftLabel: shift.label,
          startValue: current,
          endValue: next,
        ));
        current = next;
      }

      result.add(_ShiftCounterBlock(
        counterLabel: counter.label,
        segments: segments,
      ));
    }

    return result;
  }

  int _calculateDowntimeMinutesBetween(
      DateTime windowStart, DateTime windowEnd) {
    final cycleStart = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      22,
      30,
    );
    final cycleEnd = cycleStart.add(
      const Duration(minutes: ActivityReportScreen.totalPeriodMinutes),
    );
    final now = DateTime.now();
    final ranges = <TimeRange>[];

    for (final stop in stops) {
      final start = _tryParseStopDateTime(stop.startTime, cycleStart, cycleEnd);
      if (start == null) continue;

      DateTime? end = _tryParseStopDateTime(stop.endTime, cycleStart, cycleEnd);
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

  String _formatCounterNumber(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  int get _filledCounterCount =>
      tnbCounters.where((counter) => counter.start.trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final steps = ['Infos', 'Arrêts', 'Stock', 'Verif.'];

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEditing ? "Modifier Activité TNB" : "Activité TNB"),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              OCPStepper(
                  steps: steps,
                  currentStep: _currentStep,
                  onStepTapped: (i) => setState(() => _currentStep = i)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildStepContent(),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepInfos();
      case 1:
        return _buildStepArrets();
      case 2:
        return _buildStepStock();
      case 3:
        return _buildStepVerification();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    bool isFirst = _currentStep == 0;
    bool isLast = _currentStep == 3;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
      child: Row(children: [
        if (!isFirst)
          Expanded(
              child: OCPButton(
                  text: 'Précédent',
                  onPressed: () => setState(() => _currentStep--),
                  isSecondary: true)),
        if (!isFirst) const SizedBox(width: 16),
        Expanded(
            child: OCPButton(
                text: isLast ? 'Soumettre' : 'Suivant',
                onPressed: () {
                  if (isLast) {
                    _saveReport();
                  } else {
                    setState(() => _currentStep++);
                  }
                },
                isLoading: _isSaving && isLast)),
      ]),
    );
  }

  // --- Step 0: Infos ---
  Widget _buildStepInfos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OCPCard(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                locale: const Locale('fr', 'FR'));
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Row(children: [
            const Icon(Icons.calendar_today, color: AppColors.primary),
            const SizedBox(width: 16),
            Text(
                "Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ]),
        ),
        const SizedBox(height: 16),
        OCPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _buildCounterFields(),
          ),
        ),
      ],
    );
  }

  // --- Step 1: Arrêts ---
  Widget _buildStepArrets() {
    return Column(children: [
      ...stops.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(
              _formatTnbStopResultLine(e.value, index: e.key + 1),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: e.value.endTime.isEmpty
                ? const Text(
                    'Arrêt en cours',
                    style: TextStyle(color: AppColors.success),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<_StopCardAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions arrêt',
                  onSelected: (action) {
                    switch (action) {
                      case _StopCardAction.end:
                        _endPendingStop(e.key);
                        break;
                      case _StopCardAction.edit:
                        _editStop(e.key);
                        break;
                      case _StopCardAction.delete:
                        setState(() => stops.removeAt(e.key));
                        recalculateTimes();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (e.value.endTime.isEmpty)
                      const PopupMenuItem<_StopCardAction>(
                        value: _StopCardAction.end,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.stop_circle_outlined,
                              color: AppColors.success),
                          title: Text('Terminer'),
                        ),
                      ),
                    const PopupMenuItem<_StopCardAction>(
                      value: _StopCardAction.edit,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Modifier'),
                      ),
                    ),
                    const PopupMenuItem<_StopCardAction>(
                      value: _StopCardAction.delete,
                      child: ListTile(
                        dense: true,
                        leading:
                            Icon(Icons.delete_outline, color: AppColors.error),
                        title: Text('Supprimer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Arrêt",
          icon: Icons.add,
          isSecondary: true,
          onPressed: _showAddStopDialog)
    ]);
  }

  void _showAddStopDialog() {
    StopCategory? selectedCategory;
    String? selectedNature;
    StopLocation? selectedLocation;
    String stopDetail = '';

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedNature);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedNature);
          final canSubmit = selectedCategory != null &&
              selectedNature != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: const Text('Ajouter un arrêt'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<StopCategory>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: _tnbStopCategories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                          selectedNature = null;
                          selectedLocation = null;
                          stopDetail = '';
                        });
                      },
                      hint: const Text('Sélectionner la catégorie d\'arrêt'),
                      isExpanded: true,
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedNature,
                        decoration: const InputDecoration(
                          labelText: 'Type d\'arrêt',
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map((nature) => DropdownMenuItem(
                                  value: nature,
                                  child: Text(nature),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedNature = value;
                            selectedLocation = null;
                            stopDetail = '';
                          });
                        },
                        hint: const Text('Sélectionner le type d\'arrêt'),
                        isExpanded: true,
                      ),
                    ],
                    if (requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<StopLocation>(
                        decoration: const InputDecoration(
                          labelText: 'Lieu d\'arrêt',
                          border: OutlineInputBorder(),
                        ),
                        initialValue: selectedLocation,
                        isExpanded: true,
                        items: _tnbStopLocations
                            .map((location) => DropdownMenuItem<StopLocation>(
                                  value: location,
                                  child: Text(
                                      '${location.code} - ${location.label}'),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedLocation = value;
                          });
                        },
                        hint: const Text('Sélectionner le lieu'),
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
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final selectedTimeResult =
                            await showDialog<_StopTimeSelectionResult>(
                          context: context,
                          useRootNavigator: true,
                          barrierDismissible: false,
                          barrierColor: Colors.black54,
                          builder: (_) => _StopTimeEntryPage(
                            titleSuffix: selectedNature ?? '',
                          ),
                        );

                        if (selectedTimeResult == null) {
                          return;
                        }

                        final durationMinutes = selectedTimeResult.end == null
                            ? null
                            : _durationMinutesInCycle(
                                selectedTimeResult.start,
                                selectedTimeResult.end!,
                              );
                        if (durationMinutes != null &&
                            (durationMinutes <= 0 ||
                                durationMinutes >
                                    ActivityReportScreen.totalPeriodMinutes)) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max).",
                                ),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                          return;
                        }
                        final durationText = durationMinutes == null
                            ? ''
                            : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';

                        setState(() {
                          stops.add(Stop(
                            id: const Uuid().v4(),
                            category: selectedCategory!.label,
                            duration: durationText,
                            nature: selectedNature!,
                            location: requiresLocation
                                ? '${selectedLocation!.code} - ${selectedLocation!.label}'
                                : '',
                            detail: requiresDetail ? stopDetail.trim() : '',
                            startTime:
                                formatTimeOfDay(selectedTimeResult.start),
                            endTime: selectedTimeResult.end == null
                                ? ''
                                : formatTimeOfDay(selectedTimeResult.end!),
                          ));
                          _sortStopsByStartTime();
                        });
                        recalculateTimes();
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: const Text('Suivant'),
              ),
            ],
          );
        },
      ),
    );
  }

  TimeOfDay? _parseTimeOfDay(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _endPendingStop(int index) async {
    final stop = stops[index];
    if (stop.endTime.isNotEmpty) return;
    final start = _parseTimeOfDay(stop.startTime);
    if (start == null) return;

    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return;

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    if (durationMinutes <= 0 ||
        durationMinutes > ActivityReportScreen.totalPeriodMinutes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("L'arrêt doit rester dans la fenêtre 22:30 → 22:30."),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() {
      stop.endTime =
          '${selectedEnd.hour.toString().padLeft(2, '0')}:${selectedEnd.minute.toString().padLeft(2, '0')}';
      stop.duration =
          '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
    });
    recalculateTimes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Arrêt terminé avec succès.")),
      );
    }
  }

  Future<void> _editStop(int index) async {
    final stop = stops[index];
    StopCategory? selectedCategory;
    for (final category in _tnbStopCategories) {
      if (category.label == stop.category) {
        selectedCategory = category;
        break;
      }
    }
    selectedCategory ??= _tnbStopCategories.firstWhere(
      (category) =>
          category.types.any((type) => type.trim() == stop.nature.trim()),
      orElse: () => _tnbStopCategories.first,
    );

    String? selectedNature = stop.nature.isEmpty ? null : stop.nature;
    StopLocation? selectedLocation;
    if (stop.location.isNotEmpty) {
      final code = stop.location.split(' - ').first.trim();
      for (final location in _tnbStopLocations) {
        if (location.code == code) {
          selectedLocation = location;
          break;
        }
      }
    }
    String stopDetail = stop.detail;
    TimeOfDay? selectedStart = _parseTimeOfDay(stop.startTime);
    TimeOfDay? selectedEnd = _parseTimeOfDay(stop.endTime);

    selectedStart ??= TimeOfDay.now();

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDs) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedNature);
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedNature);
          final canSubmit = selectedCategory != null &&
              selectedNature != null &&
              selectedStart != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: const Text('Modifier arrêt'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<StopCategory>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: _tnbStopCategories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ))
                          .toList(),
                      onChanged: (value) => setDs(() {
                        selectedCategory = value;
                        selectedNature = null;
                        selectedLocation = null;
                      }),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedNature,
                      decoration: const InputDecoration(
                        labelText: "Type d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: availableTypes
                          .map((nature) => DropdownMenuItem(
                                value: nature,
                                child: Text(nature),
                              ))
                          .toList(),
                      onChanged: (value) => setDs(() => selectedNature = value),
                    ),
                    if (requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<StopLocation>(
                        initialValue: selectedLocation,
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        items: _tnbStopLocations
                            .map((location) => DropdownMenuItem(
                                  value: location,
                                  child: Text(
                                      '${location.code} - ${location.label}'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setDs(() => selectedLocation = value),
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
                        onChanged: (value) => setDs(() => stopDetail = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure début'),
                      subtitle: Text(formatTimeOfDay(selectedStart!)),
                      trailing: const Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showSpinnerTimePickerDialog(
                          context: context,
                          initialTime: selectedStart!,
                          title: 'Heure début',
                        );
                        if (picked != null) {
                          setDs(() => selectedStart = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Heure fin'),
                      subtitle: Text(
                        selectedEnd == null
                            ? 'Pending'
                            : formatTimeOfDay(selectedEnd!),
                      ),
                      trailing: TextButton(
                        onPressed: () => setDs(() => selectedEnd = null),
                        child: const Text('Pending'),
                      ),
                      onTap: () async {
                        final picked = await showSpinnerTimePickerDialog(
                          context: context,
                          initialTime: selectedEnd ?? TimeOfDay.now(),
                          title: 'Heure fin',
                        );
                        if (picked != null) {
                          setDs(() => selectedEnd = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: !canSubmit
                    ? null
                    : () {
                        final durationMinutes = selectedEnd == null
                            ? null
                            : _durationMinutesInCycle(
                                selectedStart!,
                                selectedEnd!,
                              );
                        if (durationMinutes != null &&
                            (durationMinutes <= 0 ||
                                durationMinutes >
                                    ActivityReportScreen.totalPeriodMinutes)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max)."),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          stop.category = selectedCategory!.label;
                          stop.nature = selectedNature!;
                          stop.location = requiresLocation &&
                                  selectedLocation != null
                              ? '${selectedLocation!.code} - ${selectedLocation!.label}'
                              : '';
                          stop.detail = requiresDetail ? stopDetail.trim() : '';
                          stop.startTime = formatTimeOfDay(selectedStart!);
                          stop.endTime = selectedEnd == null
                              ? ''
                              : formatTimeOfDay(selectedEnd!);
                          stop.duration = durationMinutes == null
                              ? ''
                              : '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
                        });
                        _sortStopsByStartTime();
                        recalculateTimes();
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCounterFields() {
    return [
      Text(
        'Compteurs TNB',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Saisissez uniquement la valeur de départ pour chacun des cinq compteurs.',
      ),
      const SizedBox(height: 16),
      ...tnbCounters.map(
        (counter) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                counter.label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: counter.start,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Valeur de départ - ${counter.label}',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    counter.start = value.trim();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // --- Step 2: Stock ---
  Widget _buildStepStock() {
    return Column(children: [
      ...stockEntries.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(
                "${posteToString(e.value.poste)} - ${parkToString(e.value.park)}"),
            subtitle: Text(
                "${stockTypeToString(e.value.type)}: ${e.value.quantity} (${e.value.startTime})"),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () {
                  setState(() => stockEntries.removeAt(e.key));
                  recalculateTimes();
                }),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Stock",
          icon: Icons.add,
          isSecondary: true,
          onPressed: _showAddStockDialog)
    ]);
  }

  void _showAddStockDialog() {
    Poste? poste;
    Park? park;
    StockType? type;
    String qty = '';
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setDs) => AlertDialog(
                  title: const Text("Ajouter Stock"),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<Poste>(
                        hint: const Text("Poste"),
                        items: Poste.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(posteToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => poste = v)),
                    DropdownButtonFormField<Park>(
                        hint: const Text("Park"),
                        items: Park.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(parkToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => park = v)),
                    DropdownButtonFormField<StockType>(
                        hint: const Text("Type"),
                        items: StockType.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(stockTypeToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => type = v)),
                    TextField(
                        decoration:
                            const InputDecoration(labelText: "Quantité"),
                        onChanged: (v) => qty = v),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Annuler")),
                    ElevatedButton(
                        onPressed:
                            (poste != null && park != null && type != null)
                                ? () {
                                    setState(() => stockEntries.add(StockEntry(
                                        id: const Uuid().v4(),
                                        poste: poste,
                                        park: park,
                                        type: type,
                                        quantity: qty)));
                                    Navigator.pop(context);
                                  }
                                : null,
                        child: const Text("Ajouter"))
                  ],
                )));
  }

  // --- Step 3: Verification ---
  Widget _buildStepVerification() {
    final shiftCounterBlocks = _buildShiftCounterBlocks();
    return Column(
      children: [
        const Icon(Icons.check_circle_outline,
            size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        const Text("Récapitulatif",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _row("Date",
            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résumé des données',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(height: 16),
                _row('T H.A:', formatMinutesToHoursMinutes(totalDowntime)),
                _row('T H.M:', formatMinutesToHoursMinutes(operatingTime)),
                const SizedBox(height: 8),
                _row('T Nr.A:', stops.length.toString()),
                _row('T Nr.C:', '$_filledCounterCount / ${tnbCounters.length}'),
              ],
            ),
          ),
        ),
        if (stops.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arrêts',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  ...stops.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            _formatTnbStopResultLine(
                              entry.value,
                              index: entry.key + 1,
                            ),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Compteurs TNB',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Divider(height: 16),
                ...[
                  for (final shiftLabel in const [
                    '3ème poste',
                    '1er poste',
                    '2ème poste',
                  ]) ...[
                    Text(
                      shiftLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    ...shiftCounterBlocks.map((block) {
                      final segment = block.segments.firstWhere(
                        (s) => s.shiftLabel == shiftLabel,
                        orElse: () => _ShiftCounterSegment(
                          shiftLabel: shiftLabel,
                          startValue: 0,
                          endValue: 0,
                        ),
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${block.counterLabel} : ${_formatCounterNumber(segment.startValue)} → ${_formatCounterNumber(segment.endValue)}',
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ]
                ],
                const SizedBox(height: 8),
                const Text(
                  "La valeur de fin est calculée automatiquement avec T H.M",
                  style: TextStyle(color: Colors.grey),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stocks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  ...stockEntries.map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Poste: ${entry.poste != null ? posteToString(entry.poste) : '-'} | '
                          'Park: ${entry.park != null ? parkToString(entry.park) : '-'} | '
                          'Type: ${entry.type != null ? stockTypeToString(entry.type) : '-'} | '
                          'Qte: ${entry.quantity.isNotEmpty ? entry.quantity : '-'}',
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
        if (hasVibratorErrors || hasLiaisonErrors || hasStockErrors) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erreurs détectées',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (hasVibratorErrors)
                    Text('Erreurs dans les compteurs vibreurs',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (hasLiaisonErrors)
                    Text('Erreurs dans les compteurs liaison',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  if (hasStockErrors)
                    Text('Erreurs dans les entrées stock',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _saveReport() async {
    setState(() => _isSaving = true);
    try {
      final savedVibratorCounters = _buildSavedCounters(
        tnbCounters.where((counter) => counter.label == 'Vibreur'),
      );
      final savedLiaisonCounters = _buildSavedCounters(
        tnbCounters.where((counter) => counter.label != 'Vibreur'),
      );

      final report = Report(
          id: widget.initialReport?.id,
          description:
              'Activity TNB - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
          date: _selectedDate,
          group: 'MIB/U/E/I',
          type: 'Activity TNB',
          additionalData: {
            'Arrets': stops
                .map((s) => {
                      'id': s.id,
                      'duration': s.duration,
                      'category': s.category,
                      'nature': s.nature,
                      'location': s.location,
                      'detail': s.detail,
                      'startTime': s.startTime,
                      'endTime': s.endTime,
                      'Lieu': s.location,
                      'Détail': s.detail,
                      'Début': s.startTime,
                      'Fin': s.endTime,
                      'Catégorie': s.category,
                    })
                .toList(),
            'vibrator Counters': savedVibratorCounters,
            'liaison Counters': savedLiaisonCounters,
            'stock': stockEntries
                .map((e) => {
                      'id': e.id,
                      'poste': e.poste?.index,
                      'park': e.park?.index,
                      'type': e.type?.index,
                      'quantity': e.quantity
                    })
                .toList(),
            'T H.A': totalDowntime,
            'T H.M': operatingTime,
            'T H.V': totalVibratorMinutes,
            'T H.L': totalLiaisonMinutes,
            'T Nr.A': stops.length,
            'T Nr.V': savedVibratorCounters.length,
            'T Nr.L': savedLiaisonCounters.length,
            'T Nr.C': _filledCounterCount,
            'T Nr.S': stockEntries.length,
          });
      if (widget.isEditing && widget.onSave != null) {
        widget.onSave!(report);
      } else {
        await _databaseHelper.insertReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Succès'), backgroundColor: AppColors.success));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
