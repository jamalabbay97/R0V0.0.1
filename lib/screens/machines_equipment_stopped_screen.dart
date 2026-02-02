import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:r0/widgets/custom_widgets.dart';
import 'package:r0/theme.dart';

class MachinesEquipmentStoppedScreen extends StatefulWidget {
  final DateTime? selectedDate;
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const MachinesEquipmentStoppedScreen({
    super.key,
    this.selectedDate,
    this.initialReport,
    this.onSave,
    this.isEditing = false,
  });

  @override
  State<MachinesEquipmentStoppedScreen> createState() =>
      _MachinesEquipmentStoppedScreenState();
}

class _MachinesEquipmentStoppedScreenState
    extends State<MachinesEquipmentStoppedScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  DateTime _selectedDate = DateTime.now();
  int _currentStep = 0;
  bool _isSaving = false;
  final List<Map<String, String>> _equipmentList = [];

  // Data
  final Map<String, Map<String, List<String>>> _equipmentData = const {
    'Camions Servitude': {
      'Camion Citerne': ['16979-A-68', '17492-A-68', 'TEXAS'],
      'Camion DCI': ['19164-A-68', '5636-A-68'],
      'Camion de Ravitaillmenet': ['1462443', '93292-D-8'],
      'Camion Grue': ['12097-A-68'],
      'Camion Nacelle': ['17080-A-68'],
      'Camion Ridelle': ['11053-A-68', '15836-A-68', '34866-A-54'],
      'Vehicule DC': ['513714'],
    },
    'Engins': {
      'Bulldozers': [
        'BULL D9R 76',
        'BULL D9R 79',
        'BULL D9R 80',
        'BULL D9R 81',
        'BULL D9R 82',
        'BULL D9R 83',
        'BULL LIB 84',
        'BULL LIB 85',
        'BULL D9R 86',
        'BULL D9R 87'
      ],
      'Camions': [
        'CAMION T24',
        'CAMION T25',
        'CAMION T26',
        'CAMION T27',
        'CAMION T28',
        'CAMION T29',
        'CAMION T30',
        'CAMION T31',
        'CAMION T32',
        'CAMION T33',
        'WABCO 13',
        'WABCO 19'
      ],
      'Chargeuses': ['CHRG 992C', 'CHRG 992K', 'CHRG 994H'],
      'Niveleuses': ['NIV 14G', 'NIV 16H', 'NIV KOM01', 'NIV KOM02'],
      'Paydozers': ['PAY CAT03', 'PAY KOM04', 'PAY KOM05'],
      'Pelle Hydraulique': ['PH365-C', 'PH5130'],
    },
    'Machines': {
      'Draglines': ['1370 W1', '1370 W2'],
      'Pelle Electrique': ['195 P1', '195 P2'],
      'Sondeuses': ['PV275-1', 'PV275-2', 'PV275-3'],
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialReport != null) {
      _selectedDate = widget.initialReport!.date;
      _loadExistingData();
    } else {
      _selectedDate = widget.selectedDate ?? DateTime.now();
    }
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;
    if (data['equipmentList'] is List) {
      _equipmentList.clear();
      for (var equipment in data['equipmentList']) {
        _equipmentList.add({
          'equipmentType': equipment['equipmentType'] ?? '',
          'Reason': equipment['Reason'] ?? ''
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ['Infos', 'Equipements', 'Verif.'];
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.isEditing
                ? "Modifier Équipements Arrêtés"
                : "Équipements Arrêtés")),
        body: Column(children: [
          OCPStepper(
              steps: steps,
              currentStep: _currentStep,
              onStepTapped: (i) => setState(() => _currentStep = i)),
          Expanded(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildStepContent())),
          _buildBottomBar(),
        ]));
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepInfos();
      case 1:
        return _buildStepEquipment();
      case 2:
        return _buildStepVerification();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    bool isLast = _currentStep == 2;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(blurRadius: 10, color: Colors.black12)
            ]),
        child: Row(children: [
          if (_currentStep > 0)
            Expanded(
                child: OCPButton(
                    text: 'Précédent',
                    onPressed: () => setState(() => _currentStep--),
                    isSecondary: true)),
          if (_currentStep > 0) const SizedBox(width: 16),
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
                  isLoading: _isSaving && isLast))
        ]));
  }

  Widget _buildStepInfos() {
    return OCPCard(
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
              style: const TextStyle(fontWeight: FontWeight.bold))
        ]));
  }

  Widget _buildStepEquipment() {
    return Column(children: [
      ..._equipmentList.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            leading: const Icon(Icons.build, color: AppColors.primary),
            title: Text(e.value['equipmentType'] ?? ''),
            subtitle: Text(e.value['Reason'] ?? ''),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () =>
                    setState(() => _equipmentList.removeAt(e.key))),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Équipement",
          icon: Icons.add,
          isSecondary: true,
          onPressed: _showAddEquipmentDialog),
    ]);
  }

  void _showAddEquipmentDialog() {
    String? mainCat;
    String? subCat;
    String? equip;
    String reason = '';

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setDs) => AlertDialog(
                    title: const Text("Ajouter Équipement"),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<String>(
                          hint: const Text("Catégorie"),
                          isExpanded: true,
                          items: _equipmentData.keys
                              .map((k) =>
                                  DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: (v) => setDs(() {
                                mainCat = v;
                                subCat = null;
                                equip = null;
                              }),
                          initialValue: mainCat),
                      const SizedBox(height: 16),
                      if (mainCat != null)
                        DropdownButtonFormField<String>(
                            key: ValueKey(mainCat),
                            hint: const Text("Sous-catégorie"),
                            isExpanded: true,
                            items: _equipmentData[mainCat]!
                                .keys
                                .map((k) =>
                                    DropdownMenuItem(value: k, child: Text(k)))
                                .toList(),
                            onChanged: (v) => setDs(() {
                                  subCat = v;
                                  equip = null;
                                }),
                            initialValue: subCat),
                      const SizedBox(height: 16),
                      if (subCat != null)
                        DropdownButtonFormField<String>(
                            key: ValueKey(subCat),
                            hint: const Text("Equipement"),
                            isExpanded: true,
                            items: _equipmentData[mainCat]![subCat]!
                                .map((k) =>
                                    DropdownMenuItem(value: k, child: Text(k)))
                                .toList(),
                            onChanged: (v) => setDs(() => equip = v),
                            initialValue: equip),
                      const SizedBox(height: 16),
                      TextField(
                          decoration:
                              const InputDecoration(labelText: "Raison"),
                          maxLines: 2,
                          onChanged: (v) => setDs(() => reason = v)),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Annuler")),
                      ElevatedButton(
                          onPressed: (equip != null && reason.isNotEmpty)
                              ? () {
                                  setState(() => _equipmentList.add({
                                        'equipmentType':
                                            "$mainCat - $subCat - $equip",
                                        'Reason': reason
                                      }));
                                  Navigator.pop(context);
                                }
                              : null,
                          child: const Text("Ajouter"))
                    ])));
  }

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
      const SizedBox(height: 16),
      const Align(
          alignment: Alignment.centerLeft,
          child: Text("Équipements Arrêtés:",
              style: TextStyle(fontWeight: FontWeight.bold))),
      const SizedBox(height: 8),
      ..._equipmentList.map((e) => OCPCard(
              child: ListTile(
            leading: const Icon(Icons.build, color: AppColors.primary),
            title: Text(e['equipmentType'] ?? ''),
            subtitle: Text(e['Reason'] ?? ''),
          ))),
    ]);
  }

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
      ]));

  Future<void> _saveReport() async {
    if (_equipmentList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.addAtLeastOneEquipment),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final report = Report(
        id: widget.initialReport?.id,
        description: 'Machine/Engin Arrêtés',
        date: _selectedDate,
        type: 'Machine/Engin Arrêtés',
        group: 'Machines Equipment',
        additionalData: {'equipmentList': _equipmentList},
      );

      if (widget.isEditing && widget.onSave != null) {
        widget.onSave!(report);
      } else {
        await _databaseHelper.insertReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(AppLocalizations.of(context)!.reportSaved),
              backgroundColor: AppColors.success));
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingReport),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
