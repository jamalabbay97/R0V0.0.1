import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';

class ModuleStop {
  final String id;
  String duration;
  String nature;

  ModuleStop({required this.id, this.duration = '', this.nature = ''});
}

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  DateTime selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.dailyReport),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: AppLocalizations.of(context)!.date,
            onPressed: _pickDate,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: DailyReport(
          selectedDate: selectedDate,
          formKey: _formKey,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_month),
        label: Text(AppLocalizations.of(context)!.date),
      ),
    );
  }
}

class DailyReport extends StatefulWidget {
  final DateTime selectedDate;
  final GlobalKey<FormState> formKey;

  const DailyReport({
    super.key, 
    required this.selectedDate,
    required this.formKey,
  });

  @override
  DailyReportState createState() => DailyReportState();
}

class DailyReportState extends State<DailyReport> {
  static const totalPeriodMinutes = 24 * 60; // Total minutes in a day
  final uuid = Uuid();

  // Form fields
  String entree = '';
  String secteur = '';
  String rapportNo = '';
  String machineEngins = '';

  List<ModuleStop> module1Stops = [ModuleStop(id: Uuid().v4())];
  List<ModuleStop> module2Stops = [ModuleStop(id: Uuid().v4())];

  int module1TotalDowntime = 0;
  int module2TotalDowntime = 0;
  int module1OperatingTime = totalPeriodMinutes;
  int module2OperatingTime = totalPeriodMinutes;

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _calculateTotals() {
    int totalDowntime(List<ModuleStop> stops) => stops
        .map((stop) => parseDurationToMinutes(stop.duration))
        .fold(0, (a, b) => a + b);

    setState(() {
      module1TotalDowntime = totalDowntime(module1Stops);
      module2TotalDowntime = totalDowntime(module2Stops);
      module1OperatingTime = (totalPeriodMinutes - module1TotalDowntime).clamp(0, totalPeriodMinutes);
      module2OperatingTime = (totalPeriodMinutes - module2TotalDowntime).clamp(0, totalPeriodMinutes);
    });
  }

  int parseDurationToMinutes(String duration) {
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
    debugPrint('Could not parse duration: "$duration"');
    return 0;
  }

  String formatMinutesToHoursMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return "0h 0m";
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  void addStop(int module) {
    setState(() {
      if (module == 1) {
        module1Stops.add(ModuleStop(id: uuid.v4()));
      } else {
        module2Stops.add(ModuleStop(id: uuid.v4()));
      }
      _calculateTotals();
    });
  }

  void deleteStop(int module, String id) {
    setState(() {
      if (module == 1) {
        module1Stops.removeWhere((stop) => stop.id == id);
      } else {
        module2Stops.removeWhere((stop) => stop.id == id);
      }
      _calculateTotals();
    });
  }

  void updateStop(int module, String id, String field, String value) {
    setState(() {
      List<ModuleStop> stops = module == 1 ? module1Stops : module2Stops;
      for (var stop in stops) {
        if (stop.id == id) {
          if (field == 'duration') stop.duration = value;
          if (field == 'nature') stop.nature = value;
        }
      }
      _calculateTotals();
    });
  }

  void handleFieldChange(String field, String value) {
    setState(() {
      // reportData[field] = value;
    });
  }

  String? validateRequired(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est requis';
    }
    return null;
  }

  String? validateNumeric(String? value) {
    if (value == null || value.isEmpty) return null;
    if (int.tryParse(value) == null) {
      return 'Veuillez entrer un nombre valide';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildModuleStops(1, module1Stops),
          const SizedBox(height: 16),
          buildModuleStops(2, module2Stops),
          const SizedBox(height: 16),
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Totaux Temps de Fonctionnement (24h - Arrêts)',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Module 1 Fonctionnement'),
                          Text(
                              formatMinutesToHoursMinutes(
                                  module1OperatingTime),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Module 2 Fonctionnement'),
                          Text(
                              formatMinutesToHoursMinutes(
                                  module2OperatingTime),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: () {
                if (widget.formKey.currentState!.validate()) {
                  // TODO: Implement save functionality
                }
              },
              child: Text(AppLocalizations.of(context)!.save),
                ),
            ],
          )
        ],
      ),
    );
  }

  Widget buildModuleStops(int module, List<ModuleStop> stops) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Module $module - Arrêts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Ajouter Arrêt'),
              onPressed: () => addStop(module),
            ),
          ],
        ),
        DataTable(
          columns: const [
            DataColumn(label: Text('Durée')),
            DataColumn(label: Text('Nature')),
            DataColumn(label: SizedBox.shrink()),
          ],
          rows: stops.map((stop) {
            return DataRow(cells: [
              DataCell(TextFormField(
                controller: _controllers['${module}_${stop.id}_duration'],
                decoration: const InputDecoration(hintText: "ex: 1h 30"),
                onChanged: (val) {
                  updateStop(module, stop.id, 'duration', val);
                },
              )),
              DataCell(TextFormField(
                controller: _controllers['${module}_${stop.id}_nature'],
                decoration: const InputDecoration(hintText: "Nature"),
                onChanged: (val) {
                  updateStop(module, stop.id, 'nature', val);
                },
              )),
              DataCell(IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteStop(module, stop.id),
              )),
            ]);
          }).toList(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total Arrêts: ${formatMinutesToHoursMinutes(module == 1 ? module1TotalDowntime : module2TotalDowntime)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
} 