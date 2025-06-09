import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:r0_app/l10n/app_localizations.dart';

class TruckTrackingScreen extends StatefulWidget {
  const TruckTrackingScreen({super.key});

  @override
  State<TruckTrackingScreen> createState() => _TruckTrackingScreenState();
}

class _TruckTrackingScreenState extends State<TruckTrackingScreen> {
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
        title: Text(AppLocalizations.of(context)!.truckTracking),
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
        child: CamionReport(
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

class CamionReport extends StatefulWidget {
  final DateTime selectedDate;
  final GlobalKey<FormState> formKey;

  const CamionReport({
    super.key, 
    required this.selectedDate,
    required this.formKey,
  });

  @override
  CamionReportState createState() => CamionReportState();
}

class CamionReportState extends State<CamionReport> {
  final Map<String, TextEditingController> _generalInfoControllers = {};
  final Map<String, Map<String, TextEditingController>> _truckControllers = {};

  Map<String, dynamic> generalInfo = {
    "direction": "",
    "division": "",
    "oibEe": "",
    "mine": "",
    "sortie": "",
    "distance": "",
    "qualite": "",
    "machineEngins": "",
    "DéfeuitageRepriseStérile": "",
  };

  List<Map<String, dynamic>> truckData = [
    {
      "id": Uuid().v4(),
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

  // Add new state variables
  bool _isGeneralInfoComplete = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize general info controllers
    for (var key in generalInfo.keys) {
      _generalInfoControllers[key] = TextEditingController(text: generalInfo[key]);
    }

    // Initialize truck controllers
    for (var truck in truckData) {
      _initializeTruckControllers(truck['id']);
    }
  }

  void _initializeTruckControllers(String truckId) {
    final truck = truckData.firstWhere((t) => t['id'] == truckId);
    _truckControllers[truckId] = {
      'truckNumber': TextEditingController(text: truck['truckNumber']),
      'driver1': TextEditingController(text: truck['driver1']),
      'driver2': TextEditingController(text: truck['driver2']),
      'lieu': TextEditingController(text: truck['lieu']),
      'total': TextEditingController(text: truck['total']),
    };
    
    // Initialize count controllers for existing trips
    for (var i = 0; i < truck['counts'].length; i++) {
      _truckControllers[truckId]!['count${i}_time'] = 
          TextEditingController(text: truck['counts'][i]['time']);
      _truckControllers[truckId]!['count${i}_location'] = 
          TextEditingController(text: truck['counts'][i]['location']);
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _generalInfoControllers.values) {
      controller.dispose();
    }
    for (var truckControllers in _truckControllers.values) {
      for (var controller in truckControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  String calculateTotal(Map<String, dynamic> truck) {
    int countsSum = (truck['counts'] as List)
        .map((c) => int.tryParse(c['time']) ?? 0)
        .fold(0, (a, b) => a + b);
    int tSudNum = int.tryParse(truck['tSud']) ?? 0;
    int tNordNum = int.tryParse(truck['tNord']) ?? 0;
    int stockNum = int.tryParse(truck['stock']) ?? 0;
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
        truck["counts"][countIndex][countField] = value;
      } else {
        truck[field] = value;
      }
      truck["total"] = calculateTotal(truck);
    });
  }

  void handleGeneralInfoChange(String field, String value) {
    setState(() {
      generalInfo[field] = value;
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

  void addTrip(String truckId) {
    print('Adding trip for truck: $truckId'); // Debug print
    setState(() {
      try {
        final truck = truckData.firstWhere((t) => t['id'] == truckId);
        print('Found truck: ${truck['truckNumber']}'); // Debug print
        
        final tripIndex = truck['counts'].length;
        print('Current trip count: $tripIndex'); // Debug print
        
        // Add new trip
        truck['counts'].add({
          "time": "",
          "location": "",
        });
        print('Added new trip, new count: ${truck['counts'].length}'); // Debug print
        
        // Initialize controllers for the new trip
        if (_truckControllers[truckId] == null) {
          print('Error: No controllers found for truck $truckId'); // Debug print
          return;
        }
        
        _truckControllers[truckId]!['count${tripIndex}_time'] = 
            TextEditingController();
        _truckControllers[truckId]!['count${tripIndex}_location'] = 
            TextEditingController();
        print('Initialized controllers for new trip'); // Debug print
        
        // Update total
        truck["total"] = calculateTotal(truck);
        print('Updated total: ${truck["total"]}'); // Debug print
      } catch (e) {
        print('Error in addTrip: $e'); // Debug print
      }
    });
  }

  void removeTrip(String truckId, int tripIndex) {
    setState(() {
      final truck = truckData.firstWhere((t) => t['id'] == truckId);
      
      // Dispose controllers for the trip
      _truckControllers[truckId]!['count${tripIndex}_time']?.dispose();
      _truckControllers[truckId]!['count${tripIndex}_location']?.dispose();
      
      // Remove the trip
      truck['counts'].removeAt(tripIndex);
      
      // Reinitialize controllers for remaining trips
      for (var i = tripIndex; i < truck['counts'].length; i++) {
        _truckControllers[truckId]!['count${i}_time'] = 
            TextEditingController(text: truck['counts'][i]['time']);
        _truckControllers[truckId]!['count${i}_location'] = 
            TextEditingController(text: truck['counts'][i]['location']);
      }
      
      // Update total
      truck["total"] = calculateTotal(truck);
    });
  }

  Map<String, dynamic> calculateTotals() {
    int totalTrips = 0;
    Map<String, int> lieuCounts = {};
    bool allLieusMatch = true;
    String? firstLieu;

    for (var truck in truckData) {
      // Count total trips - explicitly convert to int
      totalTrips += (truck['counts'] as List).length;
      
      // Count Lieu occurrences - safely handle the lieu value
      final lieu = truck['lieu']?.toString() ?? '';
      if (lieu.isNotEmpty) {
        lieuCounts[lieu] = (lieuCounts[lieu] ?? 0) + 1;
        
        // Check if all Lieus match
        if (firstLieu == null) {
          firstLieu = lieu;
        } else if (firstLieu != lieu) {
          allLieusMatch = false;
        }
      }
    }

    return {
      'totalTrips': totalTrips,
      'lieuCounts': lieuCounts,
      'allLieusMatch': allLieusMatch,
      'firstLieu': firstLieu,
    };
  }

  // Add method to show General Info dialog
  Future<void> _showGeneralInfoDialog() async {
    int localStep = 0;
    final page1Fields = [
      ["Direction", "direction", true],
      ["Division", "division", true],
      ["OIB/EE", "oibEe", false],
      ["Mine", "mine", false],
    ];
    final page2Fields = [
      ["Sortie", "sortie", false],
      ["Distance", "distance", false],
      ["Qualité", "qualite", false],
      ["Machine ou Engins", "machineEngins", false],
    ];
    final page3Fields = [
      ["Défeuitage, Reprise ou Stérile", "DéfeuitageRepriseStérile", false],
      ["Pionteur", "poiteur", false],
    ];

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            List<Widget> fields = [];
            if (localStep == 0) {
              for (var f in page1Fields) {
                fields.add(_textField(f[0] as String, f[1] as String, isRequired: f[2] as bool));
                fields.add(const SizedBox(height: 8));
              }
            } else if (localStep == 1) {
              for (var f in page2Fields) {
                fields.add(_textField(f[0] as String, f[1] as String, isRequired: f[2] as bool));
                fields.add(const SizedBox(height: 8));
              }
            } else {
              for (var f in page3Fields) {
                fields.add(_textField(f[0] as String, f[1] as String, isRequired: f[2] as bool));
                fields.add(const SizedBox(height: 8));
              }
            }
        return AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
                  children: fields,
            ),
          ),
          actions: [
                if (localStep > 0)
            TextButton(
              onPressed: () {
                      setStateDialog(() {
                        localStep -= 1;
                      });
              },
                    child: const Text("Retour"),
            ),
                if (localStep < 2)
            ElevatedButton(
              onPressed: () {
                      // Optionally add validation for each page here
                      setStateDialog(() {
                        localStep += 1;
                      });
                    },
                    child: const Text("Suivant"),
                  ),
                if (localStep == 2)
                  ElevatedButton(
                    onPressed: () {
                  setState(() {
                    _isGeneralInfoComplete = true;
                    _currentStep = 1;
                  });
                  Navigator.of(context).pop();
              },
                    child: const Text("Terminer"),
            ),
          ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String formattedDate = "${widget.selectedDate.day.toString().padLeft(2, '0')}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}";

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('POINTAGE DES CAMIONS',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(formattedDate,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 16),

            // Step indicator
            if (!_isGeneralInfoComplete)
              ElevatedButton.icon(
                onPressed: _showGeneralInfoDialog,
                icon: const Icon(Icons.info_outline),
                label: const Text("Commencer par les Informations Générales"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              )
            else
              Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  setState(() {
                    if (_currentStep < 2) {
                      _currentStep += 1;
                    }
                  });
                },
                onStepCancel: () {
                  setState(() {
                    if (_currentStep > 0) {
                      _currentStep -= 1;
                    }
                  });
                },
                steps: [
                  Step(
                    title: const Text('Informations Générales'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showGeneralInfoDialog,
                          child: const Text("Modifier les Informations Générales"),
                        ),
                      ],
                    ),
                    isActive: _currentStep >= 0,
                  ),
                  Step(
                    title: const Text('Camions'),
                    content: SingleChildScrollView(
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
                                                                  }).toList(),
                                                              ],
                                                            ),
                                                            trailing: IconButton(
                                                              icon: const Icon(Icons.edit),
                                                              onPressed: () {
                                                                Navigator.of(context).pop();
                                                                _showTruckDialog(context, truck);
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
                    isActive: _currentStep >= 1,
                  ),
                  Step(
                    title: const Text('Vérification'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Vérifiez avant de soumettre:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showVerificationDialog(context),
                          icon: const Icon(Icons.visibility),
                          label: const Text("Voir tous les détails"),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                if (widget.formKey.currentState!.validate()) {
                                  // TODO: Implement save functionality
                                }
                              },
                              child: Text(l10n.save),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                if (widget.formKey.currentState!.validate()) {
                                  // TODO: Implement submit functionality
                                }
                              },
                              child: const Text("Soumettre"),
                            ),
                          ],
                        ),
                      ],
                    ),
                    isActive: _currentStep >= 2,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField(String label, String field, 
      {bool isRequired = false, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextFormField(
        controller: _generalInfoControllers[field],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorMaxLines: 2,
          counterText: '', // Hide character counter
        ),
        maxLines: null, // Allow unlimited lines
        minLines: 1, // Start with at least one line
        maxLength: null, // Remove max length restriction
        keyboardType: isNumeric ? TextInputType.number : TextInputType.multiline,
        validator: isRequired 
            ? validateRequired 
            : isNumeric 
                ? validateNumeric 
                : null,
        onChanged: (value) => handleGeneralInfoChange(field, value),
        style: const TextStyle(height: 1.5), // Add some line spacing
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
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
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
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
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

    return TextFormField(
      controller: _truckControllers[truck['id']]!['count${i}_$field'],
      onChanged: (val) => updateTruckData(truck['id'], "counts", val, i, field),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
        hintText: 'Lieu',
      ),
      maxLines: null,
      minLines: 1,
      style: const TextStyle(height: 1.5),
    );
  }

  Future<void> _showTruckDialog(BuildContext context, [Map<String, dynamic>? existingTruck]) async {
    final truckId = existingTruck?['id'] ?? Uuid().v4();
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

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _truckCell(truckData.firstWhere((t) => t['id'] == truckId), "truckNumber", isRequired: true),
                            const SizedBox(height: 16),
                            _truckCell(truckData.firstWhere((t) => t['id'] == truckId), "driver", isRequired: true),
                            const SizedBox(height: 16),
                            ExpansionTile(
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
                                                if (value == 'delete') {
                                                  _confirmDeleteTrip(context, truckId, i, setState);
                                                }
                                                // Add edit functionality here if needed
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _truckCountCell(truckData.firstWhere((t) => t['id'] == truckId), i, "time"),
                                        const SizedBox(height: 8),
                                        _truckCountCell(truckData.firstWhere((t) => t['id'] == truckId), i, "location"),
                                      ],
                                    ),
                                  );
                                }),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
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
                        ),
                      ),
                    ),
                    const Divider(height: 1),
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
                            child: const Text("Annuler"),
                          ),
                          if (existingTruck != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text("Supprimer le camion"),
                                      content: const Text("Êtes-vous sûr de vouloir supprimer ce camion ?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(),
                                          child: const Text("Annuler"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            deleteTruck(truckId);
                                            Navigator.of(context).pop(); // Close confirmation dialog
                                            Navigator.of(context).pop(); // Close truck dialog
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text("Supprimer"),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("Supprimer"),
                            ),
                          ],
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (widget.formKey.currentState!.validate()) {
                                setState(() {
                                  // Force a rebuild of the parent widget
                                  this.setState(() {});
                                });
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text("Terminé"),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteTrip(BuildContext context, String truckId, int tripIndex, StateSetter setState) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Supprimer le voyage"),
          content: const Text("Êtes-vous sûr de vouloir supprimer ce voyage ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Annuler"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  removeTrip(truckId, tripIndex);
                });
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text("Supprimer"),
            ),
          ],
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
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total des voyages:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${truckData.fold<int>(0, (sum, truck) => sum + (truck['counts'] as List).length)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
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
                                            'Voyage ${index + 1}: ${count['time']} - ${count['location']}',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        );
                                      }),
                                    ],
                                    const Divider(height: 16),
                                  ],
                                )).toList(),
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
} 