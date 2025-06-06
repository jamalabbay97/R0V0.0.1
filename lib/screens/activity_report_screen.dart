import 'package:flutter/material.dart';
import 'dart:math';

enum Poste { premier, deuxieme, troisieme }
enum Park { park1, park2, park3 }
enum StockType { normal, oceane, pb30 }

class Stop {
  String id;
  String duration;
  String nature;
  Stop({required this.id, this.duration = '', this.nature = ''});
}

class Counter {
  String id;
  Poste? poste;
  String start;
  String end;
  String? error;
  Counter({required this.id, this.poste, this.start = '', this.end = '', this.error});
}

class StockEntry {
  String id;
  Poste? poste;
  Park? park;
  StockType? type;
  String quantity;
  String startTime;
  StockEntry({
    required this.id,
    this.poste,
    this.park,
    this.type,
    this.quantity = '',
    this.startTime = '',
  });
}

class ActivityReportScreen extends StatelessWidget {
  const ActivityReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RAPPORT D'ACTIVITÉ TNB")),
      body: ActivityReport(selectedDate: DateTime.now()),
    );
  }
}

class ActivityReport extends StatefulWidget {
  final DateTime selectedDate;
  final String? previousDayThirdShiftEnd;

  const ActivityReport({super.key, required this.selectedDate, this.previousDayThirdShiftEnd});

  @override
  State<ActivityReport> createState() => _ActivityReportState();
}

class _ActivityReportState extends State<ActivityReport> {
  List<Stop> stops = [Stop(id: UniqueKey().toString())];
  List<Counter> vibratorCounters = [Counter(id: UniqueKey().toString())];
  List<Counter> liaisonCounters = [Counter(id: UniqueKey().toString())];
  List<StockEntry> stockEntries = [StockEntry(id: UniqueKey().toString())];

  int totalDowntime = 0;
  int operatingTime = 24 * 60;
  int totalVibratorMinutes = 0;
  int totalLiaisonMinutes = 0;

  @override
  void initState() {
    super.initState();
    calculateDowntime();
  }

  void calculateDowntime() {
    int downtime = 0;
    for (final stop in stops) {
      downtime += parseDurationToMinutes(stop.duration);
    }
    setState(() {
      totalDowntime = downtime;
      operatingTime = max(0, 24 * 60 - downtime);
    });
  }

  int parseDurationToMinutes(String duration) {
    if (duration.isEmpty) return 0;
    final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
    int hours = 0;
    int minutes = 0;
    final match = RegExp(r'^(?:(\d{1,2})\s?[Hh:·]\s?)?(\d{1,2})$').firstMatch(cleaned);
    if (match != null) {
      hours = match.group(1) != null ? int.parse(match.group(1)!) : 0;
      minutes = int.parse(match.group(2)!);
      return hours * 60 + minutes;
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
    return 0;
  }

  String formatMinutesToHoursMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return "0h 0m";
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  Widget buildStopTable() {
    return DataTable(
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
              setState(() {
                stop.duration = val;
                calculateDowntime();
              });
            },
          )),
          DataCell(TextFormField(
            initialValue: stop.nature,
            decoration: const InputDecoration(hintText: "Nature"),
            onChanged: (val) {
              setState(() => stop.nature = val);
            },
          )),
          DataCell(IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() {
                stops.remove(stop);
                calculateDowntime();
              });
            },
          )),
        ]);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        "${widget.selectedDate.day.toString().padLeft(2, '0')}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("RAPPORT D'ACTIVITÉ TNB", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              // Stops Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Arrêts', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text("Ajouter Arrêt"),
                    onPressed: () {
                      setState(() => stops.add(Stop(id: UniqueKey().toString())));
                    },
                  ),
                ],
              ),
              buildStopTable(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  "Total Arrêts: ${formatMinutesToHoursMinutes(totalDowntime)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 32),
              // Operating Time Section
              const Text(
                'Temps de Fonctionnement (24h - Arrêts)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              ListTile(
                title: const Text("Temps de Fonctionnement Estimé"),
                subtitle: Text(
                  formatMinutesToHoursMinutes(operatingTime),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              // ... (Similarly, build out other sections: Compteurs Vibreurs, Liaison, Stock, Action Buttons)
              // This is a starting point. You would repeat a similar approach for each section,
              // converting forms and tables to appropriate Flutter widgets.
            ],
          ),
        ),
      ),
    );
  }
} 