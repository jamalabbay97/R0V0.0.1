import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:r0_app/models/report.dart';
import 'package:r0_app/services/database_helper.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

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
  LiaisonCounter({required super.id, super.poste, super.start, super.end, super.error});
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
  if (kDebugMode) {
    print('Could not parse duration: "$duration"');
  }
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

class ActivityReportScreen extends StatefulWidget {
  final DateTime selectedDate;
  final String? previousDayThirdShiftEnd;
  const ActivityReportScreen({super.key, required this.selectedDate, this.previousDayThirdShiftEnd});

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
    stops = [];
    vibratorCounters = [];
    liaisonCounters = [];
    stockEntries = [];
    recalculateTimes();
  }

  void recalculateTimes() {
    setState(() {
      totalDowntime = stops.fold(0, (acc, s) => acc + parseDurationToMinutes(s.duration));
      operatingTime = max(ActivityReportScreen.totalPeriodMinutes - totalDowntime, 0);

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

  Future<void> _saveReport() async {
    try {
      final report = Report(
        description: 'Activity Report - ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}',
        date: widget.selectedDate,
        group: 'Activity',
        type: 'activity_report',
        additionalData: {
          'stops': stops.map((stop) => {
            'id': stop.id,
            'duration': stop.duration,
            'nature': stop.nature,
          }).toList(),
          'vibratorCounters': vibratorCounters.map((counter) => {
            'id': counter.id,
            'poste': counter.poste?.index,
            'start': counter.start,
            'end': counter.end,
          }).toList(),
          'liaisonCounters': liaisonCounters.map((counter) => {
            'id': counter.id,
            'poste': counter.poste?.index,
            'start': counter.start,
            'end': counter.end,
          }).toList(),
          'stockEntries': stockEntries.map((entry) => {
            'id': entry.id,
            'poste': entry.poste?.index,
            'park': entry.park?.index,
            'type': entry.type?.index,
            'quantity': entry.quantity,
            'startTime': entry.startTime,
          }).toList(),
          'totalDowntime': totalDowntime,
          'operatingTime': operatingTime,
          'totalVibratorMinutes': totalVibratorMinutes,
          'totalLiaisonMinutes': totalLiaisonMinutes,
        },
      );

      await _databaseHelper.insertReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reportSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSavingReport)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = "${widget.selectedDate.day.toString().padLeft(2, '0')}/"
      "${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("RAPPORT D'ACTIVITÉ TNR")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Date: $formattedDate", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Stepper(
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 4) {
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
                          child: const Text('Précédent'),
                        ),
                      if (_currentStep > 0)
                        const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 4 ? 'Terminer' : 'Suivant'),
                      ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Arrêts'),
                  content: buildStopsSection(),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Compteurs Vibreurs'),
                  content: buildCountersSection(),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Compteurs Liaison'),
                  content: buildLiaisonCountersSection(),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Stock'),
                  content: buildStockSection(),
                  isActive: _currentStep >= 3,
                  state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Vérification'),
                  content: buildVerificationSection(),
                  isActive: _currentStep >= 4,
                  state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                ),
              ],
            ),
            if (_currentStep == 4) ...[
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton(
                    onPressed: (hasVibratorErrors || hasLiaisonErrors || hasStockErrors)
                      ? null
                      : _saveReport,
                    child: const Text("Soumettre Rapport"),
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
          'ÉTAPE 2: COMPTEURS VIBREURS',
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

  Widget buildLiaisonCountersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPE 3: COMPTEURS LIAISON',
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
                onPressed: () => _showAddLiaisonCounterDialog(),
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
                onPressed: () => _showLiaisonCountersList(),
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
          'ÉTAPE 4: STOCK',
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

  Widget buildVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ÉTAPE 5: VÉRIFICATION',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => _showVerificationDialog(),
          icon: const Icon(Icons.visibility),
          label: const Text("Voir tous les détails"),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ],
    );
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vérification des données'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryRow('Temps d\'arrêt total:', formatMinutesToHoursMinutes(totalDowntime)),
                      _buildSummaryRow('Temps de fonctionnement:', formatMinutesToHoursMinutes(operatingTime)),
                      _buildSummaryRow('Temps vibreurs:', formatMinutesToHoursMinutes(totalVibratorMinutes)),
                      _buildSummaryRow('Temps liaison:', formatMinutesToHoursMinutes(totalLiaisonMinutes)),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Nombre d\'arrêts:', stops.length.toString()),
                      _buildSummaryRow('Nombre de compteurs vibreurs:', vibratorCounters.length.toString()),
                      _buildSummaryRow('Nombre de compteurs liaison:', liaisonCounters.length.toString()),
                      _buildSummaryRow('Nombre d\'entrées stock:', stockEntries.length.toString()),
                    ],
                  ),
                ),
              ),
              if (hasVibratorErrors || hasLiaisonErrors || hasStockErrors) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.red[50],
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
                            color: Colors.red[900],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (hasVibratorErrors)
                          Text('• Erreurs dans les compteurs vibreurs', style: TextStyle(color: Colors.red[900])),
                        if (hasLiaisonErrors)
                          Text('• Erreurs dans les compteurs liaison', style: TextStyle(color: Colors.red[900])),
                        if (hasStockErrors)
                          Text('• Erreurs dans les entrées stock', style: TextStyle(color: Colors.red[900])),
                      ],
                    ),
                  ),
                ),
              ],
            ],
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
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
                hintText: 'Maximum 20 caractères par ligne',
              ),
              maxLines: 5,
              onChanged: (value) {
                // Split text into lines of max 20 characters
                final words = value.split(' ');
                final lines = <String>[];
                String currentLine = '';
                
                for (var word in words) {
                  if (('$currentLine $word').trim().length <= 20) {
                    currentLine += (currentLine.isEmpty ? '' : ' ') + word;
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
                
                setState(() => _tempStopNature = lines.join('\n'));
              },
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
                  icon: const Icon(Icons.more_horiz, size: 20),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  position: PopupMenuPosition.under,
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      _showEditStopDialog(stop, index);
                    } else if (value == 'delete') {
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

  void _showEditStopDialog(Stop stop, int index) {
    _tempStopDuration = stop.duration;
    _tempStopNature = stop.nature;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'arrêt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Durée (ex: 1h 30)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _tempStopDuration),
              onChanged: (value) => setState(() => _tempStopDuration = value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nature',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _tempStopNature),
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
                  stops[index] = Stop(
                    id: stop.id,
                    duration: _tempStopDuration,
                    nature: _tempStopNature,
                  );
                  _tempStopDuration = '';
                  _tempStopNature = '';
                });
                recalculateTimes();
                Navigator.pop(context);
                _showStopsList();
              }
            },
            child: const Text('Enregistrer'),
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
                  icon: const Icon(Icons.more_horiz, size: 20),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  position: PopupMenuPosition.under,
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      _showEditCounterDialog(counter, index);
                    } else if (value == 'delete') {
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

  void _showEditCounterDialog(Counter counter, int index) {
    _tempCounterPoste = counter.poste;
    _tempCounterStart = counter.start;
    _tempCounterEnd = counter.end;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le compteur'),
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
              controller: TextEditingController(text: _tempCounterStart),
              onChanged: (value) => setState(() => _tempCounterStart = value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Index fin',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _tempCounterEnd),
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
                  vibratorCounters[index] = Counter(
                    id: counter.id,
                    poste: _tempCounterPoste!,
                    start: _tempCounterStart,
                    end: _tempCounterEnd,
                  );
                  _tempCounterPoste = null;
                  _tempCounterStart = '';
                  _tempCounterEnd = '';
                });
                recalculateTimes();
                Navigator.pop(context);
                _showCountersList();
              }
            },
            child: const Text('Enregistrer'),
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
              onChanged: (value) => setState(() => _tempStockPark = value),
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
              onChanged: (value) => setState(() => _tempStockType = value),
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
                  icon: const Icon(Icons.more_horiz, size: 20),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  position: PopupMenuPosition.under,
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      _showEditStockDialog(entry, index);
                    } else if (value == 'delete') {
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

  void _showEditStockDialog(StockEntry entry, int index) {
    _tempStockPoste = entry.poste;
    _tempStockPark = entry.park;
    _tempStockType = entry.type;
    _tempStockQuantity = entry.quantity;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le stock'),
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
              onChanged: (value) => setState(() => _tempStockPark = value),
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
              onChanged: (value) => setState(() => _tempStockType = value),
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
              controller: TextEditingController(text: _tempStockQuantity),
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
                  stockEntries[index] = StockEntry(
                    id: entry.id,
                    poste: _tempStockPoste!,
                    park: _tempStockPark!,
                    type: _tempStockType!,
                    quantity: _tempStockQuantity,
                  );
                  _tempStockPoste = null;
                  _tempStockPark = null;
                  _tempStockType = null;
                  _tempStockQuantity = '';
                });
                Navigator.pop(context);
                _showStockList();
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showAddLiaisonCounterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un compteur liaison'),
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
                  liaisonCounters.add(LiaisonCounter(
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

  void _showLiaisonCountersList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste des compteurs liaison'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: liaisonCounters.length,
            itemBuilder: (context, index) {
              final counter = liaisonCounters[index];
              return ListTile(
                title: Text('Poste: ${posteToString(counter.poste)}'),
                subtitle: Text('Début: ${counter.start} - Fin: ${counter.end}'),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  position: PopupMenuPosition.under,
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'edit',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, size: 18, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Modifier',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      height: 36,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Supprimer',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.pop(context);
                      _showEditLiaisonCounterDialog(counter, index);
                    } else if (value == 'delete') {
                      setState(() {
                        liaisonCounters.removeAt(index);
                        recalculateTimes();
                      });
                      Navigator.pop(context);
                      _showLiaisonCountersList();
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

  void _showEditLiaisonCounterDialog(LiaisonCounter counter, int index) {
    _tempCounterPoste = counter.poste;
    _tempCounterStart = counter.start;
    _tempCounterEnd = counter.end;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le compteur liaison'),
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
              controller: TextEditingController(text: _tempCounterStart),
              onChanged: (value) => setState(() => _tempCounterStart = value),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Index fin',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: _tempCounterEnd),
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
                  liaisonCounters[index] = LiaisonCounter(
                    id: counter.id,
                    poste: _tempCounterPoste!,
                    start: _tempCounterStart,
                    end: _tempCounterEnd,
                  );
                  _tempCounterPoste = null;
                  _tempCounterStart = '';
                  _tempCounterEnd = '';
                });
                recalculateTimes();
                Navigator.pop(context);
                _showLiaisonCountersList();
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
} 