import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:r0/models/mine_data.dart'; // Import the shared model
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:r0/theme.dart';
import 'package:r0/widgets/custom_widgets.dart';

// --- Data Models ---
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
  VentilationItem(
      {required this.code,
      required this.label,
      this.duree = '',
      this.note = ''});
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
  PersonnelItem(
      {this.conducteur = '', this.graisseur = '', this.matricules = ''});
}

class ConsommationItem {
  String tricone;
  String gasoil;
  ConsommationItem({this.tricone = '', this.gasoil = ''});
}

class R0ReportFormData {
  String selectedMine = '';
  String selectedZone = '';
  String selectedSortie = '';
  IndexCompteurPoste indexCompteurs = IndexCompteurPoste();
  String selectedPoste = '';
  List<VentilationItem> ventilation = [];
  Map<String, String> exploitation = {
    'H.M': '',
    'H.A': '',
    'Tonnage': '',
    'metrage fore': '',
    'Nr de Trous Fores': '',
    'Nr de Voyages': '',
    'M³ Decapages': '',
    'Nombre T.K.U': '',
    'Rendement %': '',
  };
  RepartitionItem repartitionTravail = RepartitionItem();
  PersonnelItem personnel = PersonnelItem();
  ConsommationItem consommation = ConsommationItem();
  String selectedCategory = '';
  String selectedType = '';
  String selectedModel = '';
  String selectedMachine = '';
}

class R0Report extends StatefulWidget {
  final DateTime? selectedDate;
  final String? previousDayThirdShiftEnd;
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const R0Report({
    super.key,
    this.selectedDate,
    this.previousDayThirdShiftEnd,
    this.initialReport,
    this.onSave,
    this.isEditing = false,
  });

  @override
  R0ReportState createState() => R0ReportState();
}

class R0ReportState extends State<R0Report> {
  // final _formKey = GlobalKey<FormState>(); // Unused
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

  // Static Data - Removed local definitions, using imported 'minesData' from model

  static const Map<String, List<String>> enginsData = {
    'BULLDOZERS': [
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
    'CAMIONS': [
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

  static const Map<String, List<String>> arretCategories = {
    'EXTERIEURS': [
      'ARRET CARREAU INDUSTRIEL',
      'COUPURE GENERALE DU COURANT',
      'GREVE',
      'INTEMPERIES',
      'STOCKS PLEINS',
      'J. FERIES OU HEBDOMADAIRES',
      'ARRET PAR LA CENTRALE (M.ENERGIE)',
      'CONTROLE'
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
      'PANNE ENGIN DEVANT MACHINE'
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
      'TERASSEMENT PUR'
    ],
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
    _calculateHours();
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;
    formData.selectedMine = data['mine'] ?? '';
    formData.selectedZone = data['zone'] ?? '';
    formData.selectedSortie = data['sortie'] ?? '';
    formData.selectedPoste = data['selectedPoste'] ?? '';
    formData.selectedCategory = data['Category'] ?? '';
    formData.selectedType = data['Type'] ?? '';
    formData.selectedModel = data['Model'] ?? '';

    if (data['Compteurs'] is Map) {
      final compteurs = data['Compteurs'] as Map;
      formData.indexCompteurs.duree = compteurs['duree'] ?? '';
      formData.indexCompteurs.note = compteurs['note'] ?? '';
    }
    if (data['exploitation'] is Map) {
      final exploitation = data['exploitation'] as Map;
      formData.exploitation['H.M'] = exploitation['H.M'] ?? '';
      formData.exploitation['H.A'] = exploitation['H.A'] ?? '';
      formData.exploitation['Tonnage'] = exploitation['Tonnage'] ?? '';
      formData.exploitation['metrage fore'] =
          exploitation['metrage fore'] ?? '';
      formData.exploitation['Nr de Trous Fores'] =
          exploitation['Nr de Trous Fores'] ?? '';
      formData.exploitation['Nr de Voyages'] =
          exploitation['Nr de Voyages'] ?? '';
      formData.exploitation['M³ Decapages'] =
          exploitation['M³ Decapages'] ?? '';
      formData.exploitation['Nombre T.K.U'] =
          exploitation['Nombre T.K.U'] ?? '';
      formData.exploitation['Rendement %'] =
          exploitation['Rendeme'] ?? exploitation['Rendement %'] ?? '';
    }
    if (data['personnel'] is Map) {
      final personnel = data['personnel'] as Map;
      formData.personnel.conducteur = personnel['conductr'] ?? '';
      formData.personnel.graisseur = personnel['graisseur'] ?? '';
      formData.personnel.matricules = personnel['matricules'] ?? '';
    }
    if (data['consommation'] is Map) {
      final consommation = data['consommation'] as Map;
      formData.consommation.tricone = consommation['tricone'] ?? '';
      formData.consommation.gasoil = consommation['gasoil'] ?? '';
    }
    if (data['Arrets'] is List) {
      final arrets = data['Arrets'] as List;
      // Get all valid arret types from all categories
      final allValidTypes = <String>{};
      arretCategories.forEach((category, types) {
        allValidTypes.addAll(types);
      });

      formData.ventilation = arrets
          .map((a) => VentilationItem(
                code: 0,
                label: a['Arret'] ?? '',
                duree: a['Début'] ?? '',
                note: a['Fin'] ?? '',
              ))
          .where((item) {
        // Only include items with valid arret types (not category names)
        return allValidTypes.contains(item.label) ||
            !arretCategories.keys.contains(item.label);
      }).toList();
    }
    // Load Repartition Data
    if (data['repartition'] is Map) {
      final repartition = data['repartition'] as Map;
      formData.repartitionTravail.chantier = repartition['Chantier'] ?? '';
      formData.repartitionTravail.temps = repartition['Temps'] ?? '';
      formData.repartitionTravail.imputation = repartition['Imputation'] ?? '';
    }
  }

  double _parseNumeric(String value) {
    if (value.isEmpty) return 0.0;
    return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
  }

  void _calculateHours() {
    double totalGrossHours = 0;
    final start = _parseNumeric(formData.indexCompteurs.duree);
    final end = _parseNumeric(formData.indexCompteurs.note);
    if (end > start) {
      totalGrossHours = (end - start);
    }

    double totalStoppageHours = 0;
    for (var item in formData.ventilation) {
      if (item.duree.isNotEmpty && item.note.isNotEmpty) {
        final startParts = item.duree.split(':');
        final endParts = item.note.split(':');
        if (startParts.length == 2 && endParts.length == 2) {
          final sH = int.tryParse(startParts[0]) ?? 0;
          final sM = int.tryParse(startParts[1]) ?? 0;
          final eH = int.tryParse(endParts[0]) ?? 0;
          final eM = int.tryParse(endParts[1]) ?? 0;
          int diff = (eH * 60 + eM) - (sH * 60 + sM);
          if (diff <= 0) diff += 24 * 60;
          totalStoppageHours += diff / 60.0;
        }
      }
    }

    formData.exploitation['H.A'] = totalStoppageHours.toStringAsFixed(2);
    // H.M is the machine hour counter difference
    double hm = totalGrossHours;
    formData.exploitation['H.M'] = hm.toStringAsFixed(2);

    // Calculate Rendement %
    double tonnage = _parseNumeric(formData.exploitation['Tonnage'] ?? '0');
    if (hm > 0) {
      formData.exploitation['Rendement %'] = (tonnage / hm).toStringAsFixed(2);
    } else {
      formData.exploitation['Rendement %'] = '0.00';
    }

    if (mounted) setState(() {});
  }

  String _getLocalizedTypeLabel(String key, AppLocalizations l10n) {
    final map = {
      'BULLDOZERS': l10n.catBulldozers,
      'CAMIONS': l10n.catTrucks,
      'CHARGEUSES': l10n.catLoaders,
      'NIVELEUSES': l10n.catGraders,
      'PAYDOZERS': l10n.catPaydozers,
      'PELLE HYDRAULIQUE': l10n.catHydraulicShovels,
      'DRAGLINES': l10n.catDraglines,
      'PELLE ELECTRIQUE': l10n.catElectricShovels,
      'SONDEUSES': l10n.catDrills,
    };
    return map[key] ?? key;
  }

  String _getLocalizedCategoryLabel(String key, AppLocalizations l10n) {
    final map = {
      'EXTERIEURS': l10n.catExterior,
      'MATERIEL': l10n.catMaterial,
      'EXPLOITATION': l10n.catExploitation,
    };
    return map[key] ?? key;
  }

  String _getLocalizedReasonLabel(String key, AppLocalizations l10n) {
    final map = {
      'ARRET CARREAU INDUSTRIEL': l10n.stopIndustrialArea,
      'COUPURE GENERALE DU COURANT': l10n.stopPowerCut,
      'GREVE': l10n.stopStrike,
      'INTEMPERIES': l10n.stopWeather,
      'STOCKS PLEINS': l10n.stopFullStocks,
      'J. FERIES OU HEBDOMADAIRES': l10n.stopHolidays,
      'ARRET PAR LA CENTRALE (M.ENERGIE)': l10n.stopPowerPlant,
      'CONTROLE': l10n.stopControl,
      'DEFAUT ELEC. (C.CRAME, RESEAU)': l10n.stopElecFault,
      'PANNE MECANIQUE': l10n.stopMechBreakdown,
      'PANNE ELECTRIQUE': l10n.stopElecBreakdown,
      'INTERVENTION ATELIER PNEUMATIQUE': l10n.stopTireWorkshop,
      'ENTRETIEN SYSTEMATIQUE': l10n.stopMaintenance,
      'APPOINT (HUILE, GAZOL, EAU)': l10n.stopRefill,
      'GRAISSAGE': l10n.stopGreasing,
      'ARRET ELEC. INSTALATION FIXES': l10n.stopFixedInstallElec,
      'MANQUE CAMIONS': l10n.stopNoTrucks,
      'MANQUE BULL': l10n.stopNoBull,
      'MANQUE MECANICIEN': l10n.stopNoMechanic,
      'MANQUE D\'OUTILS DE TRAVAIL': l10n.stopNoTools,
      'MACHINE A L\'ARRET': l10n.stopMachineStopped,
      'PANNE ENGIN DEVANT MACHINE': l10n.stopBreakdownFront,
      'RELEVE': l10n.stopShiftChange,
      'EXECUTION PLATE FORME': l10n.stopPlatformExec,
      'DEPLACEMENT': l10n.stopMove,
      'TIR ET SAUTAGE': l10n.stopBlasting,
      'MOUV. DE CABLE': l10n.stopCableMove,
      'ARRET DECIDE': l10n.stopDecidedStop,
      'MANQUE CONDUCTEUR': l10n.stopNoDriver,
      'BRIQUET': l10n.stopBreak,
      'PISTES (INTEMPERIES EXCLUES)': l10n.stopTracks,
      'ARRETS MECA. INSTALATIONS FIXES': l10n.stopFixedInstallMech,
      'TELESCOPAGE': l10n.stopTelescoping,
      'EXCAVATION PURE': l10n.stopPureExcavation,
      'TERASSEMENT PUR': l10n.stopPureEarthworks,
    };
    return map[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.stepInfos,
      l10n.stepCompteur,
      l10n.stepArrets,
      l10n.stepExploit,
      l10n.stepRepartition,
      l10n.stepPersonnel,
      l10n.stepConsom,
      l10n.stepVerif,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l10n.modifierR0 : l10n.nouveauRapportR0),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              OCPStepper(
                steps: steps,
                currentStep: _currentStep,
                onStepTapped: (index) {
                  setState(() => _currentStep = index);
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _buildStepContent(l10n),
                ),
              ),
              _buildBottomBar(l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildStepInfos(l10n);
      case 1:
        return _buildStepCompteur(l10n);
      case 2:
        return _buildStepArrets(l10n);
      case 3:
        return _buildStepExploitation(l10n);
      case 4:
        return _buildStepRepartition(l10n);
      case 5:
        return _buildStepPersonnel(l10n);
      case 6:
        return _buildStepConsommation(l10n);
      case 7:
        return _buildStepVerification(l10n);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    bool isFirst = _currentStep == 0;
    bool isLast = _currentStep == 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)],
      ),
      child: Row(
        children: [
          if (!isFirst)
            Expanded(
              child: OCPButton(
                text: l10n.previous,
                onPressed: () => setState(() => _currentStep--),
                isSecondary: true,
              ),
            ),
          if (!isFirst) const SizedBox(width: 16),
          Expanded(
            child: OCPButton(
              text: isLast ? l10n.submit : l10n.next,
              onPressed: () => _validateAndProceed(l10n),
              isLoading: _isLoading && isLast,
            ),
          ),
        ],
      ),
    );
  }

  void _validateAndProceed(AppLocalizations l10n) {
    if (_currentStep == 0) {
      if (formData.selectedMine.isEmpty ||
          formData.selectedPoste.isEmpty ||
          formData.selectedModel.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n
                .selectPosteMessage))); // Using selectPosteMessage as a general validation message for now or similar
        return;
      }
    }

    if (_currentStep < 7) {
      setState(() => _currentStep++);
    } else {
      _saveReport(l10n);
    }
  }

  // --- Step 1: Infos ---
  Widget _buildStepInfos(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date Selection
        OCPCard(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              locale: const Locale('fr', 'FR'),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: AppColors.primary),
              const SizedBox(width: 16),
              Text(
                '${l10n.date}: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Mine Selection
        OCPDropdown<String>(
            label: l10n.mine,
            value:
                formData.selectedMine.isNotEmpty ? formData.selectedMine : null,
            items: minesData
                .map(
                    (m) => DropdownMenuItem(value: m.name, child: Text(m.name)))
                .toList(),
            onChanged: (val) {
              setState(() {
                formData.selectedMine = val!;
                formData.selectedZone = '';
                formData.selectedSortie = '';
              });
            }),
        const SizedBox(height: 16),

        // Zone Selection
        if (formData.selectedMine.isNotEmpty) ...[
          OCPDropdown<String>(
              label: l10n.zone,
              value: formData.selectedZone.isNotEmpty
                  ? formData.selectedZone
                  : null,
              items: minesData
                  .firstWhere((m) => m.name == formData.selectedMine)
                  .zones
                  .map((z) =>
                      DropdownMenuItem(value: z.name, child: Text(z.name)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  formData.selectedZone = val!;
                  formData.selectedSortie = '';
                });
              }),
          const SizedBox(height: 16),
        ],

        // Sortie Selection
        if (formData.selectedZone.isNotEmpty) ...[
          OCPDropdown<String>(
            label: l10n.exit,
            value: formData.selectedSortie.isNotEmpty
                ? formData.selectedSortie
                : null,
            items: minesData
                .firstWhere((m) => m.name == formData.selectedMine)
                .zones
                .firstWhere((z) => z.name == formData.selectedZone)
                .sorties
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() => formData.selectedSortie = val!),
          ),
          const SizedBox(height: 16),
        ],

        // Category/Type/Model Selection
        OCPDropdown<String>(
            label: l10n.categoryLabel,
            value: formData.selectedCategory.isNotEmpty
                ? formData.selectedCategory
                : null,
            items: [l10n.engines, l10n.machines]
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (val) => setState(() {
                  formData.selectedCategory = val!;
                  formData.selectedType = '';
                  formData.selectedModel = '';
                })),
        const SizedBox(height: 16),

        if (formData.selectedCategory.isNotEmpty) ...[
          OCPDropdown<String>(
              label: l10n.type,
              value: formData.selectedType.isNotEmpty
                  ? formData.selectedType
                  : null,
              items: (formData.selectedCategory == l10n.engines
                      ? enginsData.keys
                      : machinesData.keys)
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(_getLocalizedTypeLabel(s, l10n))))
                  .toList(),
              onChanged: (val) => setState(() {
                    formData.selectedType = val!;
                    formData.selectedModel = '';
                  })),
          const SizedBox(height: 16),
        ],

        if (formData.selectedType.isNotEmpty) ...[
          OCPDropdown<String>(
              label: l10n.modelLabel,
              value: formData.selectedModel.isNotEmpty
                  ? formData.selectedModel
                  : null,
              items: (formData.selectedCategory == l10n.engines
                      ? enginsData[formData.selectedType]
                      : machinesData[formData.selectedType])!
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) =>
                  setState(() => formData.selectedModel = val!)),
          const SizedBox(height: 16),
        ],

        // Poste Selection
        OCPDropdown<String>(
            label: l10n.poste,
            value: formData.selectedPoste.isNotEmpty
                ? formData.selectedPoste
                : null,
            items: posteOrder
                .map((p) => DropdownMenuItem(
                    value: p, child: Text('$p (${posteTimes[p]})')))
                .toList(),
            onChanged: (val) => setState(() => formData.selectedPoste = val!)),
      ],
    );
  }

  // --- Step 2: Compteur ---
  Widget _buildStepCompteur(AppLocalizations l10n) {
    final selectedPosteIndex = posteOrder.indexOf(formData.selectedPoste);
    if (selectedPosteIndex == -1) {
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(l10n.selectPosteMessage));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.counterEntryTitle(formData.selectedPoste),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        OCPTextField(
          label: l10n.startCounterLabel,
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: formData.indexCompteurs.duree)
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: formData.indexCompteurs.duree.length)),
          onChanged: (val) {
            formData.indexCompteurs.duree = val;
            _calculateHours();
          },
        ),
        const SizedBox(height: 16),
        OCPTextField(
          label: l10n.endCounterLabel,
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: formData.indexCompteurs.note)
            ..selection = TextSelection.fromPosition(
                TextPosition(offset: formData.indexCompteurs.note.length)),
          onChanged: (val) {
            formData.indexCompteurs.note = val;
            _calculateHours();
          },
        ),
      ],
    );
  }

  // --- Step 3: Arrêts ---
  Widget _buildStepArrets(AppLocalizations l10n) {
    return Column(
      children: [
        if (formData.ventilation.isEmpty)
          Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l10n.noStopsRecorded,
                  style: const TextStyle(color: Colors.grey))),
        ...formData.ventilation.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          return OCPCard(
            padding: const EdgeInsets.all(12),
            child: ListTile(
              leading: const Icon(Icons.warning, color: AppColors.warning),
              title: Text(_getLocalizedReasonLabel(item.label, l10n),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${item.duree} -> ${item.note}"),
              trailing: IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () {
                    setState(() => formData.ventilation.removeAt(idx));
                    _calculateHours();
                  }),
            ),
          );
        }),
        const SizedBox(height: 16),
        OCPButton(
          text: l10n.addArretTitle,
          icon: Icons.add,
          onPressed: () => _showAddArretDialog(l10n),
          isSecondary: true,
        )
      ],
    );
  }

  void _showAddArretDialog(AppLocalizations l10n) {
    int step = 0;
    String? selectedCategory;
    String? selectedType;
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) {
          Widget content;
          if (step == 0) {
            content = DropdownButtonFormField<String>(
              hint: Text(l10n.category),
              items: arretCategories.keys
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(_getLocalizedCategoryLabel(c, l10n))))
                  .toList(),
              onChanged: (v) => setDs(() {
                selectedCategory = v;
                selectedType = null;
              }),
              initialValue: selectedCategory,
            );
          } else if (step == 1 && selectedCategory != null) {
            content = DropdownButtonFormField<String>(
              hint: Text(l10n.type),
              initialValue: selectedType,
              isExpanded: true,
              items: arretCategories[selectedCategory]!
                  .map((t) => DropdownMenuItem(
                      value: t, child: Text(_getLocalizedReasonLabel(t, l10n))))
                  .toList(),
              onChanged: (v) => setDs(() => selectedType = v),
            );
          } else if (step == 2 && selectedType != null) {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${l10n.category}: ${_getLocalizedCategoryLabel(selectedCategory!, l10n)}'),
                Text(
                    '${l10n.type}: ${_getLocalizedReasonLabel(selectedType!, l10n)}'),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(l10n.startTimeLabel),
                  subtitle: Text(
                      "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (context) {
                        TimeOfDay tempTime = TimeOfDay.fromDateTime(startTime);
                        return AlertDialog(
                          title: Text(l10n.selectTimeTitle),
                          content: SizedBox(
                            height: 200,
                            child: TimePickerSpinner(
                              time: startTime,
                              is24HourMode: true,
                              isShowSeconds: false,
                              minutesInterval: 1,
                              normalTextStyle: const TextStyle(
                                  fontSize: 18,
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              highlightedTextStyle: const TextStyle(
                                  fontSize: 24,
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              spacing: 50,
                              itemHeight: 60,
                              isForce2Digits: true,
                              onTimeChange: (dateTime) {
                                tempTime = TimeOfDay(
                                    hour: dateTime.hour,
                                    minute: dateTime.minute);
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(tempTime),
                              child: Text(l10n.okButton),
                            ),
                          ],
                        );
                      },
                    );
                    if (picked != null) {
                      setDs(() {
                        startTime = DateTime(startTime.year, startTime.month,
                            startTime.day, picked.hour, picked.minute);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(l10n.endTimeLabel),
                  subtitle: Text(
                      "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (context) {
                        TimeOfDay tempTime = TimeOfDay.fromDateTime(endTime);
                        return AlertDialog(
                          title: Text(l10n.selectTimeTitle),
                          content: SizedBox(
                            height: 200,
                            child: TimePickerSpinner(
                              time: endTime,
                              is24HourMode: true,
                              isShowSeconds: false,
                              minutesInterval: 1,
                              normalTextStyle: const TextStyle(
                                  fontSize: 18,
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              highlightedTextStyle: const TextStyle(
                                  fontSize: 24,
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              spacing: 50,
                              itemHeight: 60,
                              isForce2Digits: true,
                              onTimeChange: (dateTime) {
                                tempTime = TimeOfDay(
                                    hour: dateTime.hour,
                                    minute: dateTime.minute);
                              },
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(l10n.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(tempTime),
                              child: Text(l10n.okButton),
                            ),
                          ],
                        );
                      },
                    );
                    if (picked != null) {
                      setDs(() {
                        endTime = DateTime(endTime.year, endTime.month,
                            endTime.day, picked.hour, picked.minute);
                      });
                    }
                  },
                ),
              ],
            );
          } else {
            content = const SizedBox();
          }

          return AlertDialog(
            title: Text(l10n.addArretTitle),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step == 0) ...[
                      Text(l10n.selectCategoryStep,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      content,
                    ] else if (step == 1) ...[
                      Text(l10n.selectStopTypeStep,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      content,
                    ] else if (step == 2) ...[
                      Text(l10n.enterDetailsStep,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      content,
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (step > 0)
                    TextButton(
                      onPressed: () => setDs(() => step--),
                      child: Text(l10n.previous),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel),
                    ),
                  if ((step == 0 && selectedCategory != null) ||
                      (step == 1 && selectedType != null))
                    ElevatedButton(
                      onPressed: () => setDs(() => step++),
                      child: Text(l10n.next),
                    ),
                  if (step == 2 && selectedType != null)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          formData.ventilation.add(VentilationItem(
                              code: 0,
                              label: selectedType!,
                              duree:
                                  "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}",
                              note:
                                  "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}"));
                          _calculateHours();
                        });
                        Navigator.pop(context);
                      },
                      child: Text(l10n.add),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Step 4: Exploitation ---
  Widget _buildStepExploitation(AppLocalizations l10n) {
    return Column(
      children: [
        _exploitRow(l10n.heuresMarche, formData.exploitation['H.M']!,
            readOnly: true),
        _exploitRow(l10n.heuresArret, formData.exploitation['H.A']!,
            readOnly: true),
        const Divider(),
        _exploitRow(l10n.metrageFore, formData.exploitation['metrage fore']!,
            onChanged: (v) => formData.exploitation['metrage fore'] = v),
        _exploitRow(
            l10n.nrTrousFores, formData.exploitation['Nr de Trous Fores']!,
            onChanged: (v) => formData.exploitation['Nr de Trous Fores'] = v),
        _exploitRow(l10n.nrVoyages, formData.exploitation['Nr de Voyages']!,
            onChanged: (v) => formData.exploitation['Nr de Voyages'] = v),
        _exploitRow(l10n.m3Decapage, formData.exploitation['M³ Decapages']!,
            onChanged: (v) => formData.exploitation['M³ Decapages'] = v),
        _exploitRow(l10n.tonnageLabel, formData.exploitation['Tonnage']!,
            onChanged: (v) {
          formData.exploitation['Tonnage'] = v;
          _calculateHours();
        }),
        _exploitRow(l10n.nombreTKU, formData.exploitation['Nombre T.K.U']!,
            onChanged: (v) => formData.exploitation['Nombre T.K.U'] = v),
        _exploitRow(l10n.rendementLabel, formData.exploitation['Rendement %']!,
            readOnly: true),
      ],
    );
  }

  Widget _exploitRow(String label, String value,
      {bool readOnly = false, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OCPTextField(
        label: label,
        controller: TextEditingController(text: value)
          ..selection =
              TextSelection.fromPosition(TextPosition(offset: value.length)),
        readOnly: readOnly,
        keyboardType: TextInputType.number,
        onChanged: onChanged,
      ),
    );
  }

  // --- Step 5: Repartition ---
  Widget _buildStepRepartition(AppLocalizations l10n) {
    return Column(
      children: [
        Text(l10n.repartitionTravail,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        OCPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.details,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OCPTextField(
                label: l10n.chantierLabel,
                controller: TextEditingController(
                    text: formData.repartitionTravail.chantier),
                onChanged: (v) => formData.repartitionTravail.chantier = v,
              ),
              const SizedBox(height: 8),
              OCPTextField(
                label: l10n.duration,
                controller: TextEditingController(
                    text: formData.repartitionTravail.temps),
                onChanged: (v) => formData.repartitionTravail.temps = v,
              ),
              const SizedBox(height: 8),
              OCPTextField(
                label: l10n.imputationLabel,
                controller: TextEditingController(
                    text: formData.repartitionTravail.imputation),
                onChanged: (v) => formData.repartitionTravail.imputation = v,
              ),
            ],
          ),
        )
      ],
    );
  }

  // --- Step 6: Personnel ---
  Widget _buildStepPersonnel(AppLocalizations l10n) {
    return Column(
      children: [
        OCPTextField(
            label: l10n.conducteurLabel,
            controller:
                TextEditingController(text: formData.personnel.conducteur),
            onChanged: (v) => formData.personnel.conducteur = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: l10n.graisseurLabel,
            controller:
                TextEditingController(text: formData.personnel.graisseur),
            onChanged: (v) => formData.personnel.graisseur = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: l10n.matriculesLabel,
            controller:
                TextEditingController(text: formData.personnel.matricules),
            onChanged: (v) => formData.personnel.matricules = v),
      ],
    );
  }

  // --- Step 7: Consommation ---
  Widget _buildStepConsommation(AppLocalizations l10n) {
    return Column(
      children: [
        OCPTextField(
            label: l10n.triconeLabel,
            controller:
                TextEditingController(text: formData.consommation.tricone),
            onChanged: (v) => formData.consommation.tricone = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: l10n.gasoilLabel,
            controller:
                TextEditingController(text: formData.consommation.gasoil),
            onChanged: (v) => formData.consommation.gasoil = v),
      ],
    );
  }

  // --- Step 8: Verification ---
  Widget _buildStepVerification(AppLocalizations l10n) {
    return Column(
      children: [
        const Icon(Icons.check_circle_outline,
            size: 64, color: AppColors.success),
        const SizedBox(height: 16),
        Text(l10n.summary,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _row(l10n.mineSortie,
            "${formData.selectedMine} / ${formData.selectedSortie}"),
        _row(l10n.engin,
            "${_getLocalizedTypeLabel(formData.selectedType, l10n)} - ${formData.selectedModel}"),
        _row(l10n.poste, formData.selectedPoste),
        _row(l10n.counter,
            "${formData.indexCompteurs.duree} -> ${formData.indexCompteurs.note}"),
        const Divider(),
        if (formData.ventilation.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.detailsArrets,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...formData.ventilation.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(_getLocalizedReasonLabel(item.label, l10n),
                            style: const TextStyle(fontSize: 13))),
                    Text("${item.duree} - ${item.note}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )),
        ] else
          _row(l10n.stops, l10n.aucunArret),
        const Divider(),
        _row(l10n.heuresMarche, formData.exploitation['H.M']!),
        _row(l10n.heuresArret, formData.exploitation['H.A']!),
        const Divider(),
        _row(l10n.metrageFore, formData.exploitation['metrage fore']!),
        _row(l10n.nrTrousFores, formData.exploitation['Nr de Trous Fores']!),
        _row(l10n.nrVoyages, formData.exploitation['Nr de Voyages']!),
        _row(l10n.m3Decapage, formData.exploitation['M³ Decapages']!),
        _row(l10n.tonnageLabel, formData.exploitation['Tonnage']!),
        _row(l10n.nombreTKU, formData.exploitation['Nombre T.K.U']!),
        _row(l10n.rendementLabel, formData.exploitation['Rendement %'] ?? ''),
        const Divider(),
        _row("${l10n.conducteurLabel}:", formData.personnel.conducteur),
        _row("${l10n.graisseurLabel}:", formData.personnel.graisseur),
        _row("${l10n.matriculesLabel}:", formData.personnel.matricules),
        const Divider(),
        _row("${l10n.chantierLabel}:", formData.repartitionTravail.chantier),
        _row("${l10n.duration}:", formData.repartitionTravail.temps),
        _row(
            "${l10n.imputationLabel}:", formData.repartitionTravail.imputation),
        const Divider(),
        _row("${l10n.triconeLabel}:", formData.consommation.tricone),
        _row("${l10n.gasoilLabel}:", formData.consommation.gasoil),
      ],
    );
  }

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
      ]));

  Future<void> _saveReport(AppLocalizations l10n) async {
    setState(() => _isLoading = true);
    try {
      final report = Report(
        id: widget.initialReport?.id,
        description: 'Rapport R0 - ${formData.selectedPoste}',
        date: _selectedDate,
        type: formData.selectedModel,
        group: formData.selectedPoste,
        additionalData: {
          'mine': formData.selectedMine,
          'zone': formData.selectedZone,
          'sortie': formData.selectedSortie,
          'selectedPoste': formData.selectedPoste,
          'Category': formData.selectedCategory,
          'Type': formData.selectedType,
          'Model': formData.selectedModel,
          'Compteurs': {
            'duree': formData.indexCompteurs.duree,
            'note': formData.indexCompteurs.note
          },
          'Arrets': formData.ventilation
              .map((v) => {'Arret': v.label, 'Début': v.duree, 'Fin': v.note})
              .toList(),
          'exploitation': {
            ...formData.exploitation,
            'Rendeme': formData.exploitation[
                'Rendement %'], // For backward compatibility if needed
          },
          'repartition': {
            'Chantier': formData.repartitionTravail.chantier,
            'Temps': formData.repartitionTravail.temps,
            'Imputation': formData.repartitionTravail.imputation,
          },
          'personnel': {
            'conductr': formData.personnel.conducteur,
            'graisseur': formData.personnel.graisseur,
            'matricules': formData.personnel.matricules
          },
          'consommation': {
            'tricone': formData.consommation.tricone,
            'gasoil': formData.consommation.gasoil
          }
        },
      );

      if (widget.isEditing && widget.onSave != null) {
        widget.onSave!(report);
      } else {
        await _databaseHelper.insertReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l10n.success), backgroundColor: AppColors.success));
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
