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
  ModuleStop({required this.id, this.duration = '', this.nature = ''});
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
              nature: s['nature'] ?? ''))
          .toList();
    }
    if (data['module2Stops'] is List) {
      module2Stops = (data['module2Stops'] as List)
          .map((s) => ModuleStop(
              id: s['id'] ?? const Uuid().v4(),
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? ''))
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
            title: Text(e.value.nature),
            subtitle: Text(
                "Durée: ${formatMinutesToHoursMinutes(parseDurationToMinutes(e.value.duration))}"),
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
    String duration = '';
    String nature = '';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text("Ajouter Arrêt - Module $module"),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    decoration:
                        const InputDecoration(labelText: "Durée (ex: 1h30)"),
                    onChanged: (v) => duration = v),
                const SizedBox(height: 8),
                TextField(
                    decoration: const InputDecoration(labelText: "Nature"),
                    maxLines: 3,
                    onChanged: (v) => nature = v),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Annuler")),
                ElevatedButton(
                    onPressed: () {
                      if (duration.isNotEmpty && nature.isNotEmpty) {
                        setState(() {
                          if (module == 1) {
                            module1Stops.add(ModuleStop(
                                id: const Uuid().v4(),
                                duration: duration,
                                nature: nature));
                          } else {
                            module2Stops.add(ModuleStop(
                                id: const Uuid().v4(),
                                duration: duration,
                                nature: nature));
                          }
                          _calculateTotals();
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text("Ajouter"))
              ],
            ));
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
    return Column(children: [
      const Icon(Icons.check_circle_outline,
          size: 64, color: AppColors.success),
      const SizedBox(height: 16),
      const Text("Récapitulatif",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
            formatMinutesToHoursMinutes(parseDurationToMinutes(s.duration)))),
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
            formatMinutesToHoursMinutes(parseDurationToMinutes(s.duration)))),
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
                    'Catégorie': '',
                    'CarryOver': false,
                  })
              .toList(),
          'module2Stops': module2Stops
              .map((s) => {
                    'id': s.id,
                    'duration': s.duration,
                    'nature': s.nature,
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
