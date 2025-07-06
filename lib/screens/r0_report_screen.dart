import 'package:flutter/material.dart';
import 'package:r0_app/services/database_helper.dart';
import 'package:r0_app/models/report.dart';
// import 'package:r0_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

// Data models
class IndexCompteurPoste {
  String duree;
  String note;
  IndexCompteurPoste({this.duree = '', this.note = ''});
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

class ZoneData {
  final String name;
  final List<String> sorties;
  ZoneData({required this.name, required this.sorties});
}

class MineData {
  final String name;
  final List<ZoneData> zones;
  MineData({required this.name, required this.zones});
}

class R0ReportFormData {
  String entree = '';
  String selectedMine = '';
  String selectedZone = '';
  String selectedSortie = '';
  String rapportNo = '';
  String unite = '';
  List<IndexCompteurPoste> indexCompteurs = List.generate(3, (_) => IndexCompteurPoste());
  List<String> shifts = List.generate(3, (_) => '');
  String selectedPoste = '';
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
  String selectedCategory = '';
  String selectedType = '';
  String selectedModel = '';
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

  final posteOrder = const ["3ème", "1er", "2ème"];
  final posteTimes = const {
    "3ème": "22:30 - 06:30",
    "1er": "06:30 - 14:30",
    "2ème": "14:30 - 22:30",
  };

  // Ventilation codes and labels
  final List<VentilationItem> ventilationCodes = [
    VentilationItem(code: 121, label: "ARRET CARREAU INDUSTRIEL"),
  ];

  // Static mine/zone/sortie data
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

// Add ENGINS and MACHINES data maps
static const Map<String, List<String>> enginsData = {
  'BULLDOZERS': [
    'BULL D9R 76', 'BULL D9R 79', 'BULL D9R 80', 'BULL D9R 81', 'BULL D9R 82', 'BULL D9R 83', 'BULL LIB 84', 'BULL LIB 85', 'BULL D9R 86', 'BULL D9R 87',
  ],
  'CAMIONS': [
    'CAMION T24', 'CAMION T25', 'CAMION T26', 'CAMION T27', 'CAMION T28', 'CAMION T29', 'CAMION T30', 'CAMION T31', 'CAMION T32', 'CAMION T33', 'WABCO 13', 'WABCO 19',
  ],
  'CHARGEUSES': ['CHRG 992C', 'CHRG 992K', 'CHRG 994H'],
  'NIVELEUSES': ['NIV 14G', 'NIV 16H', 'NIV KOM01', 'NIV KOM02'],
  'PAYDOZERS': ['PAY CAT03', 'PAY KOM04', 'PAY KOM05'],
  'PELLE HYDRAULIQUE': ['PH365-C', 'PH5130'],
};
static const Map<String, List<String>> machinesData = {
  'DRAGLINES': ['1370 W1', '1370 W2'],
  'PELLE ELECTRIQUE': ['195 P1', '195 P2'],
  'SONDEUSES': ['PV275-1', 'PV275-2', 'PV275-3'],
};

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
  double _parseNumeric(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  void _calculateHours() {
    // Calculate gross hours from compteur indexes
    double totalGrossHours = 0;
    for (int i = 0; i < formData.indexCompteurs.length; i++) {
      final start = _parseNumeric(formData.indexCompteurs[i].duree);
      final end = _parseNumeric(formData.indexCompteurs[i].note);
      if (end > start) {
        final shiftHours = (end - start) / 1; // Assuming compteur is in 1.0 hour units
        totalGrossHours += shiftHours;
      }
    }
    
    formData.exploitation['heuresBrutes'] = totalGrossHours.toStringAsFixed(2);
    
    // Calculate total stoppage time from ventilation data
    double totalStoppageHours = 0;
    for (var item in formData.ventilation) {
      if (item.duree.isNotEmpty && item.note.isNotEmpty) {
        // Parse time format HH:MM
        final startParts = item.duree.split(':');
        final endParts = item.note.split(':');
        if (startParts.length == 2 && endParts.length == 2) {
          final startHour = int.parse(startParts[0]);
          final startMin = int.parse(startParts[1]);
          final endHour = int.parse(endParts[0]);
          final endMin = int.parse(endParts[1]);
          
          final startTotal = startHour * 60 + startMin;
          final endTotal = endHour * 60 + endMin;
          int diff = endTotal - startTotal;
          if (diff <= 0) diff += 24 * 60; // Handle overnight periods
          
          totalStoppageHours += diff / 60.0;
        }
      }
    }
    
    formData.exploitation['heuresArrets'] = totalStoppageHours.toStringAsFixed(2);
  }

  // UI Building methods
  Widget _buildHierarchicalSelectionDialog(BuildContext context) {
    int step = 0;
    return StatefulBuilder(
      builder: (context, setDialogState) {
        MineData? selectedMine = formData.selectedMine.isNotEmpty
            ? minesData.where((m) => m.name == formData.selectedMine).isNotEmpty
                ? minesData.firstWhere((m) => m.name == formData.selectedMine)
                : null
            : null;
        ZoneData? selectedZone = (selectedMine != null && formData.selectedZone.isNotEmpty)
            ? selectedMine.zones.where((z) => z.name == formData.selectedZone).isNotEmpty
                ? selectedMine.zones.firstWhere((z) => z.name == formData.selectedZone)
                : null
            : null;
        String? selectedSortie = (selectedZone != null && formData.selectedSortie.isNotEmpty)
            ? formData.selectedSortie
            : null;
        String? selectedPoste = formData.selectedPoste.isNotEmpty ? formData.selectedPoste : null;
        String? selectedCategory = formData.selectedCategory.isNotEmpty ? formData.selectedCategory : null;
        String? selectedType = formData.selectedType.isNotEmpty ? formData.selectedType : null;
        String? selectedModel = formData.selectedModel.isNotEmpty ? formData.selectedModel : null;

        void goNext() => setDialogState(() => step++);
        void goBack() => setDialogState(() => step--);

        Widget content;
        if (step == 0) {
          content = DropdownButtonFormField<MineData>(
            value: selectedMine,
            decoration: const InputDecoration(labelText: 'Mine', border: OutlineInputBorder()),
            items: minesData.map((mine) => DropdownMenuItem(value: mine, child: Text(mine.name))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedMine = value?.name ?? '';
                formData.selectedZone = '';
                formData.selectedSortie = '';
                formData.selectedPoste = '';
                formData.selectedCategory = '';
                formData.selectedType = '';
                formData.selectedModel = '';
              });
            },
          );
        } else if (step == 1 && selectedMine != null) {
          content = DropdownButtonFormField<ZoneData>(
            value: selectedZone,
            decoration: const InputDecoration(labelText: 'Zone', border: OutlineInputBorder()),
            items: selectedMine.zones.map((zone) => DropdownMenuItem(value: zone, child: Text(zone.name))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedZone = value?.name ?? '';
                formData.selectedSortie = '';
                formData.selectedPoste = '';
                formData.selectedCategory = '';
                formData.selectedType = '';
                formData.selectedModel = '';
              });
            },
          );
        } else if (step == 2) {
          content = DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'ENGINS', child: Text('ENGINS')),
              DropdownMenuItem(value: 'MACHINES', child: Text('MACHINES')),
            ],
            onChanged: (value) {
              setDialogState(() {
                formData.selectedCategory = value ?? '';
                formData.selectedType = '';
                formData.selectedModel = '';
              });
            },
          );
        } else if (step == 3 && selectedCategory != null) {
          final types = selectedCategory == 'ENGINS'
              ? enginsData.keys.toList()
              : machinesData.keys.toList();
          content = DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedType = value ?? '';
                formData.selectedModel = '';
              });
            },
          );
        } else if (step == 4 && selectedType != null) {
          final models = selectedCategory == 'ENGINS'
              ? enginsData[selectedType] ?? []
              : machinesData[selectedType] ?? [];
          content = DropdownButtonFormField<String>(
            value: selectedModel,
            decoration: const InputDecoration(labelText: 'Modèle', border: OutlineInputBorder()),
            items: models.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedModel = value ?? '';
              });
            },
          );
        } else if (step == 5 && selectedZone != null && selectedZone.sorties.isNotEmpty) {
          content = DropdownButtonFormField<String>(
            value: selectedSortie,
            decoration: const InputDecoration(labelText: 'Sortie', border: OutlineInputBorder()),
            items: selectedZone.sorties.map((sortie) => DropdownMenuItem(value: sortie, child: Text(sortie))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedSortie = value ?? '';
                formData.selectedPoste = '';
              });
            },
          );
        } else if ((step == 5 && selectedZone != null && selectedZone.sorties.isEmpty) || step == 6) {
          content = DropdownButtonFormField<String>(
            value: selectedPoste,
            decoration: const InputDecoration(labelText: 'Poste', border: OutlineInputBorder()),
            items: posteOrder.map((poste) => DropdownMenuItem(value: poste, child: Text('$poste Poste (${posteTimes[poste]})'))).toList(),
            onChanged: (value) {
              setDialogState(() {
                formData.selectedPoste = value ?? posteOrder.first;
              });
            },
          );
        } else {
          content = const SizedBox();
        }

        // Determine if all steps are filled for 'Terminer'
        bool canFinish = formData.selectedMine.isNotEmpty &&
            formData.selectedZone.isNotEmpty &&
            formData.selectedCategory.isNotEmpty &&
            formData.selectedType.isNotEmpty &&
            formData.selectedModel.isNotEmpty &&
            (selectedZone == null || selectedZone.sorties.isEmpty || formData.selectedSortie.isNotEmpty) &&
            formData.selectedPoste.isNotEmpty;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step == 0) ...[
              const Text('Sélection de la Mine', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 1) ...[
              const Text('Sélection de la Zone', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 2) ...[
              const Text('Sélection Catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 3) ...[
              const Text('Sélection Type', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 4) ...[
              const Text('Sélection Modèle', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 5 && selectedZone != null && selectedZone.sorties.isNotEmpty) ...[
              const Text('Sélection de la Sortie', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if ((step == 5 && selectedZone != null && selectedZone.sorties.isEmpty) || step == 6) ...[
              const Text('Sélection du Poste', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (step > 0)
                  OutlinedButton(
                    onPressed: step > 0 ? goBack : null,
                    child: const Text('Précédent'),
                  ),
                if ((step == 0 && selectedMine != null) ||
                    (step == 1 && selectedZone != null) ||
                    (step == 2 && selectedCategory != null) ||
                    (step == 3 && selectedType != null) ||
                    (step == 4 && selectedModel != null) ||
                    (step == 5 && selectedZone != null && (selectedZone.sorties.isEmpty || selectedSortie != null)) ||
                    (step == 6 && selectedPoste != null)
                )
                  ElevatedButton(
                    onPressed: () {
                      if (step == 0 && selectedMine != null) {
                        goNext();
                      } else if (step == 1 && selectedZone != null) {
                        goNext();
                      } else if (step == 2 && selectedCategory != null) {
                        goNext();
                      } else if (step == 3 && selectedType != null) {
                        goNext();
                      } else if (step == 4 && selectedModel != null) {
                        goNext();
                      } else if (step == 5 && selectedZone != null && (selectedZone.sorties.isEmpty || selectedSortie != null)) {
                        goNext();
                      } else if ((step == 6 && selectedPoste != null) && canFinish) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text((step == 6 || (step == 5 && selectedZone != null && selectedZone.sorties.isEmpty)) && canFinish ? 'Terminer' : 'Suivant'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompteurSection() {
    final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
    if (selectedPosteIndex == -1) {
      return const Text('Veuillez sélectionner un poste.');
    }

    // Parse allowed hours for the selected poste
    String timeRange = posteTimes[posteOrder[selectedPosteIndex]] ?? '';
    double allowedHours = 0.0;
    if (timeRange.isNotEmpty) {
      final parts = timeRange.split(' - ');
      if (parts.length == 2) {
        final start = parts[0].split(':');
        final end = parts[1].split(':');
        if (start.length == 2 && end.length == 2) {
          int startHour = int.parse(start[0]);
          int startMin = int.parse(start[1]);
          int endHour = int.parse(end[0]);
          int endMin = int.parse(end[1]);
          // Handle overnight shift (e.g., 22:30 - 06:30)
          int startTotal = startHour * 60 + startMin;
          int endTotal = endHour * 60 + endMin;
          int diff = endTotal - startTotal;
          if (diff <= 0) diff += 24 * 60;
          allowedHours = diff / 60.0;
        }
      }
    }

    String? errorText;
    final compteur = formData.indexCompteurs[selectedPosteIndex];
    final debut = _parseNumeric(compteur.duree);
    final fin = _parseNumeric(compteur.note);
    final marche = fin > debut ? (fin - debut) / 100 : 0.0;
    if (marche > allowedHours) {
      errorText =
          'Heure de marche (${marche.toStringAsFixed(2)}h) dépasse la durée maximale autorisée pour ce poste (${allowedHours.toStringAsFixed(2)}h).';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compteur - ${formData.selectedPoste} Poste',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          '${posteOrder[selectedPosteIndex]} Poste (${posteTimes[posteOrder[selectedPosteIndex]]})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Début',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: compteur.duree,
          onChanged: (value) {
            setState(() {
              formData.indexCompteurs[selectedPosteIndex].duree = value;
            });
            _calculateHours();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Fin',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          initialValue: compteur.note,
          onChanged: (value) {
            setState(() {
              formData.indexCompteurs[selectedPosteIndex].note = value;
            });
            _calculateHours();
          },
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            errorText,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ],
    );
  }

  Widget _buildExploitationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exploitation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Heures marche',
            border: const OutlineInputBorder(),
            suffixText: 'h',
            filled: true,
            fillColor: Colors.grey[100],
          ),
          readOnly: true,
          controller: TextEditingController(text: formData.exploitation['heuresBrutes']),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Heures Arrêts',
            border: const OutlineInputBorder(),
            suffixText: 'h',
            filled: true,
            fillColor: Colors.grey[100],
          ),
          readOnly: true,
          controller: TextEditingController(text: formData.exploitation['heuresArrets']),
        ),
        const SizedBox(height: 16),
        TextFormField(
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
        const SizedBox(height: 16),
        TextFormField(
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
      ],
    );
  }

  Widget _buildRepartitionSection() {
    // Get the index of the selected poste
    final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
    if (selectedPosteIndex == -1) {
      return const Text('Veuillez sélectionner un poste.');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Répartition du Temps de Travail Pur - ${formData.selectedPoste} Poste',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Text(
          '${posteOrder[selectedPosteIndex]} Poste',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Chantier',
            border: OutlineInputBorder(),
          ),
          initialValue: formData.repartitionTravail[selectedPosteIndex].chantier,
          onChanged: (value) {
            setState(() {
              formData.repartitionTravail[selectedPosteIndex].chantier = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Temps',
            border: OutlineInputBorder(),
          ),
          initialValue: formData.repartitionTravail[selectedPosteIndex].temps,
          onChanged: (value) {
            setState(() {
              formData.repartitionTravail[selectedPosteIndex].temps = value;
            });
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Imputation',
            border: OutlineInputBorder(),
          ),
          initialValue: formData.repartitionTravail[selectedPosteIndex].imputation,
          onChanged: (value) {
            setState(() {
              formData.repartitionTravail[selectedPosteIndex].imputation = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPersonnelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personnel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
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
        const SizedBox(height: 16),
        TextFormField(
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
    );
  }

  Widget _buildConsommationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suivi Consommation',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextFormField(
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
        const SizedBox(height: 16),
        TextFormField(
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
      ],
    );
  }

  // Removed unused _buildVerificationSection method

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



  Future<void> _saveReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final report = Report(
        description: 'Rapport R0 - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'R0',
        type: 'r0_submitted',
        additionalData: _serializeFormData(),
      );

      await _databaseHelper.insertReport(report);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapport soumis avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back to home screen
      Navigator.of(context).pop();
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
      'mine': formData.selectedMine,
      'zone': formData.selectedZone,
      'sortie': formData.selectedSortie,
      'rapportNo': formData.rapportNo,
      'unite': formData.unite,
      'indexCompteurs': formData.indexCompteurs.map((ic) => {
        'duree': ic.duree,
        'note': ic.note,
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

  static const Map<String, List<String>> arretCategories = {
    'EXTERIEURS': [
      'ARRET CARREAU INDUSTRIEL',
      'COUPURE GENERALE DU COURANT',
      'GREVE',
      'INTEMPERIES',
      'STOCKS PLEINS',
      'J. FERIES OU HEBDOMADAIRES',
      'ARRET PAR LA CENTRALE (M.ENERGIE)',
      'CONTROLE',
    ],
    'MATERIEL': [
      'DEFAUT ELEC. (C.CRAME, RESEAU)',
      'PANNE MECANIQUE',
      'PANNE ELECTRIQUE',
      'INTERVENTION ATELIER PNEUMATIQUE',
      'ENTRETIEN SYSTEMATIQUE',
      'APPOINT (HUILE, GAZOL, EAU)',
      'GRAISSAGE',
      'ARRET ELEC. INSTALATION FIXES',
      'MANQUE CAMIONS',
      'MANQUE BULL',
      'MANQUE MECANICIEN',
      'MANQUE D\'OUTILS DE TRAVAIL',
      'MACHINE A L\'ARRET',
      'PANNE ENGIN DEVANT MACHINE',
    ],
    'EXPLOITATION': [
      'RELEVE',
      'EXECUTION PLATE FORME',
      'DEPLACEMENT',
      'TIR ET SAUTAGE',
      'MOUV. DE CABLE',
      'ARRET DECIDE',
      'MANQUE CONDUCTEUR',
      'BRIQUET',
      'PISTES (INTEMPERIES EXCLUES)',
      'ARRETS MECA. INSTALATIONS FIXES',
      'TELESCOPAGE',
      'EXCAVATION PURE',
      'TERASSEMENT PUR',
    ],
  };

  Widget _buildAddVentilationDialog(BuildContext context) {
    int step = 0;
    String? selectedCategory;
    String? selectedType;
    String startTime = '';
    String endTime = '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        Widget content;
        if (step == 0) {
          content = DropdownButtonFormField<String>(
            value: selectedCategory,
            decoration: const InputDecoration(labelText: 'Catégorie', border: OutlineInputBorder()),
            items: arretCategories.keys
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) {
              setDialogState(() {
                selectedCategory = value;
                selectedType = null;
              });
            },
          );
        } else if (step == 1 && selectedCategory != null) {
          content = DropdownButtonFormField<String>(
            value: selectedType,
            decoration: const InputDecoration(labelText: 'Type d\'arrêt', border: OutlineInputBorder()),
            items: arretCategories[selectedCategory]!
                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                .toList(),
            onChanged: (value) {
              setDialogState(() {
                selectedType = value;
              });
            },
          );
        } else if (step == 2 && selectedType != null) {
          content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catégorie: $selectedCategory'),
              Text('Type: $selectedType'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Heure début'),
                subtitle: Text(startTime.isEmpty ? 'Sélectionner l\'heure' : startTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Heure fin'),
                subtitle: Text(endTime.isEmpty ? 'Sélectionner l\'heure' : endTime),
                trailing: const Icon(Icons.access_time),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
            ],
          );
        } else {
          content = const SizedBox();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (step == 0) ...[
              const Text('Sélection de la catégorie', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 1) ...[
              const Text('Sélection du type d\'arrêt', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 2) ...[
              const Text('Saisie des détails', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (step > 0)
                  OutlinedButton(
                    onPressed: () => setDialogState(() => step--),
                    child: const Text('Précédent'),
                  ),
                if ((step == 0 && selectedCategory != null) ||
                    (step == 1 && selectedType != null))
                  ElevatedButton(
                    onPressed: () {
                      setDialogState(() => step++);
                    },
                    child: const Text('Suivant'),
                  ),
                if (step == 2 && selectedType != null)
                  ElevatedButton(
                    onPressed: startTime.isNotEmpty && endTime.isNotEmpty
                        ? () {
                            setState(() {
                              formData.ventilation.add(VentilationItem(
                                code: 0, // You can assign a code if needed
                                label: selectedType!,
                                duree: startTime,
                                note: endTime,
                              ));
                            });
                            _calculateHours();
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('Terminer'),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rapport R0"),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stepper(
                  currentStep: _currentStep,
                  onStepContinue: () {
                    if (_currentStep < 7) {
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
                    if (_currentStep == 7) {
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
                                onPressed: () => _saveReport(),
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
                          if (_currentStep > 0)
                            const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: details.onStepContinue,
                              child: Text(_currentStep == 8 ? 'Terminer' : 'Suivant'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  steps: [
                    Step(
                      title: const Text('Date du rapport'),
                      content: Column(
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
                      isActive: _currentStep >= 0,
                      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Info OIB/EE'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 2: INFO OIB/EE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Info OIB/EE'),
                                        content: SingleChildScrollView(
                                          child: _buildHierarchicalSelectionDialog(context),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Info OIB/EE'),
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
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Liste Info OIB/EE'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Modifier Info OIB/EE'),
                                                      content: SingleChildScrollView(
                                                        child: _buildHierarchicalSelectionDialog(context),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.selectedMine = '';
                                                    formData.selectedZone = '';
                                                    formData.selectedSortie = '';
                                                    formData.selectedCategory = '';
                                                    formData.selectedType = '';
                                                    formData.selectedModel = '';
                                                    formData.selectedPoste = '';
                                                  });
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Info OIB/EE supprimée'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildSummaryItem('Mine', formData.selectedMine),
                                              _buildSummaryItem('Zone', formData.selectedZone),
                                              _buildSummaryItem('Sortie', formData.selectedSortie),
                                              _buildSummaryItem('Catégorie', formData.selectedCategory),
                                              _buildSummaryItem('Type', formData.selectedType),
                                              _buildSummaryItem('Modèle', formData.selectedModel),
                                              _buildSummaryItem('Poste', formData.selectedPoste),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Info OIB/EE'),
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
                      ),
                      isActive: _currentStep >= 1,
                      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Compteurs'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 3: INDEX COMPTEURS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Compteur'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildCompteurSection(),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Compteur'),
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
                                  onPressed: () {
                                    // Get the index of the selected poste
                                    final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
                                    if (selectedPosteIndex == -1) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Veuillez d\'abord sélectionner un poste'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    final compteur = formData.indexCompteurs[selectedPosteIndex];
                                    final debut = _parseNumeric(compteur.duree);
                                    final fin = _parseNumeric(compteur.note);
                                    final heureMarche = fin > debut ? (fin - debut) / 1 : 0.0; // Assuming compteur is in 1.0 hour units
                                    
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Compteur - ${formData.selectedPoste} Poste'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('Modifier Compteur - ${formData.selectedPoste} Poste'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            _buildCompteurSection(),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.indexCompteurs[selectedPosteIndex].duree = '';
                                                    formData.indexCompteurs[selectedPosteIndex].note = '';
                                                  });
                                                  _calculateHours();
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Compteur supprimé'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildSummaryItem('Début', compteur.duree.isEmpty ? 'Non renseigné' : compteur.duree),
                                              _buildSummaryItem('Fin', compteur.note.isEmpty ? 'Non renseigné' : compteur.note),
                                              _buildSummaryItem('Heure de marche', '${heureMarche.toStringAsFixed(2)}h'),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Compteur'),
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
                      ),
                      isActive: _currentStep >= 2,
                      state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Arrêts'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 4: DES ARRÊTS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Arrêts'),
                                        content: SingleChildScrollView(
                                          child: _buildAddVentilationDialog(context),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Arrêts'),
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
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Liste Arrêts'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Modifier Arrêts'),
                                                      content: SingleChildScrollView(
                                                        child: _buildAddVentilationDialog(context),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.ventilation.clear();
                                                  });
                                                  _calculateHours();
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Tous les arrêts supprimés'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: formData.ventilation.map((v) => Text('Type: ${v.label}, Début: ${v.duree}, Fin: ${v.note}')).toList(),
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Arrêts'),
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
                      ),
                      isActive: _currentStep >= 3,
                      state: _currentStep > 3 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Exploitation'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 5: EXPLOITATION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Exploitation'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildExploitationSection(),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Exploitation'),
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
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Liste Exploitation'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Modifier Exploitation'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            _buildExploitationSection(),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.exploitation['tonnage'] = '';
                                                    formData.exploitation['rendement'] = '';
                                                  });
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Données d\'exploitation supprimées'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Heures marche: ${formData.exploitation['heuresBrutes']}'),
                                              Text('Heures Arrêts: ${formData.exploitation['heuresArrets']}'),
                                              Text('Tonnage: ${formData.exploitation['tonnage']}'),
                                              Text('Rendement: ${formData.exploitation['rendement']}'),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Exploitation'),
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
                      ),
                      isActive: _currentStep >= 4,
                      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Répartition'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 6: RÉPARTITION DU TRAVAIL',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Répartition'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildRepartitionSection(),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Répartition'),
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
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Liste Répartition'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Modifier Répartition'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            _buildRepartitionSection(),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.repartitionTravail = List.generate(3, (_) => RepartitionItem());
                                                  });
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Répartition supprimée'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              (() {
                                                final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
                                                if (selectedPosteIndex != -1) {
                                                  final r = formData.repartitionTravail[selectedPosteIndex];
                                                  return Text(
                                                    'Poste ${posteOrder[selectedPosteIndex]}: Chantier ${r.chantier}, Temps ${r.temps}, Imputation ${r.imputation}'
                                                  );
                                                } else {
                                                  return const Text('Aucun poste sélectionné.');
                                                }
                                              })(),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Répartition'),
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
                      ),
                      isActive: _currentStep >= 5,
                      state: _currentStep > 5 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Personnel & Consommation'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 7: PERSONNEL & CONSOMMATION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter Personnel & Consommation'),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildPersonnelSection(),
                                              const SizedBox(height: 24),
                                              _buildConsommationSection(),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter'),
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
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Liste Personnel & Consommation'),
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
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  Navigator.of(context).pop();
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Modifier Personnel & Consommation'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          mainAxisSize: MainAxisSize.min,
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            _buildPersonnelSection(),
                                                            const SizedBox(height: 24),
                                                            _buildConsommationSection(),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.of(context).pop(),
                                                          child: const Text('Terminer'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else if (value == 'delete') {
                                                  setState(() {
                                                    formData.personnel.conducteur = '';
                                                    formData.personnel.graisseur = '';
                                                    formData.personnel.matricules = '';
                                                    formData.consommation.tricone = '';
                                                    formData.consommation.gasoil = '';
                                                  });
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Personnel & Consommation supprimés'),
                                                      backgroundColor: Colors.orange,
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Conducteur: ${formData.personnel.conducteur}'),
                                              Text('Graisseur: ${formData.personnel.graisseur}'),
                                              Text('Matricules: ${formData.personnel.matricules}'),
                                              Text('Tricone: ${formData.consommation.tricone}'),
                                              Text('Gasoil: ${formData.consommation.gasoil}'),
                                            ],
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Terminer'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir Personnel & Consommation'),
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
                      ),
                      isActive: _currentStep >= 6,
                      state: _currentStep > 6 ? StepState.complete : StepState.indexed,
                    ),
                    Step(
                      title: const Text('Vérification'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 9: VÉRIFICATION R0',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
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
                                          const Padding(
                                            padding: EdgeInsets.fromLTRB(14, 10, 6, 10),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Vérification du Rapport R0',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                                                          _buildInfoRow('Date du rapport', DateFormat('dd/MM/yyyy').format(_selectedDate)),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Info OIB/EE Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Info OIB/EE',
                                                            style: Theme.of(context).textTheme.titleMedium,
                                                          ),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('Mine', formData.selectedMine),
                                                          _buildInfoRow('Zone', formData.selectedZone),
                                                          _buildInfoRow('Sortie', formData.selectedSortie),
                                                          _buildInfoRow('Catégorie', formData.selectedCategory),
                                                          _buildInfoRow('Type', formData.selectedType),
                                                          _buildInfoRow('Modèle', formData.selectedModel),
                                                          _buildInfoRow('Poste', formData.selectedPoste),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Compteurs Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Compteurs',
                                                            style: Theme.of(context).textTheme.titleMedium,
                                                          ),
                                                          const Divider(height: 16),
                                                          ...List.generate(formData.indexCompteurs.length, (index) {
                                                             final compteur = formData.indexCompteurs[index];
                                                             if (compteur.duree.isEmpty && compteur.note.isEmpty) return const SizedBox.shrink();
                                                             return Column(
                                                               crossAxisAlignment: CrossAxisAlignment.start,
                                                               children: [
                                                                 Text(
                                                                   '${posteOrder[index]} Poste',
                                                                   style: Theme.of(context).textTheme.titleSmall,
                                                                 ),
                                                                 const SizedBox(height: 8),
                                                                 _buildInfoRow('Début', compteur.duree),
                                                                 _buildInfoRow('Fin', compteur.note),
                                                                 const Divider(height: 16),
                                                               ],
                                                             );
                                                           }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Exploitation Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Exploitation',
                                                            style: Theme.of(context).textTheme.titleMedium,
                                                          ),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('Heures marche', '${formData.exploitation['heuresBrutes']}h'),
                                                          _buildInfoRow('Heures Arrêts', '${formData.exploitation['heuresArrets']}h'),
                                                          _buildInfoRow('Tonnage', '${formData.exploitation['tonnage']}t'),
                                                          _buildInfoRow('Rendement', '${formData.exploitation['rendement']}%'),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Personnel Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Personnel',
                                                            style: Theme.of(context).textTheme.titleMedium,
                                                          ),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('Conducteur', formData.personnel.conducteur),
                                                          _buildInfoRow('Graisseur', formData.personnel.graisseur),
                                                          _buildInfoRow('Matricules', formData.personnel.matricules),
                                                          _buildInfoRow('Tricone', formData.consommation.tricone),
                                                          _buildInfoRow('Gasoil', formData.consommation.gasoil),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Consommation Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'Consommation',
                                                            style: Theme.of(context).textTheme.titleMedium,
                                                          ),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('Tricone', formData.consommation.tricone),
                                                          _buildInfoRow('Gasoil', formData.consommation.gasoil),
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
                            },
                            icon: const Icon(Icons.visibility),
                            label: const Text("Voir tous les détails"),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            ),
                          ),
                        ],
                      ),
                      isActive: _currentStep >= 7,
                      state: _currentStep > 7 ? StepState.complete : StepState.indexed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 