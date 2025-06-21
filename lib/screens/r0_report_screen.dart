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

class PersonnelItem {
  String conducteur;
  String graisseur;
  String matricules;
  PersonnelItem({this.conducteur = '', this.graisseur = '', this.matricules = ''});
}

class ConsommationItem {
  String tricone;
  String gasoil;
  ConsommationItem({this.tricone = '', this.gasoil = ''});
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
  String selectedPoste = '1er';
  List<VentilationItem> ventilation = [];
  String arretsExplication = '';
  Map<String, String> exploitation = {
    'heuresBrutes': '',
    'heuresArrets': '',
    'heuresNettes': '',
    'tonnage': '',
    'rendement': '',
  };
  List<String> bulls = List.generate(3, (_) => '');
  List<RepartitionItem> repartitionTravail = List.generate(3, (_) => RepartitionItem());
  PersonnelItem personnel = PersonnelItem();
  ConsommationItem consommation = ConsommationItem();
}

class R0Report extends StatefulWidget {
  final DateTime selectedDate;
  final String? previousDayThirdShiftEnd;

  const R0Report({super.key, required this.selectedDate, this.previousDayThirdShiftEnd});

  @override
  R0ReportState createState() => R0ReportState();
}

class R0ReportState extends State<R0Report> {
  final _formKey = GlobalKey<FormState>();
  final _databaseHelper = DatabaseHelper();
  R0ReportFormData formData = R0ReportFormData();
  late DateTime _selectedDate;
  int _currentStep = 0;
  bool _isLoading = false;

  final posteOrder = const ["1er", "2ème", "3ème"];
  final posteTimes = const {
    "1er": "06:30 - 14:30",
    "2ème": "14:30 - 22:30",
    "3ème": "22:30 - 06:30",
  };

  // Machine and equipment options
  final List<String> machineOptions = [
    // ENGINS - BULLDOZERS
    'BULL D9R 76',
    'BULL D9R 79',
    'BULL D9R 80',
    'BULL D9R 81',
    'BULL D9R 82',
    'BULL D9R 83',
    'BULL D9R 86',
    'BULL D9R 87',
    'BULL LIB 84',
    'BULL LIB 85',
    
    // ENGINS - CAMIONS
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
    'WABCO 19',
    
    // ENGINS - CHARGEUSES
    'CHRG 992C',
    'CHRG 992K',
    'CHRG 994H',
    
    // ENGINS - NIVELEUSES
    'NIV 14G',
    'NIV 16H',
    'NIV KOM01',
    'NIV KOM02',
    
    // ENGINS - PAYDOZERS
    'PAY CAT03',
    'PAY KOM04',
    'PAY KOM05',
    
    // ENGINS - PELLE HYDRAULIQUE
    'PH365-C',
    'PH5130',
    
    // MACHINES - DRAGLINES
    '1370 W1',
    '1370 W2',
    
    // MACHINES - PELLE ELECTRIQUE
    '195 P1',
    '195 P2',
    
    // MACHINES - SONDEUSES
    'PV275-1',
    'PV275-2',
    'PV275-3',
  ];

  // Ventilation codes and labels
  final List<VentilationItem> ventilationCodes = [
    VentilationItem(code: 121, label: "ARRET CARREAU INDUSTRIEL"),
    VentilationItem(code: 122, label: "ARRET CARREAU MINE"),
    VentilationItem(code: 123, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 124, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 125, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 126, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 127, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 128, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 129, label: "ARRET CARREAU MINEUR"),
    VentilationItem(code: 130, label: "ARRET CARREAU MINEUR"),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _initializeVentilation();
    _calculateHours();
  }

  void _initializeVentilation() {
    formData.ventilation = ventilationCodes.map((item) => VentilationItem(
      code: item.code,
      label: item.label,
      duree: '',
      note: '',
    )).toList();
  }

  // Helper functions
  int _parseDuration(String duration) {
    if (duration.isEmpty) return 0;
    
    int totalMinutes = 0;
    final hoursMatch = RegExp(r'(\d+)\s*h').firstMatch(duration);
    final minutesMatch = RegExp(r'(\d+)\s*m').firstMatch(duration);
    
    if (hoursMatch != null) {
      totalMinutes += int.parse(hoursMatch.group(1)!) * 60;
    }
    if (minutesMatch != null) {
      totalMinutes += int.parse(minutesMatch.group(1)!);
    }
    
    return totalMinutes;
  }

  double _parseNumeric(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  void _calculateHours() {
    setState(() {
      // Calculate gross hours from compteur indexes
      double totalGrossHours = 0;
      for (int i = 0; i < formData.indexCompteurs.length; i++) {
        final start = _parseNumeric(formData.indexCompteurs[i].debut);
        final end = _parseNumeric(formData.indexCompteurs[i].fin);
        if (end > start) {
          final shiftHours = (end - start) / 100; // Assuming compteur is in 0.01 hour units
          totalGrossHours += shiftHours;
        }
      }
      
      formData.exploitation['heuresBrutes'] = totalGrossHours.toStringAsFixed(2);
      
      // Calculate total stoppage time
      int totalStoppageMinutes = 0;
      for (var item in formData.ventilation) {
        totalStoppageMinutes += _parseDuration(item.duree);
      }
      
      final stoppageHours = totalStoppageMinutes / 60;
      formData.exploitation['heuresArrets'] = stoppageHours.toStringAsFixed(2);
      
      // Calculate net hours
      final netHours = totalGrossHours - stoppageHours;
      formData.exploitation['heuresNettes'] = netHours.toStringAsFixed(2);
    });
  }

  bool _validateCompteurIndexes() {
    for (int i = 0; i < formData.indexCompteurs.length; i++) {
      final start = _parseNumeric(formData.indexCompteurs[i].debut);
      final end = _parseNumeric(formData.indexCompteurs[i].fin);
      
      if (end <= start) {
        return false;
      }
      
      final shiftHours = (end - start) / 100;
      if (shiftHours > 8) {
        return false;
      }
      
      // Validate continuity between shifts
      if (i > 0) {
        final previousEnd = _parseNumeric(formData.indexCompteurs[i - 1].fin);
        if ((start - previousEnd).abs() > 0.1) { // Allow small tolerance
          return false;
        }
      } else if (widget.previousDayThirdShiftEnd != null) {
        final previousEnd = _parseNumeric(widget.previousDayThirdShiftEnd!);
        if ((start - previousEnd).abs() > 0.1) {
          return false;
        }
      }
    }
    return true;
  }

  // UI Building methods
  Widget _buildHeaderSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informations Générales',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Entrée',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.entree,
                    onChanged: (value) {
                      setState(() {
                        formData.entree = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Secteur',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.secteur,
                    onChanged: (value) {
                      setState(() {
                        formData.secteur = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'N° Rapport',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.rapportNo,
                    onChanged: (value) {
                      setState(() {
                        formData.rapportNo = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'S.A',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.sa,
                    onChanged: (value) {
                      setState(() {
                        formData.sa = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Machine/Engins',
                border: OutlineInputBorder(),
              ),
              value: formData.machineEngins.isEmpty ? null : formData.machineEngins,
              hint: const Text('Sélectionner une machine'),
              isExpanded: true,
              items: machineOptions.map((String machine) {
                return DropdownMenuItem<String>(
                  value: machine,
                  child: Text(
                    machine,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  formData.machineEngins = newValue ?? '';
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez sélectionner une machine';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Unité',
                border: OutlineInputBorder(),
              ),
              initialValue: formData.unite,
              onChanged: (value) {
                setState(() {
                  formData.unite = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompteurSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Index Compteur par Poste',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${posteOrder[index]} Poste (${posteTimes[posteOrder[index]]})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Début',
                              border: OutlineInputBorder(),
                              suffixText: 'h',
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: formData.indexCompteurs[index].debut,
                            onChanged: (value) {
                              setState(() {
                                formData.indexCompteurs[index].debut = value;
                                _calculateHours();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Fin',
                              border: OutlineInputBorder(),
                              suffixText: 'h',
                            ),
                            keyboardType: TextInputType.number,
                            initialValue: formData.indexCompteurs[index].fin,
                            onChanged: (value) {
                              setState(() {
                                formData.indexCompteurs[index].fin = value;
                                _calculateHours();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    if (!_validateCompteurIndexes() && 
                        (formData.indexCompteurs[index].debut.isNotEmpty || 
                         formData.indexCompteurs[index].fin.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Vérifiez les valeurs du compteur',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPosteSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélection du Poste',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...posteOrder.map((poste) {
              return RadioListTile<String>(
                title: Text('$poste Poste (${posteTimes[poste]})'),
                value: poste,
                groupValue: formData.selectedPoste,
                onChanged: (value) {
                  setState(() {
                    formData.selectedPoste = value!;
                  });
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVentilationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ventilation des Arrêts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Arrêt')),
                  DataColumn(label: Text('Durée')),
                  DataColumn(label: Text('Note')),
                ],
                rows: formData.ventilation.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(Text(item.code.toString())),
                      DataCell(Text(item.label)),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: '1h 30m',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: item.duree,
                            onChanged: (value) {
                              setState(() {
                                item.duree = value;
                                _calculateHours();
                              });
                            },
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Note',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: item.note,
                            onChanged: (value) {
                              setState(() {
                                item.note = value;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Explication des Arrêts',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              initialValue: formData.arretsExplication,
              onChanged: (value) {
                setState(() {
                  formData.arretsExplication = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploitationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exploitation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Heures Brutes',
                      border: OutlineInputBorder(),
                      suffixText: 'h',
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: formData.exploitation['heuresBrutes']),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Heures Arrêts',
                      border: OutlineInputBorder(),
                      suffixText: 'h',
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: formData.exploitation['heuresArrets']),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Heures Nettes',
                      border: OutlineInputBorder(),
                      suffixText: 'h',
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: formData.exploitation['heuresNettes']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Tonnage',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: formData.exploitation['tonnage'],
                    onChanged: (value) {
                      setState(() {
                        formData.exploitation['tonnage'] = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Rendement',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: formData.exploitation['rendement'],
                    onChanged: (value) {
                      setState(() {
                        formData.exploitation['rendement'] = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepartitionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition du Temps de Travail Pur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...List.generate(3, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${posteOrder[index]} Poste',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Chantier',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: formData.repartitionTravail[index].chantier,
                            onChanged: (value) {
                              setState(() {
                                formData.repartitionTravail[index].chantier = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Temps',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: formData.repartitionTravail[index].temps,
                            onChanged: (value) {
                              setState(() {
                                formData.repartitionTravail[index].temps = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Imputation',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: formData.repartitionTravail[index].imputation,
                            onChanged: (value) {
                              setState(() {
                                formData.repartitionTravail[index].imputation = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personnel',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Conducteur',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.personnel.conducteur,
                    onChanged: (value) {
                      setState(() {
                        formData.personnel.conducteur = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Graisseur',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: formData.personnel.graisseur,
                    onChanged: (value) {
                      setState(() {
                        formData.personnel.graisseur = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Matricules',
                border: OutlineInputBorder(),
              ),
              initialValue: formData.personnel.matricules,
              onChanged: (value) {
                setState(() {
                  formData.personnel.matricules = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsommationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suivi Consommation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Tricone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: formData.consommation.tricone,
                    onChanged: (value) {
                      setState(() {
                        formData.consommation.tricone = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Gasoil',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: formData.consommation.gasoil,
                    onChanged: (value) {
                      setState(() {
                        formData.consommation.gasoil = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vérification du Rapport',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildSummaryItem('Date du rapport', DateFormat('dd/MM/yyyy').format(_selectedDate)),
            _buildSummaryItem('Entrée', formData.entree),
            _buildSummaryItem('Secteur', formData.secteur),
            _buildSummaryItem('Machine/Engins', formData.machineEngins),
            _buildSummaryItem('Heures Brutes', '${formData.exploitation['heuresBrutes']}h'),
            _buildSummaryItem('Heures Nettes', '${formData.exploitation['heuresNettes']}h'),
            _buildSummaryItem('Conducteur', formData.personnel.conducteur),
            const SizedBox(height: 16),
            if (!_validateCompteurIndexes())
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Veuillez corriger les erreurs dans les index compteur avant de soumettre',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? 'Non renseigné' : value),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final report = Report(
        description: 'Brouillon R0 - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'R0',
        type: 'r0_draft',
        additionalData: _serializeFormData(),
      );

      await _databaseHelper.insertReport(report);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brouillon enregistré avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_validateCompteurIndexes()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les erreurs avant de soumettre'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final report = Report(
        description: 'Rapport R0 - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'R0',
        type: 'r0_report',
        additionalData: _serializeFormData(),
      );

      await _databaseHelper.insertReport(report);
      
      if (!mounted) return;
      
      final l10n = AppLocalizations.of(context)!;
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
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _serializeFormData() {
    return {
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
      'selectedPoste': formData.selectedPoste,
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
      'personnel': {
        'conducteur': formData.personnel.conducteur,
        'graisseur': formData.personnel.graisseur,
        'matricules': formData.personnel.matricules,
      },
      'consommation': {
        'tricone': formData.consommation.tricone,
        'gasoil': formData.consommation.gasoil,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rapport Journalier Détaillé (R0)"),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 6) {
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
                          child: Text(_currentStep == 6 ? 'Terminer' : 'Suivant'),
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
                    state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('En-tête'),
                    content: _buildHeaderSection(),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Compteurs'),
                    content: _buildCompteurSection(),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Poste'),
                    content: _buildPosteSelection(),
                    isActive: _currentStep >= 3,
                    state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Ventilation'),
                    content: _buildVentilationSection(),
                    isActive: _currentStep >= 4,
                    state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Exploitation'),
                    content: _buildExploitationSection(),
                    isActive: _currentStep >= 5,
                    state: _currentStep > 5 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Répartition'),
                    content: _buildRepartitionSection(),
                    isActive: _currentStep >= 6,
                    state: _currentStep > 6 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Personnel'),
                    content: _buildPersonnelSection(),
                    isActive: _currentStep >= 7,
                    state: _currentStep > 7 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Consommation'),
                    content: _buildConsommationSection(),
                    isActive: _currentStep >= 8,
                    state: _currentStep > 8 ? StepState.complete : StepState.indexed,
                  ),
                  Step(
                    title: const Text('Vérification'),
                    content: _buildVerificationSection(),
                    isActive: _currentStep >= 9,
                    state: _currentStep > 9 ? StepState.complete : StepState.indexed,
                  ),
                ],
              ),
              if (_currentStep == 9) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _saveDraft,
                        child: const Text('Enregistrer Brouillon'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitReport,
                        child: const Text('Soumettre Rapport'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}