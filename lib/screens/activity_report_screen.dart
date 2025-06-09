import 'package:flutter/material.dart';
import 'dart:math';

enum Poste { premier, deuxieme, troisieme }
enum Park { park1, park2, park3 }
enum StockType { normal, oceane, pb30 }

String posteToString(Poste? p) {
  switch (p) {
    case Poste.premier:
      return "1er";
    case Poste.deuxieme:
      return "2ème";
    case Poste.troisieme:
      return "3ème";
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

class LiaisonCounter extends Counter {
  LiaisonCounter({required String id, Poste? poste, String start = '', String end = '', String? error})
    : super(id: id, poste: poste, start: start, end: end, error: error);
}

class StockEntry {
  String id;
  Poste? poste;
  Park? park;
  StockType? type;
  String quantity;
  String startTime;
  StockEntry({required this.id, this.poste, this.park, this.type, this.quantity = '', this.startTime = ''});
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
  print('Could not parse duration: "$duration"');
  return 0;
}

String formatMinutesToHoursMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return '0h 0m';
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  return '${hours}h ${minutes}m';
}

double? validateAndParseCounterValue(String value) {
  if (value.isEmpty) return 0;
  final cleaned = value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
  if (cleaned == '' || cleaned == '.' || cleaned == ',') return null;
  return double.tryParse(cleaned);
}

const TOTAL_PERIOD_MINUTES = 24 * 60;
const MAX_HOURS_PER_POSTE = 8;

class ActivityReportScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? previousDayThirdShiftEnd;
  const ActivityReportScreen({Key? key, required this.selectedDate, this.previousDayThirdShiftEnd}) : super(key: key);

  @override
  State<ActivityReportScreen> createState() => _ActivityReportScreenState();
}

class _ActivityReportScreenState extends State<ActivityReportScreen> {
  List<Stop> stops = [Stop(id: UniqueKey().toString())];
  List<Counter> vibratorCounters = [Counter(id: UniqueKey().toString())];
  List<LiaisonCounter> liaisonCounters = [LiaisonCounter(id: UniqueKey().toString())];
  List<StockEntry> stockEntries = [StockEntry(id: UniqueKey().toString())];

  int totalDowntime = 0;
  int operatingTime = TOTAL_PERIOD_MINUTES;
  int totalVibratorMinutes = 0;
  int totalLiaisonMinutes = 0;

  Map<String, String> vibratorCounterErrors = {};
  Map<String, String> liaisonCounterErrors = {};

  bool hasVibratorErrors = false;
  bool hasLiaisonErrors = false;
  bool hasStockErrors = false;

  int _currentStep = 0;

  String _tempStopDuration = '';
  String _tempStopNature = '';
  Poste? _tempCounterPoste;
  String _tempCounterStart = '';
  String _tempCounterEnd = '';
  Poste? _tempStockPoste;
  Park? _tempStockPark;
  StockType? _tempStockType;
  String _tempStockQuantity = '';

  @override
  void initState() {
    super.initState();
    recalculateTimes();
  }

  void recalculateTimes() {
    setState(() {
      totalDowntime = stops.fold(0, (acc, s) => acc + parseDurationToMinutes(s.duration));
      operatingTime = max(TOTAL_PERIOD_MINUTES - totalDowntime, 0);

      // Validate and calculate counters (simplified)
      totalVibratorMinutes = calculateTotalCounterMinutes(vibratorCounters);
      totalLiaisonMinutes = calculateTotalCounterMinutes(liaisonCounters);

      hasVibratorErrors = false;
      hasLiaisonErrors = false;
      hasStockErrors = stockEntries.any((entry) =>
        (entry.park != null || entry.type != null || entry.quantity.isNotEmpty || entry.startTime.isNotEmpty) && entry.poste == null
      );
    });
  }

  int calculateTotalCounterMinutes(List counters) {
    double totalHours = 0;
    for (var counter in counters) {
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
    String formattedDate = "${widget.selectedDate.day.toString().padLeft(2, '0')}/"
      "${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: Text("RAPPORT D'ACTIVITÉ TNR")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: $formattedDate", style: TextStyle(color: Colors.grey[600])),
            SizedBox(height: 12),
            Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 3) {
                  setState(() {
                    _currentStep += 1;
                  });
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() {
                    _currentStep -= 1;
                  });
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: Text('Précédent'),
                        ),
                      if (_currentStep > 0)
                        SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 3 ? 'Terminer' : 'Suivant'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: Text('Arrêts'),
                  content: buildStopsSection(),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: Text('Compteurs Vibreurs'),
                  content: buildCountersSection(),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: Text('Stock'),
                  content: buildStockSection(),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                ),
              ],
            ),
            if (_currentStep == 3) ...[
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {},
                    child: Text("Enregistrer Brouillon"),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: (hasVibratorErrors || hasLiaisonErrors || hasStockErrors)
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Rapport soumis avec succès.")));
                        },
                    child: Text("Soumettre Rapport"),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildStopsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPE 1: ARRÊTS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddStopDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un arrêt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showStopsList(),
                icon: const Icon(Icons.list),
                label: const Text('Voir les arrêts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[900],
                  side: BorderSide(color: Colors.blue[900]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildCountersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPE 2: COMPTEURS',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddCounterDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un compteur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showCountersList(),
                icon: const Icon(Icons.list),
                label: const Text('Voir les compteurs'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[900],
                  side: BorderSide(color: Colors.blue[900]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildStockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPE 3: STOCK',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showAddStockDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un stock'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showStockList(),
                icon: const Icon(Icons.list),
                label: const Text('Voir les stocks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[900],
                  side: BorderSide(color: Colors.blue[900]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddStopDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un arrêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Durée (ex: 1h 30)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempStopDuration = value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nature',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempStopNature = value),
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
              if (_tempStopDuration.isNotEmpty && _tempStopNature.isNotEmpty) {
                setState(() {
                  stops.add(Stop(
                    id: UniqueKey().toString(),
                    duration: _tempStopDuration,
                    nature: _tempStopNature,
                  ));
                  _tempStopDuration = '';
                  _tempStopNature = '';
                });
                recalculateTimes();
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showStopsList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste des arrêts'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              return ListTile(
                title: Text('Durée: ${stop.duration}'),
                subtitle: Text('Nature: ${stop.nature}'),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      setState(() {
                        stops.removeAt(index);
                        recalculateTimes();
                      });
                      Navigator.pop(context);
                      _showStopsList();
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showAddCounterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un compteur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Poste>(
              value: _tempCounterPoste,
              decoration: const InputDecoration(
                labelText: 'Poste',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempCounterPoste = value),
              items: Poste.values.map((p) => DropdownMenuItem(
                value: p,
                child: Text("${posteToString(p)} Poste"),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Index début',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempCounterStart = value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Index fin',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempCounterEnd = value),
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
              if (_tempCounterPoste != null && 
                  _tempCounterStart.isNotEmpty && 
                  _tempCounterEnd.isNotEmpty) {
                setState(() {
                  vibratorCounters.add(Counter(
                    id: UniqueKey().toString(),
                    poste: _tempCounterPoste!,
                    start: _tempCounterStart,
                    end: _tempCounterEnd,
                  ));
                  _tempCounterPoste = null;
                  _tempCounterStart = '';
                  _tempCounterEnd = '';
                });
                recalculateTimes();
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showCountersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste des compteurs'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vibratorCounters.length,
            itemBuilder: (context, index) {
              final counter = vibratorCounters[index];
              return ListTile(
                title: Text('Poste: ${posteToString(counter.poste)}'),
                subtitle: Text('Début: ${counter.start} - Fin: ${counter.end}'),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      setState(() {
                        vibratorCounters.removeAt(index);
                        recalculateTimes();
                      });
                      Navigator.pop(context);
                      _showCountersList();
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _showAddStockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Poste>(
              value: _tempStockPoste,
              decoration: const InputDecoration(
                labelText: 'Poste',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempStockPoste = value),
              items: Poste.values.map((p) => DropdownMenuItem(
                value: p,
                child: Text("${posteToString(p)} Poste"),
              )).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Park>(
              value: _tempStockPark,
              decoration: const InputDecoration(
                labelText: 'PARK',
                border: OutlineInputBorder(),
              ),
              onChanged: _tempStockPoste == null ? null : (value) => 
                setState(() => _tempStockPark = value),
              items: Park.values.map((p) => DropdownMenuItem(
                value: p,
                child: Text(parkToString(p)),
              )).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<StockType>(
              value: _tempStockType,
              decoration: const InputDecoration(
                labelText: 'Type Produit',
                border: OutlineInputBorder(),
              ),
              onChanged: (_tempStockPoste == null || _tempStockPark == null) ? null : 
                (value) => setState(() => _tempStockType = value),
              items: StockType.values.map((t) => DropdownMenuItem(
                value: t,
                child: Text(stockTypeToString(t)),
              )).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Quantité',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _tempStockQuantity = value),
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
              if (_tempStockPoste != null && 
                  _tempStockPark != null && 
                  _tempStockType != null && 
                  _tempStockQuantity.isNotEmpty) {
                setState(() {
                  stockEntries.add(StockEntry(
                    id: UniqueKey().toString(),
                    poste: _tempStockPoste!,
                    park: _tempStockPark!,
                    type: _tempStockType!,
                    quantity: _tempStockQuantity,
                  ));
                  _tempStockPoste = null;
                  _tempStockPark = null;
                  _tempStockType = null;
                  _tempStockQuantity = '';
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _showStockList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste des stocks'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: stockEntries.length,
            itemBuilder: (context, index) {
              final entry = stockEntries[index];
              return ListTile(
                title: Text('Poste: ${posteToString(entry.poste)}'),
                subtitle: Text(
                  'PARK: ${parkToString(entry.park)}\n'
                  'Type: ${stockTypeToString(entry.type)}\n'
                  'Quantité: ${entry.quantity}',
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Supprimer'),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'delete') {
                      setState(() {
                        stockEntries.removeAt(index);
                      });
                      Navigator.pop(context);
                      _showStockList();
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
} 