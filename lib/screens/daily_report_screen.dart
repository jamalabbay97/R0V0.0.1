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
        title: const Text('Daily Report TSUD'),
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
  int _currentStep = 0;
  DateTime selectedDate = DateTime.now();

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
    String tempDuration = '';
    String tempNature = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ajouter un arrêt - Module $module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Durée (ex: 1h 30)',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => tempDuration = value,
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
                  if ((currentLine + ' ' + word).trim().length <= 20) {
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
                
                tempNature = lines.join('\n');
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
              if (tempDuration.isNotEmpty && tempNature.isNotEmpty) {
    setState(() {
      if (module == 1) {
                    module1Stops.add(ModuleStop(
                      id: uuid.v4(),
                      duration: tempDuration,
                      nature: tempNature,
                    ));
      } else {
                    module2Stops.add(ModuleStop(
                      id: uuid.v4(),
                      duration: tempDuration,
                      nature: tempNature,
                    ));
      }
      _calculateTotals();
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
                        child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                    if (_currentStep > 0)
                      const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 3 ? AppLocalizations.of(context)!.save : 'Suivant'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Date du Rapport'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sélectionnez la date du rapport',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: const TextStyle(fontSize: 18),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: _pickDate,
                      ),
                    ),
                  ],
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('Module 1 - Arrêts'),
                content: buildModuleStops(1, module1Stops),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('Module 2 - Arrêts'),
                content: buildModuleStops(2, module2Stops),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: const Text('Totaux Fonctionnement'),
                content: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement save draft functionality
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('Enregistrer Brouillon'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                // TODO: Implement submit report functionality
                              },
                              icon: const Icon(Icons.send),
                              label: const Text('Soumettre Rapport'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            color: Colors.grey.shade100,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Temps de Fonctionnement (24h - Arrêts)',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Module 1',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatMinutesToHoursMinutes(module1OperatingTime),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Arrêts: ${formatMinutesToHoursMinutes(module1TotalDowntime)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Module 2',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              formatMinutesToHoursMinutes(module2OperatingTime),
                                              style: const TextStyle(
                                                fontSize: 18,
                                                color: Colors.green,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Arrêts: ${formatMinutesToHoursMinutes(module2TotalDowntime)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                isActive: _currentStep >= 3,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildModuleStops(int module, List<ModuleStop> stops) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Module $module - Arrêts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => addStop(module),
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
                onPressed: () => _showStopsList(module, stops),
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

  void _showStopsList(int module, List<ModuleStop> stops) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Liste des arrêts - Module $module'),
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
                      _showEditStopDialog(module, stop);
                    } else if (value == 'delete') {
                      setState(() {
                        deleteStop(module, stop.id);
                      });
                      Navigator.pop(context);
                      _showStopsList(module, stops);
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

  void _showEditStopDialog(int module, ModuleStop stop) {
    String tempDuration = stop.duration;
    String tempNature = stop.nature;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier l\'arrêt - Module $module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Durée (ex: 1h 30)',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: tempDuration),
              onChanged: (value) => tempDuration = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Nature',
                border: OutlineInputBorder(),
                hintText: 'Maximum 20 caractères par ligne',
              ),
              controller: TextEditingController(text: tempNature),
              maxLines: 5,
              onChanged: (value) {
                // Split text into lines of max 20 characters
                final words = value.split(' ');
                final lines = <String>[];
                String currentLine = '';
                
                for (var word in words) {
                  if ((currentLine + ' ' + word).trim().length <= 20) {
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
                
                tempNature = lines.join('\n');
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
              if (tempDuration.isNotEmpty && tempNature.isNotEmpty) {
                setState(() {
                  updateStop(module, stop.id, 'duration', tempDuration);
                  updateStop(module, stop.id, 'nature', tempNature);
                  _calculateTotals();
                });
                Navigator.pop(context);
                _showStopsList(module, module == 1 ? module1Stops : module2Stops);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
} 