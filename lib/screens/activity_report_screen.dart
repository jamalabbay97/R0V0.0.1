import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/theme.dart';
import 'package:r0/l10n/app_localizations.dart';
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
  String duration;
  String nature;
  String location;
  String startTime;
  String endTime;
  Stop({
    required this.id,
    this.duration = '',
    this.nature = '',
    this.location = '',
    this.startTime = '',
    this.endTime = '',
  });
}

class StopLocation {
  final String code;
  final String label;
  const StopLocation({required this.code, required this.label});
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

class Counter {
  String id;
  Poste? poste;
  String start;
  String end;
  String? error;
  bool startDefect;
  bool endDefect;
  Counter({
    required this.id,
    this.poste,
    this.start = '',
    this.end = '',
    this.error,
    this.startDefect = false,
    this.endDefect = false,
  });
}

class LiaisonCounter extends Counter {
  LiaisonCounter({
    required super.id,
    super.poste,
    super.start,
    super.end,
    super.error,
    super.startDefect,
    super.endDefect,
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

double? validateAndParseCounterValue(String value) {
  if (value.isEmpty) return 0;
  final cleaned =
      value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
  if (cleaned == '' || cleaned == '.' || cleaned == ',') return null;
  return double.tryParse(cleaned);
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
  List<Counter> vibratorCounters = [];
  List<LiaisonCounter> liaisonCounters = [];
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
      vibratorCounters = [];
      liaisonCounters = [];
      stockEntries = [];
    }
    recalculateTimes();
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;

    // Load stops
    if (data['Arrets'] is List) {
      stops = (data['Arrets'] as List)
          .map((s) => Stop(
              id: s['id'] ?? const Uuid().v4(),
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? '',
              location: s['location'] ?? s['Lieu'] ?? '',
              startTime: s['startTime'] ?? s['Début'] ?? '',
              endTime: s['endTime'] ?? s['Fin'] ?? ''))
          .toList();
    }
    // Load vibrator counters
    if (data['vibrator Counters'] is List) {
      vibratorCounters = (data['vibrator Counters'] as List)
          .map((counter) => Counter(
                id: counter['id'] ?? const Uuid().v4(),
                poste: _parsePosteFromString(counter['poste']),
                start: counter['start'] ?? '',
                end: counter['end'] ?? '',
                error: counter['error'],
                startDefect: counter['startDefect'] ?? false,
                endDefect: counter['endDefect'] ?? false,
              ))
          .toList();
    }
    // Load liaison counters
    if (data['liaison Counters'] is List) {
      liaisonCounters = (data['liaison Counters'] as List)
          .map((counter) => LiaisonCounter(
                id: counter['id'] ?? const Uuid().v4(),
                poste: _parsePosteFromString(counter['poste']),
                start: counter['start'] ?? '',
                end: counter['end'] ?? '',
                error: counter['error'],
                startDefect: counter['startDefect'] ?? false,
                endDefect: counter['endDefect'] ?? false,
              ))
          .toList();
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
      totalVibratorMinutes = calculateTotalCounterMinutes(vibratorCounters);
      totalLiaisonMinutes = calculateTotalCounterMinutes(liaisonCounters);

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

  int calculateTotalCounterMinutes(List counters) {
    double totalHours = 0;
    for (var counter in counters) {
      if (counter.startDefect || counter.endDefect) {
        continue;
      }
      var startVal = validateAndParseCounterValue(counter.start);
      var endVal = validateAndParseCounterValue(counter.end);
      if (startVal != null && endVal != null && endVal >= startVal) {
        totalHours += (endVal - startVal);
      }
    }
    return (totalHours * 60).round();
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Infos', 'Arrêts', 'Vibreur', 'Liaison', 'Stock', 'Verif.'];

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
        return _buildStepVibreurs();
      case 3:
        return _buildStepLiaison();
      case 4:
        return _buildStepStock();
      case 5:
        return _buildStepVerification();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    bool isFirst = _currentStep == 0;
    bool isLast = _currentStep == 5;
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
            title: Text(e.value.nature),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
    const List<String> predefinedNatures = [
      'Arrêts Extérieures:',
      'Arrêts Eléctrique:',
      'Arrêts Mécanique:',
      'Arrêts d\'installation:',
      'Arrêts d\'exploitation:',
      'Arrêts Entretien systématique:',
      'Manque Produit:',
      'Décolmatage:',
      'Coupure de courant:',
      'Vidange:',
      'Arrêts Décidés:',
      'Nettoyage:',
      'Stock saturée:',
      'Dégagement stérile:',
      'Surcharge:',
    ];
    String? selectedNature;
    String customNature = '';
    StopLocation? selectedLocation;
    TimeOfDay? selectedStart;
    TimeOfDay? selectedEnd;
    int step = 0;
    final customNatureController = TextEditingController();

    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    int minutesFromTimeOfDay(TimeOfDay value) =>
        (value.hour * 60) + value.minute;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget content;
          if (step == 0) {
            content = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedNature,
                  decoration: const InputDecoration(
                    labelText: 'Type d\'arrêt',
                    border: OutlineInputBorder(),
                  ),
                  items: predefinedNatures
                      .map((nature) => DropdownMenuItem(
                            value: nature,
                            child: Text(nature),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedNature = value;
                      customNature = '';
                      customNatureController.clear();
                    });
                  },
                  hint: const Text('Sélectionner un type d\'arrêt'),
                  isExpanded: true,
                ),
                if (selectedNature?.endsWith(':') == true) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: customNatureController,
                    decoration: const InputDecoration(
                      labelText: 'Nature (complément)',
                      border: OutlineInputBorder(),
                      hintText: 'Maximum 20 caractères par ligne',
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
                          currentLine +=
                              (currentLine.isEmpty ? '' : ' ') + word;
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
                      setState(() => customNature = lines.join(''));
                    },
                  ),
                ],
              ],
            );
          } else if (step == 1) {
            content = DropdownButtonFormField<StopLocation>(
              decoration: const InputDecoration(
                labelText: 'Lieu d\'arrêt',
                border: OutlineInputBorder(),
              ),
              initialValue: selectedLocation,
              isExpanded: true,
              items: _tnbStopLocations
                  .map((location) => DropdownMenuItem<StopLocation>(
                        value: location,
                        child: Text('${location.code} - ${location.label}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedLocation = value),
              hint: const Text('Sélectionner le lieu'),
            );
          } else {
            content = Row(
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
                        initialTime:
                            selectedEnd ?? (selectedStart ?? TimeOfDay.now()),
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
            );
          }

          return AlertDialog(
            title: const Text('Ajouter un arrêt'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step == 0
                          ? 'Type d\'arrêt'
                          : step == 1
                              ? 'Lieu d\'arrêt'
                              : 'Horaire de l\'arrêt',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    content,
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (step == 0)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    )
                  else
                    TextButton(
                      onPressed: () => setState(() => step--),
                      child: const Text('Précédent'),
                    ),
                  if (step < 2)
                    ElevatedButton(
                      onPressed: () {
                        if (step == 0) {
                          if (selectedNature == null) return;
                          if (selectedNature!.endsWith(':') &&
                              customNature.trim().isEmpty) {
                            return;
                          }
                        }
                        if (step == 1 && selectedLocation == null) return;
                        setState(() => step++);
                      },
                      child: const Text('Suivant'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        if (selectedNature == null ||
                            selectedLocation == null ||
                            selectedStart == null ||
                            selectedEnd == null) {
                          return;
                        }

                        final startMinutes =
                            minutesFromTimeOfDay(selectedStart!);
                        final endMinutes = minutesFromTimeOfDay(selectedEnd!);
                        if (endMinutes <= startMinutes) return;

                        final durationMinutes = endMinutes - startMinutes;
                        final durationHours = durationMinutes ~/ 60;
                        final remainingMinutes = durationMinutes % 60;
                        final durationText =
                            '${durationHours}h ${remainingMinutes.toString().padLeft(2, '0')}';

                        final finalNature = selectedNature!.endsWith(':')
                            ? '$selectedNature\n${customNature.trim()}'
                            : selectedNature!;

                        setState(() {
                          stops.add(Stop(
                            id: const Uuid().v4(),
                            duration: durationText,
                            nature: finalNature,
                            location:
                                '${selectedLocation!.code} - ${selectedLocation!.label}',
                            startTime: formatTimeOfDay(selectedStart!),
                            endTime: formatTimeOfDay(selectedEnd!),
                          ));
                        });
                        recalculateTimes();
                        Navigator.pop(context);
                      },
                      child: const Text('Ajouter'),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Step 2: Vibreurs ---
  Widget _buildStepVibreurs() {
    return _buildCounterList(
        vibratorCounters, (c) => setState(() => vibratorCounters.add(c)));
  }

  // --- Step 3: Liaison ---
  Widget _buildStepLiaison() {
    return _buildCounterList(
        liaisonCounters,
        (c) => setState(() => liaisonCounters.add(LiaisonCounter(
              id: c.id,
              poste: c.poste,
              start: c.start,
              end: c.end,
              error: c.error,
            ))));
  }

  Widget _buildCounterList(List<Counter> list, Function(Counter) onAdd) {
    return Column(children: [
      ...list.asMap().entries.map((e) {
        final startText = e.value.startDefect
            ? (AppLocalizations.of(context)?.defautLabel ?? 'Défaut')
            : e.value.start;
        final endText = e.value.endDefect
            ? (AppLocalizations.of(context)?.defautLabel ?? 'Défaut')
            : e.value.end;
        return OCPCard(
            child: ListTile(
          title: Text("${posteToString(e.value.poste)} Poste"),
          subtitle: Text("$startText -> $endText"),
          trailing: IconButton(
              icon: const Icon(Icons.delete, color: AppColors.error),
              onPressed: () {
                setState(() => list.removeAt(e.key));
                recalculateTimes();
              }),
        ));
      }),
      const SizedBox(height: 16),
      OCPButton(
          text: "Aj Compteur",
          icon: Icons.add,
          isSecondary: true,
          onPressed: () => _showAddCounterDialog(onAdd))
    ]);
  }

  void _showAddCounterDialog(Function(Counter) onAdd) {
    Poste? poste;
    String start = '';
    String end = '';
    bool startDefect = false;
    bool endDefect = false;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setDs) => AlertDialog(
                  title: const Text("Aj Compteur"),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<Poste>(
                        hint: const Text("Poste"),
                        items: Poste.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(posteToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => poste = v)),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              decoration:
                                  const InputDecoration(labelText: "Début"),
                              keyboardType: TextInputType.number,
                              enabled: !startDefect,
                              controller: startDefect
                                  ? TextEditingController(text: 'Défaut')
                                  : null,
                              onChanged: (v) => start = v),
                        ),
                        Column(
                          children: [
                            Checkbox(
                                value: startDefect,
                                onChanged: (v) => setDs(() {
                                      startDefect = v ?? false;
                                      if (startDefect) start = '';
                                    })),
                            // Using a hardcoded string or a helper if l10n unavailable in State
                            // Assuming 'Défaut' is okay or reusing existing label if possible.
                            // The context here is ActivityScreenState, I can access context but maybe not l10n easily if it's not passed,
                            // but I can try AppLocalizations.of(context).defautLabel
                            const Text("Défaut",
                                style: TextStyle(fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                              decoration:
                                  const InputDecoration(labelText: "Fin"),
                              keyboardType: TextInputType.number,
                              enabled: !endDefect,
                              controller: endDefect
                                  ? TextEditingController(text: 'Défaut')
                                  : null,
                              onChanged: (v) => end = v),
                        ),
                        Column(
                          children: [
                            Checkbox(
                                value: endDefect,
                                onChanged: (v) => setDs(() {
                                      endDefect = v ?? false;
                                      if (endDefect) end = '';
                                    })),
                            const Text("Défaut",
                                style: TextStyle(fontSize: 10)),
                          ],
                        )
                      ],
                    ),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Annuler")),
                    ElevatedButton(
                        onPressed: (poste != null)
                            ? () {
                                onAdd(Counter(
                                    id: const Uuid().v4(),
                                    poste: poste,
                                    start: start,
                                    end: end,
                                    startDefect: startDefect,
                                    endDefect: endDefect));
                                recalculateTimes();
                                Navigator.pop(context);
                              }
                            : null,
                        child: const Text("Ajouter"))
                  ],
                )));
  }

  // --- Step 4: Stock ---
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

  // --- Step 5: Verification ---
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
                _row('T H.V:',
                    formatMinutesToHoursMinutes(totalVibratorMinutes)),
                _row(
                    'T H.L:', formatMinutesToHoursMinutes(totalLiaisonMinutes)),
                const SizedBox(height: 8),
                _row('T Nr.A:', stops.length.toString()),
                _row('T Nr.V:', vibratorCounters.length.toString()),
                _row('T Nr.L:', liaisonCounters.length.toString()),
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
        if (vibratorCounters.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compteurs Vibreurs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  ...vibratorCounters.map((counter) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                            'Poste: ${counter.poste != null ? posteToString(counter.poste) : '-'} | '
                            'Début: ${counter.start.isNotEmpty ? counter.start : '-'} | '
                            'Fin: ${counter.end.isNotEmpty ? counter.end : '-'} '),
                      )),
                ],
              ),
            ),
          ),
        ],
        if (liaisonCounters.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Compteurs Liaison',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(height: 16),
                  ...liaisonCounters.map((counter) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          'Poste: ${counter.poste != null ? posteToString(counter.poste) : '-'} | '
                          'Début: ${counter.start.isNotEmpty ? counter.start : '-'} | '
                          'Fin: ${counter.end.isNotEmpty ? counter.end : '-'}',
                        ),
                      )),
                ],
              ),
            ),
          ),
        ],
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
                      'nature': s.nature,
                      'location': s.location,
                      'startTime': s.startTime,
                      'endTime': s.endTime,
                      'Lieu': s.location,
                      'Début': s.startTime,
                      'Fin': s.endTime,
                      'Catégorie': '',
                    })
                .toList(),
            'vibrator Counters': vibratorCounters
                .map((c) => {
                      'id': c.id,
                      'poste': c.poste?.index,
                      'start': c.start,
                      'end': c.end
                    })
                .toList(),
            'liaison Counters': liaisonCounters
                .map((c) => {
                      'id': c.id,
                      'poste': c.poste?.index,
                      'start': c.start,
                      'end': c.end
                    })
                .toList(),
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
            'T Nr.V': vibratorCounters.length,
            'T Nr.L': liaisonCounters.length,
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
