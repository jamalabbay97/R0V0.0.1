import 'package:flutter/material.dart';
// import 'package:r0/l10n/app_localizations.dart'; // Unused
import 'package:uuid/uuid.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:intl/intl.dart';
import 'package:r0/theme.dart';
import 'package:r0/widgets/custom_widgets.dart';

// --- Models & Enums ---
class ModuleStop {
  final String id;
  String duration;
  String nature;
  String stopType;
  String stopLocation;
  String startTime;
  String endTime;

  ModuleStop(
      {required this.id,
      this.duration = '',
      this.nature = '',
      this.stopType = '',
      this.stopLocation = '',
      this.startTime = '',
      this.endTime = ''});
}

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

class DailyStockEntry {
  String id;
  Poste? poste;
  Park? park;
  StockType? type;
  String quantity;
  DailyStockEntry(
      {required this.id, this.poste, this.park, this.type, this.quantity = ''});
}

// --- Helper Functions ---
int parseDurationToMinutes(String duration) {
  if (duration.isEmpty) return 0;
  final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
  // Simplified parsing logic
  try {
    if (cleaned.contains('h')) {
      final parts = cleaned.split('h');
      int h = int.parse(parts[0]);
      int m = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;
      return h * 60 + m;
    }
    return int.parse(cleaned);
  } catch (_) {
    return 0;
  }
}

String formatMinutesToHoursMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return "0h 00m";
  int hours = totalMinutes ~/ 60;
  int minutes = totalMinutes % 60;
  return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
}

// --- Screen ---
class DailyReportScreen extends StatefulWidget {
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const DailyReportScreen(
      {super.key, this.initialReport, this.onSave, this.isEditing = false});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  static const totalPeriodMinutes = 24 * 60;
  final _databaseHelper = DatabaseHelper();

  DateTime _selectedDate = DateTime.now();

  List<ModuleStop> module1Stops = [];
  List<ModuleStop> module2Stops = [];
  List<DailyStockEntry> stockEntries = [];

  int module1TotalDowntime = 0;
  int module2TotalDowntime = 0;
  int module1OperatingTime = totalPeriodMinutes;
  int module2OperatingTime = totalPeriodMinutes;

  int _currentStep = 0;
  bool _isSaving = false;

  static const Map<String, String> _stopTypes = {
    'AEXT': 'Arrêts Extérieures',
    'AE': 'Arrêts Électrique',
    'AM': 'Arrêts Mécanique',
    'AI': "Arrêts d'Installation",
    'MP': 'Manque Produit',
    'DEC': 'décolmatage',
    'CC': 'coupure de courant',
    'VID': 'vidange',
    'AEXP': "Arrêts d'Exploitation",
    'AD': 'Arrêts Décidés',
    'NET': 'nettoyage',
    'aut': 'aut',
    'STS': 'stock saturée',
    'DS': 'dégagement stérile',
    'AESYS': 'Arrêts Entretien systématique',
    'surch': 'surcharge',
  };

  static const Map<int, Map<String, String>> _moduleLocations = {
    1: {
      'M1_TR01': 'Tremie',
      'M1_VIB01': 'Vibreur 01',
      'M1_VIB02': 'Vibreur 02',
      'M1_CV73': 'Convoyeur 73',
      'M1_cv77': 'Convoyeur 77',
      'M1_CRIBLE1': 'Crible 01',
      'M1_CV84': 'Convoyeur 84',
      'M1_CV86': 'Convoyeur 86',
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
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialReport != null) {
      _selectedDate = widget.initialReport!.date;
      _loadExistingData();
    }
    _calculateTotals();
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;

    if (data['module1Stops'] is List) {
      module1Stops = (data['module1Stops'] as List)
          .map((s) => ModuleStop(
              id: s['id'] ?? const Uuid().v4(),
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? '',
              stopType: s['stopType'] ?? '',
              stopLocation: s['stopLocation'] ?? '',
              startTime: s['startTime'] ?? '',
              endTime: s['endTime'] ?? ''))
          .toList();
    }
    if (data['module2Stops'] is List) {
      module2Stops = (data['module2Stops'] as List)
          .map((s) => ModuleStop(
              id: s['id'] ?? const Uuid().v4(),
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? '',
              stopType: s['stopType'] ?? '',
              stopLocation: s['stopLocation'] ?? '',
              startTime: s['startTime'] ?? '',
              endTime: s['endTime'] ?? ''))
          .toList();
    }
    if (data['stock'] is List) {
      stockEntries = (data['stock'] as List)
          .map((s) => DailyStockEntry(
              id: s['id'] ?? const Uuid().v4(),
              poste: _parsePoste(s['poste']),
              park: _parsePark(s['park']),
              type: _parseStockType(s['type']),
              quantity: s['quantity'] ?? ''))
          .toList();
    }
  }

  Poste? _parsePoste(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < Poste.values.length) {
      return Poste.values[idx];
    }
    return null;
  }

  Park? _parsePark(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < Park.values.length) {
      return Park.values[idx];
    }
    return null;
  }

  StockType? _parseStockType(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < StockType.values.length) {
      return StockType.values[idx];
    }
    return null;
  }

  void _calculateTotals() {
    setState(() {
      module1TotalDowntime = module1Stops.fold(
          0, (acc, s) => acc + parseDurationToMinutes(s.duration));
      module2TotalDowntime = module2Stops.fold(
          0, (acc, s) => acc + parseDurationToMinutes(s.duration));

      module1OperatingTime = (totalPeriodMinutes - module1TotalDowntime)
          .clamp(0, totalPeriodMinutes);
      module2OperatingTime = (totalPeriodMinutes - module2TotalDowntime)
          .clamp(0, totalPeriodMinutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Localizations handled naively or assume English/French provided context
    final title =
        widget.isEditing ? 'Modifier Daily Report TSUD' : 'Daily Report TSUD';
    final steps = ['Infos', 'Arrêts M1', 'Arrêts M2', 'Stock', 'Verif.'];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                      child: _buildStepContent())),
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
        return _buildStepArrets(1, module1Stops);
      case 2:
        return _buildStepArrets(2, module2Stops);
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
    return Column(children: [
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
    ]);
  }

  // --- Step 1 & 2: Arrêts ---
  Widget _buildStepArrets(int module, List<ModuleStop> stops) {
    return Column(children: [
      Text("Module $module",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppColors.primary)),
      const SizedBox(height: 16),
      if (stops.isEmpty)
        const Text("Aucun arrêt enregistré.",
            style: TextStyle(color: Colors.grey)),
      ...stops.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(e.value.stopType.isNotEmpty
                ? '${e.value.stopType} • ${e.value.stopLocation}'
                : e.value.nature),
            subtitle: Text(e.value.startTime.isNotEmpty &&
                    e.value.endTime.isNotEmpty
                ? 'De ${e.value.startTime} à ${e.value.endTime} • ${formatMinutesToHoursMinutes(parseDurationToMinutes(e.value.duration))}'
                : "Durée: ${formatMinutesToHoursMinutes(parseDurationToMinutes(e.value.duration))}"),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () {
                  setState(() {
                    stops.removeAt(e.key);
                    _calculateTotals();
                  });
                }),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Arrêt (Module $module)",
          icon: Icons.add,
          isSecondary: true,
          onPressed: () => _showAddStopDialog(module))
    ]);
  }

  void _showAddStopDialog(int module) {
    int step = 0;
    String? selectedType;
    String? selectedLocation;
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now().add(const Duration(minutes: 1));
    final locations = _moduleLocations[module] ?? const <String, String>{};
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (context, setDs) {
                Widget content;
                if (step == 0) {
                  content = DropdownButtonFormField<String>(
                    hint: const Text("Type d'arrêt"),
                    initialValue: selectedType,
                    isExpanded: true,
                    items: _stopTypes.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text('${entry.key} - ${entry.value}')))
                        .toList(),
                    onChanged: (value) => setDs(() {
                      selectedType = value;
                    }),
                  );
                } else if (step == 1) {
                  content = DropdownButtonFormField<String>(
                    hint: const Text("Lieu d'arrêt"),
                    initialValue: selectedLocation,
                    isExpanded: true,
                    items: locations.entries
                        .map((entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text('${entry.key} - ${entry.value}')))
                        .toList(),
                    onChanged: (value) => setDs(() {
                      selectedLocation = value;
                    }),
                  );
                } else {
                  content = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                          title: const Text('Heure début'),
                          subtitle: Text(_formatTime(startTime)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(startTime),
                                builder: (context, child) => MediaQuery(
                                    data: MediaQuery.of(context)
                                        .copyWith(alwaysUse24HourFormat: true),
                                    child: child ?? const SizedBox()));
                            if (picked != null) {
                              setDs(() {
                                startTime = DateTime(
                                    startTime.year,
                                    startTime.month,
                                    startTime.day,
                                    picked.hour,
                                    picked.minute);
                              });
                            }
                          }),
                      ListTile(
                          title: const Text('Heure fin'),
                          subtitle: Text(_formatTime(endTime)),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(endTime),
                                builder: (context, child) => MediaQuery(
                                    data: MediaQuery.of(context)
                                        .copyWith(alwaysUse24HourFormat: true),
                                    child: child ?? const SizedBox()));
                            if (picked != null) {
                              setDs(() {
                                endTime = DateTime(endTime.year, endTime.month,
                                    endTime.day, picked.hour, picked.minute);
                              });
                            }
                          }),
                    ],
                  );
                }

                return AlertDialog(
                  title: Text("Ajouter Arrêt - Module $module"),
                  content: SizedBox(
                    width: 340,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step == 0
                              ? "Sélection du type d'arrêt"
                              : step == 1
                                  ? "Sélection du lieu d'arrêt"
                                  : 'Saisie des heures',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        content,
                      ],
                    ),
                  ),
                  actions: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (step > 0)
                          TextButton(
                              onPressed: () => setDs(() => step--),
                              child: const Text('Précédent'))
                        else
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler')),
                        if ((step == 0 && selectedType != null) ||
                            (step == 1 && selectedLocation != null))
                          ElevatedButton(
                              onPressed: () => setDs(() => step++),
                              child: const Text('Suivant')),
                        if (step == 2)
                          ElevatedButton(
                              onPressed: () {
                                final validation = _validateSingleStop(
                                    startTime, endTime, selectedType,
                                    selectedLocation: selectedLocation);
                                if (validation != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(validation),
                                          backgroundColor: AppColors.error));
                                  return;
                                }

                                final durationMinutes =
                                    endTime.difference(startTime).inMinutes;
                                final durationText =
                                    '${durationMinutes ~/ 60}h${(durationMinutes % 60).toString().padLeft(2, '0')}';
                                final typeLabel =
                                    '${selectedType ?? ''} - ${_stopTypes[selectedType] ?? ''}';
                                final locationLabel =
                                    '${selectedLocation ?? ''} - ${locations[selectedLocation] ?? ''}';
                                setState(() {
                                  final stop = ModuleStop(
                                      id: const Uuid().v4(),
                                      duration: durationText,
                                      nature: '$typeLabel | $locationLabel',
                                      stopType: typeLabel,
                                      stopLocation: locationLabel,
                                      startTime: _formatTime(startTime),
                                      endTime: _formatTime(endTime));
                                  if (module == 1) {
                                    module1Stops.add(stop);
                                  } else {
                                    module2Stops.add(stop);
                                  }
                                  _calculateTotals();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Ajouter'))
                      ],
                    )
                  ],
                );
              },
            ));
  }

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String? _validateSingleStop(
      DateTime startTime, DateTime endTime, String? selectedType,
      {String? selectedLocation}) {
    if (selectedType == null || selectedType.isEmpty) {
      return "Le type d'arrêt est obligatoire.";
    }
    if (selectedLocation == null || selectedLocation.isEmpty) {
      return "Le lieu d'arrêt est obligatoire.";
    }
    if (!endTime.isAfter(startTime)) {
      return "L'heure de fin doit être supérieure à l'heure de début.";
    }
    return null;
  }

  List<String> _collectVerificationErrors() {
    final errors = <String>[];
    void validateModule(int module, List<ModuleStop> stops) {
      for (var i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final start = _parseTime(stop.startTime);
        final end = _parseTime(stop.endTime);
        if (stop.stopType.isEmpty || stop.stopLocation.isEmpty) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: Type et lieu d\'arrêt obligatoires.');
        }
        if (start == null || end == null || !end.isAfter(start)) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: horaires invalides (début/fin).');
        }
      }
    }

    validateModule(1, module1Stops);
    validateModule(2, module2Stops);
    return errors;
  }

  DateTime? _parseTime(String value) {
    if (!value.contains(':')) return null;
    final split = value.split(':');
    if (split.length != 2) return null;
    final hour = int.tryParse(split[0]);
    final minute = int.tryParse(split[1]);
    if (hour == null || minute == null) return null;
    return DateTime(2000, 1, 1, hour, minute);
  }

  Widget _syntheseCard(String title, int operating, int downtime) {
    return OCPCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const Divider(),
      _row("Fonctionnement", formatMinutesToHoursMinutes(operating),
          color: AppColors.primary),
      _row("Arrêts", formatMinutesToHoursMinutes(downtime),
          color: AppColors.error),
    ]));
  }

  Widget _row(String l, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l),
        Text(v, style: TextStyle(fontWeight: FontWeight.bold, color: color))
      ]));

  // --- Step 3: Stock ---
  Widget _buildStepStock() {
    return Column(children: [
      ...stockEntries.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(
                "${posteToString(e.value.poste)} - ${parkToString(e.value.park)}"),
            subtitle:
                Text("${stockTypeToString(e.value.type)}: ${e.value.quantity}"),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () {
                  setState(() => stockEntries.removeAt(e.key));
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
                        onPressed: (poste != null &&
                                park != null &&
                                type != null)
                            ? () {
                                setState(() => stockEntries.add(DailyStockEntry(
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
    final errors = _collectVerificationErrors();
    return Column(children: [
      Icon(errors.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
          size: 64,
          color: errors.isEmpty ? AppColors.success : AppColors.error),
      const SizedBox(height: 16),
      const Text("Récapitulatif",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...errors.map((e) => Align(
            alignment: Alignment.centerLeft,
            child:
                Text('• $e', style: const TextStyle(color: AppColors.error)))),
      ],
      const SizedBox(height: 24),
      _row("Date",
          "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
      const Divider(),

      // Details Arrêts M1
      if (module1Stops.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Arrêts M1",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...module1Stops.map((s) => _row(s.nature,
            '${s.startTime} - ${s.endTime} (${formatMinutesToHoursMinutes(parseDurationToMinutes(s.duration))})')),
        const Divider(),
      ],

      // Details Arrêts M2
      if (module2Stops.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Arrêts M2",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...module2Stops.map((s) => _row(s.nature,
            '${s.startTime} - ${s.endTime} (${formatMinutesToHoursMinutes(parseDurationToMinutes(s.duration))})')),
        const Divider(),
      ],

      _syntheseCard(
          "Synthèse Module 1", module1OperatingTime, module1TotalDowntime),
      const SizedBox(height: 16),
      _syntheseCard(
          "Synthèse Module 2", module2OperatingTime, module2TotalDowntime),
      const Divider(),

      // Details Stock
      if (stockEntries.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Stock",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...stockEntries.map((e) => _row(
            "${posteToString(e.poste)} - ${parkToString(e.park)}",
            "${stockTypeToString(e.type)}: ${e.quantity}")),
        const Divider(),
      ],
    ]);
  }

  Future<void> _saveReport() async {
    final verificationErrors = _collectVerificationErrors();
    if (verificationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Corrigez les erreurs de vérification avant de sauvegarder.'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final report = Report(
        id: widget.initialReport?.id,
        description:
            'Daily TSUD - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'Daily',
        type: 'daily TSUD',
        additionalData: {
          'module1Stops': module1Stops
              .map((s) => {
                    'id': s.id,
                    'duration': s.duration,
                    'nature': s.nature,
                    'stopType': s.stopType,
                    'stopLocation': s.stopLocation,
                    'startTime': s.startTime,
                    'endTime': s.endTime,
                    'Catégorie': '',
                    'CarryOver': false,
                  })
              .toList(),
          'module2Stops': module2Stops
              .map((s) => {
                    'id': s.id,
                    'duration': s.duration,
                    'nature': s.nature,
                    'stopType': s.stopType,
                    'stopLocation': s.stopLocation,
                    'startTime': s.startTime,
                    'endTime': s.endTime,
                    'Catégorie': '',
                    'CarryOver': false,
                  })
              .toList(),
          'T H.A1': module1TotalDowntime,
          'T H.M1': module1OperatingTime,
          'T H.A2': module2TotalDowntime,
          'T H.M2': module2OperatingTime,
          'stock': stockEntries
              .map((e) => {
                    'id': e.id,
                    'poste': e.poste?.index,
                    'park': e.park?.index,
                    'type': e.type?.index,
                    'quantity': e.quantity
                  })
              .toList(),
        },
      );

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
