import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:r0/screens/home_screen.dart';

class MachinesEquipmentStoppedScreen extends StatefulWidget {
  final DateTime selectedDate;

  const MachinesEquipmentStoppedScreen({
    super.key,
    required this.selectedDate,
  });

  @override
  State<MachinesEquipmentStoppedScreen> createState() => _MachinesEquipmentStoppedScreenState();
}

class _MachinesEquipmentStoppedScreenState extends State<MachinesEquipmentStoppedScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final _durationController = TextEditingController();
  
  String _selectedEquipmentType = '';
  String _selectedMainCategory = '';
  String _selectedSubCategory = '';
  String _selectedEquipment = '';
  String _stopReason = '';
  int _currentStep = 0;
  DateTime _selectedDate = DateTime.now();
  
  // List to store multiple equipment
  final List<Map<String, String>> _equipmentList = [];
  


  // Equipment data structure
  final Map<String, Map<String, List<String>>> _equipmentData = {
    'Camions Servitude': {
      'camion citerne': ['16979-A-68', '17492-A-68', 'TEXAS'],
      'camion DCI': ['19164-A-68', '5636-A-68'],
      'camion de ravitaillmenet': ['1462443', '93292-D-8'],
      'camion Grue': ['12097-A-68'],
      'camion Nacelle': ['17080-A-68'],
      'camion Ridelle': ['11053-A-68', '15836-A-68', '34866-A-54'],
      'Vehicule DC': ['513714'],
    },
    'ENGINS': {
      'BULLDOZERS': ['BULL D9R 76', 'BULL D9R 79', 'BULL D9R 80', 'BULL D9R 81', 'BULL D9R 82', 'BULL D9R 83', 'BULL LIB 84', 'BULL LIB 85', 'BULL D9R 86', 'BULL D9R 87'],
      'CAMIONS': ['CAMION T24', 'CAMION T25', 'CAMION T26', 'CAMION T27', 'CAMION T28', 'CAMION T29', 'CAMION T30', 'CAMION T31', 'CAMION T32', 'CAMION T33', 'WABCO 13', 'WABCO 19'],
      'CHARGEUSES': ['CHRG 992C', 'CHRG 992K', 'CHRG 994H'],
      'NIVELEUSES': ['NIV 14G', 'NIV 16H', 'NIV KOM01', 'NIV KOM02'],
      'PAYDOZERS': ['PAY CAT03', 'PAY KOM04', 'PAY KOM05'],
      'PELLE HYDRAULIQUE': ['PH365-C', 'PH5130'],
    },
    'MACHINES': {
      'DRAGLINES': ['1370 W1', '1370 W2'],
      'PELLE ELECTRIQUE': ['195 P1', '195 P2'],
      'SONDEUSES': ['PV275-1', 'PV275-2', 'PV275-3'],
    },
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }


  Future<void> _saveReport() async {
    if (_equipmentList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajoutez au moins un équipement avant de soumettre.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final report = Report(
        description: 'Machine/Engin Arrêtés',
        date: _selectedDate,
        type: 'Machine/Engin Arrêtés',
        group: 'Machines Equipment',
        additionalData: {
          'equipmentList': _equipmentList,
        },
      );

      await _databaseHelper.insertReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reportSaved),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingReport),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = "${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}";

    return Scaffold(
      appBar: AppBar(title: const Text("Les Machines et l'Engins a l'Arret")),
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
                      if (_currentStep < 2) {
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
                      final isLastStep = _currentStep == 2;
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: details.onStepCancel,
                                  child: const Text('Précédent'),
                                ),
                              ),
                            if (_currentStep > 0)
                              const SizedBox(width: 8),
                            Expanded(
                              child: isLastStep
                                  ? ElevatedButton.icon(
                                      icon: const Icon(Icons.check_circle, color: Colors.white),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).colorScheme.secondary,
                                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _equipmentList.isNotEmpty
                                          ? () async {
                                              final shouldSave = await showDialog<bool>(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Confirmation'),
                                                  content: const Text(
                                                    "When you click Done, the report will be saved on the reports page. If you want to send this report to the company, go to the reports page and send it from there."
                                                  ),
                                                  actions: [
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.of(context).pop(true),
                                                      child: const Text('Done'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              // ignore: use_build_context_synchronously
                                              if (!mounted) return;
                                              if (shouldSave == true) {
                                                await _saveReport();
                                                // ignore: use_build_context_synchronously
                                                if (!mounted) return;
                                                Navigator.of(context).pushAndRemoveUntil(
                                                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                                                  (route) => false,
                                                );
                                              }
                                            }
                                          : null,
                                      label: const Text('Soumettre'),
                                    )
                                  : ElevatedButton(
                                      onPressed: details.onStepContinue,
                                      child: const Text('Suivant'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        title: const Text('Sélection de la date'),
                        content: _buildStep1Content(),
                        isActive: _currentStep >= 0,
                        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                      ),
                      Step(
                        title: const Text('Sélection de l\'équipement'),
                        content: _buildStep2Content(),
                        isActive: _currentStep >= 1,
                        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                      ),
                      Step(
                        title: const Text('Vérification'),
                        content: _buildStep3Content(),
                        isActive: _currentStep >= 2,
                        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }



  Widget _buildStep1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date Display
        Card(
          child: InkWell(
            onTap: () => _selectDate(context),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.edit, size: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sélectionnez la date pour laquelle vous souhaitez créer le rapport',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildStep2Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Équipements - Arrêts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _addEquipment(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un équipement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
                onPressed: () => _showEquipmentList(),
                icon: const Icon(Icons.list),
                label: const Text('Voir les équipements'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vérification des informations',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showVerificationDetails(),
                icon: const Icon(Icons.visibility),
                label: const Text('Voir les détails'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  side: BorderSide(color: Theme.of(context).colorScheme.secondary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_equipmentList.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_equipmentList.length} équipement${_equipmentList.length > 1 ? 's' : ''} prêt${_equipmentList.length > 1 ? 's' : ''} à être soumis',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
        ),
      ],
    );
  }

  void _addEquipment() {
    // Reset form fields when opening dialog
    _selectedMainCategory = '';
    _selectedSubCategory = '';
    _selectedEquipment = '';
    _selectedEquipmentType = '';
    _stopReason = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            type: MaterialType.card,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
              mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                        Text('Ajouter un équipement', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedMainCategory.isEmpty ? null : _selectedMainCategory,
                          decoration: const InputDecoration(labelText: 'Catégorie principale', border: OutlineInputBorder()),
                      items: _equipmentData.keys.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                            setDialogState(() {
                          _selectedMainCategory = newValue ?? '';
                          _selectedSubCategory = '';
                          _selectedEquipment = '';
                          _selectedEquipmentType = '';
                        });
                      },
                ),
                const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedSubCategory.isEmpty ? null : _selectedSubCategory,
                          decoration: const InputDecoration(labelText: 'Sous-catégorie', border: OutlineInputBorder()),
                          items: (_selectedMainCategory.isNotEmpty ? _equipmentData[_selectedMainCategory]!.keys : <String>[]).map((String subCategory) {
                          return DropdownMenuItem<String>(
                            value: subCategory,
                            child: Text(subCategory),
                          );
                        }).toList(),
                          onChanged: _selectedMainCategory.isNotEmpty ? (String? newValue) {
                            setDialogState(() {
                            _selectedSubCategory = newValue ?? '';
                            _selectedEquipment = '';
                            _selectedEquipmentType = '';
                          });
                          } : null,
                        ),
                        const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedEquipment.isEmpty ? null : _selectedEquipment,
                          decoration: const InputDecoration(labelText: 'Équipement', border: OutlineInputBorder()),
                          items: (_selectedSubCategory.isNotEmpty ? _equipmentData[_selectedMainCategory]![_selectedSubCategory]! : <String>[]).map((String equipment) {
                          return DropdownMenuItem<String>(
                            value: equipment,
                            child: Text(equipment),
                          );
                        }).toList(),
                          onChanged: _selectedSubCategory.isNotEmpty ? (String? newValue) {
                            setDialogState(() {
                            _selectedEquipment = newValue ?? '';
                            _selectedEquipmentType = '$_selectedMainCategory - $_selectedSubCategory - $_selectedEquipment';
                          });
                          } : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _stopReason,
                          decoration: const InputDecoration(
                            labelText: 'Raison de l\'arrêt',
                            border: OutlineInputBorder(),
                            hintText: 'Entrez la raison de l\'arrêt...',
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            setDialogState(() {
                              _stopReason = value;
                          });
                        },
                      ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
          TextButton(
                              onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
                            const SizedBox(width: 8),
                      ElevatedButton(
                              onPressed: _selectedEquipment.isNotEmpty && _stopReason.isNotEmpty
                                  ? () {
                                      // Add equipment to the list
                                      setState(() {
                                        _equipmentList.add({
                                          'equipmentType': _selectedEquipmentType,
                                          'stopReason': _stopReason,
                                        });
                                      });
                      Navigator.pop(context);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Équipement ajouté'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }
                  : null,
                              child: const Text('Terminer'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _editEquipment(int index) {
    final equipment = _equipmentList[index];
    
    // Parse the equipment type to get individual components
    final equipmentType = equipment['equipmentType'] ?? '';
    final parts = equipmentType.split(' - ');
    
    if (parts.length >= 3) {
      _selectedMainCategory = parts[0];
      _selectedSubCategory = parts[1];
      _selectedEquipment = parts[2];
      _selectedEquipmentType = equipmentType;
    }
    _stopReason = equipment['stopReason'] ?? '';
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            type: MaterialType.card,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Modifier l\'équipement', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedMainCategory.isEmpty ? null : _selectedMainCategory,
                          decoration: const InputDecoration(labelText: 'Catégorie principale', border: OutlineInputBorder()),
                          items: _equipmentData.keys.map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setDialogState(() {
                              _selectedMainCategory = newValue ?? '';
                              _selectedSubCategory = '';
                              _selectedEquipment = '';
                              _selectedEquipmentType = '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedSubCategory.isEmpty ? null : _selectedSubCategory,
                          decoration: const InputDecoration(labelText: 'Sous-catégorie', border: OutlineInputBorder()),
                          items: (_selectedMainCategory.isNotEmpty ? _equipmentData[_selectedMainCategory]!.keys : <String>[]).map((String subCategory) {
                            return DropdownMenuItem<String>(
                              value: subCategory,
                              child: Text(subCategory),
                            );
                          }).toList(),
                          onChanged: _selectedMainCategory.isNotEmpty ? (String? newValue) {
                            setDialogState(() {
                              _selectedSubCategory = newValue ?? '';
                              _selectedEquipment = '';
                              _selectedEquipmentType = '';
                            });
                          } : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedEquipment.isEmpty ? null : _selectedEquipment,
                          decoration: const InputDecoration(labelText: 'Équipement', border: OutlineInputBorder()),
                          items: (_selectedSubCategory.isNotEmpty ? _equipmentData[_selectedMainCategory]![_selectedSubCategory]! : <String>[]).map((String equipment) {
                            return DropdownMenuItem<String>(
                              value: equipment,
                              child: Text(equipment),
                            );
                          }).toList(),
                          onChanged: _selectedSubCategory.isNotEmpty ? (String? newValue) {
                            setDialogState(() {
                              _selectedEquipment = newValue ?? '';
                              _selectedEquipmentType = '$_selectedMainCategory - $_selectedSubCategory - $_selectedEquipment';
                            });
                          } : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: _stopReason,
                          decoration: const InputDecoration(
                            labelText: 'Raison de l\'arrêt',
                            border: OutlineInputBorder(),
                            hintText: 'Entrez la raison de l\'arrêt...',
                          ),
                          maxLines: 3,
                          onChanged: (value) {
                            setDialogState(() {
                              _stopReason = value;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Annuler'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _selectedEquipment.isNotEmpty && _stopReason.isNotEmpty
                                  ? () {
                                      // Update equipment in the list
                                      setState(() {
                                        _equipmentList[index] = {
                                          'equipmentType': _selectedEquipmentType,
                                          'stopReason': _stopReason,
                                        };
                                      });
                                      Navigator.pop(context);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('Équipement modifié'),
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                        ),
                                      );
                                    }
                                  : null,
                              child: const Text('Enregistrer'),
            ),
        ],
      ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEquipmentList() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liste des équipements'),
        content: SizedBox(
          width: double.maxFinite,
          child: _equipmentList.isNotEmpty
              ? ListView.builder(
                  shrinkWrap: true,
                  itemCount: _equipmentList.length,
                  itemBuilder: (context, index) {
                    final equipment = _equipmentList[index];
                    return ListTile(
                      title: Text('Équipement: ${equipment['equipmentType']}'),
                      subtitle: Text('Raison: ${equipment['stopReason']}'),
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
                            _editEquipment(index);
                          } else if (value == 'delete') {
                            setState(() {
                              _equipmentList.removeAt(index);
                            });
                            Navigator.pop(context);
                            _showEquipmentList();
                          }
                        },
                      ),
                    );
                  },
                )
              : const Center(
                  child: Text('Aucun équipement ajouté'),
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

  void _showVerificationDetails() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            type: MaterialType.card,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vérification des informations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date du rapport',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text(
                                  '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                  style: const TextStyle(fontSize: 16),
                                ),
              ],
            ),
          ),
        ),
                        const SizedBox(height: 16),
                        // Equipment Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Équipements arrêtés',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                if (_equipmentList.isEmpty)
                                  const Text(
                                    'Aucun équipement ajouté',
                                    style: TextStyle(color: Colors.grey),
                                  )
                                else
                                  ..._equipmentList.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final equipment = entry.value;
    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                                          Text(
                                            'Équipement ${index + 1}:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
                                          const SizedBox(height: 4),
                                          Text('Type: ${equipment['equipmentType']}'),
                                          Text('Raison: ${equipment['stopReason']}'),
                                          if (index < _equipmentList.length - 1) const Divider(),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_equipmentList.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
          Expanded(
            child: Text(
                                    '${_equipmentList.length} équipement${_equipmentList.length > 1 ? 's' : ''} prêt${_equipmentList.length > 1 ? 's' : ''} à être soumis',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
          ),
        );
      },
    );
  }
} 