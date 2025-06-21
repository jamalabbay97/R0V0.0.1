import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:r0_app/services/database_helper.dart';
import 'package:r0_app/models/report.dart';

enum QualiteType {
  normal,
  oceane,
  pb30,
}

String qualiteTypeToString(QualiteType? t) {
  switch (t) {
    case QualiteType.normal:
      return "NORMAL";
    case QualiteType.oceane:
      return "OCEANE";
    case QualiteType.pb30:
      return "PB30";
    default:
      return "";
  }
}

enum Poste {
  premier,
  deuxieme,
  troisieme,
}

String posteToString(Poste? p) {
  switch (p) {
    case Poste.premier:
      return "1er";
    case Poste.deuxieme:
      return "2eme";
    case Poste.troisieme:
      return "3eme";
    default:
      return "";
  }
}

// Mine and Sortie data structure
class MineData {
  final String name;
  final List<ZoneData> zones;

  MineData({required this.name, required this.zones});
}

class ZoneData {
  final String name;
  final List<String> sorties;

  ZoneData({required this.name, required this.sorties});
}

final List<MineData> minesData = [
  MineData(
    name: 'Mine G',
    zones: [
      ZoneData(
        name: 'Mine G Zone Dragline',
        sorties: ['Sortie 1', 'Sortie 2'],
      ),
    ],
  ),
  MineData(
    name: 'Mine E',
    zones: [
      ZoneData(
        name: 'Mine E1 Zone Dragline',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3', 'Sortie 4'],
      ),
      ZoneData(
        name: 'Mine E1 Zone Bulls',
        sorties: ['Sortie 2', 'Sortie 3'],
      ),
      ZoneData(
        name: 'Mine E3 Zone Dragline',
        sorties: ['Sortie -1', 'Sortie 0', 'Sortie 1', 'Sortie 2'],
      ),
      ZoneData(
        name: 'Mine E2 Zone Bulls',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3'],
      ),
    ],
  ),
  MineData(
    name: 'Mine C',
    zones: [
      ZoneData(
        name: 'Mine C Zone Dragline',
        sorties: [],
      ),
    ],
  ),
  MineData(
    name: 'Mine A',
    zones: [
      ZoneData(
        name: 'Mine A',
        sorties: ['Sortie 1', 'Sortie 2', 'Sortie 3', 'Sortie 4', 'Sortie 5', 'Sortie 6', 'Sortie 7'],
      ),
    ],
  ),
];

class TruckTrackingScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const TruckTrackingScreen({
    super.key,
    required this.formKey,
  });

  @override
  State<TruckTrackingScreen> createState() => _TruckTrackingScreenState();
}

class _TruckTrackingScreenState extends State<TruckTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.truckTracking),
      ),
      body: Form(
        key: widget.formKey,
        child: CamionReport(
          formKey: widget.formKey,
        ),
      ),
    );
  }
}

class CamionReport extends StatefulWidget {
  final GlobalKey<FormState> formKey;

  const CamionReport({
    super.key, 
    required this.formKey,
  });

  @override
  CamionReportState createState() => CamionReportState();
}

class CamionReportState extends State<CamionReport> {
  final Map<String, Map<String, TextEditingController>> _truckControllers = {};
  DateTime _selectedDate = DateTime.now();
  QualiteType? _selectedQualite;
  String? _selectedEquipment;
  Poste? _selectedPoste;
  
  // Mine and Sortie selection
  MineData? _selectedMine;
  ZoneData? _selectedZone;
  String? _selectedSortie;

  List<Map<String, dynamic>> truckData = [
    {
      "id": const Uuid().v4(),
      "truckNumber": "",
      "driver1": "",
      "driver2": "",
      "counts": [],
      "lieu": "",
      "total": "0",
    },
  ];

  // Add predefined truck numbers
  static const List<String> predefinedTrucks = [
    'W17',
    'W19',
    'TEREX 24',
    'TEREX 25',
    'TEREX 26',
    'TEREX 27',
    'TEREX 28',
    'TEREX 29',
    'TEREX 30',
    'TEREX 31',
    'TEREX 32',
  ];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize truck controllers
    for (var truck in truckData) {
      _initializeTruckControllers(truck['id']);
    }
  }

  void _initializeTruckControllers(String truckId) {
    final truck = truckData.firstWhere((t) => t['id'] == truckId);
    _truckControllers[truckId] = {
      'truckNumber': TextEditingController(text: truck['truckNumber']?.toString() ?? ''),
      'driver1': TextEditingController(text: truck['driver1']?.toString() ?? ''),
      'driver2': TextEditingController(text: truck['driver2']?.toString() ?? ''),
      'lieu': TextEditingController(text: truck['lieu']?.toString() ?? ''),
      'total': TextEditingController(text: truck['total']?.toString() ?? '0'),
    };
    
    // Initialize count controllers for existing trips
    if (truck['counts'] != null) {
    for (var i = 0; i < truck['counts'].length; i++) {
      _truckControllers[truckId]!['count${i}_time'] = 
            TextEditingController(text: truck['counts'][i]['time']?.toString() ?? '0');
      }
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var truckControllers in _truckControllers.values) {
      for (var controller in truckControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  String calculateTotal(Map<String, dynamic> truck) {
    int countsSum = 0;
    if (truck['counts'] != null) {
      countsSum = (truck['counts'] as List)
          .map((c) => int.tryParse(c['time']?.toString() ?? '0') ?? 0)
        .fold(0, (a, b) => a + b);
    }
    
    int tSudNum = int.tryParse(truck['tSud']?.toString() ?? '0') ?? 0;
    int tNordNum = int.tryParse(truck['tNord']?.toString() ?? '0') ?? 0;
    int stockNum = int.tryParse(truck['stock']?.toString() ?? '0') ?? 0;
    
    return (countsSum + tSudNum + tNordNum + stockNum).toString();
  }

  void deleteTruck(String id) {
    setState(() {
      // Dispose controllers before removing truck
      for (var controller in _truckControllers[id]!.values) {
        controller.dispose();
      }
      _truckControllers.remove(id);
      truckData.removeWhere((truck) => truck["id"] == id);
    });
  }

  void updateTruckData(String id, String field, String value, [int? countIndex, String? countField]) {
    setState(() {
      var truck = truckData.firstWhere((t) => t['id'] == id);
      if (field == "counts" && countIndex != null && countField != null) {
        if (truck["counts"] == null) {
          truck["counts"] = [];
        }
        while (truck["counts"].length <= countIndex) {
          truck["counts"].add({"time": "0"});
        }
        truck["counts"][countIndex][countField] = value;
      } else {
        truck[field] = value;
      }
      truck["total"] = calculateTotal(truck);
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

  Future<void> _showTruckDialog(BuildContext context, [Map<String, dynamic>? existingTruck]) async {
    final truckId = existingTruck?['id'] ?? const Uuid().v4();
    int dialogStep = 0;

    if (existingTruck == null) {
      truckData.add({
        "id": truckId,
        "truckNumber": "",
        "driver1": "",
        "driver2": "",
        "counts": [],
        "lieu": "",
        "total": "0",
      });
      _initializeTruckControllers(truckId);
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void goNext() {
              setDialogState(() {
                dialogStep++;
              });
            }
            void goPrev() {
              setDialogState(() {
                dialogStep--;
              });
            }
            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop && existingTruck == null) {
                  deleteTruck(truckId);
                  Navigator.of(context).pop();
                } else if (!didPop) {
                  Navigator.of(context).pop();
                }
              },
              child: Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            existingTruck == null ? "Nouveau Camion" : "Modifier Camion",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              if (existingTruck == null) {
                                deleteTruck(truckId);
                              }
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                          child: Builder(
                            builder: (context) {
                              if (dialogStep == 0) {
                                // Step 1: Select truck
                                return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                    Text("Selectionner un camion", style: Theme.of(context).textTheme.titleMedium),
                                    const SizedBox(height: 16),
                            _truckCell(truckData.firstWhere((t) => t['id'] == truckId), "truckNumber", isRequired: true),
                                  ],
                                );
                              } else if (dialogStep == 1) {
                                // Step 2: Enter driver(s) and details
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Informations sur le conducteur", style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            _truckCell(truckData.firstWhere((t) => t['id'] == truckId), "driver", isRequired: true),
                                    const SizedBox(height: 16),
                                    _truckCell(truckData.firstWhere((t) => t['id'] == truckId), "lieu"),
                                  ],
                                );
                              } else {
                                // Step 3: Add trips
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Voyages", style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            ExpansionTile(
                                      initiallyExpanded: true,
                              title: Text(
                                "Voyages (${truckData.firstWhere((t) => t['id'] == truckId)['counts'].length})",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              children: [
                                ...List.generate(truckData.firstWhere((t) => t['id'] == truckId)['counts'].length, (i) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "Voyage ${i + 1}",
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            ),
                                            PopupMenuButton<String>(
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
                                              onSelected: (String value) {
                                                Navigator.of(context).pop();
                                                if (value == 'edit') {
                                                  _showTruckDialog(context, truckData.firstWhere((t) => t['id'] == truckId));
                                                } else if (value == 'delete') {
                                                  Future.delayed(const Duration(milliseconds: 100), () {
                                                    deleteTruck(truckId);
                                                  });
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _truckCountCell(truckData.firstWhere((t) => t['id'] == truckId), i, "time"),
                                      ],
                                    ),
                                  );
                                }),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                              setDialogState(() {
                                        addTrip(truckId);
                                      });
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text("Ajouter un voyage"),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 36),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (dialogStep > 0)
                              TextButton(
                                onPressed: goPrev,
                                child: const Text('Precedent'),
                              ),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {
                                    if (existingTruck == null) {
                                      deleteTruck(truckId);
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Annuler'),
                                ),
                                const SizedBox(width: 8),
                                if (dialogStep < 2)
                                  ElevatedButton(
                                    onPressed: goNext,
                                    child: const Text('Suivant'),
                                  ),
                                if (dialogStep == 2)
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text('Enregistrer'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  Future<void> _showVerificationDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Verification des informations',
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
                                  'Date',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Date du rapport', '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Poste Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Text(
                                  'Poste',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Poste selectionne', _selectedPoste != null ? posteToString(_selectedPoste) : '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Mine and Sortie Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mine et Sortie',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Mine', _selectedMine?.name ?? '-'),
                                _buildInfoRow('Zone', _selectedZone?.name ?? '-'),
                                _buildInfoRow('Sortie', _selectedSortie ?? '-'),
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
                                  'Equipement',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Type d\'equipement', _selectedEquipment ?? '-'),
                                _buildInfoRow('Qualite de produits', _selectedQualite != null ? qualiteTypeToString(_selectedQualite) : '-'),
                            ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Trucks Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Camions',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                ...truckData.map((truck) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Camion ${truck['truckNumber']}',
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInfoRow('Chauffeur 1', truck['driver1']),
                                    _buildInfoRow('Chauffeur 2', truck['driver2']),
                                    if (truck['counts'].isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Voyages',
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      ...List.generate(truck['counts'].length, (index) {
                                        final count = truck['counts'][index];
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 16, top: 4),
                                          child: Text(
                                            'Voyage ${index + 1}: ${count['time']}',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        );
                                      }),
                                    ],
                                    const Divider(height: 16),
                                  ],
                                )),
                              ],
                            ),
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

  Future<void> _saveReport(bool isDraft) async {
    if (!widget.formKey.currentState!.validate()) {
      return;
    }

    try {
      final report = Report(
        description: 'Rapport de suivi des camions',
        date: _selectedDate,
        group: 'Truck Tracking',
        type: isDraft ? 'draft' : 'submitted',
        additionalData: {
          'truckData': truckData,
          'mine': _selectedMine?.name,
          'zone': _selectedZone?.name,
          'sortie': _selectedSortie,
        },
      );

      final dbHelper = DatabaseHelper();
      await dbHelper.insertReport(report);

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context)!.truckTracking,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          Stepper(
            currentStep: _currentStep,
            onStepContinue: () {
              if (_currentStep < 5) {
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
              if (_currentStep == 4) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Precedent'),
                      ),
                      ElevatedButton(
                        onPressed: () => _saveReport(false),
                        child: const Text("Soumettre"),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Precedent'),
                      ),
                    if (_currentStep > 0)
                      const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: details.onStepContinue,
                      child: Text(_currentStep == 5 ? 'Terminer' : 'Suivant'),
                    ),
                  ],
                ),
              );
            },
            steps: [
              Step(
                title: const Text('Date du rapport'),
                content: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const Text(
                        'Sélectionnez la date du rapport',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              locale: const Locale('fr', 'FR'),
                            );
                            if (picked != null && picked != _selectedDate) {
                              setState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today),
                                const SizedBox(width: 16),
                                Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const Spacer(),
                                const Icon(Icons.arrow_forward_ios),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: const Text('Sélection Mine et Sortie'),
                content: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const Text(
                        'Sélectionnez la mine, zone, sortie et poste',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sélection de la Mine',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<MineData>(
                                value: _selectedMine,
                                decoration: const InputDecoration(
                                  labelText: 'Mine',
                                  border: OutlineInputBorder(),
                                ),
                                items: minesData.map((mine) {
                                  return DropdownMenuItem(
                                    value: mine,
                                    child: Text(mine.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMine = value;
                                    _selectedZone = null;
                                    _selectedSortie = null;
                                  });
                                },
                              ),
                              if (_selectedMine != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Sélection de la Zone',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<ZoneData>(
                                  value: _selectedZone,
                                  decoration: const InputDecoration(
                                    labelText: 'Zone',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _selectedMine!.zones.map((zone) {
                                    return DropdownMenuItem(
                                      value: zone,
                                      child: Text(zone.name),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedZone = value;
                                      _selectedSortie = null;
                                    });
                                  },
                                ),
                              ],
                              if (_selectedZone != null && _selectedZone!.sorties.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Sélection de la Sortie',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  value: _selectedSortie,
                                  decoration: const InputDecoration(
                                    labelText: 'Sortie',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _selectedZone!.sorties.map((sortie) {
                                    return DropdownMenuItem(
                                      value: sortie,
                                      child: Text(sortie),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSortie = value;
                                    });
                                  },
                                ),
                              ],
                              if (_selectedMine != null && _selectedZone != null && 
                                  (_selectedZone!.sorties.isEmpty || _selectedSortie != null)) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Selection du Poste',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<Poste>(
                                  value: _selectedPoste,
                                  decoration: const InputDecoration(
                                    labelText: 'Poste',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: Poste.values.map((poste) {
                                    return DropdownMenuItem(
                                      value: poste,
                                      child: Text(posteToString(poste)),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPoste = value;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: const Text('Selection equipement'),
                content: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Equipement et Qualite de Produits',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                value: _selectedEquipment,
                                decoration: const InputDecoration(
                                  labelText: 'Type d\'equipement',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Chargeuse 992K',
                                    child: Text('Chargeuse 992K'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Chargeuse 994H',
                                    child: Text('Chargeuse 994H'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Pelle Hy',
                                    child: Text('Pelle hydraulique'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Pelle B1',
                                    child: Text('Pelle electrique B1'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedEquipment = value;
                                  });
                                },
                              ),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<QualiteType>(
                                value: _selectedQualite,
                                decoration: const InputDecoration(
                                  labelText: 'Qualite de Produits',
                                  border: OutlineInputBorder(),
                                ),
                                items: QualiteType.values.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(qualiteTypeToString(type)),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedQualite = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: const Text('Selection du camion'),
                content: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                _showTruckDialog(context);
                              },
                              icon: const Icon(Icons.add),
                              label: const Text("Ajouter un camion"),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 36),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return Dialog(
                                      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "Liste des camions",
                                                    style: Theme.of(context).textTheme.titleLarge,
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.close),
                                                    onPressed: () => Navigator.of(context).pop(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            Flexible(
                                              child: SingleChildScrollView(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  children: truckData.map((truck) {
                                                    return Card(
                                                      margin: const EdgeInsets.only(bottom: 8),
                                                      child: ListTile(
                                                        title: Text("Camion ${truck['truckNumber']}"),
                                                        subtitle: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text("Chauffeur: ${truck['driver1']}"),
                                                            if (truck['trips'] != null && (truck['trips'] as List).isNotEmpty)
                                                              ...(truck['trips'] as List).map((trip) {
                                                                return Padding(
                                                                  padding: const EdgeInsets.only(top: 4),
                                                                  child: Text(
                                                                    "📍 ${trip['location']}",
                                                                    style: const TextStyle(
                                                                      fontSize: 12,
                                                                      color: Colors.grey,
                                                                    ),
                                                                  ),
                                                                );
                                                              }),
                                                          ],
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
                                                          onSelected: (String value) {
                                                            Navigator.of(context).pop();
                                                            if (value == 'edit') {
                                                              _showTruckDialog(context, truckData.firstWhere((t) => t['id'] == truck['id']));
                                                            } else if (value == 'delete') {
                                                              Future.delayed(const Duration(milliseconds: 100), () {
                                                                deleteTruck(truck['id']);
                                                              });
                                                            }
                                                          },
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.list),
                              label: const Text("Voir la liste des camions"),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 36),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                isActive: _currentStep >= 3,
              ),
              Step(
                title: const Text('Verification'),
                content: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      const Text(
                        "Verifiez avant de soumettre:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _showVerificationDialog(context),
                        icon: const Icon(Icons.visibility),
                        label: const Text("Voir tous les details"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                          ),
                        ],
                      ),
                  ),
                isActive: _currentStep >= 4,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _truckCell(Map<String, dynamic> truck, String field, 
      {bool isRequired = false, bool isNumeric = false}) {
    if (field == 'truckNumber') {
      return DropdownButtonFormField<String>(
        value: _truckControllers[truck['id']]![field]!.text.isEmpty 
            ? null 
            : _truckControllers[truck['id']]![field]!.text,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(),
          errorMaxLines: 2,
        ),
        items: predefinedTrucks.map((String truckNumber) {
          return DropdownMenuItem<String>(
            value: truckNumber,
            child: Text(truckNumber),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            _truckControllers[truck['id']]![field]!.text = newValue;
            updateTruckData(truck['id'], field, newValue);
          }
        },
        validator: isRequired ? validateRequired : null,
      );
    } else if (field == 'driver') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _truckControllers[truck['id']]!['driver1'],
            onChanged: (val) => updateTruckData(truck['id'], 'driver1', val),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              hintText: 'Conducteur 1',
              errorMaxLines: 2,
            ),
            maxLines: null,
            minLines: 1,
            style: const TextStyle(height: 1.5),
            validator: isRequired ? validateRequired : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _truckControllers[truck['id']]!['driver2'],
            onChanged: (val) => updateTruckData(truck['id'], 'driver2', val),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
              hintText: 'Conducteur 2 (optionnel)',
              errorMaxLines: 2,
            ),
            maxLines: null,
            minLines: 1,
            style: const TextStyle(height: 1.5),
          ),
        ],
      );
    } else if (field == 'lieu') {
      return TextFormField(
        controller: _truckControllers[truck['id']]![field],
        onChanged: (val) => updateTruckData(truck['id'], field, val),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(),
          hintText: 'Lieu',
        ),
        maxLines: null,
        minLines: 1,
        style: const TextStyle(height: 1.5),
      );
    }

    return TextFormField(
      controller: _truckControllers[truck['id']]![field],
      onChanged: (val) => updateTruckData(truck['id'], field, val),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
        errorMaxLines: 2,
      ),
      maxLines: null,
      minLines: 1,
      style: const TextStyle(height: 1.5),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.multiline,
      validator: isRequired 
          ? validateRequired 
          : isNumeric 
              ? validateNumeric 
              : null,
    );
  }

  Widget _truckCountCell(Map<String, dynamic> truck, int i, String field) {
    final isTime = field == "time";
    if (isTime) {
      return InkWell(
        onTap: () => _selectTime(context, truck, i),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _truckControllers[truck['id']]!['count${i}_$field'],
                  readOnly: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: InputBorder.none,
                    hintText: 'Heure',
                    hintStyle: TextStyle(color: Colors.grey[600]),
                  ),
                  validator: validateNumeric,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: const Icon(Icons.access_time, size: 20, color: Colors.blue),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void addTrip(String truckId) {
    setState(() {
      try {
        final truck = truckData.firstWhere((t) => t['id'] == truckId);
        if (truck['counts'] == null) {
          truck['counts'] = [];
        }
        final tripIndex = truck['counts'].length;
        
        // Add new trip
        truck['counts'].add({
          "time": "0"
        });
        
        // Initialize controllers for the new trip
        if (_truckControllers[truckId] == null) {
          _truckControllers[truckId] = {};
        }
        
        _truckControllers[truckId]!['count${tripIndex}_time'] = 
            TextEditingController(text: "0");
        
        // Update total
        truck["total"] = calculateTotal(truck);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'ajout du voyage: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  void removeTrip(String truckId, int tripIndex) {
    setState(() {
      final truck = truckData.firstWhere((t) => t['id'] == truckId);
      
      // Dispose controllers for the trip
      _truckControllers[truckId]!['count${tripIndex}_time']?.dispose();
      
      // Remove the trip
      truck['counts'].removeAt(tripIndex);
      
      // Reinitialize controllers for remaining trips
      for (var i = tripIndex; i < truck['counts'].length; i++) {
        _truckControllers[truckId]!['count${i}_time'] = 
            TextEditingController(text: truck['counts'][i]['time']?.toString() ?? '0');
      }
      
      // Update total
      truck["total"] = calculateTotal(truck);
    });
  }

  Future<void> _selectTime(BuildContext context, Map<String, dynamic> truck, int index) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hourMinuteTextStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _truckControllers[truck['id']]!['count${index}_time']!.text = formattedTime;
      updateTruckData(truck['id'], "counts", formattedTime, index, "time");
    }
  }
} 