import 'package:flutter/material.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
// import 'package:r0/l10n/app_localizations.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:r0/theme.dart';

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
  String selectedMine = '';
  String selectedZone = '';
  String selectedSortie = '';
  List<IndexCompteurPoste> indexCompteurs = List.generate(3, (_) => IndexCompteurPoste());
  String selectedPoste = '';
  List<VentilationItem> ventilation = [];
  Map<String, String> exploitation = {
    'heuresBrutes': '',
    'heuresArrets': '',
    'heuresNettes': '',
    'tonnage': '',
    'rendement': '',
  };
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
    _calculateHours();
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
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MineData>(
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
                ),
              ),
            ],
          );
        } else if (step == 1 && selectedMine != null) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ZoneData>(
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
                ),
              ),
            ],
          );
        } else if (step == 2) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
                ),
              ),
            ],
          );
        } else if (step == 3 && selectedCategory != null) {
          final types = selectedCategory == 'ENGINS'
              ? enginsData.keys.toList()
              : machinesData.keys.toList();
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: types.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      formData.selectedType = value ?? '';
                      formData.selectedModel = '';
                    });
                  },
                ),
              ),
            ],
          );
        } else if (step == 4 && selectedType != null) {
          final models = selectedCategory == 'ENGINS'
              ? enginsData[selectedType] ?? []
              : machinesData[selectedType] ?? [];
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedModel,
                  decoration: const InputDecoration(labelText: 'Modèle', border: OutlineInputBorder()),
                  items: models.map((model) => DropdownMenuItem(value: model, child: Text(model))).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      formData.selectedModel = value ?? '';
                    });
                  },
                ),
              ),
            ],
          );
        } else if (step == 5 && selectedZone != null && selectedZone.sorties.isNotEmpty) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedSortie,
                  decoration: const InputDecoration(labelText: 'Sortie', border: OutlineInputBorder()),
                  items: selectedZone.sorties.map((sortie) => DropdownMenuItem(value: sortie, child: Text(sortie))).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      formData.selectedSortie = value ?? '';
                      formData.selectedPoste = '';
                    });
                  },
                ),
              ),
            ],
          );
        } else if ((step == 5 && selectedZone != null && selectedZone.sorties.isEmpty) || step == 6) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedPoste,
                  decoration: const InputDecoration(labelText: 'Poste', border: OutlineInputBorder()),
                  items: posteOrder.map((poste) => DropdownMenuItem(value: poste, child: Text('$poste Poste (${posteTimes[poste]})'))).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      formData.selectedPoste = value ?? posteOrder.first;
                    });
                  },
                ),
              ),
            ],
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
            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
        ],
      ],
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
        description: 'Rapport R0 - ${formData.selectedPoste}',
        date: _selectedDate,
        group: 'R0',
        type: formData.selectedModel,
        additionalData: _serializeFormData(),
      );

      await _databaseHelper.insertReport(report);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rapport soumis avec succès'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      // Delay navigation so the SnackBar is visible
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          final navigator = Navigator.of(context);
          navigator.popUntil((route) => route.isFirst);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
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
      'mine': formData.selectedMine,
      'zone': formData.selectedZone,
      'sortie': formData.selectedSortie,
      'Category': formData.selectedCategory,
      'Type': formData.selectedType,
      'Model': formData.selectedModel,
      'selectedPoste': formData.selectedPoste,
      'Compteurs': formData.indexCompteurs
          .asMap()
          .entries
          .where((entry) {
            final compteur = entry.value;
            return compteur.duree.isNotEmpty || compteur.note.isNotEmpty;
          })
          .map((entry) {
            final compteur = entry.value;
            return {
              'duree': compteur.duree,
              'note': compteur.note,
            };
          })
          .toList(),
      'Arrets': formData.ventilation.map((v) => {
        'Arret': v.label,
        'Début': v.duree,
        'Fin': v.note,
      }).toList(),
      'exploitation': formData.exploitation,
      'Répartition Travail': formData.repartitionTravail
          .where((r) => r.chantier.isNotEmpty || r.temps.isNotEmpty || r.imputation.isNotEmpty)
          .map((r) => {
        'Chantier': r.chantier,
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

  Widget _buildAddVentilationDialog(BuildContext context, {int? editIndex, VentilationItem? initialItem}) {
    int step = 0;
    String? selectedCategory = initialItem != null ? arretCategories.keys.firstWhere((cat) => arretCategories[cat]!.contains(initialItem.label), orElse: () => '') : null;
    String? selectedType = initialItem?.label;
    String startTime = initialItem?.duree ?? '';
    String endTime = initialItem?.note ?? '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        Widget content;
        if (step == 0) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
                ),
              ),
            ],
          );
        } else if (step == 1 && selectedCategory != null) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
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
                ),
              ),
            ],
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
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title: const Text('Sélectionner l\'heure'),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('start_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: const TextStyle(fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(tempTime),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
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
                  final picked = await showDialog<TimeOfDay>(
                    context: context,
                    builder: (context) {
                      TimeOfDay tempTime = TimeOfDay.now();
                      return AlertDialog(
                        title: const Text('Sélectionner l\'heure'),
                        content: SizedBox(
                          height: 200,
                          child: TimePickerSpinner(
                            key: const ValueKey('end_time_picker_spinner'),
                            is24HourMode: true,
                            isShowSeconds: false,
                            minutesInterval: 1,
                            normalTextStyle: const TextStyle(fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(tempTime),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
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
                              if (editIndex != null) {
                                formData.ventilation[editIndex] = VentilationItem(
                                  code: 0,
                                  label: selectedType!,
                                  duree: startTime,
                                  note: endTime,
                                );
                              } else {
                                formData.ventilation.add(VentilationItem(
                                  code: 0,
                                  label: selectedType!,
                                  duree: startTime,
                                  note: endTime,
                                ));
                              }
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
                    if (_currentStep < 4) { // 5 steps: 0 to 4
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
                    if (_currentStep == 4) { // Last step
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
                                onPressed: () async {
                                  // Show confirmation dialog before saving
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
                                  if (!mounted) return;
                                  if (shouldSave == true) {
                                    await _saveReport();
                                    if (!mounted) return;
                                    // After saving, pop to home page
                                    if (mounted) {
                                      final navigator = Navigator.of(context);
                                      navigator.popUntil((route) => route.isFirst);
                                    }
                                  }
                                },
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
                              child: Text(_currentStep == 3 ? 'Suivant' : 'Suivant'),
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
                            'ÉTAPE 1: DATE',
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
                                  lastDate: DateTime.now(), // Restrict to today
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
                              color: Theme.of(context).colorScheme.primary,
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Liste Info OIB/EE'),
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
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          // Insert Compteurs content from old step 3 here
                          Text(
                            'ÉTAPE 3: INDEX COMPTEURS',
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter'),
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
                                  label: const Text('Ajouter'),
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
                                    // Get the index of the selected poste
                                    final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
                                    if (selectedPosteIndex == -1) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Veuillez d\'abord sélectionner un poste'),
                                          backgroundColor: AppColors.warning,
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
                                  label: const Text('Voir'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                      title: const Text('Arrêts'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 4: DES ARRÊTS',
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Ajouter'),
                                        content: SingleChildScrollView(
                                          child: _buildAddVentilationDialog(context),
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter'),
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => StatefulBuilder(
                                        builder: (context, setDialogState) => AlertDialog(
                                          title: const Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('Liste Arrêts'),
                                            ],
                                          ),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: formData.ventilation.isEmpty ||
                                                      formData.ventilation.every((v) => v.label.isEmpty && v.duree.isEmpty && v.note.isEmpty)
                                                  ? [const Text('Aucun arrêt ajouté.')]
                                                  : List.generate(formData.ventilation.length, (index) {
                                                      final v = formData.ventilation[index];
                                                      if ((v.label.isEmpty && v.duree.isEmpty && v.note.isEmpty)) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      return Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text('Type: ${v.label}'),
                                                                Text('Début: ${v.duree}'),
                                                                Text('Fin: ${v.note}'),
                                                              ],
                                                            ),
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
                                                            onSelected: (value) async {
                                                              if (value == 'edit') {
                                                                // Open the add/edit dialog pre-filled with v's data
                                                                await showDialog(
                                                                  context: context,
                                                                  builder: (context) => AlertDialog(
                                                                    title: const Text('Modifier Arrêt'),
                                                                    content: SingleChildScrollView(
                                                                      child: _buildAddVentilationDialog(context, editIndex: index, initialItem: v),
                                                                    ),
                                                                  ),
                                                                );
                                                                setDialogState(() {}); // Refresh
                                                              } else if (value == 'delete') {
                                                                setState(() {
                                                                  formData.ventilation.removeAt(index);
                                                                });
                                                                setDialogState(() {}); // Refresh
                                                              }
                                                            },
                                                          ),
                                                        ],
                                                      );
                                                    }),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(context).pop(),
                                              child: const Text('Terminer'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                      title: const Text('Exploitation'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 5: EXPLOITATION, RÉPARTITION, PERSONNEL & CONSOMMATION',
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
                                    showDialog(
                                      context: context,
                                      builder: (context) {
                                        int subStep = 0;
                                        // --- Persistent controllers for all fields ---
                                        // Exploitation
                                        final TextEditingController heuresBrutesController = TextEditingController(text: formData.exploitation['heuresBrutes']);
                                        final TextEditingController heuresArretsController = TextEditingController(text: formData.exploitation['heuresArrets']);
                                        final TextEditingController tonnageController = TextEditingController(text: formData.exploitation['tonnage']);
                                        final TextEditingController rendementController = TextEditingController(text: formData.exploitation['rendement']);
                                        // Répartition
                                        final TextEditingController chantierController = TextEditingController(text: formData.repartitionTravail.isNotEmpty ? formData.repartitionTravail[0].chantier : '');
                                        final TextEditingController tempsController = TextEditingController(text: formData.repartitionTravail.isNotEmpty ? formData.repartitionTravail[0].temps : '');
                                        final TextEditingController imputationController = TextEditingController(text: formData.repartitionTravail.isNotEmpty ? formData.repartitionTravail[0].imputation : '');
                                        // Personnel
                                        final TextEditingController conducteurController = TextEditingController(text: formData.personnel.conducteur);
                                        final TextEditingController graisseurController = TextEditingController(text: formData.personnel.graisseur);
                                        final TextEditingController matriculesController = TextEditingController(text: formData.personnel.matricules);
                                        // Consommation
                                        final TextEditingController triconeController = TextEditingController(text: formData.consommation.tricone);
                                        final TextEditingController gasoilController = TextEditingController(text: formData.consommation.gasoil);
                                        return StatefulBuilder(
                                          builder: (context, setDialogState) {
                                            Widget content;
                                            String title;
                                            switch (subStep) {
                                              case 0:
                                                title = 'Exploitation';
                                                content = Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Exploitation', style: Theme.of(context).textTheme.titleLarge),
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
                                                      controller: heuresBrutesController,
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
                                                      controller: heuresArretsController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Tonnage',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: TextInputType.number,
                                                      controller: tonnageController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Rendement',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: TextInputType.number,
                                                      controller: rendementController,
                                                    ),
                                                  ],
                                                );
                                                break;
                                              case 1:
                                                title = 'Répartition';
                                                content = Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Répartition', style: Theme.of(context).textTheme.titleMedium),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      controller: chantierController,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Chantier',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      controller: tempsController,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Temps',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      controller: imputationController,
                                                      decoration: const InputDecoration(
                                                        labelText: 'Imputation',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                    ),
                                                  ],
                                                );
                                                break;
                                              case 2:
                                                title = 'Personnel';
                                                content = Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Personnel', style: Theme.of(context).textTheme.titleLarge),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Conducteur',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      controller: conducteurController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Graisseur',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      controller: graisseurController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Matricules',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      controller: matriculesController,
                                                    ),
                                                  ],
                                                );
                                                break;
                                              case 3:
                                                title = 'Consommation';
                                                content = Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('Suivi Consommation', style: Theme.of(context).textTheme.titleLarge),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Tricone',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: TextInputType.number,
                                                      controller: triconeController,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    TextFormField(
                                                      decoration: const InputDecoration(
                                                        labelText: 'Gasoil',
                                                        border: OutlineInputBorder(),
                                                      ),
                                                      keyboardType: TextInputType.number,
                                                      controller: gasoilController,
                                                    ),
                                                  ],
                                                );
                                                break;
                                              default:
                                                title = '';
                                                content = const SizedBox();
                                            }
                                            return AlertDialog(
                                              title: Text(title),
                                              content: SingleChildScrollView(
                                                child: content,
                                              ),
                                              actions: [
                                                if (subStep > 0)
                                                  TextButton(
                                                    onPressed: () => setDialogState(() => subStep--),
                                                    child: const Text('Précédent'),
                                                  ),
                                                if (subStep < 3)
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // Save data for the current sub-step before moving forward
                                                      if (subStep == 0) {
                                                        formData.exploitation['heuresBrutes'] = heuresBrutesController.text;
                                                        formData.exploitation['heuresArrets'] = heuresArretsController.text;
                                                        formData.exploitation['tonnage'] = tonnageController.text;
                                                        formData.exploitation['rendement'] = rendementController.text;
                                                      } else if (subStep == 1) {
                                                        if (formData.repartitionTravail.isEmpty) {
                                                          formData.repartitionTravail.add(RepartitionItem());
                                                        }
                                                        formData.repartitionTravail[0] = RepartitionItem(
                                                          chantier: chantierController.text,
                                                          temps: tempsController.text,
                                                          imputation: imputationController.text,
                                                        );
                                                      } else if (subStep == 2) {
                                                        formData.personnel.conducteur = conducteurController.text;
                                                        formData.personnel.graisseur = graisseurController.text;
                                                        formData.personnel.matricules = matriculesController.text;
                                                      }
                                                      setDialogState(() => subStep++);
                                                    },
                                                    child: const Text('Suivant'),
                                                  ),
                                                if (subStep == 3)
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // Save data for the last sub-step
                                                      formData.consommation.tricone = triconeController.text;
                                                      formData.consommation.gasoil = gasoilController.text;
                                                      Navigator.of(context).pop();
                                                    },
                                                    child: const Text('Terminer'),
                                                  ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter'),
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
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Liste'),
                                          ],
                                        ),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Exploitation Section
                                              Text('Exploitation', style: Theme.of(context).textTheme.titleMedium),
                                              const Divider(height: 16),
                                              Text('Heures marche: ${formData.exploitation['heuresMarche']}'),
                                              Text('Heures Arrêts: ${formData.exploitation['heuresArrets']}'),
                                              Text('Tonnage: ${formData.exploitation['tonnage']}t'),
                                              Text('Rendement: ${formData.exploitation['rendement']}%'),
                                              const SizedBox(height: 20),
                                              // Répartition Section
                                              Text('Répartition', style: Theme.of(context).textTheme.titleMedium),
                                              const Divider(height: 16),
                                              ...(() {
                                                final List<RepartitionItem> nonEmptyRepartitions = formData.repartitionTravail
                                                    .where((r) => r.chantier.isNotEmpty || r.temps.isNotEmpty || r.imputation.isNotEmpty)
                                                    .toList();
                                                if (nonEmptyRepartitions.isEmpty) {
                                                  return [const Text('Aucune répartition ajoutée.')];
                                                }
                                                return List.generate(nonEmptyRepartitions.length, (index) {
                                                  final r = nonEmptyRepartitions[index];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 8.0),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('Chantier: ${r.chantier}'),
                                                        Text('Temps: ${r.temps}'),
                                                        Text('Imputation: ${r.imputation}'),
                                                        if (index < nonEmptyRepartitions.length - 1) const Divider(height: 12),
                                                      ],
                                                    ),
                                                  );
                                                });
                                              })(),
                                              const SizedBox(height: 20),
                                              // Personnel Section
                                              Text('Personnel', style: Theme.of(context).textTheme.titleMedium),
                                              const Divider(height: 16),
                                              if (formData.personnel.conducteur.isNotEmpty)
                                                Text('Conducteur: ${formData.personnel.conducteur}'),
                                              if (formData.personnel.graisseur.isNotEmpty)
                                                Text('Graisseur: ${formData.personnel.graisseur}'),
                                              if (formData.personnel.matricules.isNotEmpty)
                                                Text('Matricules: ${formData.personnel.matricules}'),
                                              if (formData.personnel.conducteur.isEmpty && formData.personnel.graisseur.isEmpty && formData.personnel.matricules.isEmpty)
                                                const Text('Aucun personnel renseigné.'),
                                              const SizedBox(height: 20),
                                              // Consommation Section
                                              Text('Consommation', style: Theme.of(context).textTheme.titleMedium),
                                              const Divider(height: 16),
                                              if (formData.consommation.tricone.isNotEmpty)
                                                Text('Tricone: ${formData.consommation.tricone}'),
                                              if (formData.consommation.gasoil.isNotEmpty)
                                                Text('Gasoil: ${formData.consommation.gasoil}'),
                                              if (formData.consommation.tricone.isEmpty && formData.consommation.gasoil.isEmpty)
                                                const Text('Aucune consommation renseignée.'),
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
                                  label: const Text('Voir'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                      title: const Text('Vérification'),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ÉTAPE 6: VÉRIFICATION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
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
                                                      child: _buildSummaryItem(
                                                        'Date',
                                                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
                                                          const Text('Info OIB/EE', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          const Divider(height: 16),
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
                                                  // After Compteurs Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text('Arrêts', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          const Divider(height: 16),
                                                          if (formData.ventilation.isEmpty)
                                                            const Text('Aucun arrêt ajouté.'),
                                                          ...formData.ventilation.asMap().entries.map((entry) {
                                                            final v = entry.value;
                                                            if (v.label.isEmpty && v.duree.isEmpty && v.note.isEmpty) return const SizedBox.shrink();
                                                            return Padding(
                                                              padding: const EdgeInsets.only(bottom: 12.0),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text('Type: ${v.label}', style: Theme.of(context).textTheme.titleSmall),
                                                                  _buildInfoRow('Début', v.duree),
                                                                  _buildInfoRow('Fin', v.note),
                                                                  const Divider(height: 12),
                                                                ],
                                                              ),
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
                                                          const Text('Exploitation', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('H.M', formData.exploitation['heuresBrutes'] ?? ''),
                                                          _buildInfoRow('H.A', formData.exploitation['heuresArrets'] ?? ''),
                                                          _buildInfoRow('Tonnage', formData.exploitation['tonnage'] ?? ''),
                                                          _buildInfoRow('Rendeme', formData.exploitation['rendement'] ?? ''),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  // Répartition Section
                                                  Card(
                                                    margin: EdgeInsets.zero,
                                                    child: Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          const Text('Répartition', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          const Divider(height: 16),
                                                          ...(() {
                                                            final List<RepartitionItem> nonEmptyRepartitions = formData.repartitionTravail
                                                                .where((r) => r.chantier.isNotEmpty || r.temps.isNotEmpty || r.imputation.isNotEmpty)
                                                                .toList();
                                                            if (nonEmptyRepartitions.isEmpty) {
                                                              return [const Text('Aucune répartition ajoutée.')];
                                                            }
                                                            return List.generate(nonEmptyRepartitions.length, (index) {
                                                              final r = nonEmptyRepartitions[index];
                                                              return Padding(
                                                                padding: const EdgeInsets.only(bottom: 8.0),
                                                                child: Column(
                                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                                  children: [
                                                                    Text('Chantier: ${r.chantier}'),
                                                                    Text('Temps: ${r.temps}'),
                                                                    Text('Imputation: ${r.imputation}'),
                                                                    if (index < nonEmptyRepartitions.length - 1) const Divider(height: 12),
                                                                  ],
                                                                ),
                                                              );
                                                            });
                                                          })(),
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
                                                          const Text('Personnel', style: TextStyle(fontWeight: FontWeight.bold)),
                                                          const Divider(height: 16),
                                                          _buildInfoRow('Conductr', formData.personnel.conducteur),
                                                          _buildInfoRow('Graisseur', formData.personnel.graisseur),
                                                          _buildInfoRow('Matricules', formData.personnel.matricules),
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
                      isActive: _currentStep >= 4,
                      state: _currentStep > 4 ? StepState.complete : StepState.indexed,
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