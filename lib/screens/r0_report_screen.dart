import 'package:flutter/material.dart';
import 'package:r0_app/services/database_helper.dart';
import 'package:r0_app/models/report.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

// Data models
class IndexCompteurPoste {
  String debut;
  String fin;
  IndexCompteurPoste({this.debut = '', this.fin = ''});
}

class VentilationItem {
  int code;
  String label;
  String duree;
  String note;
  VentilationItem({required this.code, required this.label, this.duree = '', this.note = ''});
}

class RepartitionItem {
  String chantier;
  String temps;
  String imputation;
  RepartitionItem({this.chantier = '', this.temps = '', this.imputation = ''});
}

class R0ReportFormData {
  String entree = '';
  String secteur = '';
  String rapportNo = '';
  String machineEngins = '';
  String sa = '';
  String unite = '';
  List<IndexCompteurPoste> indexCompteurs = List.generate(3, (_) => IndexCompteurPoste());
  List<String> shifts = List.generate(3, (_) => '');
  List<VentilationItem> ventilation = [];
  String arretsExplication = '';
  Map<String, String> exploitation = {};
  List<String> bulls = List.generate(3, (_) => '');
  List<RepartitionItem> repartitionTravail = List.generate(3, (_) => RepartitionItem());
  // ... add other fields as needed
}

class R0Report extends StatefulWidget {
  final DateTime selectedDate;
  final String? previousDayThirdShiftEnd;

  R0Report({super.key, required this.selectedDate, this.previousDayThirdShiftEnd}) {
    // TODO: implement R0Report
  }

  @override
  R0ReportState createState() => R0ReportState();
}

class R0ReportState extends State<R0Report> {
  final _formKey = GlobalKey<FormState>();
  final _databaseHelper = DatabaseHelper();
  R0ReportFormData formData = R0ReportFormData();
  late DateTime _selectedDate;
  int _currentStep = 0;

  final posteOrder = const ["1er", "2ème", "3ème"];
  final posteTimes = const {
    "1er": "06:30 - 14:30",
    "2ème": "14:30 - 22:30",
    "3ème": "22:30 - 06:30",
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    // Initialize ventilation data, etc.
    formData.ventilation = [
      VentilationItem(code: 121, label: "ARRET CARREAU INDUSTRIEL"),
      // ... Add all your ventilation items here
    ];
  }

  // Example: handle input change for a text field
  void _onTextChanged(String value, void Function(String) update) {
    setState(() {
      update(value);
    });
  }

  // Example UI building for a section of the form
  Widget _buildEnteteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(labelText: "Entrée"),
          initialValue: formData.entree,
          onChanged: (v) => _onTextChanged(v, (v) => formData.entree = v),
        ),
        TextFormField(
          decoration: const InputDecoration(labelText: "Secteur"),
          initialValue: formData.secteur,
          onChanged: (v) => _onTextChanged(v, (v) => formData.secteur = v),
        ),
        // Add other TextFormFields similarly
      ],
    );
  }

  Future<void> _saveReport() async {
    try {
      final report = Report(
        description: 'R0 Report - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'R0',
        type: 'r0_report',
        additionalData: {
          'entree': formData.entree,
          'secteur': formData.secteur,
          'rapportNo': formData.rapportNo,
          'machineEngins': formData.machineEngins,
          'sa': formData.sa,
          'unite': formData.unite,
          'indexCompteurs': formData.indexCompteurs.map((ic) => {
            'debut': ic.debut,
            'fin': ic.fin,
          }).toList(),
          'shifts': formData.shifts,
          'ventilation': formData.ventilation.map((v) => {
            'code': v.code,
            'label': v.label,
            'duree': v.duree,
            'note': v.note,
          }).toList(),
          'arretsExplication': formData.arretsExplication,
          'exploitation': formData.exploitation,
          'bulls': formData.bulls,
          'repartitionTravail': formData.repartitionTravail.map((r) => {
            'chantier': r.chantier,
            'temps': r.temps,
            'imputation': r.imputation,
          }).toList(),
        },
      );

      await _databaseHelper.insertReport(report);
      if (!mounted) return;
      
      final l10n = AppLocalizations.of(context)!;
      // Show confirmation dialog
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(l10n.reportConfirmationTitle),
            content: Text(l10n.reportConfirmationMessage),
            actions: [
              TextButton(
                child: Text(l10n.done),
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to home
                },
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}";
    return Scaffold(
      appBar: AppBar(title: const Text("Rapport Journalier Détaillé (R0)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 3) {
                    setState(() {
                      _currentStep += 1;
                    });
                  } else {
                    if (_formKey.currentState?.validate() ?? false) {
                      _saveReport();
                    }
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
                          child: Text(_currentStep == 3 ? 'Terminer' : 'Suivant'),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Date du rapport'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ÉTAPE 1: DATE DU RAPPORT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "Date sélectionnée: $formattedDate",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.calendar_today),
                                      onPressed: () async {
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: _selectedDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2100),
                                        );
                                        if (picked != null && picked != _selectedDate) {
                                          setState(() {
                                            _selectedDate = picked;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('En-tête'),
                    content: _buildEnteteSection(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Ventilation'),
                    content: const Column(
                      children: [
                        // Add ventilation content here
                      ],
                    ),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Vérification'),
                    content: const Column(
                      children: [
                        // Add verification content here
                      ],
                    ),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 