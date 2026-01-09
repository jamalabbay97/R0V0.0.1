import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:r0/models/mine_data.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:r0/theme.dart';

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
  troisieme,
  premier,
  deuxieme,
}

String posteToString(Poste? p) {
  switch (p) {
    case Poste.troisieme:
      return "3ème";
    case Poste.premier:
      return "1er";
    case Poste.deuxieme:
      return "2ème";
    default:
      return "";
  }
}

class TruckTrackingScreen extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const TruckTrackingScreen({
    super.key,
    required this.formKey,
    this.initialReport,
    this.onSave,
    this.isEditing = false,
  });

  @override
  State<TruckTrackingScreen> createState() => _TruckTrackingScreenState();
}

class _TruckTrackingScreenState extends State<TruckTrackingScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? "Modifier - ${AppLocalizations.of(context)!.truckTracking}"
            : AppLocalizations.of(context)!.truckTracking),
      ),
      body: Form(
        key: widget.formKey,
        child: CamionReport(
          formKey: widget.formKey,
          initialReport: widget.initialReport,
          onSave: widget.onSave,
          isEditing: widget.isEditing,
        ),
      ),
    );
  }
}

class CamionReport extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const CamionReport({
    super.key,
    required this.formKey,
    this.initialReport,
    this.onSave,
    this.isEditing = false,
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

  // Add for step 3 selection
  String? _selectedOperationType;
  // Mine and Sortie selection
  MineData? _selectedMine;
  ZoneData? _selectedZone;
  String? _selectedSortie;

  List<Map<String, dynamic>> truckData = [];

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

    if (widget.isEditing && widget.initialReport != null) {
      // Editing mode - load existing data
      _loadExistingData();
    }

    _initializeControllers();
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;

    final data = widget.initialReport!.additionalData!;

    // Load truck data
    if (data['truckData'] is List) {
      truckData = List.from(data['truckData']);
    }

    // Load other fields
    if (data['mine'] != null) {
      // Find and set selected mine
      for (var mine in minesData) {
        if (mine.name == data['mine']) {
          _selectedMine = mine;
          break;
        }
      }
    }

    if (data['zone'] != null && _selectedMine != null) {
      // Find and set selected zone
      for (var zone in _selectedMine!.zones) {
        if (zone.name == data['zone']) {
          _selectedZone = zone;
          break;
        }
      }
    }

    if (data['sortie'] != null) {
      _selectedSortie = data['sortie'];
    }

    if (data['operationType'] != null) {
      _selectedOperationType = data['operationType'];
    }

    if (data['equipment'] != null) {
      _selectedEquipment = data['equipment'];
    }

    if (data['selectedPoste'] != null) {
      _selectedPoste = _parsePosteFromString(data['selectedPoste']);
    }
  }

  Poste? _parsePosteFromString(dynamic posteValue) {
    if (posteValue == null) return null;
    final posteStr = posteValue.toString();
    switch (posteStr) {
      case '0':
      case '3ème':
        return Poste.premier;
      case '1':
      case '1er':
        return Poste.deuxieme;
      case '2':
      case '2ème':
        return Poste.troisieme;
      default:
        return null;
    }
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
      'truckNumber':
          TextEditingController(text: truck['truckNumber']?.toString() ?? ''),
      'driver1':
          TextEditingController(text: truck['driver1']?.toString() ?? ''),
      'lieu': TextEditingController(text: truck['lieu']?.toString() ?? ''),
      'total': TextEditingController(text: truck['total']?.toString() ?? '0'),
    };

    // Initialize count controllers for existing trips
    if (truck['counts'] != null) {
      for (var i = 0; i < truck['counts'].length; i++) {
        _truckControllers[truckId]!['count${i}_time'] = TextEditingController(
            text: truck['counts'][i]['time']?.toString() ?? '0');
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
    final controllersToDispose = _truckControllers[id]?.values.toList() ?? [];
    setState(() {
      _truckControllers.remove(id);
      truckData.removeWhere((truck) => truck["id"] == id);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (var controller in controllersToDispose) {
        controller.dispose();
      }
    });
  }

  void updateTruckData(String id, String field, String value,
      [int? countIndex, String? countField]) {
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

  Future<void> _showTruckDialog(BuildContext context,
      [Map<String, dynamic>? existingTruck]) async {
    final truckId = existingTruck?['id'] ?? const Uuid().v4();

    if (existingTruck == null) {
      truckData.add({
        "id": truckId,
        "truckNumber": "",
        "driver1": "",
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
            // Only one step: select truck and enter driver info
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
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                              existingTruck == null
                                  ? "Nouveau Camion"
                                  : "Modifier Camion",
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Selectionner un camion",
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              _truckCell(
                                  truckData
                                      .firstWhere((t) => t['id'] == truckId),
                                  "truckNumber",
                                  isRequired: true),
                              const SizedBox(height: 24),
                              Text("Informations sur le conducteur",
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              _truckCell(
                                  truckData
                                      .firstWhere((t) => t['id'] == truckId),
                                  "driver1",
                                  isRequired: true),
                              const SizedBox(height: 16),
                              // Add window with two buttons for trips
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.add),
                                      label: const Text('Ajouter'),
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            final truck = truckData.firstWhere(
                                                (t) => t['id'] == truckId);
                                            var timeController =
                                                TextEditingController();
                                            String? selectedEquipment =
                                                _selectedEquipment;
                                            DateTime selectedTripTime =
                                                DateTime.now();
                                            return AlertDialog(
                                              title: const Text('Ajouter'),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text('Temps du voyage',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium),
                                                  const SizedBox(height: 8),
                                                  TimePickerSpinner(
                                                    is24HourMode: true,
                                                    isShowSeconds: false,
                                                    normalTextStyle:
                                                        const TextStyle(
                                                            fontSize: 18,
                                                            color:
                                                                Colors.black54),
                                                    highlightedTextStyle:
                                                        const TextStyle(
                                                            fontSize: 24,
                                                            color:
                                                                Colors.black),
                                                    spacing: 50,
                                                    itemHeight: 60,
                                                    isForce2Digits: true,
                                                    time: selectedTripTime,
                                                    onTimeChange: (dateTime) {
                                                      selectedTripTime =
                                                          dateTime;
                                                      timeController.text =
                                                          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                                                    },
                                                  ),
                                                  const SizedBox(height: 16),
                                                  DropdownButtonFormField<
                                                      String>(
                                                    value: selectedEquipment,
                                                    decoration:
                                                        const InputDecoration(
                                                      labelText:
                                                          "Equipement utilisé",
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                    items: const [
                                                      DropdownMenuItem(
                                                          value:
                                                              'Chargeuse 992K',
                                                          child: Text(
                                                              'Chargeuse 992K')),
                                                      DropdownMenuItem(
                                                          value:
                                                              'Chargeuse 994H',
                                                          child: Text(
                                                              'Chargeuse 994H')),
                                                      DropdownMenuItem(
                                                          value: 'Pelle Hy',
                                                          child: Text(
                                                              'Pelle hydraulique')),
                                                      DropdownMenuItem(
                                                          value: 'Pelle B1',
                                                          child: Text(
                                                              'Pelle electrique B1')),
                                                    ],
                                                    onChanged: (value) {
                                                      selectedEquipment = value;
                                                    },
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('Annuler'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    if (timeController
                                                            .text.isNotEmpty &&
                                                        selectedEquipment !=
                                                            null) {
                                                      setState(() {
                                                        if (truck['counts'] ==
                                                            null) {
                                                          truck['counts'] = [];
                                                        }
                                                        truck['counts'].add({
                                                          'time': timeController
                                                              .text,
                                                          'equipment':
                                                              selectedEquipment,
                                                        });
                                                        truck['total'] =
                                                            calculateTotal(
                                                                truck);
                                                      });
                                                      Navigator.of(context)
                                                          .pop();
                                                    }
                                                  },
                                                  child: const Text('Ajouter'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.list),
                                      label: const Text('Voir les voyages'),
                                      onPressed: () async {
                                        while (true) {
                                          final result = await showDialog(
                                            context: context,
                                            builder: (context) {
                                              final truck =
                                                  truckData.firstWhere((t) =>
                                                      t['id'] == truckId);
                                              final counts =
                                                  truck['counts'] ?? [];
                                              // Calculate totals for summary card
                                              final Map<String, int>
                                                  equipmentCounts = {};
                                              for (var trip in counts) {
                                                final eq =
                                                    trip['equipment'] ?? '-';
                                                equipmentCounts[eq] =
                                                    (equipmentCounts[eq] ?? 0) +
                                                        1;
                                              }
                                              return AlertDialog(
                                                title: const Text(
                                                    'Détails des voyages'),
                                                content: counts.isEmpty
                                                    ? const Text(
                                                        'Aucun voyage ajouté.')
                                                    : SizedBox(
                                                        width: 300,
                                                        height:
                                                            400, // Set a fixed height for the dialog content
                                                        child:
                                                            SingleChildScrollView(
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              ListView
                                                                  .separated(
                                                                shrinkWrap:
                                                                    true,
                                                                physics:
                                                                    const NeverScrollableScrollPhysics(),
                                                                itemCount:
                                                                    counts
                                                                        .length,
                                                                separatorBuilder:
                                                                    (_, __) =>
                                                                        const Divider(),
                                                                itemBuilder:
                                                                    (context,
                                                                        i) {
                                                                  final trip =
                                                                      counts[i];
                                                                  return ListTile(
                                                                    title: Text(
                                                                        'v${i + 1}'),
                                                                    subtitle:
                                                                        Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                            'Temps: ${trip['time']}'),
                                                                        Text(
                                                                            'Equipement: ${trip['equipment'] ?? '-'}'),
                                                                      ],
                                                                    ),
                                                                    trailing:
                                                                        PopupMenuButton<
                                                                            String>(
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .more_horiz,
                                                                          size:
                                                                              20),
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(8),
                                                                      ),
                                                                      position:
                                                                          PopupMenuPosition
                                                                              .under,
                                                                      itemBuilder:
                                                                          (BuildContext context) =>
                                                                              [
                                                                        PopupMenuItem<
                                                                            String>(
                                                                          value:
                                                                              'edit',
                                                                          height:
                                                                              36,
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
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
                                                                        PopupMenuItem<
                                                                            String>(
                                                                          value:
                                                                              'delete',
                                                                          height:
                                                                              36,
                                                                          child:
                                                                              Row(
                                                                            mainAxisSize:
                                                                                MainAxisSize.min,
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
                                                                      onSelected:
                                                                          (String
                                                                              value) {
                                                                        Navigator.of(context)
                                                                            .pop({
                                                                          'action':
                                                                              value,
                                                                          'tripIndex':
                                                                              i
                                                                        });
                                                                      },
                                                                    ),
                                                                  );
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(context)
                                                            .pop(),
                                                    child: const Text('Fermer'),
                                                  ),
                                                ],
                                              );
                                            },
                                          );
                                          if (!mounted) return;
                                          if (result is Map &&
                                              result['action'] == 'edit') {
                                            final tripIndex =
                                                result['tripIndex'] as int;
                                            final truck = truckData.firstWhere(
                                                (t) => t['id'] == truckId);
                                            final trip =
                                                truck['counts'][tripIndex];
                                            var timeController =
                                                TextEditingController(
                                                    text: trip['time']);
                                            String? selectedEquipment =
                                                trip['equipment'];
                                            DateTime selectedTripTime =
                                                DateTime.now();
                                            if (!context.mounted) return;
                                            await showDialog(
                                              context: context,
                                              builder: (context) {
                                                return AlertDialog(
                                                  title: const Text(
                                                      'Modifier le voyage'),
                                                  content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text('Temps du voyage',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium),
                                                      const SizedBox(height: 8),
                                                      TimePickerSpinner(
                                                        is24HourMode: true,
                                                        isShowSeconds: false,
                                                        normalTextStyle:
                                                            const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .black54),
                                                        highlightedTextStyle:
                                                            const TextStyle(
                                                                fontSize: 24,
                                                                color: Colors
                                                                    .black),
                                                        spacing: 50,
                                                        itemHeight: 60,
                                                        isForce2Digits: true,
                                                        time: selectedTripTime,
                                                        onTimeChange:
                                                            (dateTime) {
                                                          selectedTripTime =
                                                              dateTime;
                                                          timeController.text =
                                                              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                                                        },
                                                      ),
                                                      const SizedBox(
                                                          height: 16),
                                                      DropdownButtonFormField<
                                                          String>(
                                                        value:
                                                            selectedEquipment,
                                                        decoration:
                                                            const InputDecoration(
                                                          labelText:
                                                              "Equipement utilisé",
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                        items: const [
                                                          DropdownMenuItem(
                                                              value:
                                                                  'Chargeuse 992K',
                                                              child: Text(
                                                                  'Chargeuse 992K')),
                                                          DropdownMenuItem(
                                                              value:
                                                                  'Chargeuse 994H',
                                                              child: Text(
                                                                  'Chargeuse 994H')),
                                                          DropdownMenuItem(
                                                              value: 'Pelle Hy',
                                                              child: Text(
                                                                  'Pelle hydraulique')),
                                                          DropdownMenuItem(
                                                              value: 'Pelle B1',
                                                              child: Text(
                                                                  'Pelle electrique B1')),
                                                        ],
                                                        onChanged: (value) {
                                                          selectedEquipment =
                                                              value;
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(),
                                                      child:
                                                          const Text('Annuler'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        if (timeController.text
                                                                .isNotEmpty &&
                                                            selectedEquipment !=
                                                                null) {
                                                          setState(() {
                                                            trip['time'] =
                                                                timeController
                                                                    .text;
                                                            trip['equipment'] =
                                                                selectedEquipment;
                                                            truck['total'] =
                                                                calculateTotal(
                                                                    truck);
                                                          });
                                                          Navigator.of(context)
                                                              .pop();
                                                        }
                                                      },
                                                      child: const Text(
                                                          'Enregistrer'),
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                            // Reopen the trip list dialog after editing
                                            continue;
                                          } else if (result is Map &&
                                              result['action'] == 'delete') {
                                            final tripIndex =
                                                result['tripIndex'] as int;
                                            setState(() {
                                              final truck =
                                                  truckData.firstWhere((t) =>
                                                      t['id'] == truckId);
                                              truck['counts']
                                                  .removeAt(tripIndex);
                                              truck['total'] =
                                                  calculateTotal(truck);
                                            });
                                            // Reopen the trip list dialog after deleting
                                            continue;
                                          }
                                          // If result is null or closed, break the loop
                                          break;
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
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
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: const Text('Enregistrer'),
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
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Date',
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                    'Poste',
                                    _selectedPoste != null
                                        ? posteToString(_selectedPoste)
                                        : '-'),
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                    'Mine', _selectedMine?.name ?? '-'),
                                _buildInfoRow(
                                    'Zone', _selectedZone?.name ?? '-'),
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                    'Equipment', _selectedEquipment ?? '-'),
                                _buildInfoRow(
                                    'Opération', _selectedOperationType ?? '-'),
                                _buildInfoRow(
                                    'Produits',
                                    _selectedQualite != null
                                        ? qualiteTypeToString(_selectedQualite)
                                        : '-'),
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                ...truckData.map((truck) => Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Camion ${truck['truckNumber']}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Chauffeur', truck['driver1']),
                                        if (truck['counts'].isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Voyages',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                          ),
                                          ...List.generate(
                                              truck['counts'].length, (index) {
                                            final count =
                                                truck['counts'][index];
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 16, top: 4),
                                              child: Row(
                                                children: [
                                                  Text(
                                                    'v${index + 1}: ',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                  Text(
                                                    count['time'] ?? '-',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text('|'),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    count['equipment'] ?? '-',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ],
                                    )),
                              ],
                            ),
                          ),
                        ),
                        // Add global summary for all trips
                        Builder(
                          builder: (context) {
                            // Gather all trips from all trucks
                            final allTrips = truckData
                                .expand((truck) => truck['counts'] ?? [])
                                .toList();
                            final totalTrips = allTrips.length;
                            final Map<String, int> equipmentCounts = {};
                            for (var trip in allTrips) {
                              final eq = trip['equipment'] ?? '-';
                              equipmentCounts[eq] =
                                  (equipmentCounts[eq] ?? 0) + 1;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Card(
                                color: Colors.grey[100],
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Résumé des voyages',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Total de voyages: $totalTrips'),
                                      const SizedBox(height: 8),
                                      ...equipmentCounts.entries.map((e) => Text(
                                          'Total pour ${e.key}: ${e.value}')),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
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
        id: widget.initialReport?.id,
        description: 'Suivi des camions - ${_selectedEquipment ?? ''}',
        date: _selectedDate,
        group: posteToString(_selectedPoste),
        type: _selectedEquipment ?? '',
        additionalData: {
          'truckData': truckData,
          'poste':
              _selectedPoste != null ? posteToString(_selectedPoste) : null,
          'equipment': _selectedEquipment,
          'mine': _selectedMine?.name,
          'zone': _selectedZone?.name,
          'sortie': _selectedSortie,
          'operationType': _selectedOperationType,
        },
      );

      if (widget.isEditing && widget.onSave != null) {
        // Editing mode - call the onSave callback
        widget.onSave!(report);
      } else {
        // Creation mode - save to database
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically build the steps list first
    final steps = [
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
                      lastDate: DateTime.now(),
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
        title: const Text('Informations principales'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ÉTAPE 2: INFORMATIONS PRINCIPALES',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showFullInfoDialog(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter Informations'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
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
                    onPressed: () {
                      _showInfoSummaryDialog(context);
                    },
                    icon: const Icon(Icons.list),
                    label: const Text('Voir Informations'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        isActive: _currentStep >= 1,
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Liste des camions'),
                                content: truckData.isEmpty
                                    ? const Text('Aucun camion ajouté.')
                                    : SizedBox(
                                        width: 350,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ...truckData.map((truck) => Card(
                                                    margin: const EdgeInsets
                                                        .symmetric(vertical: 6),
                                                    child: ListTile(
                                                      title: Text(
                                                          'Camion: ${truck['truckNumber'] ?? ''}'),
                                                      subtitle: Text(
                                                          'Chauffeur: ${truck['driver1'] ?? ''}'),
                                                      trailing: PopupMenuButton<
                                                          String>(
                                                        icon: const Icon(
                                                            Icons.more_horiz,
                                                            size: 20),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        shape:
                                                            RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        position:
                                                            PopupMenuPosition
                                                                .under,
                                                        itemBuilder:
                                                            (BuildContext
                                                                    context) =>
                                                                [
                                                          PopupMenuItem<String>(
                                                            value: 'edit',
                                                            height: 36,
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(Icons.edit,
                                                                    size: 18,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                  'Modifier',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .primary,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          PopupMenuItem<String>(
                                                            value: 'delete',
                                                            height: 36,
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .delete_outline,
                                                                    size: 18,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                  'Supprimer',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .error,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          PopupMenuItem<String>(
                                                            value: 'trips',
                                                            height: 36,
                                                            child: Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(Icons.list,
                                                                    size: 18,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .secondary),
                                                                const SizedBox(
                                                                    width: 8),
                                                                Text(
                                                                  'Voir',
                                                                  style:
                                                                      TextStyle(
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .secondary,
                                                                    fontSize:
                                                                        14,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                        onSelected: (String
                                                            value) async {
                                                          Navigator.of(context)
                                                              .pop(); // Close the truck list dialog

                                                          if (value == 'edit') {
                                                            // Edit truck
                                                            await _showTruckDialog(
                                                                context, truck);
                                                          } else if (value ==
                                                              'delete') {
                                                            // Delete truck
                                                            final shouldDelete =
                                                                await showDialog<
                                                                    bool>(
                                                              context: context,
                                                              builder:
                                                                  (context) =>
                                                                      AlertDialog(
                                                                title: const Text(
                                                                    'Confirmer la suppression'),
                                                                content: Text(
                                                                    'Voulez-vous vraiment supprimer le camion ${truck['truckNumber']} ?'),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.of(context)
                                                                            .pop(false),
                                                                    child: const Text(
                                                                        'Annuler'),
                                                                  ),
                                                                  ElevatedButton(
                                                                    onPressed: () =>
                                                                        Navigator.of(context)
                                                                            .pop(true),
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          AppColors
                                                                              .error,
                                                                      foregroundColor: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onError,
                                                                    ),
                                                                    child: const Text(
                                                                        'Supprimer'),
                                                                  ),
                                                                ],
                                                              ),
                                                            );

                                                            if (shouldDelete ==
                                                                true) {
                                                              deleteTruck(
                                                                  truck['id']);
                                                            }
                                                          } else if (value ==
                                                              'trips') {
                                                            // View trips
                                                            while (true) {
                                                              final result =
                                                                  await showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) {
                                                                  final counts =
                                                                      truck['counts'] ??
                                                                          [];
                                                                  final Map<
                                                                          String,
                                                                          int>
                                                                      equipmentCounts =
                                                                      {};
                                                                  for (var trip
                                                                      in counts) {
                                                                    final eq =
                                                                        trip['equipment'] ??
                                                                            '-';
                                                                    equipmentCounts[
                                                                            eq] =
                                                                        (equipmentCounts[eq] ??
                                                                                0) +
                                                                            1;
                                                                  }
                                                                  return AlertDialog(
                                                                    title: const Text(
                                                                        'Détails des voyages'),
                                                                    content: counts
                                                                            .isEmpty
                                                                        ? const Text(
                                                                            'Aucun voyage ajouté.')
                                                                        : SizedBox(
                                                                            width:
                                                                                300,
                                                                            height:
                                                                                400,
                                                                            child:
                                                                                SingleChildScrollView(
                                                                              child: Column(
                                                                                mainAxisSize: MainAxisSize.min,
                                                                                children: [
                                                                                  ListView.separated(
                                                                                    shrinkWrap: true,
                                                                                    physics: const NeverScrollableScrollPhysics(),
                                                                                    itemCount: counts.length,
                                                                                    separatorBuilder: (_, __) => const Divider(),
                                                                                    itemBuilder: (context, i) {
                                                                                      final trip = counts[i];
                                                                                      return ListTile(
                                                                                        title: Text('v${i + 1}'),
                                                                                        subtitle: Column(
                                                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                                                          children: [
                                                                                            Text('Temps: ${trip['time']}'),
                                                                                            Text('Equipement: ${trip['equipment'] ?? '-'}'),
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
                                                                                            Navigator.of(context).pop({
                                                                                              'action': value,
                                                                                              'tripIndex': i
                                                                                            });
                                                                                          },
                                                                                        ),
                                                                                      );
                                                                                    },
                                                                                  ),
                                                                                ],
                                                                              ),
                                                                            ),
                                                                          ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.of(context).pop(),
                                                                        child: const Text(
                                                                            'Fermer'),
                                                                      ),
                                                                    ],
                                                                  );
                                                                },
                                                              );
                                                              if (!context
                                                                  .mounted) {
                                                                return;
                                                              }
                                                              if (result
                                                                      is Map &&
                                                                  result['action'] ==
                                                                      'edit') {
                                                                final tripIndex =
                                                                    result['tripIndex']
                                                                        as int;
                                                                final trip = truck[
                                                                        'counts']
                                                                    [tripIndex];
                                                                var timeController =
                                                                    TextEditingController(
                                                                        text: trip[
                                                                            'time']);
                                                                String?
                                                                    selectedEquipment =
                                                                    trip[
                                                                        'equipment'];
                                                                DateTime
                                                                    selectedTripTime =
                                                                    DateTime
                                                                        .now();
                                                                final currentContext =
                                                                    context;
                                                                await showDialog(
                                                                  context:
                                                                      currentContext,
                                                                  builder:
                                                                      (context) {
                                                                    return AlertDialog(
                                                                      title: const Text(
                                                                          'Modifier le voyage'),
                                                                      content:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Text(
                                                                              'Temps du voyage',
                                                                              style: Theme.of(context).textTheme.titleMedium),
                                                                          const SizedBox(
                                                                              height: 8),
                                                                          TimePickerSpinner(
                                                                            is24HourMode:
                                                                                true,
                                                                            isShowSeconds:
                                                                                false,
                                                                            normalTextStyle:
                                                                                const TextStyle(fontSize: 18, color: Colors.black54),
                                                                            highlightedTextStyle:
                                                                                const TextStyle(fontSize: 24, color: Colors.black),
                                                                            spacing:
                                                                                50,
                                                                            itemHeight:
                                                                                60,
                                                                            isForce2Digits:
                                                                                true,
                                                                            time:
                                                                                selectedTripTime,
                                                                            onTimeChange:
                                                                                (dateTime) {
                                                                              selectedTripTime = dateTime;
                                                                              timeController.text = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                                                                            },
                                                                          ),
                                                                          const SizedBox(
                                                                              height: 16),
                                                                          DropdownButtonFormField<
                                                                              String>(
                                                                            value:
                                                                                selectedEquipment,
                                                                            decoration:
                                                                                const InputDecoration(
                                                                              labelText: "Equipement utilisé",
                                                                              border: OutlineInputBorder(),
                                                                            ),
                                                                            items: const [
                                                                              DropdownMenuItem(value: 'Chargeuse 992K', child: Text('Chargeuse 992K')),
                                                                              DropdownMenuItem(value: 'Chargeuse 994H', child: Text('Chargeuse 994H')),
                                                                              DropdownMenuItem(value: 'Pelle Hy', child: Text('Pelle hydraulique')),
                                                                              DropdownMenuItem(value: 'Pelle B1', child: Text('Pelle electrique B1')),
                                                                            ],
                                                                            onChanged:
                                                                                (value) {
                                                                              selectedEquipment = value;
                                                                            },
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      actions: [
                                                                        TextButton(
                                                                          onPressed: () =>
                                                                              Navigator.of(context).pop(),
                                                                          child:
                                                                              const Text('Annuler'),
                                                                        ),
                                                                        ElevatedButton(
                                                                          onPressed:
                                                                              () {
                                                                            if (timeController.text.isNotEmpty &&
                                                                                selectedEquipment != null) {
                                                                              setState(() {
                                                                                trip['time'] = timeController.text;
                                                                                trip['equipment'] = selectedEquipment;
                                                                                truck['total'] = calculateTotal(truck);
                                                                              });
                                                                              Navigator.of(context).pop();
                                                                            }
                                                                          },
                                                                          child:
                                                                              const Text('Enregistrer'),
                                                                        ),
                                                                      ],
                                                                    );
                                                                  },
                                                                );
                                                                // Reopen the trip list dialog after editing
                                                                continue;
                                                              } else if (result
                                                                      is Map &&
                                                                  result['action'] ==
                                                                      'delete') {
                                                                final tripIndex =
                                                                    result['tripIndex']
                                                                        as int;
                                                                setState(() {
                                                                  truck['counts']
                                                                      .removeAt(
                                                                          tripIndex);
                                                                  truck['total'] =
                                                                      calculateTotal(
                                                                          truck);
                                                                });
                                                                // Reopen the trip list dialog after deleting
                                                                continue;
                                                              }
                                                              // If result is null or closed, break the loop
                                                              break;
                                                            }
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: const Text('Fermer'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.list),
                        label: const Text("Voir les camions"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          side: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        isActive: _currentStep >= 2,
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
              OutlinedButton.icon(
                onPressed: () => _showVerificationDialog(context),
                icon: const Icon(Icons.visibility),
                label: const Text("Voir tous les details"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side:
                      BorderSide(color: Theme.of(context).colorScheme.primary),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
            ],
          ),
        ),
        isActive: _currentStep >= 3,
      ),
    ];

    // Always keep _currentStep in range
    final int stepCount = steps.length;
    if (_currentStep < 0 || _currentStep >= stepCount) {
      _currentStep = 0;
    }

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
              if (_currentStep < stepCount - 1) {
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
              if (_currentStep == stepCount - 1) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Précédent'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveReport(false),
                          child: const Text('Soumettre'),
                        ),
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
                      Expanded(
                        child: OutlinedButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Précédent'),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == stepCount - 1
                            ? 'Terminer'
                            : 'Suivant'),
                      ),
                    ),
                  ],
                ),
              );
            },
            steps: steps,
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
    } else if (field == 'driver1') {
      return TextFormField(
        controller: _truckControllers[truck['id']]!['driver1'],
        onChanged: (val) => updateTruckData(truck['id'], 'driver1', val),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(),
          hintText: 'Conducteur',
          errorMaxLines: 2,
        ),
        maxLines: null,
        minLines: 1,
        style: const TextStyle(height: 1.5),
        validator: isRequired ? validateRequired : null,
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

  void addTrip(String truckId) {
    setState(() {
      try {
        final truck = truckData.firstWhere((t) => t['id'] == truckId);
        if (truck['counts'] == null) {
          truck['counts'] = [];
        }
        final tripIndex = truck['counts'].length;

        // Add new trip
        truck['counts'].add({"time": "0"});

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
              content:
                  Text('Erreur lors de l\'ajout du voyage: ${e.toString()}'),
              backgroundColor: AppColors.error,
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
        _truckControllers[truckId]!['count${i}_time'] = TextEditingController(
            text: truck['counts'][i]['time']?.toString() ?? '0');
      }

      // Update total
      truck["total"] = calculateTotal(truck);
    });
  }

  void _showFullInfoDialog(BuildContext context) {
    MineData? selectedMine = _selectedMine;
    ZoneData? selectedZone = _selectedZone;
    String? selectedSortie = _selectedSortie;
    Poste? selectedPoste = _selectedPoste;
    String? selectedEquipment = _selectedEquipment;
    String? selectedOperationType = _selectedOperationType;
    QualiteType? selectedQualite = _selectedQualite;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                        Text('Ajouter Informations',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<MineData>(
                          value: selectedMine,
                          decoration: const InputDecoration(
                              labelText: 'Mine', border: OutlineInputBorder()),
                          items: minesData
                              .map((mine) => DropdownMenuItem(
                                  value: mine, child: Text(mine.name)))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedMine = value;
                              selectedZone = null;
                              selectedSortie = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<ZoneData>(
                          value: selectedZone,
                          decoration: const InputDecoration(
                              labelText: 'Zone', border: OutlineInputBorder()),
                          items: (selectedMine?.zones ?? [])
                              .map((zone) => DropdownMenuItem(
                                  value: zone, child: Text(zone.name)))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedZone = value;
                              selectedSortie = null;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedSortie,
                          decoration: const InputDecoration(
                              labelText: 'Sortie',
                              border: OutlineInputBorder()),
                          items: (selectedZone?.sorties ?? [])
                              .map((sortie) => DropdownMenuItem(
                                  value: sortie, child: Text(sortie)))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedSortie = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<Poste>(
                          value: selectedPoste,
                          decoration: const InputDecoration(
                              labelText: 'Poste', border: OutlineInputBorder()),
                          items: Poste.values
                              .map((poste) => DropdownMenuItem(
                                  value: poste,
                                  child: Text(posteToString(poste))))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedPoste = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedEquipment,
                          decoration: const InputDecoration(
                              labelText: "Type d'equipement",
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'Chargeuse 992K',
                                child: Text('Chargeuse 992K')),
                            DropdownMenuItem(
                                value: 'Chargeuse 994H',
                                child: Text('Chargeuse 994H')),
                            DropdownMenuItem(
                                value: 'Pelle Hy',
                                child: Text('Pelle hydraulique')),
                            DropdownMenuItem(
                                value: 'Pelle B1',
                                child: Text('Pelle electrique B1')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedEquipment = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedOperationType,
                          decoration: const InputDecoration(
                              labelText: "Type d'opération",
                              border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(
                                value: 'Défeuitage', child: Text('Défeuitage')),
                            DropdownMenuItem(
                                value: 'Reprise', child: Text('Reprise')),
                            DropdownMenuItem(
                                value: 'stérile', child: Text('stérile')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedOperationType = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<QualiteType>(
                          value: selectedQualite,
                          decoration: const InputDecoration(
                              labelText: 'Qualite de Produits',
                              border: OutlineInputBorder()),
                          items: QualiteType.values
                              .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Text(qualiteTypeToString(type))))
                              .toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedQualite = value;
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
                              onPressed: () {
                                setState(() {
                                  _selectedMine = selectedMine;
                                  _selectedZone = selectedZone;
                                  _selectedSortie = selectedSortie;
                                  _selectedPoste = selectedPoste;
                                  _selectedEquipment = selectedEquipment;
                                  _selectedOperationType =
                                      selectedOperationType;
                                  _selectedQualite = selectedQualite;
                                });
                                Navigator.of(context).pop();
                              },
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

  void _showInfoSummaryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Résumé des informations'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Mine', _selectedMine?.name ?? '-'),
              _buildInfoRow('Zone', _selectedZone?.name ?? '-'),
              _buildInfoRow('Sortie', _selectedSortie ?? '-'),
              _buildInfoRow('Poste', _selectedPoste?.name ?? '-'),
              _buildInfoRow('Equipment', _selectedEquipment ?? '-'),
              _buildInfoRow('Opération', _selectedOperationType ?? '-'),
              _buildInfoRow('Produits', _selectedQualite?.name ?? '-'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
