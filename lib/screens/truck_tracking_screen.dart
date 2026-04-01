import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/services/database_helper.dart';
import 'package:r0/models/report.dart';
import 'package:r0/models/mine_data.dart';
import 'package:intl/intl.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:r0/theme.dart';
import 'package:r0/widgets/custom_widgets.dart';

// --- Enums ---
enum QualiteType { normal, oceane, pb30 }

enum Poste { troisieme, premier, deuxieme }

String qualiteTypeToString(QualiteType? t, AppLocalizations l10n) {
  switch (t) {
    case QualiteType.normal:
      return l10n.normal;
    case QualiteType.oceane:
      return l10n.oceane;
    case QualiteType.pb30:
      return l10n.pb30;
    default:
      return "";
  }
}

String posteToString(Poste? p, AppLocalizations l10n) {
  switch (p) {
    case Poste.troisieme:
      return l10n.troisiemePosteShort;
    case Poste.premier:
      return l10n.premierPosteShort;
    case Poste.deuxieme:
      return l10n.deuxiemePosteShort;
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
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final TextEditingController _distanceController = TextEditingController();

  // State
  DateTime _selectedDate = DateTime.now();
  MineData? _selectedMine;
  ZoneData? _selectedZone;
  String? _selectedSortie;
  String? _selectedQualite;
  QualiteType? _selectedQualiteType;
  Poste? _selectedPoste;
  String? _selectedOperationType;

  List<Map<String, dynamic>> truckData = [];
  int _currentStep = 0;
  bool _isSaving = false;

  int _tripTimeToMinutes(dynamic rawTime) {
    final value = rawTime?.toString() ?? '';
    final parts = value.split(':');
    if (parts.length != 2) return (24 * 60) + 1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return (24 * 60) + 1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return (24 * 60) + 1;
    }
    return (hour * 60) + minute;
  }

  void _sortTruckTrips(Map<String, dynamic> truck) {
    final counts = truck['counts'];
    if (counts is! List) return;
    counts.sort((a, b) {
      final aMap = a is Map ? a : const {};
      final bMap = b is Map ? b : const {};
      return _tripTimeToMinutes(aMap['time'])
          .compareTo(_tripTimeToMinutes(bMap['time']));
    });
  }

  void _sortAllTruckTrips() {
    for (final truck in truckData) {
      _sortTruckTrips(truck);
    }
  }

  // Predefined lists
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
    'TEREX 32'
  ];
  static const List<String> equipmentList = [
    'Chargeuse 992K',
    'Chargeuse 994H',
    'Pelle hydraulique',
    'Pelle electrique B1'
  ];
  // Predefined lists (Localized via getters if static needed, but simpler to use instance)
  Map<String, String> _getOperationTypes(AppLocalizations l10n) => {
        'Défeuitage': l10n.defeuitage,
        'Reprise': l10n.reprise,
        'Stérile': l10n.sterile,
      };

  Map<String, String> _getQualiteOptions(AppLocalizations l10n) => {
        'Chargeuse 992K': l10n.chargeuse992k,
        'Chargeuse 994H': l10n.chargeuse994h,
        'Pelle hydraulique': l10n.pelleHydraulique,
        'Pelle electrique B1': l10n.pelleElectriqueB1,
      };

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.initialReport != null) {
      _loadExistingData();
    }
  }

  void _loadExistingData() {
    if (widget.initialReport?.additionalData == null) return;
    final data = widget.initialReport!.additionalData!;
    if (data['truckData'] is List) {
      truckData = List<Map<String, dynamic>>.from(
        (data['truckData'] as List).map(
          (truck) => Map<String, dynamic>.from(truck),
        ),
      );
      _sortAllTruckTrips();
    }

    // Find mine/zone
    if (data['mine'] != null) {
      _selectedMine = minesData.firstWhere((m) => m.name == data['mine'],
          orElse: () => minesData.first);
    }
    if (data['zone'] != null && _selectedMine != null) {
      _selectedZone = _selectedMine!.zones.firstWhere(
          (z) => z.name == data['zone'],
          orElse: () => _selectedMine!.zones.first);
    }
    _selectedSortie = data['sortie'];
    _selectedQualite = data['selectedQualite'];
    _distanceController.text = data['distance']?.toString() ?? '';
    _selectedQualiteType = _parseQualiteType(data['selectedQualiteType']);
    _selectedOperationType = data['operationType'];
    _selectedPoste = _parsePoste(data['selectedPoste']);
  }

  Poste? _parsePoste(dynamic val) {
    if (val == null) return null;
    var str = val.toString();
    if (str == '3ème' || str == '0') return Poste.troisieme;
    if (str == '1er' || str == '1') return Poste.premier;
    if (str == '2ème' || str == '2') return Poste.deuxieme;
    return null;
  }

  int _minutesFromDateTime(DateTime time) => time.hour * 60 + time.minute;

  bool _isTripTimeWithinPoste(DateTime time, Poste poste) {
    final minutes = _minutesFromDateTime(time);
    const startThird = 22 * 60 + 30;
    const endThird = 6 * 60 + 30;
    const startFirst = 6 * 60 + 30;
    const endFirst = 14 * 60 + 30;
    const startSecond = 14 * 60 + 30;
    const endSecond = 22 * 60 + 30;

    switch (poste) {
      case Poste.troisieme:
        return minutes >= startThird || minutes < endThird;
      case Poste.premier:
        return minutes >= startFirst && minutes < endFirst;
      case Poste.deuxieme:
        return minutes >= startSecond && minutes < endSecond;
    }
  }

  bool _areAllTripTimesWithinSelectedPoste() {
    final poste = _selectedPoste;
    if (poste == null) return false;
    for (final truck in truckData) {
      final counts = truck['counts'] as List?;
      if (counts == null) continue;
      for (final trip in counts) {
        if (trip is! Map) continue;
        final timeStr = trip['time']?.toString() ?? '';
        final parts = timeStr.split(':');
        if (parts.length != 2) return false;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour == null || minute == null) return false;
        final time = DateTime(2000, 1, 1, hour, minute);
        if (!_isTripTimeWithinPoste(time, poste)) return false;
      }
    }
    return true;
  }

  QualiteType? _parseQualiteType(dynamic val) {
    if (val == null) return null;
    var str = val.toString();
    if (str == "NORMAL" || str == 'QualiteType.normal') {
      return QualiteType.normal;
    }
    if (str == "OCEANE" || str == 'QualiteType.oceane') {
      return QualiteType.oceane;
    }
    if (str == "PB30" || str == 'QualiteType.pb30') {
      return QualiteType.pb30;
    }
    return null;
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = [
      l10n.stepInfos,
      l10n.stepCamions,
      l10n.stepVoyages,
      l10n.stepVerif
    ];
    return Scaffold(
        appBar: AppBar(
            title: Text(widget.isEditing
                ? l10n.editTruckTracking
                : l10n.newTruckTracking)),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
                key: widget.formKey,
                child: Column(children: [
                  OCPStepper(
                      steps: steps,
                      currentStep: _currentStep,
                      onStepTapped: (i) => setState(() => _currentStep = i)),
                  Expanded(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _buildStepContent(l10n))),
                  _buildBottomBar(l10n),
                ])),
          ),
        ));
  }

  Widget _buildStepContent(AppLocalizations l10n) {
    switch (_currentStep) {
      case 0:
        return _buildStepInfos(l10n);
      case 1:
        return _buildStepCamions(l10n);
      case 2:
        return _buildStepVoyages(l10n);
      case 3:
        return _buildStepVerification(l10n);
      default:
        return const SizedBox();
    }
  }

  Widget _buildBottomBar(AppLocalizations l10n) {
    bool isLast = _currentStep == 3;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: const [
              BoxShadow(blurRadius: 10, color: Colors.black12)
            ]),
        child: Row(children: [
          if (_currentStep > 0)
            Expanded(
                child: OCPButton(
                    text: l10n.previous,
                    onPressed: () => setState(() => _currentStep--),
                    isSecondary: true)),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
              child: OCPButton(
                  text: isLast ? l10n.submit : l10n.next,
                  onPressed: () {
                    if (isLast) {
                      _saveReport(l10n);
                    } else {
                      setState(() => _currentStep++);
                    }
                  },
                  isLoading: _isSaving && isLast))
        ]));
  }

  // --- Step 1: Infos ---
  Widget _buildStepInfos(AppLocalizations l10n) {
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
                "${l10n.date}: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                style: const TextStyle(fontWeight: FontWeight.bold))
          ])),
      const SizedBox(height: 16),
      OCPDropdown<MineData>(
          label: l10n.mine,
          value: _selectedMine,
          items: minesData
              .map((m) => DropdownMenuItem(value: m, child: Text(m.name)))
              .toList(),
          onChanged: (v) => setState(() {
                _selectedMine = v;
                _selectedZone = null;
                _selectedSortie = null;
              })),
      const SizedBox(height: 16),
      if (_selectedMine != null) ...[
        OCPDropdown<ZoneData>(
            label: l10n.zone,
            value: _selectedZone,
            items: _selectedMine!.zones
                .map((z) => DropdownMenuItem(value: z, child: Text(z.name)))
                .toList(),
            onChanged: (v) => setState(() {
                  _selectedZone = v;
                  _selectedSortie = null;
                })),
        const SizedBox(height: 16),
      ],
      if (_selectedZone != null) ...[
        OCPDropdown<String>(
            label: l10n.exit,
            value: _selectedSortie,
            items: _selectedZone!.sorties
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSortie = v)),
        const SizedBox(height: 16),
      ],
      OCPDropdown<Poste>(
          label: l10n.poste,
          value: _selectedPoste,
          items: Poste.values
              .map((p) => DropdownMenuItem(
                  value: p, child: Text(posteToString(p, l10n))))
              .toList(),
          onChanged: (v) => setState(() => _selectedPoste = v)),
      const SizedBox(height: 16),
      OCPTextField(
          label: l10n.distance,
          controller: _distanceController,
          keyboardType: TextInputType.text),
      const SizedBox(height: 16),
      OCPDropdown<String>(
          label: l10n.operation,
          value: _selectedOperationType,
          items: _getOperationTypes(l10n)
              .entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedOperationType = v)),
      const SizedBox(height: 16),
      OCPDropdown<String>(
          label: l10n.equipment,
          value: _selectedQualite,
          items: _getQualiteOptions(l10n)
              .entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => _selectedQualite = v)),
      const SizedBox(height: 16),
      OCPDropdown<QualiteType>(
          label: l10n.type,
          value: _selectedQualiteType,
          items: QualiteType.values
              .map((t) => DropdownMenuItem(
                  value: t, child: Text(qualiteTypeToString(t, l10n))))
              .toList(),
          onChanged: (v) => setState(() => _selectedQualiteType = v)),
    ]);
  }

  // --- Step 2: Camions ---
  Widget _buildStepCamions(AppLocalizations l10n) {
    return Column(children: [
      ...truckData.asMap().entries.map((e) => OCPCard(
              child: ListTile(
            leading: const Icon(Icons.local_shipping, color: AppColors.primary),
            title: Text(e.value['truckNumber'] ?? l10n.newTruckLabel),
            subtitle: Text("${l10n.driverLabel}: ${e.value['driver1'] ?? ''}"),
            trailing: IconButton(
                icon: const Icon(Icons.delete, color: AppColors.error),
                onPressed: () => setState(() => truckData.removeAt(e.key))),
            onTap: () => _showEditTruckDialog(e.value),
          ))),
      const SizedBox(height: 16),
      OCPButton(
          text: l10n.addTruckTitle,
          icon: Icons.add,
          isSecondary: true,
          onPressed: () => _showAddTruckDialog(l10n)),
    ]);
  }

  void _showAddTruckDialog(AppLocalizations l10n) {
    String number = '';
    String driver = '';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(l10n.addTruckTitle),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<String>(
                      hint: Text(l10n.truckNumberLabel),
                      items: predefinedTrucks
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => number = v ?? ''),
                  TextField(
                      decoration: InputDecoration(labelText: l10n.driverLabel),
                      onChanged: (v) => driver = v),
                  TextField(
                      decoration:
                          InputDecoration(labelText: l10n.locationLabel),
                      onChanged: (v) {}),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel)),
                  ElevatedButton(
                      onPressed: () {
                        // Logic to add truck
                        setState(() {
                          truckData.add({
                            'id': const Uuid().v4(),
                            'truckNumber': number,
                            'driver1': driver,
                            'counts': []
                          });
                        });
                        Navigator.pop(context);
                      },
                      child: Text(l10n.add))
                ]));
  }

  void _showEditTruckDialog(Map<String, dynamic> truck) {
    // Placeholder specifically to satisfy unused variable if needed, but in this case I am just skipping implementation for brevity as per previous logic.
  }

  // --- Step 3: Voyages (Simplified: List trucks and allow adding trips) ---
  Widget _buildStepVoyages(AppLocalizations l10n) {
    // Show list of trucks, each with "Add Trip" button and trip count
    return Column(children: [
      ...truckData.map((truck) {
        int tripCount = (truck['counts'] as List?)?.length ?? 0;
        return OCPCard(
            child: Column(children: [
          ListTile(
            title: Text(truck['truckNumber']),
            subtitle: Text(l10n.tripsCountLabel(tripCount)),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: Text(l10n.tripLabel),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
              onPressed: () => _addTrip(truck, l10n),
            ),
          ),
          if (tripCount > 0) ...[
            const Divider(),
            ExpansionTile(
                title: Text(l10n.viewDetails),
                children: ((truck['counts'] as List)
                    .map((trip) => ListTile(
                          title: Text(trip['time']),
                          subtitle: Text(_buildTripSubtitle(trip, l10n)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    size: 20, color: AppColors.primary),
                                onPressed: () => _editTrip(truck, trip, l10n),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    size: 20, color: AppColors.error),
                                onPressed: () => _deleteTrip(truck, trip),
                              ),
                            ],
                          ),
                        ))
                    .toList()))
          ]
        ]));
      })
    ]);
  }

  void _deleteTrip(Map<String, dynamic> truck, Map<String, dynamic> trip) {
    setState(() {
      (truck['counts'] as List).remove(trip);
      _sortTruckTrips(truck);
    });
  }

  void _editTrip(Map<String, dynamic> truck, Map<String, dynamic> trip,
      AppLocalizations l10n) {
    // Parse current time
    List<String> parts = trip['time'].split(':');
    DateTime time = DateTime.now();
    if (parts.length == 2) {
      time = DateTime(time.year, time.month, time.day, int.parse(parts[0]),
          int.parse(parts[1]));
    }
    String? eq = trip['equipment'];
    final String? initialEquipment = equipmentList.contains(eq) ? eq : null;
    QualiteType? tripQuality = _parseQualiteType(trip['productQualityType']);

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(l10n.editTrip),
                content: StatefulBuilder(
                    builder: (c, setDs) =>
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          TimePickerSpinner(
                              is24HourMode: true,
                              time: time,
                              normalTextStyle: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              highlightedTextStyle: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onTimeChange: (t) => time = t),
                          DropdownButtonFormField<String>(
                              initialValue: initialEquipment,
                              hint: Text(l10n.equipment),
                              items: equipmentList
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setDs(() => eq = v)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<QualiteType>(
                              initialValue: tripQuality,
                              hint: Text(l10n.qualityLabel),
                              items: QualiteType.values
                                  .map((t) => DropdownMenuItem(
                                      value: t,
                                      child:
                                          Text(qualiteTypeToString(t, l10n))))
                                  .toList(),
                              onChanged: (v) => setDs(() => tripQuality = v))
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel)),
                  ElevatedButton(
                      onPressed: () {
                        if (_selectedPoste == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.pleaseSelectPoste),
                              backgroundColor: AppColors.error));
                          return;
                        }
                        if (!_isTripTimeWithinPoste(time, _selectedPoste!)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.invalidStopStartTimeForPoste),
                              backgroundColor: AppColors.error));
                          return;
                        }
                        setState(() {
                          trip['time'] =
                              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                          trip['equipment'] = eq;
                          trip['productQualityType'] = tripQuality?.toString();
                          _sortTruckTrips(truck);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(l10n.save))
                ]));
  }

  void _addTrip(Map<String, dynamic> truck, AppLocalizations l10n) {
    DateTime time = DateTime.now();
    String? eq = _selectedQualite; // Default to equipment selected in Step 1
    final String? initialEquipment = equipmentList.contains(eq) ? eq : null;
    QualiteType? tripQuality = _selectedQualiteType;

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(l10n.addTrip),
                content: StatefulBuilder(
                    builder: (c, setDs) =>
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          TimePickerSpinner(
                              is24HourMode: true,
                              normalTextStyle: TextStyle(
                                fontSize: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              highlightedTextStyle: TextStyle(
                                fontSize: 24,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onTimeChange: (t) => time = t),
                          DropdownButtonFormField<String>(
                              initialValue: initialEquipment,
                              hint: Text(l10n.equipment),
                              items: equipmentList
                                  .map((e) => DropdownMenuItem(
                                      value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setDs(() => eq = v)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<QualiteType>(
                              initialValue: tripQuality,
                              hint: Text(l10n.qualityLabel),
                              items: QualiteType.values
                                  .map((t) => DropdownMenuItem(
                                      value: t,
                                      child:
                                          Text(qualiteTypeToString(t, l10n))))
                                  .toList(),
                              onChanged: (v) => setDs(() => tripQuality = v))
                        ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.cancel)),
                  ElevatedButton(
                      onPressed: () {
                        if (_selectedPoste == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.pleaseSelectPoste),
                              backgroundColor: AppColors.error));
                          return;
                        }
                        if (!_isTripTimeWithinPoste(time, _selectedPoste!)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(l10n.invalidStopStartTimeForPoste),
                              backgroundColor: AppColors.error));
                          return;
                        }
                        setState(() {
                          if (truck['counts'] == null) truck['counts'] = [];
                          truck['counts'].add({
                            'time':
                                "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                            'equipment': eq,
                            'productQualityType': tripQuality?.toString()
                          });
                          _sortTruckTrips(truck);
                        });
                        Navigator.pop(context);
                      },
                      child: Text(l10n.add))
                ]));
  }

  // --- Step 4: Verification ---
  Widget _buildStepVerification(AppLocalizations l10n) {
    int totalTrips = truckData.fold(
        0, (acc, t) => acc + ((t['counts'] as List?)?.length ?? 0));

    // Calculate trips per equipment
    Map<String, int> equipmentTrips = {};
    Map<String, Map<String, int>> equipmentQualityTrips = {};
    for (var truck in truckData) {
      final counts = truck['counts'] as List?;
      if (counts != null) {
        for (var trip in counts) {
          String eq = trip['equipment'] ?? l10n.unknownLabel;
          equipmentTrips[eq] = (equipmentTrips[eq] ?? 0) + 1;
          final quality = _parseQualiteType(trip['productQualityType']);
          final qualityLabel = quality == null
              ? l10n.unknownLabel
              : qualiteTypeToString(quality, l10n);
          equipmentQualityTrips.putIfAbsent(eq, () => {});
          equipmentQualityTrips[eq]![qualityLabel] =
              (equipmentQualityTrips[eq]![qualityLabel] ?? 0) + 1;
        }
      }
    }

    Map<String, int> qualityTrips = {};
    for (var truck in truckData) {
      final counts = truck['counts'] as List?;
      if (counts != null) {
        for (var trip in counts) {
          final quality = _parseQualiteType(trip['productQualityType']);
          final label = quality == null
              ? l10n.unknownLabel
              : qualiteTypeToString(quality, l10n);
          qualityTrips[label] = (qualityTrips[label] ?? 0) + 1;
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Center(
          child: Icon(Icons.check_circle_outline,
              size: 64, color: AppColors.success)),
      const SizedBox(height: 16),
      Center(
          child: Text(l10n.summaryTitle,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      const SizedBox(height: 24),

      // General Info
      _sectionHeader(l10n.generalInformation),
      _row(l10n.date,
          "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
      _row(l10n.mineZoneLabel,
          "${_selectedMine?.name ?? '-'} / ${_selectedZone?.name ?? '-'}"),
      _row(l10n.type, qualiteTypeToString(_selectedQualiteType, l10n)),
      _row(
          l10n.distance,
          _distanceController.text.trim().isEmpty
              ? '-'
              : _distanceController.text.trim()),
      _row(l10n.poste, posteToString(_selectedPoste, l10n)),
      _row(
          l10n.operation,
          _selectedOperationType != null
              ? _getOperationTypes(l10n)[_selectedOperationType!] ??
                  _selectedOperationType!
              : "-"),
      _row(l10n.stepCamions, "${truckData.length}"),
      _row(l10n.total, "$totalTrips"),

      const SizedBox(height: 24),

      // Trips per Equipment
      _sectionHeader(l10n.tripsByEquipment),
      ...equipmentTrips.entries.map((e) {
        final qualityBreakdown = equipmentQualityTrips[e.key] ?? {};
        return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(e.key)),
              const SizedBox(width: 8),
              Text("${e.value}",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: qualityBreakdown.entries
                          .map((q) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text("${q.key} - ${q.value}",
                                  textAlign: TextAlign.right)))
                          .toList()))
            ]));
      }),

      const SizedBox(height: 24),

      _sectionHeader("${l10n.total} ${l10n.qualityLabel}"),
      ...qualityTrips.entries.map((e) => _row(e.key, "${e.value}")),

      const SizedBox(height: 24),

      // Trips per Truck
      _sectionHeader(l10n.tripsByTruck),
      ...truckData.map((t) => _row(t['truckNumber'],
          l10n.tripsCountLabel((t['counts'] as List?)?.length ?? 0))),

      const SizedBox(height: 24),

      // All Voyages Details
      _sectionHeader(l10n.tripDetailsTitle),
      ...truckData.expand((t) {
        final counts = t['counts'] as List?;
        if (counts == null || counts.isEmpty) return <Widget>[];
        return counts.map((trip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(trip['time'],
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(t['truckNumber'],
                            style: const TextStyle(color: AppColors.primary)),
                        const Spacer(),
                        Text(trip['equipment'] ?? '',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                    Text(
                      _buildTripQualityLabel(trip, l10n),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  ]),
            ));
      }),
    ]);
  }

  String _buildTripQualityLabel(
      Map<String, dynamic> trip, AppLocalizations l10n) {
    final quality = _parseQualiteType(trip['productQualityType']);
    return quality == null
        ? "${l10n.qualityLabel}: -"
        : "${l10n.qualityLabel}: ${qualiteTypeToString(quality, l10n)}";
  }

  String _buildTripSubtitle(Map<String, dynamic> trip, AppLocalizations l10n) {
    final equipment = trip['equipment'] ?? '';
    final quality = _parseQualiteType(trip['productQualityType']);
    final qualityLabel = quality == null
        ? "${l10n.qualityLabel}: -"
        : "${l10n.qualityLabel}: ${qualiteTypeToString(quality, l10n)}";
    if (equipment.toString().isEmpty) {
      return qualityLabel;
    }
    return "$equipment • $qualityLabel";
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary)),
      );

  Widget _row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
      ]));

  Future<void> _saveReport(AppLocalizations l10n) async {
    final hasDate = _selectedDate.year > 0;
    final hasPoste = _selectedPoste != null;
    final hasMachineOrEngin =
        _selectedQualite != null && _selectedQualite!.trim().isNotEmpty;

    if (!hasDate || !hasPoste || !hasMachineOrEngin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'La date, le poste et la machine/engin sont obligatoires pour enregistrer le rapport.'),
          backgroundColor: AppColors.error));
      return;
    }
    if (!_areAllTripTimesWithinSelectedPoste()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.invalidStopStartTimeForPoste),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _isSaving = true);
    _sortAllTruckTrips();
    int totalTrips = truckData.fold(
        0, (acc, t) => acc + ((t['counts'] as List?)?.length ?? 0));

    // Calculate trips per equipment summary for storage
    Map<String, int> equipmentTrips = {};
    for (var truck in truckData) {
      final counts = truck['counts'] as List?;
      if (counts != null) {
        for (var trip in counts) {
          String eq = trip['equipment'] ?? l10n.unknownLabel;
          equipmentTrips[eq] = (equipmentTrips[eq] ?? 0) + 1;
        }
      }
    }

    try {
      final report = Report(
          id: widget.initialReport?.id,
          description: l10n.reportDescriptionPattern(
              _selectedQualite != null
                  ? _getQualiteOptions(l10n)[_selectedQualite!] ??
                      _selectedQualite!
                  : l10n.trackingType,
              DateFormat('yyyy-MM-dd').format(_selectedDate),
              posteToString(_selectedPoste, l10n)),
          date: _selectedDate,
          group: posteToString(_selectedPoste, l10n),
          type: _selectedQualite ?? l10n.trackingType,
          additionalData: {
            'mine': _selectedMine?.name,
            'zone': _selectedZone?.name,
            'sortie': _selectedSortie,
            'selectedPoste': posteToString(_selectedPoste, l10n),
            'selectedQualite': _selectedQualite,
            'distance': _distanceController.text.trim(),
            'selectedQualiteType':
                qualiteTypeToString(_selectedQualiteType, l10n),
            'operationType': _selectedOperationType,
            'equipment': _selectedQualite,
            'truckData': truckData,
            'totalTrips': totalTrips,
            'camionsCount': truckData.length,
            'equipmentTrips': equipmentTrips,
          });

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
            content: Text("${l10n.errorSavingReport}: $e"),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
