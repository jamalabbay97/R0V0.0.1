import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/theme.dart';
import 'package:r0/widgets/custom_widgets.dart';

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
  String startTime;
  String endTime;
  Stop({
    required this.id,
    this.category = '',
    this.duration = '',
    this.nature = '',
    this.location = '',
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

const List<StopCategory> _tnbStopCategories = [
  StopCategory(
    label: 'Arrêts Extérieures',
    types: [
      'MP - Manque Produit',
      'CC - Coupure De Courant',
      'AD - Arrêts Décidés',
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
      'Surch - Surcharge',
      'Attente Vidange Extracteur',
      'Attente Vidange Silo',
      'DEC - Décolmatage',
      'MO - Manque Opérateur',
    ],
  ),
  StopCategory(
    label: 'STS - Stock Saturée',
    types: ['Stock Saturée'],
  ),
];

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
  StopLocation(code: 'MTS', label: 'mise à térill secours'),
  StopLocation(code: 'MTP', label: 'mise à térill principal'),
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
              startTime: s['startTime'] ?? s['Début'] ?? '',
              endTime: s['endTime'] ?? s['Fin'] ?? ''))
          .toList();
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
      totalDowntime =
          stops.fold(0, (acc, s) => acc + parseDurationToMinutes(s.duration));
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
    return counters
        .where((counter) => counter.start.trim().isNotEmpty)
        .map((counter) => {
              'id': counter.id,
              'poste': counter.label,
              'start': counter.start.trim(),
              'end': '',
            })
        .toList();
  }

  int get _filledCounterCount =>
      tnbCounters.where((counter) => counter.start.trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    final steps = ['Infos', 'Arrêts', 'Compteurs', 'Stock', 'Verif.'];

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
        return _buildStepCompteurs();
      case 3:
        return _buildStepStock();
      case 4:
        return _buildStepVerification();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    bool isFirst = _currentStep == 0;
    bool isLast = _currentStep == 4;
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
    return OCPCard(
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const Spacer(),
        const Icon(Icons.arrow_forward_ios, size: 16),
      ]),
    );
  }

  // --- Step 1: Arrêts ---
  Widget _buildStepArrets() {
    return Column(children: [
      ...stops.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(e.value.nature.isNotEmpty ? e.value.nature : '-'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    "Catégorie: ${e.value.category.isNotEmpty ? e.value.category : '-'}"),
                Text(
                    "Lieu: ${e.value.location.isNotEmpty ? e.value.location : '-'}"),
                Text(
                    "De ${e.value.startTime.isNotEmpty ? e.value.startTime : '--:--'} à ${e.value.endTime.isNotEmpty ? e.value.endTime : '--:--'}"),
                Text(
                    "Durée: ${formatMinutesToHoursMinutes(parseDurationToMinutes(e.value.duration))}"),
              ],
            ),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () {
                  setState(() => stops.removeAt(e.key));
                  recalculateTimes();
                }),
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
    TimeOfDay? selectedStart;
    TimeOfDay? selectedEnd;

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    int minutesFromTimeOfDay(TimeOfDay value) =>
        (value.hour * 60) + value.minute;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final canSubmit = selectedCategory != null &&
              selectedNature != null &&
              selectedLocation != null &&
              selectedStart != null &&
              selectedEnd != null &&
              minutesFromTimeOfDay(selectedEnd!) >
                  minutesFromTimeOfDay(selectedStart!);

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
                          selectedStart = null;
                          selectedEnd = null;
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
                            selectedStart = null;
                            selectedEnd = null;
                          });
                        },
                        hint: const Text('Sélectionner le type d\'arrêt'),
                        isExpanded: true,
                      ),
                    ],
                    if (selectedNature != null) ...[
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
                            selectedStart = null;
                            selectedEnd = null;
                          });
                        },
                        hint: const Text('Sélectionner le lieu'),
                      ),
                    ],
                    if (selectedLocation != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Début'),
                              subtitle: Text(selectedStart == null
                                  ? '--:--'
                                  : formatTimeOfDay(selectedStart!)),
                              trailing: const Icon(Icons.access_time),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedStart ?? TimeOfDay.now(),
                                  builder: (context, child) => MediaQuery(
                                    data: MediaQuery.of(context)
                                        .copyWith(alwaysUse24HourFormat: true),
                                    child: child ?? const SizedBox(),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => selectedStart = picked);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Fin'),
                              subtitle: Text(selectedEnd == null
                                  ? '--:--'
                                  : formatTimeOfDay(selectedEnd!)),
                              trailing: const Icon(Icons.access_time),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: selectedEnd ??
                                      (selectedStart ?? TimeOfDay.now()),
                                  builder: (context, child) => MediaQuery(
                                    data: MediaQuery.of(context)
                                        .copyWith(alwaysUse24HourFormat: true),
                                    child: child ?? const SizedBox(),
                                  ),
                                );
                                if (picked != null) {
                                  setState(() => selectedEnd = picked);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (selectedStart != null &&
                          selectedEnd != null &&
                          minutesFromTimeOfDay(selectedEnd!) <=
                              minutesFromTimeOfDay(selectedStart!))
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "L'heure de fin doit être après l'heure de début.",
                            style: TextStyle(color: AppColors.error),
                          ),
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
                    ? () {
                        final startMinutes =
                            minutesFromTimeOfDay(selectedStart!);
                        final endMinutes = minutesFromTimeOfDay(selectedEnd!);

                        final durationMinutes = endMinutes - startMinutes;
                        final durationHours = durationMinutes ~/ 60;
                        final remainingMinutes = durationMinutes % 60;
                        final durationText =
                            '${durationHours}h ${remainingMinutes.toString().padLeft(2, '0')}';

                        setState(() {
                          stops.add(Stop(
                            id: const Uuid().v4(),
                            category: selectedCategory!.label,
                            duration: durationText,
                            nature: selectedNature!,
                            location:
                                '${selectedLocation!.code} - ${selectedLocation!.label}',
                            startTime: formatTimeOfDay(selectedStart!),
                            endTime: formatTimeOfDay(selectedEnd!),
                          ));
                        });
                        recalculateTimes();
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Step 2: Compteurs ---
  Widget _buildStepCompteurs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            child: OCPCard(
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
        ),
      ],
    );
  }

  // --- Step 3: Stock ---
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

  // --- Step 4: Verification ---
  Widget _buildStepVerification() {
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
                  ...stops.map((stop) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Catégorie: ${stop.category.isNotEmpty ? stop.category : '-'} | '
                          '${stop.nature.isNotEmpty ? stop.nature : '-'} | '
                          'Lieu: ${stop.location.isNotEmpty ? stop.location : '-'} | '
                          'De: ${stop.startTime.isNotEmpty ? stop.startTime : '--:--'} '
                          'à ${stop.endTime.isNotEmpty ? stop.endTime : '--:--'} | '
                          'Durée: ${stop.duration.isNotEmpty ? formatMinutesToHoursMinutes(parseDurationToMinutes(stop.duration)) : '-'}',
                        ),
                      )),
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
                ...tnbCounters.map((counter) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${counter.label}: ${counter.start.isNotEmpty ? counter.start : '-'}',
                      ),
                    )),
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
                      'startTime': s.startTime,
                      'endTime': s.endTime,
                      'Lieu': s.location,
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
