import 'package:flutter/material.dart';

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
  _R0ReportState createState() => _R0ReportState();
}

class _R0ReportState extends State<R0Report> {
  final _formKey = GlobalKey<FormState>();
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
              ElevatedButton(
                onPressed: () {
                  // Validate and submit
                  if (_formKey.currentState?.validate() ?? false) {
                    // Submit logic here
                  }
                },
                child: const Text("Soumettre Rapport"),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 