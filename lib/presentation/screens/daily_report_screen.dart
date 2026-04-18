import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/domain/models/report.dart';
import 'package:intl/intl.dart';
import 'package:r0/presentation/theme.dart';
import 'package:r0/presentation/widgets/custom_widgets.dart';
import 'package:r0/presentation/widgets/spinner_time_picker_dialog.dart';

// --- Models & Enums ---
class ModuleStop {
  final String id;
  String category;
  String duration;
  String nature;
  String location;
  String detail;
  String stopType;
  String stopLocation;
  String startTime;
  String endTime;

  ModuleStop(
      {required this.id,
      this.category = '',
      this.duration = '',
      this.nature = '',
      this.location = '',
      this.detail = '',
      this.stopType = '',
      this.stopLocation = '',
      this.startTime = '',
      this.endTime = ''});
}

class StopCategory {
  final String label;
  final List<String> types;
  const StopCategory({required this.label, required this.types});
}

enum Poste { premier, deuxieme, troisieme }

enum Park { park1, park2, park3 }

enum StockType { normal, oceane, pb30 }

String posteToString(Poste? p) {
  switch (p) {
    case Poste.premier:
      return "3ème";
    case Poste.deuxieme:
      return "1er";
    case Poste.troisieme:
      return "2ème";
    default:
      return "";
  }
}

String parkToString(Park? p) {
  switch (p) {
    case Park.park1:
      return "PARK 1";
    case Park.park2:
      return "PARK 2";
    case Park.park3:
      return "PARK 3";
    default:
      return "";
  }
}

String stockTypeToString(StockType? t) {
  switch (t) {
    case StockType.normal:
      return "NORMAL";
    case StockType.oceane:
      return "OCEANE";
    case StockType.pb30:
      return "PB30";
    default:
      return "";
  }
}

class DailyStockEntry {
  String id;
  Poste? poste;
  Park? park;
  StockType? type;
  String quantity;
  DailyStockEntry(
      {required this.id, this.poste, this.park, this.type, this.quantity = ''});
}

class _StopTimeSelectionResult {
  final TimeOfDay start;
  final TimeOfDay? end;

  const _StopTimeSelectionResult({required this.start, required this.end});
}

class _StopTimeEntryPage extends StatefulWidget {
  final String titleSuffix;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;
  final bool initialPending;

  const _StopTimeEntryPage({
    required this.titleSuffix,
    this.initialStartTime,
    this.initialEndTime,
    this.initialPending = false,
  });

  @override
  State<_StopTimeEntryPage> createState() => _StopTimeEntryPageState();
}

class _StopTimeEntryPageState extends State<_StopTimeEntryPage> {
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime ?? TimeOfDay.now();
    _endTime = widget.initialEndTime ?? _startTime;
    _isPending = widget.initialPending;
  }

  String _formatTime(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  int _toMinutes(TimeOfDay value) => (value.hour * 60) + value.minute;
  int _toCycleMinutes(TimeOfDay value) {
    final minutes = _toMinutes(value);
    return minutes < _cycleAnchorMinutes ? minutes + (24 * 60) : minutes;
  }

  Future<void> _pickStartTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _startTime,
      title: 'Heure début',
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _endTime,
      title: 'Heure fin',
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationMinutes =
        _toCycleMinutes(_endTime) - _toCycleMinutes(_startTime);
    final hasValidRange =
        _isPending || (durationMinutes > 0 && durationMinutes <= 24 * 60);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF202820), Color(0xFF1C211D)],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter Arrêt ${widget.titleSuffix}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Saisie des heures',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Heure début',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      subtitle: Text(
                        _formatTime(_startTime),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 34,
                      ),
                      onTap: _pickStartTime,
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Heure fin',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      subtitle: Text(
                        _isPending ? 'Pending' : _formatTime(_endTime),
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 16,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.access_time,
                        color: Colors.white70,
                        size: 34,
                      ),
                      onTap: _isPending ? null : _pickEndTime,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Arrêt en cours',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        "Enregistrer l'heure de début maintenant, puis ajouter l'heure de fin plus tard.",
                        style: TextStyle(color: Colors.white70),
                      ),
                      value: _isPending,
                      onChanged: (value) => setState(() => _isPending = value),
                    ),
                    const SizedBox(height: 16),
                    if (!hasValidRange)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max).",
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Précédent',
                            style: TextStyle(
                                color: AppColors.success, fontSize: 22),
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(150, 56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          onPressed: hasValidRange
                              ? () {
                                  Navigator.of(context).pop(
                                    _StopTimeSelectionResult(
                                      start: _startTime,
                                      end: _isPending ? null : _endTime,
                                    ),
                                  );
                                }
                              : null,
                          child: const Text(
                            'Ajouter',
                            style: TextStyle(fontSize: 28),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _StopActionMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Flexible(child: Text(label)),
      ],
    );
  }
}

// --- Helper Functions ---
int parseDurationToMinutes(String duration) {
  if (duration.isEmpty) return 0;
  final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
  // Simplified parsing logic
  try {
    if (cleaned.contains('h')) {
      final parts = cleaned.split('h');
      int h = int.parse(parts[0]);
      int m = parts.length > 1 && parts[1].isNotEmpty ? int.parse(parts[1]) : 0;
      return h * 60 + m;
    }
    return int.parse(cleaned);
  } catch (_) {
    return 0;
  }
}

String formatMinutesToHoursMinutes(int totalMinutes) {
  if (totalMinutes <= 0) return "0h 00m";
  int hours = totalMinutes ~/ 60;
  int minutes = totalMinutes % 60;
  return "${hours}h ${minutes.toString().padLeft(2, '0')}m";
}

const List<StopCategory> _tnbStopCategories = [
  StopCategory(
    label: 'Arrêts Extérieures',
    types: [
      'MP - Manque Produit',
      'CC - Coupure De Courant',
      'AD - Arrêts Décidés',
      'STS - Stock Saturée',
      'DS - Attente Dégagement Stérile',
      'MB - Manque Bull',
      'Aut - Autre',
    ],
  ),
  StopCategory(
    label: 'Arrêts Materiel',
    types: [
      'AE - Arrêts Éléctrique',
      'AM - Arrêts Mécanique',
      'AI - Arrêts Installateur',
      'AESYS - Arrêts Entretien Systématique',
    ],
  ),
  StopCategory(
    label: "Arrêts d'Exploitation",
    types: [
      'NET - Nettoyage',
      'NETG - Nettoyage Général',
      'SURCH - Surcharge',
      'DEC - Décolmatage',
      'MO - Manque Opérateur',
    ],
  ),
];

String _extractTnbStopTypeCode(String? type) {
  final rawType = type?.trim() ?? '';
  if (rawType.isEmpty) {
    return '';
  }

  return rawType.split(' - ').first.trim().toUpperCase();
}

bool _tnbStopTypeRequiresDetail(String? type) =>
    const {'AE', 'AM', 'AI', 'AESYS'}.contains(_extractTnbStopTypeCode(type));

bool _tnbStopTypeRequiresLocation(String? type) {
  final code = _extractTnbStopTypeCode(type);
  if (const {'AE', 'AM', 'AI', 'AESYS', 'SURCH', 'DEC', 'NET'}.contains(code)) {
    return true;
  }

  return false;
}

bool _tnbStopTypeAlwaysMirrors(String? type) {
  final code = _extractTnbStopTypeCode(type);
  return const {'MP', 'CC', 'AD', 'STS', 'DS', 'MB', 'NETG', 'AUT'}
      .contains(code);
}

// --- Screen ---
class DailyReportScreen extends StatefulWidget {
  final Report? initialReport;
  final Function(Report)? onSave;
  final bool isEditing;

  const DailyReportScreen(
      {super.key, this.initialReport, this.onSave, this.isEditing = false});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  static const totalPeriodMinutes = 24 * 60;
  static const int _cycleAnchorMinutes = 22 * 60 + 30;
  static const Set<String> _sharedConveyorLocationKeys = {
    'CV_G0_G2',
  };
  ReportRepository get _reportRepository => context.read<ReportRepository>();

  DateTime _selectedDate = DateTime.now();

  List<ModuleStop> module1Stops = [];
  List<ModuleStop> module2Stops = [];
  List<DailyStockEntry> stockEntries = [];

  int module1TotalDowntime = 0;
  int module2TotalDowntime = 0;
  int module1OperatingTime = totalPeriodMinutes;
  int module2OperatingTime = totalPeriodMinutes;

  int _currentStep = 0;
  bool _isSaving = false;

  int _toCycleMinutes(TimeOfDay value) {
    final minutes = (value.hour * 60) + value.minute;
    return minutes < _cycleAnchorMinutes ? minutes + (24 * 60) : minutes;
  }

  int _durationMinutesInCycle(TimeOfDay start, TimeOfDay end) =>
      _toCycleMinutes(end) - _toCycleMinutes(start);

  int _minutesFromTimeText(String value) {
    if (!value.contains(':')) return (24 * 60) + 1;
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

  void _sortModuleStopsByStartTime(List<ModuleStop> stops) {
    stops.sort((a, b) => _minutesFromTimeText(a.startTime)
        .compareTo(_minutesFromTimeText(b.startTime)));
  }

  static const Map<int, Map<String, String>> _moduleLocations = {
    1: {
      'M1_TR01': 'Tremie',
      'M1_VIB01': 'Vibreur 01',
      'M1_VIB02': 'Vibreur 02',
      'M1_CV73': 'Convoyeur 73',
      'M1_cv77': 'Convoyeur 77',
      'M1_CRIBLE1': 'Crible 01',
      'M1_CV84': 'Convoyeur 84',
      'M1_CV86': 'Convoyeur 86',
      'CV_G0': 'Convoyeur G0',
      'CV_G2': 'Convoyeur G2',
      'CV_G0_G2': 'Convoyeurs G0 + G2 (panne totale)',
      'CV_G4': 'Convoyeur G4',
    },
    2: {
      'M2_TR01': 'Tremie',
      'M2_VIB01': 'Vibreur 01',
      'M2_VIB02': 'Vibreur 02',
      'M2_CV73': 'Convoyeur 73',
      'M2_cv77': 'Convoyeur 77',
      'M2_CRIBLE1': 'Crible 01',
      'M2_CV84': 'Convoyeur 84',
      'M2_CV86': 'Convoyeur 86',
      'CV_G0': 'Convoyeur G0',
      'CV_G2': 'Convoyeur G2',
      'CV_G0_G2': 'Convoyeurs G0 + G2 (panne totale)',
      'CV_G5': 'Convoyeur G5',
    },
  };

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialReport != null) {
      _selectedDate = widget.initialReport!.date;
      _loadExistingData();
    }
    _calculateTotals();
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;

    if (data['module1Stops'] is List) {
      module1Stops = (data['module1Stops'] as List)
          .map((s) => ModuleStop(
              id: s['id'] ?? const Uuid().v4(),
              category: s['category'] ?? s['Catégorie'] ?? '',
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? s['Arret'] ?? '',
              location: s['location'] ?? s['Lieu'] ?? s['stopLocation'] ?? '',
              detail: s['detail'] ?? s['Détail'] ?? '',
              stopType: s['stopType'] ?? s['nature'] ?? s['Arret'] ?? '',
              stopLocation: s['stopLocation'] ?? '',
              startTime: s['startTime'] ?? '',
              endTime: s['endTime'] ?? ''))
          .toList();
      _sortModuleStopsByStartTime(module1Stops);
    }
    if (data['module2Stops'] is List) {
      module2Stops = (data['module2Stops'] as List)
          .map((s) => ModuleStop(
              id: s['id'] ?? const Uuid().v4(),
              category: s['category'] ?? s['Catégorie'] ?? '',
              duration: s['duration'] ?? '',
              nature: s['nature'] ?? s['Arret'] ?? '',
              location: s['location'] ?? s['Lieu'] ?? s['stopLocation'] ?? '',
              detail: s['detail'] ?? s['Détail'] ?? '',
              stopType: s['stopType'] ?? s['nature'] ?? s['Arret'] ?? '',
              stopLocation: s['stopLocation'] ?? '',
              startTime: s['startTime'] ?? '',
              endTime: s['endTime'] ?? ''))
          .toList();
      _sortModuleStopsByStartTime(module2Stops);
    }
    if (data['stock'] is List) {
      stockEntries = (data['stock'] as List)
          .map((s) => DailyStockEntry(
              id: s['id'] ?? const Uuid().v4(),
              poste: _parsePoste(s['poste']),
              park: _parsePark(s['park']),
              type: _parseStockType(s['type']),
              quantity: s['quantity'] ?? ''))
          .toList();
    }
  }

  Poste? _parsePoste(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < Poste.values.length) {
      return Poste.values[idx];
    }
    return null;
  }

  Park? _parsePark(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < Park.values.length) {
      return Park.values[idx];
    }
    return null;
  }

  StockType? _parseStockType(dynamic val) {
    if (val == null) return null;
    int? idx = int.tryParse(val.toString());
    if (idx != null && idx >= 0 && idx < StockType.values.length) {
      return StockType.values[idx];
    }
    return null;
  }

  void _calculateTotals() {
    setState(() {
      module1TotalDowntime = module1Stops.fold(
          0, (acc, s) => acc + parseDurationToMinutes(s.duration));
      module2TotalDowntime = module2Stops.fold(
          0, (acc, s) => acc + parseDurationToMinutes(s.duration));

      module1OperatingTime = (totalPeriodMinutes - module1TotalDowntime)
          .clamp(0, totalPeriodMinutes);
      module2OperatingTime = (totalPeriodMinutes - module2TotalDowntime)
          .clamp(0, totalPeriodMinutes);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Localizations handled naively or assume English/French provided context
    final title =
        widget.isEditing ? 'Modifier Daily Report TSUD' : 'Daily Report TSUD';
    final steps = ['Infos', 'Arrêts M1', 'Arrêts M2', 'Stock', 'Verif.'];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              OCPStepper(
                  steps: steps,
                  currentStep: _currentStep,
                  onStepTapped: (i) => setState(() => _currentStep = i)),
              Expanded(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildStepContent())),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepInfos();
      case 1:
        return _buildStepArrets(1, module1Stops);
      case 2:
        return _buildStepArrets(2, module2Stops);
      case 3:
        return _buildStepStock();
      case 4:
        return _buildStepVerification();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar() {
    bool isFirst = _currentStep == 0;
    bool isLast = _currentStep == 4;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black12)]),
      child: Row(children: [
        if (!isFirst)
          Expanded(
              child: OCPButton(
                  text: 'Précédent',
                  onPressed: () => setState(() => _currentStep--),
                  isSecondary: true)),
        if (!isFirst) const SizedBox(width: 16),
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
                isLoading: _isSaving && isLast)),
      ]),
    );
  }

  // --- Step 0: Infos ---
  Widget _buildStepInfos() {
    return Column(children: [
      OCPCard(
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
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ]),
      ),
    ]);
  }

  // --- Step 1 & 2: Arrêts ---
  Widget _buildStepArrets(int module, List<ModuleStop> stops) {
    return Column(children: [
      Text("Module $module",
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(color: AppColors.primary)),
      const SizedBox(height: 16),
      if (stops.isEmpty)
        const Text("Aucun arrêt enregistré.",
            style: TextStyle(color: Colors.grey)),
      ...stops.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(_formatModuleStopHeadline(e.value, e.key + 1)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_formatModuleStopTimeline(e.value)),
                if (_isPendingModuleStop(e.value))
                  const Text(
                    'Arrêt en cours',
                    style: TextStyle(color: AppColors.success),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Actions arrêt',
              onSelected: (value) {
                if (value == 'end') {
                  _endPendingModuleStop(module, stops, e.key);
                  return;
                }

                if (value == 'edit') {
                  _showEditStopDialog(module, stops, e.key);
                  return;
                }

                setState(() {
                  stops.removeAt(e.key);
                  _calculateTotals();
                });
              },
              itemBuilder: (context) => [
                if (_isPendingModuleStop(e.value))
                  const PopupMenuItem<String>(
                    value: 'end',
                    child: _StopActionMenuItem(
                      icon: Icons.stop_circle_outlined,
                      label: 'Terminer',
                      iconColor: AppColors.success,
                    ),
                  ),
                PopupMenuItem<String>(
                  value: 'edit',
                  child: _StopActionMenuItem(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                    iconColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: _StopActionMenuItem(
                    icon: Icons.delete_outline,
                    label: 'Supprimer',
                    iconColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Arrêt (Module $module)",
          icon: Icons.add,
          isSecondary: true,
          onPressed: () => _showAddStopDialog(module))
    ]);
  }

  void _showAddStopDialog(int module) {
    StopCategory? selectedCategory;
    String? selectedNature;
    String? selectedLocation;
    String stopDetail = '';
    bool applyToBothModules = true;
    final locations = _moduleLocations[module] ?? const <String, String>{};
    String formatTimeOfDay(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (context, setDs) {
                final availableTypes =
                    selectedCategory?.types ?? const <String>[];
                final requiresDetail =
                    _tnbStopTypeRequiresDetail(selectedNature);
                final requiresLocation =
                    _tnbStopTypeRequiresLocation(selectedNature);
                final canSubmit = selectedCategory != null &&
                    selectedNature != null &&
                    (!requiresLocation || selectedLocation != null) &&
                    (!requiresDetail || stopDetail.trim().isNotEmpty);

                return AlertDialog(
                  title: Text(AppLocalizations.of(context)!.addStopForModule(module.toString())),
                  content: SingleChildScrollView(
                    child: SizedBox(
                      width: 360,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<StopCategory>(
                            initialValue: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: "Catégorie d'arrêt",
                              border: OutlineInputBorder(),
                            ),
                            items: _tnbStopCategories
                                .map((category) => DropdownMenuItem(
                                      value: category,
                                      child: Text(category.label),
                                    ))
                                .toList(),
                            onChanged: (value) => setDs(() {
                              selectedCategory = value;
                              selectedNature = null;
                              selectedLocation = null;
                              stopDetail = '';
                              applyToBothModules = true;
                            }),
                            hint: Text(AppLocalizations.of(context)!.selectStopCategory),
                            isExpanded: true,
                          ),
                          if (selectedCategory != null) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedNature,
                              decoration: const InputDecoration(
                                labelText: 'Type d\'arrêt',
                                border: OutlineInputBorder(),
                              ),
                              items: availableTypes
                                  .map((nature) => DropdownMenuItem(
                                        value: nature,
                                        child: Text(nature),
                                      ))
                                  .toList(),
                              onChanged: (value) => setDs(() {
                                selectedNature = value;
                                selectedLocation = null;
                                stopDetail = '';
                                applyToBothModules = true;
                              }),
                              hint: Text(AppLocalizations.of(context)!.selectStopType),
                              isExpanded: true,
                            ),
                          ],
                          if (selectedNature != null && requiresLocation) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: "Lieu d'arrêt",
                                border: OutlineInputBorder(),
                              ),
                              initialValue: selectedLocation,
                              isExpanded: true,
                              items: locations.entries
                                  .map((entry) => DropdownMenuItem(
                                      value: entry.key,
                                      child: Text(
                                          '${entry.key} - ${entry.value}')))
                                  .toList(),
                              onChanged: (value) => setDs(() {
                                selectedLocation = value;
                                applyToBothModules =
                                    _isSharedConveyorLocation(value);
                              }),
                              hint: Text(AppLocalizations.of(context)!.selectLocation),
                            ),
                          ],
                          if (requiresLocation &&
                              _isSharedConveyorLocation(selectedLocation))
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(AppLocalizations.of(context)!.applyToBothModules),
                              subtitle: const Text(
                                  'Appliquer aux deux modules 1 et 2.'),
                              value: applyToBothModules,
                              onChanged: (value) =>
                                  setDs(() => applyToBothModules = value),
                            ),
                          if (requiresDetail) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: stopDetail,
                              decoration: const InputDecoration(
                                labelText: "Détail de l'arrêt",
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) =>
                                  setDs(() => stopDetail = value),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLocalizations.of(context)!.cancel)),
                    ElevatedButton(
                      onPressed: canSubmit
                          ? () async {
                              final selectedTimeResult =
                                  await showDialog<_StopTimeSelectionResult>(
                                context: context,
                                useRootNavigator: true,
                                barrierDismissible: false,
                                barrierColor: Colors.black54,
                                builder: (_) => _StopTimeEntryPage(
                                  titleSuffix: selectedNature ?? '',
                                ),
                              );

                              if (selectedTimeResult == null) {
                                return;
                              }

                              final validation = _validateSingleStop(
                                selectedTimeResult.start,
                                selectedTimeResult.end,
                                selectedCategory,
                                selectedNature,
                                selectedLocation,
                                stopDetail,
                              );
                              if (validation != null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(validation),
                                          backgroundColor: AppColors.error));
                                }
                                return;
                              }

                              final durationText = selectedTimeResult.end ==
                                      null
                                  ? ''
                                  : '${_durationMinutesInCycle(selectedTimeResult.start, selectedTimeResult.end!) ~/ 60}h '
                                      '${(_durationMinutesInCycle(selectedTimeResult.start, selectedTimeResult.end!) % 60).toString().padLeft(2, '0')}';
                              final locationLabel = selectedLocation == null
                                  ? ''
                                  : '${selectedLocation ?? ''} - ${locations[selectedLocation] ?? ''}';

                              setState(() {
                                final stop = ModuleStop(
                                  id: const Uuid().v4(),
                                  category: selectedCategory!.label,
                                  duration: durationText,
                                  nature: selectedNature!,
                                  location: locationLabel,
                                  detail: stopDetail.trim(),
                                  stopType: selectedNature!,
                                  stopLocation: locationLabel,
                                  startTime:
                                      formatTimeOfDay(selectedTimeResult.start),
                                  endTime: selectedTimeResult.end == null
                                      ? 'Pending'
                                      : formatTimeOfDay(
                                          selectedTimeResult.end!),
                                );
                                if (module == 1) {
                                  module1Stops.add(stop);
                                  _sortModuleStopsByStartTime(module1Stops);
                                } else {
                                  module2Stops.add(stop);
                                  _sortModuleStopsByStartTime(module2Stops);
                                }
                                final shouldMirrorByType =
                                    _tnbStopTypeAlwaysMirrors(selectedNature);
                                final shouldMirrorBySharedLocation =
                                    requiresLocation &&
                                        applyToBothModules &&
                                        _isSharedConveyorLocation(
                                            selectedLocation);

                                if (shouldMirrorByType ||
                                    shouldMirrorBySharedLocation) {
                                  final mirroredStop = ModuleStop(
                                    id: const Uuid().v4(),
                                    category: selectedCategory!.label,
                                    duration: durationText,
                                    nature: selectedNature!,
                                    location: locationLabel,
                                    detail: stopDetail.trim(),
                                    stopType: selectedNature!,
                                    stopLocation: locationLabel,
                                    startTime: formatTimeOfDay(
                                        selectedTimeResult.start),
                                    endTime: selectedTimeResult.end == null
                                        ? 'Pending'
                                        : formatTimeOfDay(
                                            selectedTimeResult.end!),
                                  );
                                  if (module == 1) {
                                    module2Stops.add(mirroredStop);
                                    _sortModuleStopsByStartTime(module2Stops);
                                  } else {
                                    module1Stops.add(mirroredStop);
                                    _sortModuleStopsByStartTime(module1Stops);
                                  }
                                }
                                _calculateTotals();
                              });
                              if (context.mounted) Navigator.pop(context);
                            }
                          : null,
                      child: Text(AppLocalizations.of(context)!.next),
                    )
                  ],
                );
              },
            ));
  }

  void _showEditStopDialog(int module, List<ModuleStop> stops, int index) {
    final stop = stops[index];
    StopCategory? selectedCategory = _tnbStopCategories.firstWhere(
      (category) => category.label == stop.category,
      orElse: () => _tnbStopCategories.first,
    );
    String? selectedNature = stop.nature.isNotEmpty
        ? stop.nature
        : (selectedCategory.types.isNotEmpty
            ? selectedCategory.types.first
            : null);
    final locations = _moduleLocations[module] ?? const <String, String>{};
    String? selectedLocation;
    for (final entry in locations.entries) {
      if (stop.location.isNotEmpty && stop.location.startsWith(entry.key)) {
        selectedLocation = entry.key;
        break;
      }
    }
    String stopDetail = stop.detail;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDs) {
          final availableTypes = selectedCategory?.types ?? const <String>[];
          final requiresDetail = _tnbStopTypeRequiresDetail(selectedNature);
          final requiresLocation = _tnbStopTypeRequiresLocation(selectedNature);
          final canSubmit = selectedCategory != null &&
              selectedNature != null &&
              (!requiresLocation || selectedLocation != null) &&
              (!requiresDetail || stopDetail.trim().isNotEmpty);

          return AlertDialog(
            title: Text('${AppLocalizations.of(context)!.editArret} - Module $module'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<StopCategory>(
                      initialValue: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Catégorie d'arrêt",
                        border: OutlineInputBorder(),
                      ),
                      items: _tnbStopCategories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.label),
                              ))
                          .toList(),
                      onChanged: (value) => setDs(() {
                        selectedCategory = value;
                        if (!(selectedCategory?.types
                                .contains(selectedNature) ??
                            false)) {
                          selectedNature = null;
                        }
                        if (!_tnbStopTypeRequiresLocation(selectedNature)) {
                          selectedLocation = null;
                        }
                        if (!_tnbStopTypeRequiresDetail(selectedNature)) {
                          stopDetail = '';
                        }
                      }),
                      hint: Text(AppLocalizations.of(context)!.selectStopCategory),
                      isExpanded: true,
                    ),
                    if (selectedCategory != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedNature,
                        decoration: const InputDecoration(
                          labelText: 'Type d\'arrêt',
                          border: OutlineInputBorder(),
                        ),
                        items: availableTypes
                            .map((nature) => DropdownMenuItem(
                                  value: nature,
                                  child: Text(nature),
                                ))
                            .toList(),
                        onChanged: (value) => setDs(() {
                          selectedNature = value;
                          if (!_tnbStopTypeRequiresLocation(value)) {
                            selectedLocation = null;
                          }
                          if (!_tnbStopTypeRequiresDetail(value)) {
                            stopDetail = '';
                          }
                        }),
                        hint: Text(AppLocalizations.of(context)!.selectStopType),
                        isExpanded: true,
                      ),
                    ],
                    if (selectedNature != null && requiresLocation) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Lieu d'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        initialValue: selectedLocation,
                        isExpanded: true,
                        items: locations.entries
                            .map((entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text('${entry.key} - ${entry.value}')))
                            .toList(),
                        onChanged: (value) =>
                            setDs(() => selectedLocation = value),
                        hint: Text(AppLocalizations.of(context)!.selectLocation),
                      ),
                    ],
                    if (requiresDetail) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: stopDetail,
                        decoration: const InputDecoration(
                          labelText: "Détail de l'arrêt",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) => setDs(() => stopDetail = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel)),
              ElevatedButton(
                onPressed: canSubmit
                    ? () async {
                        final selectedTimeResult =
                            await showDialog<_StopTimeSelectionResult>(
                          context: context,
                          useRootNavigator: true,
                          barrierDismissible: false,
                          barrierColor: Colors.black54,
                          builder: (_) => _StopTimeEntryPage(
                            titleSuffix: selectedNature ?? '',
                            initialStartTime: _parseTime(stop.startTime),
                            initialEndTime: _parseTime(stop.endTime),
                            initialPending: _isPendingModuleStop(stop),
                          ),
                        );

                        if (selectedTimeResult == null) {
                          return;
                        }

                        final validation = _validateSingleStop(
                          selectedTimeResult.start,
                          selectedTimeResult.end,
                          selectedCategory,
                          selectedNature,
                          selectedLocation,
                          stopDetail,
                        );
                        if (validation != null) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(validation),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                          return;
                        }

                        final locationLabel = selectedLocation == null
                            ? ''
                            : '${selectedLocation ?? ''} - ${locations[selectedLocation] ?? ''}';
                        final durationText = selectedTimeResult.end == null
                            ? ''
                            : '${_durationMinutesInCycle(selectedTimeResult.start, selectedTimeResult.end!) ~/ 60}h '
                                '${(_durationMinutesInCycle(selectedTimeResult.start, selectedTimeResult.end!) % 60).toString().padLeft(2, '0')}';
                        setState(() {
                          stop.category = selectedCategory!.label;
                          stop.nature = selectedNature!;
                          stop.location = locationLabel;
                          stop.detail = stopDetail.trim();
                          stop.stopType = selectedNature!;
                          stop.stopLocation = locationLabel;
                          stop.startTime =
                              '${selectedTimeResult.start.hour.toString().padLeft(2, '0')}:${selectedTimeResult.start.minute.toString().padLeft(2, '0')}';
                          stop.endTime = selectedTimeResult.end == null
                              ? 'Pending'
                              : '${selectedTimeResult.end!.hour.toString().padLeft(2, '0')}:${selectedTimeResult.end!.minute.toString().padLeft(2, '0')}';
                          stop.duration = durationText;
                          _calculateTotals();
                        });
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
                child: Text(AppLocalizations.of(context)!.next),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _isSharedConveyorLocation(String? locationKey) =>
      locationKey != null && _sharedConveyorLocationKeys.contains(locationKey);

  Future<void> _endPendingModuleStop(
      int module, List<ModuleStop> stops, int index) async {
    final stop = stops[index];
    if (!_isPendingModuleStop(stop)) return;
    final start = _parseTime(stop.startTime);
    if (start == null) return;

    final selectedEnd = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: TimeOfDay.now(),
      title: 'Heure fin',
    );
    if (selectedEnd == null) return;

    final validation = _validateSingleStop(
      start,
      selectedEnd,
      StopCategory(label: stop.category, types: const []),
      stop.nature,
      stop.location,
      stop.detail,
    );
    if (validation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validation), backgroundColor: AppColors.error),
        );
      }
      return;
    }

    final durationMinutes = _durationMinutesInCycle(start, selectedEnd);
    setState(() {
      stop.endTime =
          '${selectedEnd.hour.toString().padLeft(2, '0')}:${selectedEnd.minute.toString().padLeft(2, '0')}';
      stop.duration =
          '${durationMinutes ~/ 60}h ${(durationMinutes % 60).toString().padLeft(2, '0')}';
      if (module == 1) {
        module1Stops[index] = stop;
      } else {
        module2Stops[index] = stop;
      }
      _calculateTotals();
    });
  }

  String? _validateSingleStop(
    TimeOfDay startTime,
    TimeOfDay? endTime,
    StopCategory? selectedCategory,
    String? selectedNature,
    String? selectedLocation,
    String stopDetail,
  ) {
    if (selectedCategory == null) {
      return "La catégorie d'arrêt est obligatoire.";
    }
    if (selectedNature == null || selectedNature.isEmpty) {
      return "Le type d'arrêt est obligatoire.";
    }
    if (_tnbStopTypeRequiresLocation(selectedNature) &&
        (selectedLocation == null || selectedLocation.isEmpty)) {
      return "Le lieu d'arrêt est obligatoire.";
    }
    if (_tnbStopTypeRequiresDetail(selectedNature) &&
        stopDetail.trim().isEmpty) {
      return "Le détail d'arrêt est obligatoire.";
    }
    if (endTime == null) {
      return null;
    }
    final durationMinutes = _durationMinutesInCycle(startTime, endTime);
    if (durationMinutes <= 0 || durationMinutes > totalPeriodMinutes) {
      return "L'arrêt doit rester dans la fenêtre 22:30 → 22:30 (24h max).";
    }
    return null;
  }

  List<String> _collectVerificationErrors() {
    final errors = <String>[];
    void validateModule(int module, List<ModuleStop> stops) {
      for (var i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final start = _parseTime(stop.startTime);
        final end = _parseTime(stop.endTime);
        if (stop.category.isEmpty || stop.nature.isEmpty) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: catégorie et type d\'arrêt obligatoires.');
        }
        if (_tnbStopTypeRequiresLocation(stop.nature) &&
            stop.location.isEmpty) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: lieu d\'arrêt obligatoire.');
        }
        if (_tnbStopTypeRequiresDetail(stop.nature) &&
            stop.detail.trim().isEmpty) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: Type et lieu d\'arrêt obligatoires.');
        }
        if (start == null) {
          errors.add(
              'Module $module - Arrêt ${i + 1}: heure de début obligatoire.');
          continue;
        }
        if (end != null) {
          final durationMinutes = _durationMinutesInCycle(start, end);
          if (durationMinutes <= 0 || durationMinutes > totalPeriodMinutes) {
            errors.add(
                'Module $module - Arrêt ${i + 1}: plage horaire invalide.');
          }
        }
      }
    }

    validateModule(1, module1Stops);
    validateModule(2, module2Stops);
    return errors;
  }

  TimeOfDay? _parseTime(String value) {
    if (!value.contains(':')) return null;
    final split = value.split(':');
    if (split.length != 2) return null;
    final hour = int.tryParse(split[0]);
    final minute = int.tryParse(split[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Widget _syntheseCard(String title, int operating, int downtime) {
    return OCPCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      const Divider(),
      _row("Fonctionnement", formatMinutesToHoursMinutes(operating),
          color: AppColors.primary),
      _row("Arrêts", formatMinutesToHoursMinutes(downtime),
          color: AppColors.error),
    ]));
  }

  Widget _row(String l, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 2,
          child: Text(l),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            v,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.end,
          ),
        ),
      ]));

  bool _isPendingModuleStop(ModuleStop stop) {
    final end = stop.endTime.trim().toLowerCase();
    return end.isEmpty || end == 'pending';
  }

  String _formatModuleStopHeadline(ModuleStop stop, int index) {
    final segments = <String>[
      stop.nature.isNotEmpty ? stop.nature : '-',
      if (_tnbStopTypeRequiresDetail(stop.nature) && stop.detail.isNotEmpty)
        stop.detail,
      if (_tnbStopTypeRequiresLocation(stop.nature) && stop.location.isNotEmpty)
        stop.location,
    ];
    return '$index • ${segments.join(' - ')}';
  }

  String _formatModuleStopTimeline(ModuleStop stop) {
    final start = stop.startTime.isNotEmpty ? stop.startTime : '--:--';
    final end = stop.endTime.isNotEmpty ? stop.endTime : '--:--';
    final duration = formatMinutesToHoursMinutes(parseDurationToMinutes(
        stop.duration.isNotEmpty ? stop.duration : '$start - $end'));
    return 'From $start to $end ($duration)';
  }

  // --- Step 3: Stock ---
  Widget _buildStepStock() {
    return Column(children: [
      ...stockEntries.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            title: Text(
                "${posteToString(e.value.poste)} - ${parkToString(e.value.park)}"),
            subtitle:
                Text("${stockTypeToString(e.value.type)}: ${e.value.quantity}"),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () {
                  setState(() => stockEntries.removeAt(e.key));
                }),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: "Ajouter Stock",
          icon: Icons.add,
          isSecondary: true,
          onPressed:
              _availableStockPostes().isEmpty ? null : _showAddStockDialog)
    ]);
  }

  Set<Poste> _usedStockPostes() {
    return stockEntries.map((entry) => entry.poste).whereType<Poste>().toSet();
  }

  List<Poste> _availableStockPostes() {
    final usedPostes = _usedStockPostes();
    return Poste.values.where((poste) => !usedPostes.contains(poste)).toList();
  }

  void _showAddStockDialog() {
    final availablePostes = _availableStockPostes();
    if (availablePostes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Vous ne pouvez ajouter que 3 stocks (un seul par poste).")));
      return;
    }
    Poste? poste;
    Park? park;
    StockType? type;
    String qty = '';
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (c, setDs) => AlertDialog(
                  title: Text(AppLocalizations.of(context)!.addStock),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    DropdownButtonFormField<Poste>(
                        hint: Text(AppLocalizations.of(context)!.poste),
                        items: availablePostes
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(posteToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => poste = v)),
                    DropdownButtonFormField<Park>(
                        hint: Text(AppLocalizations.of(context)!.parkLabel),
                        items: Park.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(parkToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => park = v)),
                    DropdownButtonFormField<StockType>(
                        hint: Text(AppLocalizations.of(context)!.type),
                        items: StockType.values
                            .map((p) => DropdownMenuItem(
                                value: p, child: Text(stockTypeToString(p))))
                            .toList(),
                        onChanged: (v) => setDs(() => type = v)),
                    TextField(
                        decoration:
                            const InputDecoration(labelText: "Quantité"),
                        onChanged: (v) => qty = v),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppLocalizations.of(context)!.cancel)),
                    ElevatedButton(
                        onPressed: (poste != null &&
                                park != null &&
                                type != null)
                            ? () {
                                if (stockEntries
                                    .any((entry) => entry.poste == poste)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Ce poste a déjà un stock.")));
                                  return;
                                }
                                setState(() => stockEntries.add(DailyStockEntry(
                                    id: const Uuid().v4(),
                                    poste: poste,
                                    park: park,
                                    type: type,
                                    quantity: qty)));
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(AppLocalizations.of(context)!.add))
                  ],
                )));
  }

  // --- Step 4: Verification ---
  Widget _buildStepVerification() {
    final errors = _collectVerificationErrors();
    return Column(children: [
      Icon(errors.isEmpty ? Icons.check_circle_outline : Icons.error_outline,
          size: 64,
          color: errors.isEmpty ? AppColors.success : AppColors.error),
      const SizedBox(height: 16),
      const Text("Récapitulatif",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      if (errors.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...errors.map((e) => Align(
            alignment: Alignment.centerLeft,
            child:
                Text('• $e', style: const TextStyle(color: AppColors.error)))),
      ],
      const SizedBox(height: 24),
      _row("Date",
          "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
      const Divider(),

      // Details Arrêts M1
      if (module1Stops.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Arrêts M1",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...module1Stops.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_formatModuleStopHeadline(entry.value, entry.key + 1)}\n'
                  '    ${_formatModuleStopTimeline(entry.value)}',
                ),
              ),
            )),
        ...module1Stops
            .asMap()
            .entries
            .where((e) => _isPendingModuleStop(e.value))
            .map(
              (e) => Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      _endPendingModuleStop(1, module1Stops, e.key),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: Text('Terminer M1 #${e.key + 1}'),
                ),
              ),
            ),
        const Divider(),
      ],

      // Details Arrêts M2
      if (module2Stops.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Arrêts M2",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...module2Stops.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_formatModuleStopHeadline(entry.value, entry.key + 1)}\n'
                  '    ${_formatModuleStopTimeline(entry.value)}',
                ),
              ),
            )),
        ...module2Stops
            .asMap()
            .entries
            .where((e) => _isPendingModuleStop(e.value))
            .map(
              (e) => Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      _endPendingModuleStop(2, module2Stops, e.key),
                  icon: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: Text('Terminer M2 #${e.key + 1}'),
                ),
              ),
            ),
        const Divider(),
      ],

      _syntheseCard(
          "Synthèse Module 1", module1OperatingTime, module1TotalDowntime),
      const SizedBox(height: 16),
      _syntheseCard(
          "Synthèse Module 2", module2OperatingTime, module2TotalDowntime),
      const Divider(),

      // Details Stock
      if (stockEntries.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("Détails Stock",
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        ...stockEntries.map((e) => _row(
            "${posteToString(e.poste)} - ${parkToString(e.park)}",
            "${stockTypeToString(e.type)}: ${e.quantity}")),
        const Divider(),
      ],
    ]);
  }

  Future<void> _saveReport() async {
    final verificationErrors = _collectVerificationErrors();
    if (verificationErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Corrigez les erreurs de vérification avant de sauvegarder.'),
          backgroundColor: AppColors.error));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final report = Report(
        id: widget.initialReport?.id,
        description:
            'Daily TSUD - ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
        date: _selectedDate,
        group: 'Daily',
        type: 'daily TSUD',
        additionalData: {
          'module1Stops': module1Stops
              .map((s) => {
                    'id': s.id,
                    'category': s.category,
                    'duration': s.duration,
                    'nature': s.nature,
                    'location': s.location,
                    'detail': s.detail,
                    'stopType': s.stopType,
                    'stopLocation': s.stopLocation,
                    'startTime': s.startTime,
                    'endTime': s.endTime,
                    'Catégorie': s.category,
                    'CarryOver': false,
                  })
              .toList(),
          'module2Stops': module2Stops
              .map((s) => {
                    'id': s.id,
                    'category': s.category,
                    'duration': s.duration,
                    'nature': s.nature,
                    'location': s.location,
                    'detail': s.detail,
                    'stopType': s.stopType,
                    'stopLocation': s.stopLocation,
                    'startTime': s.startTime,
                    'endTime': s.endTime,
                    'Catégorie': s.category,
                    'CarryOver': false,
                  })
              .toList(),
          'T H.A1': module1TotalDowntime,
          'T H.M1': module1OperatingTime,
          'T H.A2': module2TotalDowntime,
          'T H.M2': module2OperatingTime,
          'stock': stockEntries
              .map((e) => {
                    'id': e.id,
                    'poste': e.poste?.index,
                    'park': e.park?.index,
                    'type': e.type?.index,
                    'quantity': e.quantity
                  })
              .toList(),
        },
      );

      if (widget.isEditing && widget.onSave != null) {
        widget.onSave!(report);
      } else {
        await _reportRepository.insertReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Succès'), backgroundColor: AppColors.success));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
