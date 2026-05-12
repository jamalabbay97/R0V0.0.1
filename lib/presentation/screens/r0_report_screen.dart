import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/domain/services/time_calculation_service.dart';
import 'package:r0/domain/models/report.dart';
import 'package:r0/domain/models/mine_data.dart'; // Import the shared model
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:r0/presentation/theme.dart';
import 'package:r0/presentation/widgets/custom_widgets.dart';
import 'package:r0/data/constants/r0_arrets_data.dart';

// --- Data Models ---
class IndexCompteurPoste {
  String duree;
  String note;
  bool dureeDefaut;
  bool noteDefaut;
  IndexCompteurPoste({
    this.duree = '',
    this.note = '',
    this.dureeDefaut = false,
    this.noteDefaut = false,
  });
}

class VentilationItem {
  int code;
  String category;
  String label;
  String stopDetail;
  String duree;
  String note;
  String originalStart;
  String originalEnd;
  VentilationItem(
      {required this.code,
      this.category = '',
      required this.label,
      this.stopDetail = '',
      this.duree = '',
      this.note = '',
      this.originalStart = '',
      this.originalEnd = ''});
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

class _ShiftWindow {
  final String poste;
  final DateTime date;
  final DateTime start;
  final DateTime end;

  const _ShiftWindow({
    required this.poste,
    required this.date,
    required this.start,
    required this.end,
  });
}

class _ShiftPointer {
  final String poste;
  final DateTime date;

  const _ShiftPointer({required this.poste, required this.date});
}

class _CarryOverShift {
  final String poste;
  final DateTime date;
  final List<Map<String, dynamic>> arrets;

  _CarryOverShift({
    required this.poste,
    required this.date,
    List<Map<String, dynamic>>? arrets,
  }) : arrets = arrets ?? [];
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
  ReportRepository get _reportRepository => context.read<ReportRepository>();
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

  int _posteOrderIndex(String poste) {
    return posteOrder.indexOf(poste);
  }

  int _timeOfDayToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  bool _isTimeWithinShift(TimeOfDay time, String poste) {
    final ranges = {
      "3ème": const [
        TimeOfDay(hour: 22, minute: 30),
        TimeOfDay(hour: 6, minute: 30)
      ],
      "1er": const [
        TimeOfDay(hour: 6, minute: 30),
        TimeOfDay(hour: 14, minute: 30)
      ],
      "2ème": const [
        TimeOfDay(hour: 14, minute: 30),
        TimeOfDay(hour: 22, minute: 30)
      ],
    };

    final shiftRange = ranges[poste];
    if (shiftRange == null) return true;
    final start = _timeOfDayToMinutes(shiftRange[0]);
    final end = _timeOfDayToMinutes(shiftRange[1]);
    final value = _timeOfDayToMinutes(time);

    if (end < start) {
      return value >= start || value <= end;
    }
    return value >= start && value <= end;
  }

  // Static Data - Removed local definitions, using imported 'minesData' from model

  static const Map<String, List<String>> enginsData = {
    'BULLDOZERS': [
      'BULL D9GC 88',
      'BULL D9GC 89',
      'BULL D9R 76',
      'BULL D9R 79',
      'BULL D9R 80',
      'BULL D9R 81',
      'BULL D9R 82',
      'BULL D9R 83',
      'BULL D9R 86',
      'BULL D9R 87',
      'BULL LIB 84',
      'BULL LIB 85'
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
    'ARROSEUR': ['ARROSEUR T33'],
    'CHARGEUSES': [
      'CHRG 980C-1',
      'CHRG 980C-2',
      'CHRG 992C',
      'CHRG 992K',
      'CHRG 994H'
    ],
    'NIVELEUSES': [
      'NIV 14G',
      'NIV 14G-2',
      'NIV 14G-3',
      'NIV 16H',
      'NIV KOM01',
      'NIV KOM02'
    ],
    'PAYDOZERS': ['PAY CAT03', 'PAY KOM04', 'PAY KOM05'],
    'PELLE HYDRAULIQUE': ['PH365-C', 'PH5130'],
    'PORT CHAR': ['CAMION W18', 'CAMION W21'],
    'MINI CHARGEUSES': [
      'CHRG CASE 1',
      'CHRG CAT 216B2-2',
      'CHRG CAT 216B3-2',
      'CHRG LIEBH',
      'CHRG NEWHOL'
    ],
  };
  static const Map<String, List<String>> machinesData = {
    'DRAGLINES': ['1370 W1', '1370 W2'],
    'PELLE ELECTRIQUE': ['195 P1', '195 P2'],
    'SONDEUSES Gasoil': ['PV275-1'],
    'SONDEUSES Electrique': ['PV275-2', 'PV275-3'],
  };

  Map<String, List<String>> _currentArretCategories() {
    return R0ArretsData.arretsForType(formData.selectedType);
  }

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
      formData.indexCompteurs.dureeDefaut = compteurs['dureeDefaut'] ?? false;
      formData.indexCompteurs.noteDefaut = compteurs['noteDefaut'] ?? false;
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
      formData.ventilation = arrets
          .whereType<Map>()
          .map((a) => VentilationItem(
                code: 0,
                category: a['Catégorie']?.toString() ?? '',
                label: a['Arret']?.toString() ?? '',
                stopDetail: (a['Detail'] ?? a['Détail'])?.toString() ?? '',
                duree: (a['OriginalStart'] ?? a['Début'])?.toString() ?? '',
                note: (a['OriginalEnd'] ?? a['Fin'])?.toString() ?? '',
                originalStart:
                    (a['OriginalStart'] ?? a['Début'])?.toString() ?? '',
                originalEnd: (a['OriginalEnd'] ?? a['Fin'])?.toString() ?? '',
              ))
          .toList();
      _sortVentilationByStart();
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

  int _startMinutesFromValue(String? value) {
    if (value == null || !value.contains(':')) return (24 * 60) + 1;
    final split = value.split(':');
    if (split.length != 2) return (24 * 60) + 1;
    final hour = int.tryParse(split[0]);
    final minute = int.tryParse(split[1]);
    if (hour == null || minute == null) return (24 * 60) + 1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (24 * 60) + 1;
    }
    return (hour * 60) + minute;
  }

  void _sortVentilationByStart() {
    formData.ventilation.sort((a, b) {
      final aMinutes = _startMinutesFromValue(
        a.originalStart.isNotEmpty ? a.originalStart : a.duree,
      );
      final bMinutes = _startMinutesFromValue(
        b.originalStart.isNotEmpty ? b.originalStart : b.duree,
      );
      return aMinutes.compareTo(bMinutes);
    });
  }

  void _calculateHours() {
    // Calculate total stoppage hours (H.A) with interval merging
    final totalStoppageHours = _calculateCurrentShiftDowntime();

    formData.exploitation['H.A'] = totalStoppageHours.toStringAsFixed(2);

    // Calculate working hours (H.M) using TimeCalculationService
    final hasDefect = formData.indexCompteurs.dureeDefaut ||
        formData.indexCompteurs.noteDefaut;
    final start =
        hasDefect ? null : _parseNumeric(formData.indexCompteurs.duree);
    final end = hasDefect ? null : _parseNumeric(formData.indexCompteurs.note);

    double hm = TimeCalculationService.calculateWorkingHours(
      startCounter: start,
      endCounter: end,
      hasDefect: hasDefect,
      totalStoppageHours: totalStoppageHours,
    );

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

  double _calculateDowntimeFromRanges(List<Map<String, String>> rawRanges) {
    final ranges = TimeCalculationService.parseTimeRanges(rawRanges);
    return TimeCalculationService.calculateTotalDowntime(ranges);
  }

  double _calculateDowntimeFromVentilation(List<VentilationItem> items) {
    final rawRanges = items
        .where((v) => v.duree.isNotEmpty && v.note.isNotEmpty)
        .map((v) => {'start': v.duree, 'end': v.note})
        .toList();
    return _calculateDowntimeFromRanges(rawRanges);
  }

  double _calculateDowntimeForShift(
    List<VentilationItem> items,
    _ShiftWindow shift,
  ) {
    final ranges = <TimeRange>[];

    for (final item in items) {
      if (item.duree.isEmpty || item.note.isEmpty) continue;

      DateTime arretStart =
          _getDateTimeForShift(_selectedDate, item.duree, shift.poste);
      DateTime arretEnd =
          _getDateTimeForShift(_selectedDate, item.note, shift.poste);

      if (arretEnd.isBefore(arretStart)) {
        arretEnd = arretEnd.add(const Duration(days: 1));
      }

      final effectiveStart =
          arretStart.isBefore(shift.start) ? shift.start : arretStart;
      final effectiveEnd = arretEnd.isAfter(shift.end) ? shift.end : arretEnd;

      if (effectiveStart.isBefore(effectiveEnd)) {
        final startMin = effectiveStart.difference(shift.start).inMinutes;
        final endMin = effectiveEnd.difference(shift.start).inMinutes;
        ranges.add(TimeRange(startMin, endMin));
      }
    }

    return TimeCalculationService.calculateTotalDowntime(ranges);
  }

  double _calculateCurrentShiftDowntime() {
    if (formData.selectedPoste.isEmpty) {
      return _calculateDowntimeFromVentilation(formData.ventilation);
    }

    final shift = _shiftWindow(formData.selectedPoste, _selectedDate);
    return _calculateDowntimeForShift(formData.ventilation, shift);
  }

  double _calculateDowntimeFromArrets(List<Map<String, dynamic>> arrets) {
    final rawRanges = arrets
        .where((v) =>
            (v['Début'] ?? '').toString().isNotEmpty &&
            (v['Fin'] ?? '').toString().isNotEmpty)
        .map((v) => {
              'start': v['Début'].toString(),
              'end': v['Fin'].toString(),
            })
        .toList();
    return _calculateDowntimeFromRanges(rawRanges);
  }

  String _getLocalizedTypeLabel(String key, AppLocalizations l10n) {
    final map = {
      'BULLDOZERS': AppLocalizations.of(context)!.catBulldozers,
      'CAMIONS': AppLocalizations.of(context)!.catTrucks,
      'CHARGEUSES': AppLocalizations.of(context)!.catLoaders,
      'NIVELEUSES': AppLocalizations.of(context)!.catGraders,
      'PAYDOZERS': AppLocalizations.of(context)!.catPaydozers,
      'PELLE HYDRAULIQUE': AppLocalizations.of(context)!.catHydraulicShovels,
      'DRAGLINES': AppLocalizations.of(context)!.catDraglines,
      'PELLE ELECTRIQUE': AppLocalizations.of(context)!.catElectricShovels,
      'SONDEUSES': AppLocalizations.of(context)!.catDrills,
      'MINI CHARGEUSES': AppLocalizations.of(context)!.catMiniLoaders,
      'PORT CHAR': AppLocalizations.of(context)!.catTruckLoaders
    };
    return map[key] ?? key;
  }

  String _getLocalizedCategoryLabel(String key, AppLocalizations l10n) {
    final map = {
      'EXTERIEURS': AppLocalizations.of(context)!.catExterior,
      'MATERIEL': AppLocalizations.of(context)!.catMaterial,
      'EXPLOITATION': AppLocalizations.of(context)!.catExploitation,
    };
    return map[key] ?? key;
  }

  String _getLocalizedReasonLabel(String key, AppLocalizations l10n) {
    final map = {
      'ARRET CARREAU INDUSTRIEL':
          AppLocalizations.of(context)!.stopIndustrialArea,
      'COUPURE GENERALE DU COURANT': AppLocalizations.of(context)!.stopPowerCut,
      'GREVE': AppLocalizations.of(context)!.stopStrike,
      'INTEMPERIES': AppLocalizations.of(context)!.stopWeather,
      'STOCKS PLEINS': AppLocalizations.of(context)!.stopFullStocks,
      'J. FERIES OU HEBDOMADAIRES': AppLocalizations.of(context)!.stopHolidays,
      'ARRET PAR LA CENTRALE (M.ENERGIE)':
          AppLocalizations.of(context)!.stopPowerPlant,
      'CONTROLE': AppLocalizations.of(context)!.stopControl,
      'DEFAUT ELEC. (C.CRAME, RESEAU)':
          AppLocalizations.of(context)!.stopElecFault,
      'PANNE MECANIQUE': AppLocalizations.of(context)!.stopMechBreakdown,
      'PANNE ELECTRIQUE': AppLocalizations.of(context)!.stopElecBreakdown,
      'INTERVENTION ATELIER PNEUMATIQUE':
          AppLocalizations.of(context)!.stopTireWorkshop,
      'ENTRETIEN SYSTEMATIQUE': AppLocalizations.of(context)!.stopMaintenance,
      'APPOINT (HUILE, GAZOL, EAU)': AppLocalizations.of(context)!.stopRefill,
      'GRAISSAGE': AppLocalizations.of(context)!.stopGreasing,
      'ARRET ELEC. INSTALATION FIXES':
          AppLocalizations.of(context)!.stopFixedInstallElec,
      'MANQUE CAMIONS': AppLocalizations.of(context)!.stopNoTrucks,
      'MANQUE BULL': AppLocalizations.of(context)!.stopNoBull,
      'MANQUE MECANICIEN': AppLocalizations.of(context)!.stopNoMechanic,
      'MANQUE D\'OUTILS DE TRAVAIL': AppLocalizations.of(context)!.stopNoTools,
      'MACHINE A L\'ARRET': AppLocalizations.of(context)!.stopMachineStopped,
      'PANNE ENGIN DEVANT MACHINE':
          AppLocalizations.of(context)!.stopBreakdownFront,
      'RELEVE': AppLocalizations.of(context)!.stopShiftChange,
      'EXECUTION PLATE FORME': AppLocalizations.of(context)!.stopPlatformExec,
      'DEPLACEMENT': AppLocalizations.of(context)!.stopMove,
      'TIR ET SAUTAGE': AppLocalizations.of(context)!.stopBlasting,
      'MOUV. DE CABLE': AppLocalizations.of(context)!.stopCableMove,
      'ARRET DECIDE': AppLocalizations.of(context)!.stopDecidedStop,
      'MANQUE CONDUCTEUR': AppLocalizations.of(context)!.stopNoDriver,
      'BRIQUET': AppLocalizations.of(context)!.stopBreak,
      'PISTES (INTEMPERIES EXCLUES)': AppLocalizations.of(context)!.stopTracks,
      'ARRETS MECA. INSTALATIONS FIXES':
          AppLocalizations.of(context)!.stopFixedInstallMech,
      'TELESCOPAGE': AppLocalizations.of(context)!.stopTelescoping,
      'EXCAVATION PURE': AppLocalizations.of(context)!.stopPureExcavation,
      'TERASSEMENT PUR': AppLocalizations.of(context)!.stopPureEarthworks,
    };
    return map[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      AppLocalizations.of(context)!.stepInfos,
      AppLocalizations.of(context)!.stepCompteur,
      AppLocalizations.of(context)!.stepArrets,
      AppLocalizations.of(context)!.stepExploit,
      AppLocalizations.of(context)!.stepRepartition,
      AppLocalizations.of(context)!.stepPersonnel,
      AppLocalizations.of(context)!.stepConsom,
      AppLocalizations.of(context)!.stepVerif,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? AppLocalizations.of(context)!.modifierR0
            : AppLocalizations.of(context)!.nouveauRapportR0),
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
                text: AppLocalizations.of(context)!.previous,
                onPressed: () => setState(() => _currentStep--),
                isSecondary: true,
              ),
            ),
          if (!isFirst) const SizedBox(width: 16),
          Expanded(
            child: OCPButton(
              text: isLast
                  ? AppLocalizations.of(context)!.submit
                  : AppLocalizations.of(context)!.next,
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
            content:
                Text(AppLocalizations.of(context)!.r0ValidationMissingFields)));
        return;
      }
    }

    if (_currentStep == 1) {
      // Validate working hours (Counters)
      final start = _parseNumeric(formData.indexCompteurs.duree);
      final end = _parseNumeric(formData.indexCompteurs.note);
      if (!formData.indexCompteurs.dureeDefaut &&
          !formData.indexCompteurs.noteDefaut) {
        if (end - start > 8.0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .operatingHoursExceeded((end - start).toInt(), 8)),
            backgroundColor: AppColors.error,
          ));
          return;
        }
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
                '${AppLocalizations.of(context)!.date}: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
            label: AppLocalizations.of(context)!.mine,
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
              label: AppLocalizations.of(context)!.zone,
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
            label: AppLocalizations.of(context)!.exit,
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
            label: AppLocalizations.of(context)!.categoryLabel,
            value: formData.selectedCategory.isNotEmpty
                ? formData.selectedCategory
                : null,
            items: [
              AppLocalizations.of(context)!.engines,
              AppLocalizations.of(context)!.machines
            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (val) => setState(() {
                  formData.selectedCategory = val!;
                  formData.selectedType = '';
                  formData.selectedModel = '';
                })),
        const SizedBox(height: 16),

        if (formData.selectedCategory.isNotEmpty) ...[
          OCPDropdown<String>(
              label: AppLocalizations.of(context)!.type,
              value: formData.selectedType.isNotEmpty
                  ? formData.selectedType
                  : null,
              items: (formData.selectedCategory ==
                          AppLocalizations.of(context)!.engines
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
              label: AppLocalizations.of(context)!.modelLabel,
              value: formData.selectedModel.isNotEmpty
                  ? formData.selectedModel
                  : null,
              items: (formData.selectedCategory ==
                          AppLocalizations.of(context)!.engines
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
            label: AppLocalizations.of(context)!.poste,
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
          child: Text(AppLocalizations.of(context)!.selectPosteMessage));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            AppLocalizations.of(context)!
                .counterEntryTitle(formData.selectedPoste),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OCPTextField(
                label: AppLocalizations.of(context)!.startCounterLabel,
                keyboardType: TextInputType.number,
                enabled: !formData.indexCompteurs.dureeDefaut,
                controller: TextEditingController(
                    text: formData.indexCompteurs.dureeDefaut
                        ? AppLocalizations.of(context)!.defautLabel
                        : formData.indexCompteurs.duree)
                  ..selection = TextSelection.fromPosition(TextPosition(
                      offset: formData.indexCompteurs.dureeDefaut
                          ? 0
                          : formData.indexCompteurs.duree.length)),
                onChanged: (val) {
                  if (!formData.indexCompteurs.dureeDefaut) {
                    formData.indexCompteurs.duree = val;
                    _calculateHours();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Checkbox(
                  value: formData.indexCompteurs.dureeDefaut,
                  onChanged: (val) {
                    setState(() {
                      formData.indexCompteurs.dureeDefaut = val ?? false;
                      if (formData.indexCompteurs.dureeDefaut) {
                        formData.indexCompteurs.duree = '';
                      }
                      _calculateHours();
                    });
                  },
                ),
                Text(AppLocalizations.of(context)!.defautLabel,
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OCPTextField(
                label: AppLocalizations.of(context)!.endCounterLabel,
                keyboardType: TextInputType.number,
                enabled: !formData.indexCompteurs.noteDefaut,
                controller: TextEditingController(
                    text: formData.indexCompteurs.noteDefaut
                        ? AppLocalizations.of(context)!.defautLabel
                        : formData.indexCompteurs.note)
                  ..selection = TextSelection.fromPosition(TextPosition(
                      offset: formData.indexCompteurs.noteDefaut
                          ? 0
                          : formData.indexCompteurs.note.length)),
                onChanged: (val) {
                  if (!formData.indexCompteurs.noteDefaut) {
                    formData.indexCompteurs.note = val;
                    _calculateHours();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Checkbox(
                  value: formData.indexCompteurs.noteDefaut,
                  onChanged: (val) {
                    setState(() {
                      formData.indexCompteurs.noteDefaut = val ?? false;
                      if (formData.indexCompteurs.noteDefaut) {
                        formData.indexCompteurs.note = '';
                      }
                      _calculateHours();
                    });
                  },
                ),
                Text(AppLocalizations.of(context)!.defautLabel,
                    style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
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
              child: Text(AppLocalizations.of(context)!.noStopsRecorded,
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
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.category.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        _getLocalizedCategoryLabel(item.category, l10n),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (item.stopDetail.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        '${AppLocalizations.of(context)!.detailArretLabel}: ${item.stopDetail}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.secondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text("${item.duree} -> ${item.note}"),
                ],
              ),
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
          text: AppLocalizations.of(context)!.addArretTitle,
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
    bool showDetailField = false;
    final detailController = TextEditingController();
    DateTime startTime = DateTime.now();
    DateTime endTime = DateTime.now();
    final arretCategories = _currentArretCategories();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final spinnerTextColor = isDarkMode ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) {
          Widget content;
          if (step == 0) {
            content = DropdownButtonFormField<String>(
              hint: Text(AppLocalizations.of(context)!.category),
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
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  hint: Text(AppLocalizations.of(context)!.type),
                  initialValue: selectedType,
                  isExpanded: true,
                  items: arretCategories[selectedCategory]!
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(_getLocalizedReasonLabel(t, l10n))))
                      .toList(),
                  onChanged: (v) => setDs(() => selectedType = v),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setDs(() {
                    showDetailField = !showDetailField;
                    if (!showDetailField) {
                      detailController.clear();
                    }
                  }),
                  icon: Icon(showDetailField ? Icons.remove : Icons.add),
                  label: Text(showDetailField
                      ? 'Retirer le détail'
                      : 'Ajouter un détail'),
                ),
                if (showDetailField) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: detailController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.detailArretLabel,
                      hintText:
                          AppLocalizations.of(context)!.enterStopReasonHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            );
          } else if (step == 2 && selectedType != null) {
            content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${AppLocalizations.of(context)!.category}: ${_getLocalizedCategoryLabel(selectedCategory!, l10n)}'),
                Text(
                    '${AppLocalizations.of(context)!.type}: ${_getLocalizedReasonLabel(selectedType!, l10n)}'),
                const SizedBox(height: 16),
                ListTile(
                  title: Text(AppLocalizations.of(context)!.startTimeLabel),
                  subtitle: Text(
                      "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (context) {
                        TimeOfDay tempTime = TimeOfDay.fromDateTime(startTime);
                        return AlertDialog(
                          title: Text(
                              AppLocalizations.of(context)!.selectTimeTitle),
                          content: SizedBox(
                            height: 200,
                            child: TimePickerSpinner(
                              time: startTime,
                              is24HourMode: true,
                              isShowSeconds: false,
                              minutesInterval: 1,
                              normalTextStyle: TextStyle(
                                  fontSize: 18, color: spinnerTextColor),
                              highlightedTextStyle: TextStyle(
                                  fontSize: 24, color: spinnerTextColor),
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
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(tempTime),
                              child:
                                  Text(AppLocalizations.of(context)!.okButton),
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
                  title: Text(AppLocalizations.of(context)!.endTimeLabel),
                  subtitle: Text(
                      "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}"),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (context) {
                        TimeOfDay tempTime = TimeOfDay.fromDateTime(endTime);
                        return AlertDialog(
                          title: Text(
                              AppLocalizations.of(context)!.selectTimeTitle),
                          content: SizedBox(
                            height: 200,
                            child: TimePickerSpinner(
                              time: endTime,
                              is24HourMode: true,
                              isShowSeconds: false,
                              minutesInterval: 1,
                              normalTextStyle: TextStyle(
                                  fontSize: 18, color: spinnerTextColor),
                              highlightedTextStyle: TextStyle(
                                  fontSize: 24, color: spinnerTextColor),
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
                              child: Text(AppLocalizations.of(context)!.cancel),
                            ),
                            ElevatedButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(tempTime),
                              child:
                                  Text(AppLocalizations.of(context)!.okButton),
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
            title: Text(AppLocalizations.of(context)!.addArretTitle),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (step == 0) ...[
                      Text(AppLocalizations.of(context)!.selectCategoryStep,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      content,
                    ] else if (step == 1) ...[
                      Text(AppLocalizations.of(context)!.selectStopTypeStep,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      content,
                    ] else if (step == 2) ...[
                      Text(AppLocalizations.of(context)!.enterDetailsStep,
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
                      child: Text(AppLocalizations.of(context)!.previous),
                    )
                  else
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppLocalizations.of(context)!.cancel),
                    ),
                  if ((step == 0 && selectedCategory != null) ||
                      (step == 1 && selectedType != null))
                    ElevatedButton(
                      onPressed: () => setDs(() => step++),
                      child: Text(AppLocalizations.of(context)!.next),
                    ),
                  if (step == 2 && selectedType != null)
                    ElevatedButton(
                      onPressed: () {
                        final startTod = TimeOfDay.fromDateTime(startTime);
                        if (formData.selectedPoste.isNotEmpty &&
                            !_isTimeWithinShift(
                                startTod, formData.selectedPoste)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .invalidStopStartTimeForPoste),
                              backgroundColor: AppColors.error));
                          return;
                        }
                        setState(() {
                          formData.ventilation.add(VentilationItem(
                              code: 0,
                              category: selectedCategory ?? '',
                              label: selectedType!,
                              stopDetail: detailController.text.trim(),
                              duree:
                                  "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}",
                              note:
                                  "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}",
                              originalStart:
                                  "${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}",
                              originalEnd:
                                  "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}"));
                          _sortVentilationByStart();
                          _calculateHours();
                        });
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context)!.add),
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
        _exploitRow(AppLocalizations.of(context)!.heuresMarche,
            formData.exploitation['H.M']!,
            readOnly: true),
        _exploitRow(AppLocalizations.of(context)!.heuresArret,
            formData.exploitation['H.A']!,
            readOnly: true),
        const Divider(),
        _exploitRow(AppLocalizations.of(context)!.metrageFore,
            formData.exploitation['metrage fore']!,
            onChanged: (v) => formData.exploitation['metrage fore'] = v),
        _exploitRow(AppLocalizations.of(context)!.nrTrousFores,
            formData.exploitation['Nr de Trous Fores']!,
            onChanged: (v) => formData.exploitation['Nr de Trous Fores'] = v),
        _exploitRow(AppLocalizations.of(context)!.nrVoyages,
            formData.exploitation['Nr de Voyages']!,
            onChanged: (v) => formData.exploitation['Nr de Voyages'] = v),
        _exploitRow(AppLocalizations.of(context)!.m3Decapage,
            formData.exploitation['M³ Decapages']!,
            onChanged: (v) => formData.exploitation['M³ Decapages'] = v),
        _exploitRow(AppLocalizations.of(context)!.tonnageLabel,
            formData.exploitation['Tonnage']!, onChanged: (v) {
          formData.exploitation['Tonnage'] = v;
          _calculateHours();
        }),
        _exploitRow(AppLocalizations.of(context)!.nombreTKU,
            formData.exploitation['Nombre T.K.U']!,
            onChanged: (v) => formData.exploitation['Nombre T.K.U'] = v),
        _exploitRow(AppLocalizations.of(context)!.rendementLabel,
            formData.exploitation['Rendement %']!,
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
        Text(AppLocalizations.of(context)!.repartitionTravail,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        OCPCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.details,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OCPTextField(
                label: AppLocalizations.of(context)!.chantierLabel,
                controller: TextEditingController(
                    text: formData.repartitionTravail.chantier),
                onChanged: (v) => formData.repartitionTravail.chantier = v,
              ),
              const SizedBox(height: 8),
              OCPTextField(
                label: AppLocalizations.of(context)!.duration,
                controller: TextEditingController(
                    text: formData.repartitionTravail.temps),
                onChanged: (v) => formData.repartitionTravail.temps = v,
              ),
              const SizedBox(height: 8),
              OCPTextField(
                label: AppLocalizations.of(context)!.imputationLabel,
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
            label: AppLocalizations.of(context)!.conducteurLabel,
            controller:
                TextEditingController(text: formData.personnel.conducteur),
            onChanged: (v) => formData.personnel.conducteur = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: AppLocalizations.of(context)!.graisseurLabel,
            controller:
                TextEditingController(text: formData.personnel.graisseur),
            onChanged: (v) => formData.personnel.graisseur = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: AppLocalizations.of(context)!.matriculesLabel,
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
            label: AppLocalizations.of(context)!.triconeLabel,
            controller:
                TextEditingController(text: formData.consommation.tricone),
            onChanged: (v) => formData.consommation.tricone = v),
        const SizedBox(height: 16),
        OCPTextField(
            label: AppLocalizations.of(context)!.gasoilLabel,
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
        Text(AppLocalizations.of(context)!.summary,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _row("Date",
            "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
        _row(AppLocalizations.of(context)!.mineSortie,
            "${formData.selectedMine} / ${formData.selectedSortie}"),
        _row(AppLocalizations.of(context)!.engin,
            "${_getLocalizedTypeLabel(formData.selectedType, l10n)} - ${formData.selectedModel}"),
        _row(AppLocalizations.of(context)!.poste, formData.selectedPoste),
        _row(AppLocalizations.of(context)!.counter,
            "${formData.indexCompteurs.duree} -> ${formData.indexCompteurs.note}"),
        const Divider(),
        if (formData.ventilation.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(AppLocalizations.of(context)!.detailsArrets,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          ...formData.ventilation.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getLocalizedReasonLabel(item.label, l10n),
                              style: const TextStyle(fontSize: 13)),
                          if (item.stopDetail.trim().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${AppLocalizations.of(context)!.detailArretLabel}: ${item.stopDetail}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text("${item.duree} - ${item.note}",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )),
        ] else
          _row(AppLocalizations.of(context)!.stops,
              AppLocalizations.of(context)!.aucunArret),
        const Divider(),
        _row(AppLocalizations.of(context)!.heuresMarche,
            formData.exploitation['H.M']!),
        _row(AppLocalizations.of(context)!.heuresArret,
            formData.exploitation['H.A']!),
        const Divider(),
        _row(AppLocalizations.of(context)!.metrageFore,
            formData.exploitation['metrage fore']!),
        _row(AppLocalizations.of(context)!.nrTrousFores,
            formData.exploitation['Nr de Trous Fores']!),
        _row(AppLocalizations.of(context)!.nrVoyages,
            formData.exploitation['Nr de Voyages']!),
        _row(AppLocalizations.of(context)!.m3Decapage,
            formData.exploitation['M³ Decapages']!),
        _row(AppLocalizations.of(context)!.tonnageLabel,
            formData.exploitation['Tonnage']!),
        _row(AppLocalizations.of(context)!.nombreTKU,
            formData.exploitation['Nombre T.K.U']!),
        _row(AppLocalizations.of(context)!.rendementLabel,
            formData.exploitation['Rendement %'] ?? ''),
        const Divider(),
        _row("${AppLocalizations.of(context)!.conducteurLabel}:",
            formData.personnel.conducteur),
        _row("${AppLocalizations.of(context)!.graisseurLabel}:",
            formData.personnel.graisseur),
        _row("${AppLocalizations.of(context)!.matriculesLabel}:",
            formData.personnel.matricules),
        const Divider(),
        _row("${AppLocalizations.of(context)!.chantierLabel}:",
            formData.repartitionTravail.chantier),
        _row("${AppLocalizations.of(context)!.duration}:",
            formData.repartitionTravail.temps),
        _row("${AppLocalizations.of(context)!.imputationLabel}:",
            formData.repartitionTravail.imputation),
        const Divider(),
        _row("${AppLocalizations.of(context)!.triconeLabel}:",
            formData.consommation.tricone),
        _row("${AppLocalizations.of(context)!.gasoilLabel}:",
            formData.consommation.gasoil),
      ],
    );
  }

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
      ]));

  DateTime _getDateTimeFromTimeString(DateTime date, String timeStr) {
    final parts = timeStr.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]),
        int.parse(parts[1]));
  }

  DateTime _getDateTimeForShift(
    DateTime date,
    String timeStr,
    String poste,
  ) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    var targetDate = date;

    if (poste == "3ème") {
      final timeMinutes = hour * 60 + minute;
      const thirdShiftStartMinutes = 22 * 60 + 30;
      if (timeMinutes >= thirdShiftStartMinutes) {
        targetDate = date.subtract(const Duration(days: 1));
      }
    }

    return DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );
  }

  String _formatDateTimeToTimeString(DateTime dt) {
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  _ShiftWindow _shiftWindow(String poste, DateTime date) {
    switch (poste) {
      case "3ème":
        final startDate = date.subtract(const Duration(days: 1));
        final start = _getDateTimeFromTimeString(startDate, "22:30");
        final end = _getDateTimeFromTimeString(date, "06:30");
        return _ShiftWindow(poste: poste, date: date, start: start, end: end);
      case "1er":
        return _ShiftWindow(
          poste: poste,
          date: date,
          start: _getDateTimeFromTimeString(date, "06:30"),
          end: _getDateTimeFromTimeString(date, "14:30"),
        );
      case "2ème":
      default:
        return _ShiftWindow(
          poste: poste,
          date: date,
          start: _getDateTimeFromTimeString(date, "14:30"),
          end: _getDateTimeFromTimeString(date, "22:30"),
        );
    }
  }

  _ShiftPointer _nextShift(_ShiftPointer current) {
    switch (current.poste) {
      case "3ème":
        return _ShiftPointer(poste: "1er", date: current.date);
      case "1er":
        return _ShiftPointer(poste: "2ème", date: current.date);
      case "2ème":
      default:
        return _ShiftPointer(
            poste: "3ème", date: current.date.add(const Duration(days: 1)));
    }
  }

  Future<void> _saveReport(AppLocalizations l10n) async {
    final hasDate = _selectedDate.year > 0;
    final hasModel = formData.selectedModel.trim().isNotEmpty;
    final hasPoste = formData.selectedPoste.trim().isNotEmpty;

    if (!hasDate || !hasModel || !hasPoste) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'La date, le modèle et le poste sont obligatoires pour enregistrer le rapport R0.'),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final currentShift = _shiftWindow(formData.selectedPoste, _selectedDate);
      final shiftStart = currentShift.start;
      final shiftEnd = currentShift.end;

      List<VentilationItem> currentShiftArrets = [];
      final Map<String, _CarryOverShift> carryOverByShift = {};

      for (var item in formData.ventilation) {
        DateTime arretStart =
            _getDateTimeForShift(_selectedDate, item.duree, currentShift.poste);
        DateTime arretEnd =
            _getDateTimeForShift(_selectedDate, item.note, currentShift.poste);

        // Adjust for same-day wrap around if necessary (though usually picked times are within 24h)
        if (arretEnd.isBefore(arretStart)) {
          arretEnd = arretEnd.add(const Duration(days: 1));
        }

        // 1. Part during shift (clipped to shift boundaries)
        DateTime effectiveStart =
            arretStart.isBefore(shiftStart) ? shiftStart : arretStart;
        DateTime effectiveEnd =
            arretEnd.isAfter(shiftEnd) ? shiftEnd : arretEnd;

        if (effectiveStart.isBefore(effectiveEnd) &&
            effectiveStart.isBefore(shiftEnd) &&
            effectiveEnd.isAfter(shiftStart)) {
          currentShiftArrets.add(VentilationItem(
            code: item.code,
            category: item.category,
            label: item.label,
            stopDetail: item.stopDetail,
            duree: _formatDateTimeToTimeString(effectiveStart),
            note: _formatDateTimeToTimeString(effectiveEnd),
            originalStart:
                item.originalStart.isNotEmpty ? item.originalStart : item.duree,
            originalEnd:
                item.originalEnd.isNotEmpty ? item.originalEnd : item.note,
          ));
        }

        // 2. Parts after shift (Carry Over across subsequent shifts)
        if (arretEnd.isAfter(shiftEnd)) {
          DateTime carryStart =
              arretStart.isBefore(shiftEnd) ? shiftEnd : arretStart;
          var pointer = _nextShift(_ShiftPointer(
              poste: currentShift.poste, date: currentShift.date));

          while (carryStart.isBefore(arretEnd)) {
            final nextShift = _shiftWindow(pointer.poste, pointer.date);
            final segmentStart = carryStart.isAfter(nextShift.start)
                ? carryStart
                : nextShift.start;
            final segmentEnd =
                arretEnd.isBefore(nextShift.end) ? arretEnd : nextShift.end;

            if (segmentStart.isBefore(segmentEnd)) {
              final key =
                  '${nextShift.poste}-${nextShift.date.toIso8601String().split('T').first}';
              carryOverByShift.putIfAbsent(
                  key,
                  () => _CarryOverShift(
                        poste: nextShift.poste,
                        date: nextShift.date,
                      ));
              carryOverByShift[key]!.arrets.add({
                'Catégorie': item.category,
                'Arret': item.label,
                'Detail': item.stopDetail,
                'Début': _formatDateTimeToTimeString(segmentStart),
                'Fin': _formatDateTimeToTimeString(segmentEnd),
                'OriginalStart': item.originalStart.isNotEmpty
                    ? item.originalStart
                    : item.duree,
                'OriginalEnd':
                    item.originalEnd.isNotEmpty ? item.originalEnd : item.note,
                'CarryOver': true
              });
            }

            carryStart = segmentEnd;
            if (carryStart.isBefore(arretEnd)) {
              pointer = _nextShift(pointer);
            }
          }
        }
      }

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
            'note': formData.indexCompteurs.note,
            'dureeDefaut': formData.indexCompteurs.dureeDefaut,
            'noteDefaut': formData.indexCompteurs.noteDefaut,
          },
          'Arrets': currentShiftArrets
              .map((v) => {
                    'Catégorie': v.category,
                    'Arret': v.label,
                    'Detail': v.stopDetail,
                    'Début': v.duree,
                    'Fin': v.note,
                    'OriginalStart':
                        v.originalStart.isNotEmpty ? v.originalStart : v.duree,
                    'OriginalEnd':
                        v.originalEnd.isNotEmpty ? v.originalEnd : v.note,
                  })
              .toList(),
          'exploitation': {
            ...formData.exploitation,
            'H.A': _calculateDowntimeFromVentilation(currentShiftArrets)
                .toStringAsFixed(2),
            'Rendeme': formData.exploitation['Rendement %'],
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
        await _reportRepository.insertReport(report);

        // Handle Carry Over to Next Poste
        final carryOverShifts = carryOverByShift.values.toList()
          ..sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return _posteOrderIndex(a.poste)
                .compareTo(_posteOrderIndex(b.poste));
          });

        if (carryOverShifts.isNotEmpty) {
          for (final carryShift in carryOverShifts) {
            final shiftArrets = carryShift.arrets;
            if (shiftArrets.isEmpty) continue;

            final nextReport = Report(
              description: 'Rapport R0 - ${carryShift.poste} (Carry Over)',
              date: carryShift.date,
              type: formData.selectedModel,
              group: carryShift.poste,
              additionalData: {
                'mine': formData.selectedMine,
                'zone': formData.selectedZone,
                'sortie': formData.selectedSortie,
                'selectedPoste': carryShift.poste,
                'Category': formData.selectedCategory,
                'Type': formData.selectedType,
                'Model': formData.selectedModel,
                'Compteurs': {
                  'duree': '',
                  'note': '',
                  'dureeDefaut': false,
                  'noteDefaut': false,
                },
                'Arrets': shiftArrets,
                'exploitation': {
                  'H.M': '0.00',
                  'H.A': _calculateDowntimeFromArrets(shiftArrets)
                      .toStringAsFixed(2),
                  'Tonnage': '0',
                  'metrage fore': '',
                  'Nr de Trous Fores': '',
                  'Nr de Voyages': '',
                  'M³ Decapages': '',
                  'Nombre T.K.U': '',
                  'Rendement %': '0.00',
                },
                'repartition': {
                  'Chantier': '',
                  'Temps': '',
                  'Imputation': '',
                },
                'personnel': {
                  'conductr': '',
                  'graisseur': '',
                  'matricules': ''
                },
                'consommation': {'tricone': '', 'gasoil': ''},
                'carryOverFrom': formData.selectedPoste
              },
            );
            await _reportRepository.insertReport(nextReport);
          }
        }

        if (mounted) {
          final shouldNotifyLongStop = carryOverShifts.length > 1 &&
              carryOverShifts.any((shift) => shift.date.isAfter(_selectedDate));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(shouldNotifyLongStop
                  ? AppLocalizations.of(context)!.longStopCarryOverNotice
                  : AppLocalizations.of(context)!.success),
              backgroundColor: AppColors.success));
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorMessage(e.toString())),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
