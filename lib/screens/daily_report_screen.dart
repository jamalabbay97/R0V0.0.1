import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class ModuleStop {
  final String id;
  String duration;
  String nature;

  ModuleStop({required this.id, this.duration = '', this.nature = ''});
}

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rapport Journalier TSUD')),
      body: DailyReport(selectedDate: DateTime.now()),
    );
  }
}

class DailyReport extends StatefulWidget {
  final DateTime selectedDate;

  const DailyReport({super.key, required this.selectedDate});

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

  @override
  void initState() {
    super.initState();
    _calculateTotals();
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

  @override
  Widget build(BuildContext context) {
    String formattedDate =
        "${widget.selectedDate.day.toString().padLeft(2, '0')}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}";

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
                  initialValue: stop.duration,
                  decoration: const InputDecoration(hintText: "ex: 1h 30"),
                  onChanged: (val) {
                    updateStop(module, stop.id, 'duration', val);
                  },
                )),
                DataCell(TextFormField(
                  initialValue: stop.nature,
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

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rapport Journalier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              // Form fields
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Entrée'),
                      onChanged: (v) => setState(() => entree = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Secteur'),
                      onChanged: (v) => setState(() => secteur = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Rapport (R°)'),
                      onChanged: (v) => setState(() => rapportNo = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(labelText: 'Machine / Engins'),
                      onChanged: (v) => setState(() => machineEngins = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                      // Enregistrer Brouillon logic
                    },
                    child: const Text('Enregistrer Brouillon'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Soumettre Rapport logic
                    },
                    child: const Text('Soumettre Rapport'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
} 