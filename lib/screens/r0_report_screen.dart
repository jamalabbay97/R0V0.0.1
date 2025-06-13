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

  final posteOrder = ["1er", "2ème", "3ème"];
  final posteTimes = {
    "1er": "06:30 - 14:30",
    "2ème": "14:30 - 22:30",
    "3ème": "22:30 - 06:30",
  };

  @override
  void initState() {
    super.initState();
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
        description: 'R0 Report - ${DateFormat('yyyy-MM-dd').format(widget.selectedDate)}',
        date: widget.selectedDate,
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
    String formattedDate = "${widget.selectedDate.day}/${widget.selectedDate.month}/${widget.selectedDate.year}";
    return Scaffold(
      appBar: AppBar(title: const Text("Rapport Journalier Détaillé (R0)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(formattedDate, style: const TextStyle(fontSize: 16)),
              _buildEnteteSection(),
              // Add other sections: indexCompteurs, shifts, ventilation, etc.
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          _saveReport();
                        }
                      },
                      child: const Text("Soumettre Rapport"),
                    ),
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