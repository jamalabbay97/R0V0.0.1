import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/models/report.dart';
import 'package:r0/models/mine_data.dart';
import 'package:r0/services/database_helper.dart';
import 'package:intl/intl.dart';
import 'package:flutter_time_picker_spinner/flutter_time_picker_spinner.dart';
import 'package:uuid/uuid.dart';

/// ReportsScreen displays all saved reports with filtering capabilities.
///
/// Features:
/// - View all reports with details
/// - Filter reports by poste (3ème, 1er, 2ème)
/// - Edit and delete reports
/// - View detailed report information
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Report> _reports = [];
  List<Report> _filteredReports = [];
  bool _isLoading = true;
  String? _selectedPosteFilter;

  // Selection state management
  int? _selectedEquipmentIndex;
  int? _selectedStopIndex;
  int? _selectedCounterIndex;
  int? _selectedStockIndex;

  // Available postes for filtering
  List<String> _availablePostes = [
    '3ème',
    '1er',
    '2ème',
  ];

  // Predefined truck numbers
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

  // Arrêt categories for R0 reports
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

  // Add ENGINS and MACHINES data maps
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
      'BULL D9R 87',
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
      'WABCO 19',
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

  final posteOrder = const ["3ème", "1er", "2ème"];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final reports = await _databaseHelper.getReports();
      setState(() {
        _reports = reports;
        _filterReports();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.errorSavingReport)),
        );
      }
    }
  }

  void _filterReports() {
    if (_selectedPosteFilter == null) {
      _filteredReports = _reports;
    } else {
      _filteredReports = _reports.where((report) {
        final additionalData = report.additionalData;
        if (additionalData == null) return false;

        // Check for different poste field names used in different report types
        final poste = additionalData['selectedPoste'] ??
            additionalData['poste'] ??
            additionalData['posteSelected'];

        // Debug: log the poste value for debugging (only in debug mode)
        if (kDebugMode && report.type == 'Suivi Camion') {
          debugPrint(
              'Report ${report.id}: type=${report.type}, poste=$poste, filter=$_selectedPosteFilter');
        }

        return poste == _selectedPosteFilter;
      }).toList();
    }

    // Update available postes based on existing reports
    _updateAvailablePostes();
  }

  void _updateAvailablePostes() {
    final Set<String> foundPostes = <String>{};

    for (final report in _reports) {
      final additionalData = report.additionalData;
      if (additionalData != null) {
        final poste = additionalData['selectedPoste'] ??
            additionalData['poste'] ??
            additionalData['posteSelected'];
        if (poste != null && poste.isNotEmpty) {
          foundPostes.add(poste);
        }
      }
    }

    // Add default postes if not found in reports
    foundPostes.addAll(['3ème', '1er', '2ème']);

    setState(() {
      _availablePostes = foundPostes.toList()..sort();
    });
  }

  void _onPosteFilterChanged(String? newValue) {
    setState(() {
      _selectedPosteFilter = newValue;
      _filterReports();
    });
  }

  // Helper function to recalculate H.A from Arrets for R0 reports
  void _recalculateR0Hours(Map<String, dynamic> data) {
    // 1. Calculate H.A (Total Stoppage Hours)
    double totalStoppageHours = 0;
    if (data['Arrets'] is List) {
      for (var arret in data['Arrets'] as List) {
        if (arret is Map && arret['Début'] != null && arret['Fin'] != null) {
          final debut = arret['Début'].toString();
          final fin = arret['Fin'].toString();
          if (debut.isNotEmpty && fin.isNotEmpty) {
            // Parse time format HH:MM
            final startParts = debut.split(':');
            final endParts = fin.split(':');
            if (startParts.length == 2 && endParts.length == 2) {
              final startHour = int.tryParse(startParts[0]) ?? 0;
              final startMin = int.tryParse(startParts[1]) ?? 0;
              final endHour = int.tryParse(endParts[0]) ?? 0;
              final endMin = int.tryParse(endParts[1]) ?? 0;

              final startTotal = startHour * 60 + startMin;
              final endTotal = endHour * 60 + endMin;
              int diff = endTotal - startTotal;
              if (diff <= 0) diff += 24 * 60; // Handle overnight periods

              totalStoppageHours += diff / 60.0;
            }
          }
        }
      }
    }

    // 2. Calculate H.M (Working Hours)
    double totalCounterHours = 0;
    bool hasCounters = false;

    if (data['Compteurs'] is List && (data['Compteurs'] as List).isNotEmpty) {
      hasCounters = true;
      for (var compteur in data['Compteurs'] as List) {
        if (compteur is Map &&
            compteur['duree'] != null &&
            compteur['note'] != null) {
          // Note: In code 'duree' is Start and 'note' is End based on dialog usage
          final debut = compteur['duree'].toString();
          final fin = compteur['note'].toString();

          if (debut.isNotEmpty && fin.isNotEmpty) {
            // Parse time format HH:MM or similar simple format if needed
            // Assuming standard HH:MM for calculation
            final startParts = debut.split(':');
            final endParts = fin.split(':');
            if (startParts.length >= 2 && endParts.length >= 2) {
              final startHour = int.tryParse(startParts[0]) ?? 0;
              final startMin = int.tryParse(startParts[1]) ?? 0;
              final endHour = int.tryParse(endParts[0]) ?? 0;
              final endMin = int.tryParse(endParts[1]) ?? 0;

              final startTotal = startHour * 60 + startMin;
              final endTotal = endHour * 60 + endMin;
              int diff = endTotal - startTotal;
              if (diff <= 0) diff += 24 * 60; // Handle overnight periods

              totalCounterHours += diff / 60.0;
            }
          }
        }
      }
    }

    // 3. Apply Rules
    // Update H.A
    if (data['exploitation'] == null) {
      data['exploitation'] = {};
    }

    if (data['exploitation'] is Map) {
      data['exploitation']['H.A'] = totalStoppageHours.toStringAsFixed(2);

      double hm = 0.0;
      if (hasCounters) {
        // If counters exist, use counter hours capped at 8h
        hm = totalCounterHours > 8.0 ? 8.0 : totalCounterHours;
      } else {
        // If no counters, default to 8h minus stoppages
        hm = (8.0 - totalStoppageHours).clamp(0.0, 8.0);
      }

      data['exploitation']['H.M'] = hm.toStringAsFixed(2);
    }
  }

  Future<void> _deleteReport(Report report) async {
    try {
      await _databaseHelper.deleteReport(report.id!);
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.reportDeleted)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.errorDeletingReport)),
        );
      }
    }
  }

  Future<void> _editReport(Report report) async {
    if (!mounted) return;
    final context = this.context;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Close the details dialog if it's open
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    // Show the appropriate editing interface based on report type
    final typeLower = report.type.toLowerCase();

    if (typeLower == 'activity tnb') {
      await _showActivityReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'daily tsud') {
      await _showDailyReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'machine/engin arrêtés') {
      await _showMachinesEquipmentStoppedEditor(
          report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'suivi camion' ||
        typeLower.contains('chargeuse') ||
        typeLower.contains('pelle') ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('truckData'))) {
      await _showTruckTrackingEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else if (typeLower == 'r0' ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('mine') &&
            report.additionalData!.containsKey('selectedPoste'))) {
      await _showR0ReportEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    } else {
      await _showGenericEditor(report, scaffoldMessenger, l10n);
      // After editing, show the updated details
      final updated =
          _reports.firstWhere((r) => r.id == report.id, orElse: () => report);
      _showReportDetails(updated);
    }
  }

  // Activity Report Editor
  Future<void> _showActivityReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modifier R TNB',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stops Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Arrêts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStopDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['stops'] is List &&
                                    (data['stops'] as List).isNotEmpty)
                                  ...List.from(data['stops'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stop = entry.value;
                                    final isSelected =
                                        _selectedStopIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.green.withValues(alpha: 0.1),
                                        title: Text('Arrêt ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Durée: ${stop['duration'] ?? '-'}'),
                                            Text(
                                                'Nature: ${stop['nature'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.green)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStopIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier l\'arrêt',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer l\'arrêt',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun arrêt ajouté',
                                      style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Vibreurs Counters Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'C Vibr',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAddVibratorCounterDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['vibrator Counters'] is List &&
                                    (data['vibrator Counters'] as List)
                                        .isNotEmpty)
                                  ...List.from(data['vibrator Counters'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final counter = entry.value;
                                    final isSelected =
                                        _selectedCounterIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.orange
                                            .withValues(alpha: 0.1),
                                        title: Text('C.Vibr ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(counter['poste'])}'),
                                            Text(
                                                'Début: ${counter['start'] ?? '-'}'),
                                            Text(
                                                'Fin: ${counter['end'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.orange)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedCounterIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditVibratorCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le compteur',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteVibratorCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le compteur',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun compteur vibreur ajouté',
                                      style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Liaison Counters Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'C Liaison',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _showAddLiaisonCounterDialog(
                                              report,
                                              data,
                                              setDialogState,
                                              scaffoldMessenger,
                                              l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['liaison Counters'] is List &&
                                    (data['liaison Counters'] as List)
                                        .isNotEmpty)
                                  ...List.from(data['liaison Counters'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final counter = entry.value;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text('C.Liaison ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(counter['poste'])}'),
                                            Text(
                                                'Début: ${counter['start'] ?? '-'}'),
                                            Text(
                                                'Fin: ${counter['end'] ?? '-'}'),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditLiaisonCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le compteur',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteLiaisonCounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le compteur',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun compteur liaison ajouté',
                                      style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stock Entries Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'stocks',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStockEntryDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['stock'] is List &&
                                    (data['stock'] as List).isNotEmpty)
                                  ...List.from(data['stock'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stock = entry.value;
                                    final isSelected =
                                        _selectedStockIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.purple
                                            .withValues(alpha: 0.1),
                                        title: Text('Stock ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(stock['poste'])}'),
                                            Text(
                                                'Parc: ${_getParkString(stock['park'])}'),
                                            Text(
                                                'Type: ${_getStockTypeString(stock['type'])}'),
                                            Text(
                                                'Quantité: ${stock['quantity'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.purple)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStockIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Modifier l\'entrée de stock',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Supprimer l\'entrée de stock',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucune entrée de stock ajoutée',
                                      style: TextStyle(color: Colors.grey)),
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
        ),
      ),
    );
  }

  // Add Stop Dialog for Activity Report
  Future<void> _showAddStopDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    const List<String> predefinedNatures = [
      'Manque Produit',
      'Attente Saturation Silo',
      'Vidange Extraction 2',
      'Arret Mécanique sur:',
      'Dèfout Élèctrique sur:',
      'Arret d\'instalation sur:',
      'Travoux Mècanique sur:',
      'Travoux Elèctrique sur:',
      'Travoux dans l\'instalation sur:',
      'Autre:',
    ];

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = '';
    final customNatureController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter un arrêt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedNature,
                decoration: const InputDecoration(
                  labelText: 'Nature prédéfinie',
                  border: OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map((nature) => DropdownMenuItem(
                          value: nature,
                          child: Text(nature),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
                hint: const Text('Sélectionner une nature'),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: const InputDecoration(
                    labelText: 'Nature (complément)',
                    border: OutlineInputBorder(),
                    hintText: 'Maximum 20 caractères par ligne',
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['stops'] == null) {
                    updatedData['stops'] = [];
                  }
                  (updatedData['stops'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'duration': tempStopDuration,
                    'nature': finalNature,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stop Dialog for Activity Report
  Future<void> _showEditStopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final stop = (data['stops'] as List)[index];
    const List<String> predefinedNatures = [
      'Manque Produit',
      'Attente Saturation Silo',
      'Vidange Extraction 2',
      'Arret Mécanique sur:',
      'Dèfout Élèctrique sur:',
      'Arret d\'instalation sur:',
      'Travoux Mècanique sur:',
      'Travoux Elèctrique sur:',
      'Travoux dans l\'instalation sur:',
      'Autre:',
    ];

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = stop['duration'] ?? '';
    final customNatureController = TextEditingController();

    // Parse the nature to determine selected nature and custom part
    String currentNature = stop['nature'] ?? '';
    for (String nature in predefinedNatures) {
      if (currentNature.startsWith(nature)) {
        selectedNature = nature;
        if (nature.endsWith(':')) {
          customNature = currentNature.substring(nature.length).trim();
          customNatureController.text = customNature;
        }
        break;
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier l\'arrêt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedNature,
                decoration: const InputDecoration(
                  labelText: 'Nature prédéfinie',
                  border: OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map((nature) => DropdownMenuItem(
                          value: nature,
                          child: Text(nature),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
                hint: const Text('Sélectionner une nature'),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: tempStopDuration),
                onChanged: (value) => setState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: const InputDecoration(
                    labelText: 'Nature (complément)',
                    border: OutlineInputBorder(),
                    hintText: 'Maximum 20 caractères par ligne',
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['stops'] as List)[index] = {
                    'id': stop['id'],
                    'duration': tempStopDuration,
                    'nature': finalNature,
                  };

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Stop Dialog for Activity Report
  Future<void> _showDeleteStopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'arrêt'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet arrêt ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['stops'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Add Vibreur Counter Dialog for Activity Report
  Future<void> _showAddVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    String startIndex = '';
    String endIndex = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter un compteur vibreur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedPoste,
                decoration: const InputDecoration(
                  labelText: 'Poste',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                  DropdownMenuItem(value: 1, child: Text('1er Poste')),
                  DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Index début',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => startIndex = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Index fin',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => endIndex = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startIndex.isNotEmpty &&
                    endIndex.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['vibrator Counters'] == null) {
                    updatedData['vibrator Counters'] = [];
                  }
                  (updatedData['vibrator Counters'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'start': startIndex,
                    'end': endIndex,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Vibreur Counter Dialog for Activity Report
  Future<void> _showEditVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final counter = (data['vibrator Counters'] as List)[index];
    int? selectedPoste = counter['poste'];
    final startController = TextEditingController(text: counter['start'] ?? '');
    final endController = TextEditingController(text: counter['end'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier le compteur vibreur'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedPoste,
                  decoration: const InputDecoration(
                    labelText: 'Poste',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                    DropdownMenuItem(value: 1, child: Text('1er Poste')),
                    DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                  ],
                  onChanged: (value) => setState(() => selectedPoste = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Index début',
                    border: OutlineInputBorder(),
                  ),
                  controller: startController,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Index fin',
                    border: OutlineInputBorder(),
                  ),
                  controller: endController,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedPoste != null &&
                      startController.text.isNotEmpty &&
                      endController.text.isNotEmpty) {
                    final updatedData = Map<String, dynamic>.from(data);
                    (updatedData['vibrator Counters'] as List)[index] = {
                      'id': counter['id'],
                      'poste': selectedPoste,
                      'start': startController.text,
                      'end': endController.text,
                    };

                    // Recalculate totals for Activity TNB reports
                    final recalculatedData =
                        _recalculateActivityTotals(updatedData);

                    final updatedReport = Report(
                      id: report.id,
                      description: report.description,
                      type: report.type,
                      group: report.group,
                      date: report.date,
                      additionalData: recalculatedData,
                    );

                    Navigator.pop(context);
                    _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  }
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      startController.dispose();
      endController.dispose();
    }
  }

  // Delete Vibreur Counter Dialog for Activity Report
  Future<void> _showDeleteVibratorCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compteur vibreur'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce compteur vibreur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['vibrator Counters'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Add Liaison Counter Dialog for Activity Report
  Future<void> _showAddLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    String startIndex = '';
    String endIndex = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter un compteur liaison'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedPoste,
                decoration: const InputDecoration(
                  labelText: 'Poste',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                  DropdownMenuItem(value: 1, child: Text('1er Poste')),
                  DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Index début',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => startIndex = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Index fin',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => endIndex = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    startIndex.isNotEmpty &&
                    endIndex.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['liaison Counters'] == null) {
                    updatedData['liaison Counters'] = [];
                  }
                  (updatedData['liaison Counters'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'start': startIndex,
                    'end': endIndex,
                  });

                  // Recalculate totals for Activity TNB reports
                  final recalculatedData =
                      _recalculateActivityTotals(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: recalculatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Liaison Counter Dialog for Activity Report
  Future<void> _showEditLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final counter = (data['liaison Counters'] as List)[index];
    int? selectedPoste = counter['poste'];
    final startController = TextEditingController(text: counter['start'] ?? '');
    final endController = TextEditingController(text: counter['end'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier le compteur liaison'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedPoste,
                  decoration: const InputDecoration(
                    labelText: 'Poste',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                    DropdownMenuItem(value: 1, child: Text('1er Poste')),
                    DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                  ],
                  onChanged: (value) => setState(() => selectedPoste = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Index début',
                    border: OutlineInputBorder(),
                  ),
                  controller: startController,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Index fin',
                    border: OutlineInputBorder(),
                  ),
                  controller: endController,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedPoste != null &&
                      startController.text.isNotEmpty &&
                      endController.text.isNotEmpty) {
                    final updatedData = Map<String, dynamic>.from(data);
                    (updatedData['liaison Counters'] as List)[index] = {
                      'id': counter['id'],
                      'poste': selectedPoste,
                      'start': startController.text,
                      'end': endController.text,
                    };

                    // Recalculate totals for Activity TNB reports
                    final recalculatedData =
                        _recalculateActivityTotals(updatedData);

                    final updatedReport = Report(
                      id: report.id,
                      description: report.description,
                      type: report.type,
                      group: report.group,
                      date: report.date,
                      additionalData: recalculatedData,
                    );

                    Navigator.pop(context);
                    _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                  }
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      startController.dispose();
      endController.dispose();
    }
  }

  // Delete Liaison Counter Dialog for Activity Report
  Future<void> _showDeleteLiaisonCounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compteur liaison'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer ce compteur liaison ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['liaison Counters'] as List).removeAt(index);

              // Recalculate totals for Activity TNB reports
              final recalculatedData = _recalculateActivityTotals(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: recalculatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Add Stock Entry Dialog for Activity Report
  Future<void> _showAddStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    int? selectedPoste;
    int? selectedPark;
    int? selectedType;
    String quantity = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une entrée de stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedPoste,
                decoration: const InputDecoration(
                  labelText: 'Poste',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                  DropdownMenuItem(value: 1, child: Text('1er Poste')),
                  DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedPark,
                decoration: const InputDecoration(
                  labelText: 'Parc',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('PARK 1')),
                  DropdownMenuItem(value: 1, child: Text('PARK 2')),
                  DropdownMenuItem(value: 2, child: Text('PARK 3')),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('NORMAL')),
                  DropdownMenuItem(value: 1, child: Text('OCEANE')),
                  DropdownMenuItem(value: 2, child: Text('PB30')),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => quantity = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['stock'] == null) {
                    updatedData['stock'] = [];
                  }
                  (updatedData['stock'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'poste': selectedPoste,
                    'park': selectedPark,
                    'type': selectedType,
                    'quantity': quantity,
                  });

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stock Entry Dialog for Activity Report
  Future<void> _showEditStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final stock = (data['stock'] as List)[index];
    int? selectedPoste = stock['poste'];
    int? selectedPark = stock['park'];
    int? selectedType = stock['type'];
    String quantity = stock['quantity'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier l\'entrée de stock'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedPoste,
                decoration: const InputDecoration(
                  labelText: 'Poste',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('3ème Poste')),
                  DropdownMenuItem(value: 1, child: Text('1er Poste')),
                  DropdownMenuItem(value: 2, child: Text('2ème Poste')),
                ],
                onChanged: (value) => setState(() => selectedPoste = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedPark,
                decoration: const InputDecoration(
                  labelText: 'Parc',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('PARK 1')),
                  DropdownMenuItem(value: 1, child: Text('PARK 2')),
                  DropdownMenuItem(value: 2, child: Text('PARK 3')),
                ],
                onChanged: (value) => setState(() => selectedPark = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('NORMAL')),
                  DropdownMenuItem(value: 1, child: Text('OCEANE')),
                  DropdownMenuItem(value: 2, child: Text('PB30')),
                ],
                onChanged: (value) => setState(() => selectedType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: quantity),
                onChanged: (value) => setState(() => quantity = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedPoste != null &&
                    selectedPark != null &&
                    selectedType != null) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['stock'] as List)[index] = {
                    'id': stock['id'],
                    'poste': selectedPoste,
                    'park': selectedPark,
                    'type': selectedType,
                    'quantity': quantity,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Stock Entry Dialog for Activity Report
  Future<void> _showDeleteStockEntryDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'entrée de stock'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer cette entrée de stock ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['stock'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required BuildContext context,
    required String label,
    required String value,
    required Future<void> Function(String) onSave,
    bool isEditable = true,
  }) {
    return Row(
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
          child: Row(
            children: [
              Expanded(
                child: Text(value.isEmpty ? '-' : value),
              ),
              if (isEditable)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    final TextEditingController controller =
                        TextEditingController(text: value);
                    await showDialog(
                      context: context,
                      builder: (editContext) => AlertDialog(
                        title: Text('Modifier $label'),
                        content: TextField(
                          controller: controller,
                          decoration: InputDecoration(
                            labelText: label,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: null,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(editContext),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(editContext);
                              await onSave(controller.text);
                            },
                            child: const Text('Enregistrer'),
                          ),
                        ],
                      ),
                    );
                  },
                  tooltip: 'Modifier $label',
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditableDateField({
    required BuildContext context,
    required String label,
    required DateTime value,
    required Future<void> Function(DateTime) onSave,
  }) {
    return Row(
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
          child: Row(
            children: [
              Expanded(
                child: Text(DateFormat('yyyy-MM-dd HH:mm').format(value)),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () async {
                  await _editDate(
                    context: context,
                    initialDate: value,
                    onSave: onSave,
                  );
                },
                tooltip: 'Modifier $label',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editDate({
    required BuildContext context,
    required DateTime initialDate,
    required Future<void> Function(DateTime) onSave,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    DateTime selectedDate = initialDate;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(l10n.date),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title:
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(selectedDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    if (!dialogContext.mounted) return;
                    final DateTime? picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && dialogContext.mounted) {
                      final TimeOfDay? time = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null && dialogContext.mounted) {
                        final newDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          time.hour,
                          time.minute,
                        );
                        setState(() {
                          selectedDate = newDate;
                        });
                      }
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await onSave(selectedDate);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportDetails(Report report) async {
    // Debug: print the report type and additionalData
    // ignore: avoid_print
    print('Clicked report type: ${report.type}');
    // ignore: avoid_print
    print('Clicked report additionalData: ${report.additionalData}');
    final l10n = AppLocalizations.of(context)!;

    final typeLower = report.type.toLowerCase();

    // Special handling for Activity TNB report (case-insensitive)
    if (typeLower == 'activity tnb') {
      final data = report.additionalData ?? {};
      final maxHeight = MediaQuery.of(context).size.height * 0.8;
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) {
            Report currentReport = report;
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: maxHeight,
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
                            'Vérification des données',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await _editReport(currentReport);
                                },
                                tooltip: 'Modifier le rapport',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(dialogContext),
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints(),
                              ),
                            ],
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
                            // Date Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    Text(
                                        '${report.date.day}/${report.date.month}/${report.date.year}'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Activity Summary Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Résumé des données',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    _buildSummaryRow(
                                        'T H.A:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.A'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.M:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.M'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.V:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.V'] ?? 0)),
                                    _buildSummaryRow(
                                        'T H.L:',
                                        _formatMinutesToHoursMinutes(
                                            data['T H.L'] ?? 0)),
                                    const SizedBox(height: 8),
                                    _buildSummaryRow(
                                        'T Nr.A:',
                                        (data['stops'] is List
                                                ? (data['stops'] as List).length
                                                : 0)
                                            .toString()),
                                    _buildSummaryRow(
                                        'T Nr.V:',
                                        (data['vibrator Counters'] is List
                                                ? (data['vibrator Counters']
                                                        as List)
                                                    .length
                                                : 0)
                                            .toString()),
                                    _buildSummaryRow(
                                        'T Nr.L:',
                                        (data['liaison Counters'] is List
                                                ? (data['liaison Counters']
                                                        as List)
                                                    .length
                                                : 0)
                                            .toString()),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Stops Card
                            Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Arrêts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const Divider(height: 16),
                                    if (data['stops'] is List &&
                                        (data['stops'] as List).isNotEmpty)
                                      ...List.from(data['stops'])
                                          .map((stop) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Text(
                                                    '${_formatMinutesToHoursMinutes(int.tryParse(stop['duration']) ?? 0)} - ${stop['nature'] ?? '-'}'),
                                              ))
                                    else if (data['stops'] is List &&
                                        (data['stops'] as List).isEmpty)
                                      const Text('Aucun arrêt enregistré',
                                          style: TextStyle(color: Colors.grey))
                                    else
                                      const Text(
                                          'Données des arrêts non disponibles',
                                          style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Vibreurs Counters Card
                            if (data['vibrator Counters'] is List &&
                                (data['vibrator Counters'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Compteurs Vibreurs',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['vibrator Counters'])
                                          .map((counter) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '• Poste: ${_getPosteString(counter['poste'])}'),
                                                    if (counter['start'] !=
                                                            null &&
                                                        counter['start']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  Début: ${counter['start']}'),
                                                    if (counter['end'] !=
                                                            null &&
                                                        counter['end']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  Fin: ${counter['end']}'),
                                                  ],
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ),
                            if (data['vibrator Counters'] is List &&
                                (data['vibrator Counters'] as List).isNotEmpty)
                              const SizedBox(height: 16),
                            // Liaison Counters Card
                            if (data['liaison Counters'] is List &&
                                (data['liaison Counters'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Compteurs Liaison',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['liaison Counters'])
                                          .map((counter) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                        '• Poste: ${_getPosteString(counter['poste'])}'),
                                                    if (counter['start'] !=
                                                            null &&
                                                        counter['start']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  Début: ${counter['start']}'),
                                                    if (counter['end'] !=
                                                            null &&
                                                        counter['end']
                                                            .toString()
                                                            .isNotEmpty)
                                                      Text(
                                                          '  Fin: ${counter['end']}'),
                                                  ],
                                                ),
                                              )),
                                    ],
                                  ),
                                ),
                              ),
                            if (data['liaison Counters'] is List &&
                                (data['liaison Counters'] as List).isNotEmpty)
                              const SizedBox(height: 16),
                            // Stock Card
                            if (data['stock'] is List &&
                                (data['stock'] as List).isNotEmpty)
                              Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Stocks',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const Divider(height: 16),
                                      ...List.from(data['stock'])
                                          .map((entry) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 2),
                                                child: Text(
                                                  'Poste: ${_getPosteString(entry['poste'])} | Park: ${_getParkString(entry['park'])} | Type: ${_getStockTypeString(entry['type'])} | Qte: ${entry['quantity'] ?? '-'} |',
                                                ),
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
        ),
      );
      return;
    }

    // Special handling for daily TSUD report (case-insensitive)
    if (typeLower == 'daily tsud') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.reportDetails),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editReport(report),
                tooltip: 'Modifier le rapport',
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Module 1 Card
                Builder(
                  builder: (context) {
                    final module1Stops = (data['module1Stops'] is List)
                        ? List.from(data['module1Stops'])
                        : [];
                    final module1Downtime =
                        _calculateDowntimeFromStops(module1Stops);
                    const int totalPeriod = 24 * 60; // 24 hours in minutes
                    final module1OperatingTime =
                        (totalPeriod - module1Downtime).clamp(0, totalPeriod);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Module 1',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                'Temps de fonctionnement: ${_formatMinutesToHoursMinutes(module1OperatingTime)}'),
                            Text(
                                'Temps d\'arrêt: ${_formatMinutesToHoursMinutes(module1Downtime)}'),
                            if (module1Stops.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Arrêts:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ...module1Stops.map((stop) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                        '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Module 2 Card
                Builder(
                  builder: (context) {
                    final module2Stops = (data['module2Stops'] is List)
                        ? List.from(data['module2Stops'])
                        : [];
                    final module2Downtime =
                        _calculateDowntimeFromStops(module2Stops);
                    const int totalPeriod = 24 * 60; // 24 hours in minutes
                    final module2OperatingTime =
                        (totalPeriod - module2Downtime).clamp(0, totalPeriod);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Module 2',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text(
                                'Temps de fonctionnement: ${_formatMinutesToHoursMinutes(module2OperatingTime)}'),
                            Text(
                                'Temps d\'arrêt: ${_formatMinutesToHoursMinutes(module2Downtime)}'),
                            if (module2Stops.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Arrêts:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              ...module2Stops.map((stop) => Padding(
                                    padding:
                                        const EdgeInsets.only(left: 16, top: 4),
                                    child: Text(
                                        '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                                  )),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Stocks Card (if any)
                if (data['stock'] is List && (data['stock'] as List).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stocks',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...List.from(data['stock']).map((entry) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  'Poste: ${_getPosteString(entry['poste'])} | Park: ${_getParkString(entry['park'])} | Type: ${_getStockTypeString(entry['type'])} | Qte: ${entry['quantity'] ?? '-'} |',
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return;
    }

    // Special handling for Machine/Engin Arrêtés report (case-insensitive)
    if (typeLower == 'machine/engin arrêtés') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.reportDetails),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editReport(report),
                tooltip: 'Modifier le rapport',
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Équipements arrêtés Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Équipements arrêtés',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (data['equipmentList'] is List &&
                            (data['equipmentList'] as List).isNotEmpty) ...[
                          ...List.from(data['equipmentList'])
                              .asMap()
                              .entries
                              .map((entry) {
                            final index = entry.key;
                            final equipment = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Équipement ${index + 1}:',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Type: ${equipment['equipmentType'] ?? '-'}'),
                                  Text('Raison: ${equipment['Reason'] ?? '-'}'),
                                  if (index <
                                      (data['equipmentList'] as List).length -
                                          1)
                                    const Divider(),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          const Text('Aucun équipement arrêté',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
      return;
    }

    // Special handling for R0 report (case-insensitive)
    if (typeLower == 'r0' ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('mine') &&
            report.additionalData!.containsKey('selectedPoste'))) {
      final data = report.additionalData ?? {};
      final maxHeight = MediaQuery.of(context).size.height * 0.8;

      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
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
                        'Rapport R0',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editReport(report),
                            tooltip: 'Modifier le rapport',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
                        // Date Card
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
                                Text(
                                    '${report.date.day}/${report.date.month}/${report.date.year}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Info OIB/EE Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info OIB/EE',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildInfoRow('Mine', data['mine'] ?? '-'),
                                _buildInfoRow('Zone', data['zone'] ?? '-'),
                                _buildInfoRow('Sortie', data['sortie'] ?? '-'),
                                _buildInfoRow(
                                    'Catégorie', data['Category'] ?? '-'),
                                _buildInfoRow('Type', data['Type'] ?? '-'),
                                _buildInfoRow('Modèle', data['Model'] ?? '-'),
                                _buildInfoRow(
                                    'Poste',
                                    data['selectedPoste'] ??
                                        data['poste'] ??
                                        data['Poste'] ??
                                        '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Compteurs Card
                        if (data['Compteurs'] is List &&
                            (data['Compteurs'] as List).isNotEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Compteur',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  ...List.generate(
                                      (data['Compteurs'] as List).length,
                                      (index) {
                                    final compteur =
                                        (data['Compteurs'] as List)[index];
                                    if (compteur['duree'] == null &&
                                        compteur['note'] == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        _buildInfoRow(
                                            'Début', compteur['duree'] ?? '-'),
                                        _buildInfoRow(
                                            'Fin', compteur['note'] ?? '-'),
                                        if (index <
                                            (data['Compteurs'] as List).length -
                                                1)
                                          const Divider(height: 16),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        if (data['Compteurs'] is List &&
                            (data['Compteurs'] as List).isNotEmpty)
                          const SizedBox(height: 16),
                        // Arrêts Card
                        if (data['Arrets'] is List &&
                            (data['Arrets'] as List).isNotEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Arrêts',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  ...List.from(data['Arrets'])
                                      .map((arret) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    'Type: ${arret['Arret'] ?? '-'}'),
                                                _buildInfoRow('Début',
                                                    arret['Début'] ?? '-'),
                                                _buildInfoRow(
                                                    'Fin', arret['Fin'] ?? '-'),
                                                const Divider(height: 8),
                                              ],
                                            ),
                                          )),
                                ],
                              ),
                            ),
                          ),
                        if (data['Arrets'] is List &&
                            (data['Arrets'] as List).isNotEmpty)
                          const SizedBox(height: 16),
                        // Exploitation Card
                        if (data['exploitation'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Exploitation',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow('H.M',
                                      data['exploitation']['H.M'] ?? '-'),
                                  _buildInfoRow('H.A',
                                      data['exploitation']['H.A'] ?? '-'),
                                  _buildInfoRow('Tonnage',
                                      data['exploitation']['Tonnage'] ?? '-'),
                                  _buildInfoRow('Rendeme',
                                      data['exploitation']['Rendeme'] ?? '-'),
                                ],
                              ),
                            ),
                          ),
                        if (data['exploitation'] is Map)
                          const SizedBox(height: 16),
                        // Répartition Card
                        if (data['Répartition Travail'] is List &&
                            (data['Répartition Travail'] as List).isNotEmpty)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Répartition',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  ...List.from(data['Répartition Travail'])
                                      .map((repartition) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 2),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildInfoRow(
                                                    'Chantier',
                                                    repartition['Chantier'] ??
                                                        repartition[
                                                            'chantier'] ??
                                                        '-'),
                                                _buildInfoRow(
                                                    'Temps',
                                                    repartition['Temps'] ??
                                                        repartition['temps'] ??
                                                        '-'),
                                                _buildInfoRow(
                                                    'Imputat',
                                                    repartition['Imputation'] ??
                                                        repartition[
                                                            'imputation'] ??
                                                        '-'),
                                                const Divider(height: 8),
                                              ],
                                            ),
                                          )),
                                ],
                              ),
                            ),
                          ),
                        if (data['Répartition Travail'] is List &&
                            (data['Répartition Travail'] as List).isNotEmpty)
                          const SizedBox(height: 16),
                        // Personnel Card
                        if (data['personnel'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Personnel',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow('Conductr',
                                      data['personnel']['conductr'] ?? '-'),
                                  _buildInfoRow('Graisseur',
                                      data['personnel']['graisseur'] ?? '-'),
                                  _buildInfoRow('Matricule',
                                      data['personnel']['matricules'] ?? '-'),
                                ],
                              ),
                            ),
                          ),
                        if (data['personnel'] is Map)
                          const SizedBox(height: 16),
                        // Consommation Card
                        if (data['consommation'] is Map)
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Consommation',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildInfoRow('Tricone',
                                      data['consommation']['tricone'] ?? '-'),
                                  _buildInfoRow('Gasoil',
                                      data['consommation']['gasoil'] ?? '-'),
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
        ),
      );
      return;
    }

    // Special handling for Suivi Camion, Chargeuse, Pelle, or truckData (case-insensitive)
    if (typeLower == 'suivi camion' ||
        typeLower.contains('chargeuse') ||
        typeLower.contains('pelle') ||
        (report.additionalData != null &&
            report.additionalData!.containsKey('truckData'))) {
      final data = report.additionalData ?? {};
      final truckData =
          (data['truckData'] is List) ? List.from(data['truckData']) : [];

      // Calculate summary data
      final allTrips = truckData
          .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
          .toList();
      final Map<String, int> equipmentCounts = {};
      for (var trip in allTrips) {
        final eq = trip['equipment'] ?? '-';
        equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
      }
      final maxHeight = MediaQuery.of(context).size.height * 0.8;

      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
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
                        'Rapport Camions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editReport(report),
                            tooltip: 'Modifier le rapport',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
                        // Date Card
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
                                Text(
                                    '${report.date.day}/${report.date.month}/${report.date.year}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Poste Card
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
                                Text(data['poste'] ??
                                    data['selectedPoste'] ??
                                    '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Equipement Card
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
                                Text(
                                    'Opération: ${data['operationType'] ?? '-'}'),
                                if (data['equipment'] != null)
                                  Text('Type: ${data['equipment']}'),
                                if (data['selectedEquipment'] != null)
                                  Text('Type: ${data['selectedEquipment']}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Mine et Sortie Card
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
                                Text('Mine: ${data['mine'] ?? '-'}'),
                                Text('Zone: ${data['zone'] ?? '-'}'),
                                Text('Sortie: ${data['sortie'] ?? '-'}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Camions Card
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
                                if (truckData.isEmpty)
                                  const Text('Aucun camion ajouté.',
                                      style: TextStyle(color: Colors.grey)),
                                if (truckData.isNotEmpty)
                                  ...truckData.map((truck) => Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'C ${truck['truckNumber']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                              'Chauffeur: ${truck['driver1'] ?? '-'}'),
                                          if (truck['counts'] != null &&
                                              (truck['counts'] is List) &&
                                              (truck['counts'] as List)
                                                  .isNotEmpty) ...[
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
                                                (truck['counts'] as List)
                                                    .length, (index) {
                                              final count = (truck['counts']
                                                  as List)[index];
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
                                          if (truck != truckData.last)
                                            const Divider(),
                                        ],
                                      )),
                              ],
                            ),
                          ),
                        ),
                        // Résumé Card
                        Builder(
                          builder: (context) {
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
                                      const Text('Résumé',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(
                                          'Total de voyages: ${allTrips.length}'),
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
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.reportDetails),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editReport(report),
              tooltip: 'Modifier le rapport',
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main fields
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.description,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(report.description.isNotEmpty
                          ? report.description
                          : 'Not filled'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.additionalData,
                  style: Theme.of(context).textTheme.titleLarge),
              _buildAdditionalDataView(report),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDataView(Report report) {
    final data = report.additionalData ?? {};
    switch (report.type) {
      case 'Activity TNB':
        return _buildActivityReportAdditionalData(data);
      case 'daily TSUD':
        return _buildDailyReportAdditionalData(data);
      case 'Machine/Engin Arrêtés':
        return _buildMachinesEquipmentStoppedAdditionalData(data);
      case 'Suivi Camion':
        return _buildTruckTrackingAdditionalData(data);
      case 'R0':
        return _buildR0ReportAdditionalData(data);
      default:
        // Check if this is an R0 report by looking for mine and selectedPoste
        if (data.containsKey('mine') && data.containsKey('selectedPoste')) {
          return _buildR0ReportAdditionalData(data);
        }
        // Check if this is a truck tracking report by looking for truckData
        if (data.containsKey('truckData')) {
          return _buildTruckTrackingAdditionalData(data);
        }
        // Fallback: show all additionalData key-value pairs
        if (data.isEmpty) return const Text('No additional data');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries
              .map<Widget>((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('${entry.key}: ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(entry.value.toString())),
                      ],
                    ),
                  ))
              .toList(),
        );
    }
  }

  Widget _buildActivityReportAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('Aucune donnée d\'activité disponible.');
    }

    String formatMinutesToHoursMinutes(int? totalMinutes) {
      if (totalMinutes == null || totalMinutes <= 0) return "0h 0m";
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    }

    final stops = (data['stops'] is List) ? List.from(data['stops']) : [];
    final vibratorCounters = (data['vibrator Counters'] is List)
        ? List.from(data['vibrator Counters'])
        : [];
    final liaisonCounters = (data['liaison Counters'] is List)
        ? List.from(data['liaison Counters'])
        : [];
    final stockEntries =
        (data['stock'] is List) ? List.from(data['stock']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Résumé des données',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(
                    'T H.A:',
                    formatMinutesToHoursMinutes(
                        data['T H.A'] is int ? data['T H.A'] : 0)),
                _buildSummaryRow(
                    'T H.M:',
                    formatMinutesToHoursMinutes(
                        data['T H.M'] is int ? data['T H.M'] : 0)),
                _buildSummaryRow(
                    'T H.V:',
                    formatMinutesToHoursMinutes(
                        data['T H.V'] is int ? data['T H.V'] : 0)),
                _buildSummaryRow(
                    'T H.L:',
                    formatMinutesToHoursMinutes(
                        data['T H.L'] is int ? data['T H.L'] : 0)),
                const SizedBox(height: 8),
                _buildSummaryRow('T Nr.A:', stops.length.toString()),
                _buildSummaryRow('T Nr.V:', vibratorCounters.length.toString()),
                _buildSummaryRow('T Nr.L:', liaisonCounters.length.toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (stops.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Arrêts',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (vibratorCounters.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compteurs Vibreurs',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...vibratorCounters.map((counter) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: 9${counter['poste'] ?? '-'}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (liaisonCounters.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compteurs Liaison',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...liaisonCounters.map((counter) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: \t${counter['poste'] ?? '-'}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
        if (stockEntries.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stocks',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...stockEntries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            'Poste: ${entry['poste'] ?? '-'}, Parc: ${entry['park'] ?? '-'}, Type: ${entry['type'] ?? '-'}, Qté: ${entry['quantity'] ?? '-'}'),
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatMinutesToHoursMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return "0h 0m";
    int hours = totalMinutes ~/ 60;
    int minutes = totalMinutes % 60;
    return "${hours}h ${minutes}m";
  }

  // Calculate downtime from stops list
  int _calculateDowntimeFromStops(List stops) {
    if (stops.isEmpty) return 0;
    return stops
        .map((stop) => _parseDurationToMinutes(stop['duration'] ?? ''))
        .fold(0, (a, b) => a + b);
  }

  // Parse duration string to minutes
  int _parseDurationToMinutes(String duration) {
    if (duration.isEmpty) return 0;
    final cleaned = duration.replaceAll(RegExp(r'[^0-9Hh:·\s]'), '').trim();
    final regex1 = RegExp(r'^(?:(\d{1,2})\s?[Hh:·]\s?)?(\d{1,2})$');
    final regex2 = RegExp(r'^(\d{1,2})\s?[Hh]$');
    final regex3 = RegExp(r'^(\d+)$');
    var match = regex1.firstMatch(cleaned);
    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      return hours * 60 + minutes;
    }
    match = regex2.firstMatch(cleaned);
    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      return hours * 60;
    }
    match = regex3.firstMatch(cleaned);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  // Validate and parse counter value
  double? _validateAndParseCounterValue(String value) {
    if (value.isEmpty) return 0;
    final cleaned =
        value.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
    if (cleaned == '' || cleaned == '.' || cleaned == ',') return null;
    return double.tryParse(cleaned);
  }

  // Calculate total counter minutes
  int _calculateTotalCounterMinutes(List counters) {
    double totalHours = 0;
    for (var counter in counters) {
      var startVal = _validateAndParseCounterValue(counter['start'] ?? '');
      var endVal = _validateAndParseCounterValue(counter['end'] ?? '');
      if (startVal != null && endVal != null && endVal >= startVal) {
        totalHours += (endVal - startVal);
      }
    }
    return (totalHours * 60).round();
  }

  // Recalculate totals for Activity TNB reports
  Map<String, dynamic> _recalculateActivityTotals(Map<String, dynamic> data) {
    final updatedData = Map<String, dynamic>.from(data);

    final stops =
        (updatedData['stops'] is List) ? List.from(updatedData['stops']) : [];
    final vibratorCounters = (updatedData['vibrator Counters'] is List)
        ? List.from(updatedData['vibrator Counters'])
        : [];
    final liaisonCounters = (updatedData['liaison Counters'] is List)
        ? List.from(updatedData['liaison Counters'])
        : [];

    final totalDowntime = _calculateDowntimeFromStops(stops);
    const int totalPeriodMinutes = 24 * 60; // 24 hours in minutes
    final operatingTime =
        (totalPeriodMinutes - totalDowntime).clamp(0, totalPeriodMinutes);
    final totalVibratorMinutes =
        _calculateTotalCounterMinutes(vibratorCounters);
    final totalLiaisonMinutes = _calculateTotalCounterMinutes(liaisonCounters);

    updatedData['T H.A'] = totalDowntime;
    updatedData['T H.M'] = operatingTime;
    updatedData['T H.V'] = totalVibratorMinutes;
    updatedData['T H.L'] = totalLiaisonMinutes;

    return updatedData;
  }

  String _getPosteString(dynamic posteIndex) {
    if (posteIndex == null) return '-';
    switch (posteIndex) {
      case 0:
        return '3ème';
      case 1:
        return '1er';
      case 2:
        return '2ème';
      default:
        return '-';
    }
  }

  String _getParkString(dynamic parkIndex) {
    if (parkIndex == null) return '-';
    switch (parkIndex) {
      case 0:
        return 'PARK 1';
      case 1:
        return 'PARK 2';
      case 2:
        return 'PARK 3';
      default:
        return '-';
    }
  }

  String _getStockTypeString(dynamic typeIndex) {
    if (typeIndex == null) return '-';
    switch (typeIndex) {
      case 0:
        return 'NORMAL';
      case 1:
        return 'OCEANE';
      case 2:
        return 'PB30';
      default:
        return '-';
    }
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildDailyReportAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('Aucune donnée quotidienne disponible.');
    }

    String formatMinutesToHoursMinutes(int? totalMinutes) {
      if (totalMinutes == null || totalMinutes <= 0) return "0h 0m";
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    }

    final module1Stops =
        (data['module1Stops'] is List) ? List.from(data['module1Stops']) : [];
    final module2Stops =
        (data['module2Stops'] is List) ? List.from(data['module2Stops']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['secteur'] != null) Text('Secteur: ${data['secteur']}'),
        if (data['rapportNo'] != null) Text('Rapport N°: ${data['rapportNo']}'),
        if (data['machineEngins'] != null)
          Text('Machines/Engins: ${data['machineEngins']}'),
        const SizedBox(height: 16),
        // Module 1 Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Module 1',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    'Temps de fonctionnement: ${formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    'Temps d\'arrêt: ${formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module1Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Arrêts:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...module1Stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Module 2 Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Module 2',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text(
                    'Temps de fonctionnement: ${formatMinutesToHoursMinutes(data['Temps de fonctionnement'] is int ? data['Temps de fonctionnement'] : 0)}'),
                Text(
                    'Temps d\'arrêt: ${formatMinutesToHoursMinutes(data['Temps d\'arrêt'] is int ? data['Temps d\'arrêt'] : 0)}'),
                if (module2Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Arrêts:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  ...module2Stops.map((stop) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: Text(
                            '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                      )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachinesEquipmentStoppedAdditionalData(
      Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('Aucune donnée d\'équipement arrêtée disponible.');
    }
    final equipmentList =
        (data['equipmentList'] is List) ? List.from(data['equipmentList']) : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Date du rapport',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (data['date'] != null) Text(data['date'].toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Équipements arrêtés',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (equipmentList.isEmpty)
                  const Text('Aucun équipement ajouté',
                      style: TextStyle(color: Colors.grey)),
                if (equipmentList.isNotEmpty)
                  ...equipmentList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final equipment = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Équipement ${index + 1}:',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Type: ${equipment['equipmentType'] ?? '-'}'),
                          Text('Raison: ${equipment['Reason'] ?? '-'}'),
                          if (index < equipmentList.length - 1) const Divider(),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        if (equipmentList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${equipmentList.length} équipement${equipmentList.length > 1 ? 's' : ''} prêt${equipmentList.length > 1 ? 's' : ''} à être soumis',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTruckTrackingAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) {
      return const Text('Aucune donnée de suivi camion disponible.');
    }
    final truckData =
        (data['truckData'] is List) ? List.from(data['truckData']) : [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mine et Sortie',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                Text('Mine: ${data['mine'] ?? '-'}'),
                Text('Zone: ${data['zone'] ?? '-'}'),
                Text('Sortie: ${data['sortie'] ?? '-'}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Equipement',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                Text('Opération: ${data['operationType'] ?? '-'}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Camions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (truckData.isEmpty) const Text('Aucun camion ajouté.'),
                if (truckData.isNotEmpty)
                  ...truckData.map((truck) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Camion: ${truck['truckNumber'] ?? '-'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Chauffeur: ${truck['driver1'] ?? '-'}'),
                          if (truck['counts'] != null &&
                              (truck['counts'] is List) &&
                              (truck['counts'] as List).isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text('Voyages:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            ...List.generate((truck['counts'] as List).length,
                                (index) {
                              final count = (truck['counts'] as List)[index];
                              return Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 4),
                                child: Row(
                                  children: [
                                    Text('v${index + 1}: '),
                                    Text(count['time'] ?? '-'),
                                    const SizedBox(width: 12),
                                    const Text('|'),
                                    const SizedBox(width: 12),
                                    Text(count['equipment'] ?? '-'),
                                  ],
                                ),
                              );
                            }),
                          ],
                          const Divider(),
                        ],
                      )),
              ],
            ),
          ),
        ),
        if (truckData.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Résumé des voyages',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        'Total de voyages: ${truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).length}'),
                    const SizedBox(height: 8),
                    ..._buildEquipmentCounts(truckData),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildEquipmentCounts(List truckData) {
    final allTrips = truckData
        .expand((truck) => (truck['counts'] is List) ? truck['counts'] : [])
        .toList();
    final Map<String, int> equipmentCounts = {};
    for (var trip in allTrips) {
      final eq = trip['equipment'] ?? '-';
      equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
    }
    return equipmentCounts.entries
        .map((e) => Text('Total pour ${e.key}: ${e.value}'))
        .toList();
  }

  Widget _buildR0ReportAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text('Aucune donnée R0 disponible.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info OIB/EE Section
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Info OIB/EE',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                _buildSummaryItem('Mine', data['mine'] ?? ''),
                _buildSummaryItem('Zone', data['zone'] ?? ''),
                _buildSummaryItem('Sortie', data['sortie'] ?? ''),
                _buildSummaryItem('Catégorie', data['Category'] ?? ''),
                _buildSummaryItem('Type', data['Type'] ?? ''),
                _buildSummaryItem('Modèle', data['Model'] ?? ''),
                _buildSummaryItem(
                    'Poste', data['selectedPoste'] ?? data['poste'] ?? ''),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Compteurs Section
        if (data['Compteurs'] is List && (data['Compteurs'] as List).isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Compteurs',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  ...List.generate((data['Compteurs'] as List).length, (index) {
                    final compteur = (data['Compteurs'] as List)[index];
                    if (compteur['duree'] == null && compteur['note'] == null) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryItem('Début', compteur['duree'] ?? ''),
                        _buildSummaryItem('Fin', compteur['note'] ?? ''),
                        if (index < (data['Compteurs'] as List).length - 1)
                          const Divider(height: 12),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        if (data['Compteurs'] is List && (data['Compteurs'] as List).isNotEmpty)
          const SizedBox(height: 16),
        // Arrêts Section
        if (data['Arrets'] is List && (data['Arrets'] as List).isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Arrêts',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  ...List.from(data['Arrets']).map((arret) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Type: ${arret['Arret'] ?? '-'}'),
                            _buildSummaryItem('Début', arret['Début'] ?? ''),
                            _buildSummaryItem('Fin', arret['Fin'] ?? ''),
                            const Divider(height: 8),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
        if (data['Arrets'] is List && (data['Arrets'] as List).isNotEmpty)
          const SizedBox(height: 16),
        // Exploitation Section
        if (data['exploitation'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exploitation',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem('H.M', data['exploitation']['H.M'] ?? ''),
                  _buildSummaryItem('H.A', data['exploitation']['H.A'] ?? ''),
                  _buildSummaryItem(
                      'Tonnage', data['exploitation']['Tonnage'] ?? ''),
                  _buildSummaryItem(
                      'Rendeme',
                      data['exploitation']['Rendeme'] ??
                          data['exploitation']['Rendeme'] ??
                          ''),
                ],
              ),
            ),
          ),
        if (data['exploitation'] is Map) const SizedBox(height: 16),
        // Répartition Section
        if (data['Répartition Travail'] is List &&
            (data['Répartition Travail'] as List).isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Répartition Travail',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  ...List.from(data['Répartition Travail'])
                      .map((repartition) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummaryItem(
                                    'Chantier',
                                    repartition['Chantier'] ??
                                        repartition['chantier'] ??
                                        ''),
                                _buildSummaryItem(
                                    'Temps',
                                    repartition['temps'] ??
                                        repartition['Temps'] ??
                                        ''),
                                _buildSummaryItem(
                                    'Imputation',
                                    repartition['imputation'] ??
                                        repartition['Imputation'] ??
                                        ''),
                                const Divider(height: 8),
                              ],
                            ),
                          )),
                ],
              ),
            ),
          ),
        if (data['Répartition Travail'] is List &&
            (data['Répartition Travail'] as List).isNotEmpty)
          const SizedBox(height: 16),
        // Personnel Section
        if (data['personnel'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personnel',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem(
                      'Conductr',
                      data['personnel']['conductr'] ??
                          data['personnel']['conductr'] ??
                          ''),
                  _buildSummaryItem(
                      'Graisseur', data['personnel']['graisseur'] ?? ''),
                  _buildSummaryItem(
                      'Matricules', data['personnel']['matricules'] ?? ''),
                ],
              ),
            ),
          ),
        if (data['personnel'] is Map) const SizedBox(height: 16),
        // Consommation Section
        if (data['consommation'] is Map)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Consommation',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const Divider(height: 16),
                  _buildSummaryItem(
                      'Tricone', data['consommation']['tricone'] ?? ''),
                  _buildSummaryItem(
                      'Gasoil', data['consommation']['gasoil'] ?? ''),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _saveReportUpdate(
    Report updatedReport,
    ScaffoldMessengerState scaffoldMessenger,
    AppLocalizations l10n,
  ) async {
    try {
      await _databaseHelper.updateReport(updatedReport);
      await _loadReports();
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.reportUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(l10n.errorUpdatingReport)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedPosteFilter != null
            ? '${l10n.reports} - $_selectedPosteFilter'
            : l10n.reports),
        actions: [
          // Poste Filter Dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: DropdownButton<String>(
              value: _selectedPosteFilter,
              hint: Text('Tous les postes',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: Container(),
              icon: Icon(Icons.filter_list,
                  color: Theme.of(context).colorScheme.onPrimary),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Tous les postes'),
                ),
                ..._availablePostes.map((poste) => DropdownMenuItem<String>(
                      value: poste,
                      child: Text(poste),
                    )),
              ],
              onChanged: _onPosteFilterChanged,
            ),
          ),
          // Clear filter button when filter is active
          if (_selectedPosteFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => _onPosteFilterChanged(null),
              tooltip: 'Effacer le filtre',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredReports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _selectedPosteFilter != null
                            ? 'Aucun rapport trouvé pour le poste $_selectedPosteFilter'
                            : l10n.noDataMessage,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_selectedPosteFilter != null) ...[
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => _onPosteFilterChanged(null),
                          child: const Text('Voir tous les rapports'),
                        ),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filter summary
                    if (_selectedPosteFilter != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.06),
                        child: Row(
                          children: [
                            Icon(Icons.filter_list,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_filteredReports.length} rapport${_filteredReports.length > 1 ? 's' : ''} trouvé${_filteredReports.length > 1 ? 's' : ''} pour le poste $_selectedPosteFilter',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            // Logic to determine title
                            String title = report.description;
                            final typeLower = report.type.toLowerCase();
                            if (typeLower == 'activity tnb') {
                              title = 'Activity TNB';
                            } else if (typeLower == 'daily tsud') {
                              title = 'daily TSUD';
                            }

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type: ${report.type}'),
                                    Text(
                                        'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(report.date)}'),
                                    Text('Group: ${report.group}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Popup menu for additional actions
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz,
                                          size: 20),
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      position: PopupMenuPosition.under,
                                      itemBuilder: (BuildContext context) => [
                                        PopupMenuItem<String>(
                                          value: 'delete',
                                          height: 36,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.delete_outline,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Supprimer',
                                                style: TextStyle(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .error,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onSelected: (String value) {
                                        if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(l10n.delete),
                                              content: const Text(
                                                  'Are you sure you want to delete this report?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text(l10n.cancel),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    _deleteReport(report);
                                                  },
                                                  child: Text(l10n.delete),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _showReportDetails(report);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  // Daily Report Editor
  Future<void> _showDailyReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modifier R TSUD',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Module 1 Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Module 1',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showEditModuleDialog(
                                          report,
                                          data,
                                          'module1',
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Modifier'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['module1Stops'] is List &&
                                    (data['module1Stops'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Arrêts:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  ...List.from(data['module1Stops'])
                                      .map((stop) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 4),
                                            child: Text(
                                                '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                                          )),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Module 2 Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Module 2',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showEditModuleDialog(
                                          report,
                                          data,
                                          'module2',
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Modifier'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['module2Stops'] is List &&
                                    (data['module2Stops'] as List)
                                        .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Text('Arrêts:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  ...List.from(data['module2Stops'])
                                      .map((stop) => Padding(
                                            padding: const EdgeInsets.only(
                                                left: 16, top: 4),
                                            child: Text(
                                                '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                                          )),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Stock Entries Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'stock',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddStockEntryDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['stock'] is List &&
                                    (data['stock'] as List).isNotEmpty)
                                  ...List.from(data['stock'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final stock = entry.value;
                                    final isSelected =
                                        _selectedStockIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.purple.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor: Colors.purple
                                            .withValues(alpha: 0.1),
                                        title: Text('Stock ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Poste: ${_getPosteString(stock['poste'])}'),
                                            Text(
                                                'Parc: ${_getParkString(stock['park'])}'),
                                            Text(
                                                'Type: ${_getStockTypeString(stock['type'])}'),
                                            Text(
                                                'Quantité: ${stock['quantity'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.purple)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStockIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Modifier l\'entrée de stock',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteStockEntryDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Supprimer l\'entrée de stock',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucune entrée de stock ajoutée',
                                      style: TextStyle(color: Colors.grey)),
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
        ),
      ),
    );
  }

  // Edit Module Dialog for Daily Report
  Future<void> _showEditModuleDialog(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    List stops = List.from(data['${modulePrefix}Stops'] ?? []);

    // Ensure totals are calculated
    int totalDowntime = data['${modulePrefix}TotalDowntime'] ??
        _calculateDowntimeFromStops(stops);
    int operatingTime = data['${modulePrefix}OperatingTime'] ??
        ((24 * 60) - totalDowntime).clamp(0, 24 * 60);

    // Update data with calculated values
    data['${modulePrefix}TotalDowntime'] = totalDowntime;
    data['${modulePrefix}OperatingTime'] = operatingTime;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Modifier $modulePrefix'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Arrêts (${stops.length})'),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _showAddStopDialogForModule(
                          report,
                          data,
                          modulePrefix,
                          stops,
                          setState,
                          setDialogState,
                          scaffoldMessenger,
                          l10n, (int newTotal) {
                        setState(() {
                          totalDowntime = newTotal;
                          operatingTime =
                              (24 * 60 - newTotal).clamp(0, 24 * 60);
                        });
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  ),
                ],
              ),
              if (stops.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...stops.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stop = entry.value;
                  return ListTile(
                    title: Text('Arrêt ${index + 1}'),
                    subtitle: Text(
                        '${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () async {
                            await _showEditStopDialogForModule(
                                report,
                                data,
                                modulePrefix,
                                stops,
                                index,
                                setState,
                                setDialogState,
                                scaffoldMessenger,
                                l10n, (int newTotal) {
                              setState(() {
                                totalDowntime = newTotal;
                                operatingTime =
                                    (24 * 60 - newTotal).clamp(0, 24 * 60);
                              });
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              size: 18, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              stops.removeAt(index);
                              totalDowntime =
                                  _calculateDowntimeFromStops(stops);
                              operatingTime =
                                  (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                            });
                            // Update data
                            data['${modulePrefix}TotalDowntime'] =
                                totalDowntime;
                            data['${modulePrefix}OperatingTime'] =
                                operatingTime;
                            data['${modulePrefix}Stops'] = stops;
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedData = Map<String, dynamic>.from(data);
                updatedData['${modulePrefix}OperatingTime'] = operatingTime;
                updatedData['${modulePrefix}TotalDowntime'] = totalDowntime;
                updatedData['${modulePrefix}Stops'] = stops;

                final updatedReport = Report(
                  id: report.id,
                  description: report.description,
                  type: report.type,
                  group: report.group,
                  date: report.date,
                  additionalData: updatedData,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // Add Stop Dialog for Module
  Future<void> _showAddStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    const List<String> predefinedNatures = [
      'Manque Produit',
      'Attente Saturation Silo',
      'Vidange Extraction 2',
      'Arret Mécanique sur:',
      'Dèfout Élèctrique sur:',
      'Arret d\'instalation sur:',
      'Travoux Mècanique sur:',
      'Travoux Elèctrique sur:',
      'Travoux dans l\'instalation sur:',
      'Autre:',
    ];

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = '';
    final customNatureController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Ajouter un arrêt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedNature,
                decoration: const InputDecoration(
                  labelText: 'Nature prédéfinie',
                  border: OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map((nature) => DropdownMenuItem(
                          value: nature,
                          child: Text(nature),
                        ))
                    .toList(),
                onChanged: (value) {
                  setLocalState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
                hint: const Text('Sélectionner une nature'),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    setLocalState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: const InputDecoration(
                    labelText: 'Nature (complément)',
                    border: OutlineInputBorder(),
                    hintText: 'Maximum 20 caractères par ligne',
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setLocalState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  setState(() {
                    stops.add({
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'duration': tempStopDuration,
                      'nature': finalNature,
                    });
                    final totalDowntime = _calculateDowntimeFromStops(stops);
                    data['${modulePrefix}TotalDowntime'] = totalDowntime;
                    data['${modulePrefix}OperatingTime'] =
                        (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                    data['${modulePrefix}Stops'] = stops;
                    setDialogState(() {});
                    onTotalDowntimeChanged(totalDowntime);
                    Navigator.pop(context);
                  });
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Stop Dialog for Module
  Future<void> _showEditStopDialogForModule(
      Report report,
      Map<String, dynamic> data,
      String modulePrefix,
      List stops,
      int index,
      StateSetter setState,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n,
      Function(int) onTotalDowntimeChanged) async {
    final stop = stops[index];
    const List<String> predefinedNatures = [
      'Manque Produit',
      'Attente Saturation Silo',
      'Vidange Extraction 2',
      'Arret Mécanique sur:',
      'Dèfout Élèctrique sur:',
      'Arret d\'instalation sur:',
      'Travoux Mècanique sur:',
      'Travoux Elèctrique sur:',
      'Travoux dans l\'instalation sur:',
      'Autre:',
    ];

    String? selectedNature;
    String customNature = '';
    String tempStopDuration = stop['duration'] ?? '';
    final customNatureController = TextEditingController();

    // Parse the nature to determine selected nature and custom part
    String currentNature = stop['nature'] ?? '';
    for (String nature in predefinedNatures) {
      if (currentNature.startsWith(nature)) {
        selectedNature = nature;
        if (nature.endsWith(':')) {
          customNature = currentNature.substring(nature.length).trim();
          customNatureController.text = customNature;
        }
        break;
      }
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Modifier l\'arrêt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedNature,
                decoration: const InputDecoration(
                  labelText: 'Nature prédéfinie',
                  border: OutlineInputBorder(),
                ),
                items: predefinedNatures
                    .map((nature) => DropdownMenuItem(
                          value: nature,
                          child: Text(nature),
                        ))
                    .toList(),
                onChanged: (value) {
                  setLocalState(() {
                    selectedNature = value;
                    customNature = '';
                    customNatureController.clear();
                  });
                },
                hint: const Text('Sélectionner une nature'),
                isExpanded: true,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Durée (ex: 1h 30)',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: tempStopDuration),
                onChanged: (value) =>
                    setLocalState(() => tempStopDuration = value),
              ),
              if (selectedNature?.endsWith(':') == true) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: customNatureController,
                  decoration: const InputDecoration(
                    labelText: 'Nature (complément)',
                    border: OutlineInputBorder(),
                    hintText: 'Maximum 20 caractères par ligne',
                  ),
                  maxLines: 5,
                  onChanged: (value) {
                    final words = value.split(' ');
                    final lines = <String>[];
                    String currentLine = '';
                    for (var word in words) {
                      if ((currentLine +
                                  (currentLine.isEmpty ? '' : ' ') +
                                  word)
                              .length <=
                          20) {
                        currentLine += (currentLine.isEmpty ? '' : ' ') + word;
                      } else {
                        if (currentLine.isNotEmpty) {
                          lines.add(currentLine);
                        }
                        currentLine = word;
                      }
                    }
                    if (currentLine.isNotEmpty) {
                      lines.add(currentLine);
                    }
                    setLocalState(() => customNature = lines.join('\n'));
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                String finalNature = '';
                if (selectedNature != null) {
                  if (selectedNature?.endsWith(':') == true) {
                    if (customNature.trim().isEmpty) return;
                    finalNature = '$selectedNature\n${customNature.trim()}';
                  } else {
                    finalNature = selectedNature!;
                  }
                } else {
                  return;
                }
                if (tempStopDuration.isNotEmpty && finalNature.isNotEmpty) {
                  setState(() {
                    stops[index] = {
                      'id': stop['id'],
                      'duration': tempStopDuration,
                      'nature': finalNature,
                    };
                    final totalDowntime = _calculateDowntimeFromStops(stops);
                    data['${modulePrefix}TotalDowntime'] = totalDowntime;
                    data['${modulePrefix}OperatingTime'] =
                        (24 * 60 - totalDowntime).clamp(0, 24 * 60);
                    data['${modulePrefix}Stops'] = stops;
                    setDialogState(() {});
                    onTotalDowntimeChanged(totalDowntime);
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Machines/Equipment Stopped Editor
  Future<void> _showMachinesEquipmentStoppedEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'M/Eng Arrêtés',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Equipment List Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Équipements',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddEquipmentDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['equipmentList'] is List &&
                                    (data['equipmentList'] as List).isNotEmpty)
                                  ...List.from(data['equipmentList'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final equipment = entry.value;
                                    final isSelected =
                                        _selectedEquipmentIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.blue.withValues(alpha: 0.1),
                                        title: Text('Équipement ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Type: ${equipment['equipmentType'] ?? '-'}'),
                                            Text(
                                                'Raison: ${equipment['Reason'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.blue)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedEquipmentIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditEquipmentDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier l\'équipement',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteEquipmentDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip:
                                                  'Supprimer l\'équipement',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun équipement arrêté ajouté',
                                      style: TextStyle(color: Colors.grey)),
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
        ),
      ),
    );
  }

  // Add Equipment Dialog for Machines/Equipment Stopped
  Future<void> _showAddEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    String equipmentType = '';
    String stopReason = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Aj équipement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type d\'équipement',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => equipmentType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Raison de l\'arrêt',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => setState(() => stopReason = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (equipmentType.isNotEmpty && stopReason.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['equipmentList'] == null) {
                    updatedData['equipmentList'] = [];
                  }
                  (updatedData['equipmentList'] as List).add({
                    'id': DateTime.now().millisecondsSinceEpoch.toString(),
                    'equipmentType': equipmentType,
                    'Reason': stopReason,
                  });

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Equipment Dialog for Machines/Equipment Stopped
  Future<void> _showEditEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final equipment = (data['equipmentList'] as List)[index];
    String equipmentType = equipment['equipmentType'] ?? '';
    String stopReason = equipment['Reason'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier l\'équipement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Type d\'équipement',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: equipmentType),
                onChanged: (value) => setState(() => equipmentType = value),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Raison de l\'arrêt',
                  border: OutlineInputBorder(),
                ),
                controller: TextEditingController(text: stopReason),
                maxLines: 3,
                onChanged: (value) => setState(() => stopReason = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (equipmentType.isNotEmpty && stopReason.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['equipmentList'] as List)[index] = {
                    'id': equipment['id'],
                    'equipmentType': equipmentType,
                    'Reason': stopReason,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete Equipment Dialog for Machines/Equipment Stopped
  Future<void> _showDeleteEquipmentDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'équipement'),
        content:
            const Text('Êtes-vous sûr de vouloir supprimer cet équipement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['equipmentList'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Truck Tracking Editor
  Future<void> _showTruckTrackingEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final data = report.additionalData ?? {};
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modifier - R Camion',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: context,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Mine and Sortie Card
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
                                _buildEditableField(
                                  context: context,
                                  label: 'Mine',
                                  value: data['mine'] ?? '',
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['mine'] = value;
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Zone',
                                  value: data['zone'] ?? '',
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['zone'] = value;
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Sortie',
                                  value: data['sortie'] ?? '',
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['sortie'] = value;
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Equipment and Operation Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Équipement et Opération',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: context,
                                  label: 'équipement',
                                  value: data['equipment'] ??
                                      data['selectedEquipment'] ??
                                      '',
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['equipment'] = value;
                                    updatedData['selectedEquipment'] = value;
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: context,
                                  label: 'Opération',
                                  value: data['operationType'] ?? '',
                                  onSave: (value) async {
                                    final updatedData =
                                        Map<String, dynamic>.from(data);
                                    updatedData['operationType'] = value;
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: updatedData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trucks Management Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Camions',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showDetailedTruckDialog(
                                          report,
                                          data,
                                          null,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['truckData'] is List &&
                                    (data['truckData'] as List).isNotEmpty)
                                  ...List.from(data['truckData'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final truck = entry.value;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(
                                            '${truck['truckNumber'] ?? index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Chauffeur: ${truck['driver1'] ?? '-'}'),
                                            if (truck['counts'] is List &&
                                                (truck['counts'] as List)
                                                    .isNotEmpty)
                                              Text(
                                                  'Voyages: ${(truck['counts'] as List).length}'),
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showDetailedTruckDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le camion',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteTruckDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le camion',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun camion ajouté',
                                      style: TextStyle(color: Colors.grey)),
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
        ),
      ),
    );
  }

  // Detailed Truck Dialog (Add/Edit)
  Future<void> _showDetailedTruckDialog(
      Report report,
      Map<String, dynamic> data,
      int? index,
      StateSetter
          setReportState, // Used to trigger rebuilds in parent if needed, though Navigator.pop usually suffices.
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final isEditing = index != null;
    final truck =
        isEditing ? (data['truckData'] as List)[index] : <String, dynamic>{};
    final truckId = truck['id'] ?? const Uuid().v4();

    // Initialize temporary state
    String truckNumber = truck['truckNumber'] ?? '';
    String driver1 = truck['driver1'] ?? '';
    List<Map<String, dynamic>> counts = List<Map<String, dynamic>>.from(
        (truck['counts'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ??
            []);

    // Controllers
    final driverController = TextEditingController(text: driver1);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void addTrip() {
            var timeController = TextEditingController();
            String? selectedEquipment;
            DateTime selectedTripTime = DateTime.now();

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Ajouter'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Temps du voyage',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TimePickerSpinner(
                      is24HourMode: true,
                      isShowSeconds: false,
                      normalTextStyle:
                          const TextStyle(fontSize: 18, color: Colors.black54),
                      highlightedTextStyle:
                          const TextStyle(fontSize: 24, color: Colors.black),
                      spacing: 50,
                      itemHeight: 60,
                      isForce2Digits: true,
                      time: selectedTripTime,
                      onTimeChange: (dateTime) {
                        selectedTripTime = dateTime;
                        timeController.text =
                            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedEquipment,
                      decoration: const InputDecoration(
                        labelText: "Equipement utilisé",
                        border: OutlineInputBorder(),
                      ),
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
                      onChanged: (value) => selectedEquipment = value,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (timeController.text.isNotEmpty &&
                          selectedEquipment != null) {
                        setState(() {
                          counts.add({
                            'time': timeController.text,
                            'equipment': selectedEquipment,
                          });
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Ajouter'),
                  ),
                ],
              ),
            );
          }

          void viewTrips() {
            showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setTripState) => AlertDialog(
                  title: const Text('Détails des voyages'),
                  content: counts.isEmpty
                      ? const Text('Aucun voyage ajouté.')
                      : SizedBox(
                          width: 300,
                          height: 400,
                          child: SingleChildScrollView(
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Temps: ${trip['time']}'),
                                          Text(
                                              'Equipement: ${trip['equipment'] ?? '-'}'),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () {
                                          setTripState(() {
                                            counts.removeAt(i);
                                          });
                                          // Also update parent state to ensure sync
                                          setState(() {});
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
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 800,
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
                          isEditing ? "Modifier Camion" : "Nouveau Camion",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
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
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: predefinedTrucks.contains(truckNumber)
                                ? truckNumber
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Camion',
                              border: OutlineInputBorder(),
                            ),
                            items: predefinedTrucks.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => truckNumber = value);
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          Text("Informations sur le conducteur",
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          TextField(
                            controller: driverController,
                            decoration: const InputDecoration(
                              labelText: 'Chauffeur',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) => driver1 = value,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.add),
                                  label: const Text('Ajouter Voyage'),
                                  onPressed: addTrip,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.list),
                                  label: const Text('Voir les voyages'),
                                  onPressed: viewTrips,
                                ),
                              ),
                            ],
                          ),
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
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            if (truckNumber.isNotEmpty && driver1.isNotEmpty) {
                              final updatedData =
                                  Map<String, dynamic>.from(data);
                              if (updatedData['truckData'] == null) {
                                updatedData['truckData'] = [];
                              }

                              final newTruck = {
                                'id': truckId,
                                'truckNumber': truckNumber,
                                'driver1': driver1,
                                'counts': counts,
                              };

                              if (isEditing) {
                                (updatedData['truckData'] as List)[index] =
                                    newTruck;
                              } else {
                                (updatedData['truckData'] as List)
                                    .add(newTruck);
                              }

                              final updatedReport = Report(
                                id: report.id,
                                description: report.description,
                                type: report.type,
                                group: report.group,
                                date: report.date,
                                additionalData: updatedData,
                              );

                              Navigator.pop(context);
                              _saveReportUpdate(
                                  updatedReport, scaffoldMessenger, l10n);
                            }
                          },
                          child: const Text('Enregistrer'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Delete Truck Dialog for Truck Tracking
  Future<void> _showDeleteTruckDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le camion'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce camion ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['truckData'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // R0 Report Editor
  Future<void> _showR0ReportEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    Map<String, dynamic> data = Map.from(report.additionalData ?? {});
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modifier R0',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: dialogContext,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Info OIB/EE',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showEditR0InfoDialog(
                                          report,
                                          data,
                                          scaffoldMessenger,
                                          l10n),
                                      tooltip:
                                          'Modifier les informations OIB/EE',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _buildSummaryItem('Mine', data['mine'] ?? ''),
                                _buildSummaryItem('Zone', data['zone'] ?? ''),
                                _buildSummaryItem(
                                    'Sortie', data['sortie'] ?? ''),
                                _buildSummaryItem(
                                    'Catégorie', data['Category'] ?? ''),
                                _buildSummaryItem('Type', data['Type'] ?? ''),
                                _buildSummaryItem(
                                    'Modèle', data['Model'] ?? ''),
                                _buildSummaryItem(
                                    'Poste',
                                    data['selectedPoste'] ??
                                        data['poste'] ??
                                        ''),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Compteurs',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (!(data['Compteurs'] is List &&
                                        (data['Compteurs'] as List).isNotEmpty))
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showAddR0CounterDialog(report,
                                                data, scaffoldMessenger, l10n),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Ajouter'),
                                      ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['Compteurs'] is List &&
                                    (data['Compteurs'] as List).isNotEmpty)
                                  ...List.from(data['Compteurs'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final compteur = entry.value;
                                    final isSelected =
                                        _selectedCounterIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.blue.withValues(alpha: 0.1),
                                        title: Text('Compteur ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Début: ${compteur['duree'] ?? '-'}'),
                                            Text(
                                                'Fin: ${compteur['note'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.blue)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedCounterIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditR0CounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le compteur',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteR0CounterDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le compteur',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun compteur ajouté',
                                      style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Arrêts Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Arrêts',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddR0StopDialog(
                                          report,
                                          data,
                                          setDialogState,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['Arrets'] is List &&
                                    (data['Arrets'] as List).isNotEmpty)
                                  ...List.from(data['Arrets'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final arret = entry.value;
                                    final isSelected =
                                        _selectedStopIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.blue.withValues(alpha: 0.1),
                                        title: Text('Arrêt ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Type: ${arret['Arret'] ?? '-'}'),
                                            Text(
                                                'Début: ${arret['Début'] ?? '-'}'),
                                            Text('Fin: ${arret['Fin'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.blue)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStopIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditR0StopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier l\'arrêt',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteR0StopDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      setDialogState,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer l\'arrêt',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text('Aucun arrêt ajouté',
                                      style: TextStyle(color: Colors.grey)),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Exploitation',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0ExploitationDialog(report,
                                              data, scaffoldMessenger, l10n),
                                      tooltip: 'Modifier l\'exploitation',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['exploitation'] is Map) ...[
                                  _buildSummaryItem(
                                      'H.M', data['exploitation']['H.M'] ?? ''),
                                  _buildSummaryItem(
                                      'H.A', data['exploitation']['H.A'] ?? ''),
                                  _buildSummaryItem('Tonnage',
                                      data['exploitation']['Tonnage'] ?? ''),
                                  _buildSummaryItem(
                                      'Rendeme',
                                      data['exploitation']['Rendeme'] ??
                                          data['exploitation']['Rendeme'] ??
                                          ''),
                                ] else
                                  const Text('Aucune donnée d\'exploitation',
                                      style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Répartition Travail Section
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Répartition Travail',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddR0WorkDialog(
                                          report,
                                          data,
                                          scaffoldMessenger,
                                          l10n),
                                      icon: const Icon(Icons.add),
                                      label: const Text('Aj'),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['Répartition Travail'] is List &&
                                    (data['Répartition Travail'] as List)
                                        .isNotEmpty)
                                  ...List.from(data['Répartition Travail'])
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final repartition = entry.value;
                                    final isSelected =
                                        _selectedStockIndex == index;
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      color: isSelected
                                          ? Colors.blue.withValues(alpha: 0.1)
                                          : null,
                                      elevation: isSelected ? 4 : 1,
                                      child: ListTile(
                                        selected: isSelected,
                                        selectedTileColor:
                                            Colors.blue.withValues(alpha: 0.1),
                                        title: Text('Travail ${index + 1}'),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                'Chantier: ${repartition['Chantier'] ?? repartition['chantier'] ?? '-'}'),
                                            Text(
                                                'Temps: ${repartition['temps'] ?? repartition['Temps'] ?? '-'}'),
                                            Text(
                                                'Imputation: ${repartition['imputation'] ?? repartition['Imputation'] ?? '-'}'),
                                          ],
                                        ),
                                        leading: isSelected
                                            ? const Icon(Icons.check_circle,
                                                color: Colors.blue)
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedStockIndex =
                                                isSelected ? null : index;
                                          });
                                        },
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit,
                                                  size: 18),
                                              onPressed: () =>
                                                  _showEditR0WorkDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Modifier le travail',
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  size: 18, color: Colors.red),
                                              onPressed: () =>
                                                  _showDeleteR0WorkDialog(
                                                      report,
                                                      data,
                                                      index,
                                                      scaffoldMessenger,
                                                      l10n),
                                              tooltip: 'Supprimer le travail',
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  })
                                else
                                  const Text(
                                      'Aucune répartition de travail ajoutée',
                                      style: TextStyle(color: Colors.grey)),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Personnel',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0PersonnelDialog(report,
                                              data, scaffoldMessenger, l10n),
                                      tooltip: 'Modifier le personnel',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['personnel'] is Map) ...[
                                  _buildSummaryItem(
                                      'Conductr',
                                      data['personnel']['conductr'] ??
                                          data['personnel']['conductr'] ??
                                          ''),
                                  _buildSummaryItem('Graisseur',
                                      data['personnel']['graisseur'] ?? ''),
                                  _buildSummaryItem('Matricules',
                                      data['personnel']['matricules'] ?? ''),
                                ] else
                                  const Text('Aucune donnée de personnel',
                                      style: TextStyle(color: Colors.grey)),
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Consommation',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () =>
                                          _showEditR0ConsumptionDialog(report,
                                              data, scaffoldMessenger, l10n),
                                      tooltip: 'Modifier la consommation',
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                if (data['consommation'] is Map) ...[
                                  _buildSummaryItem('Tricone',
                                      data['consommation']['tricone'] ?? ''),
                                  _buildSummaryItem('Gasoil',
                                      data['consommation']['gasoil'] ?? ''),
                                ] else
                                  const Text('Aucune donnée de consommation',
                                      style: TextStyle(color: Colors.grey)),
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
        ),
      ),
    );
  }

  // Edit R0 Info OIB/EE Dialog
  Future<void> _showEditR0InfoDialog(Report report, Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    // Initialize with current values
    String selectedMine = data['mine'] ?? '';
    String selectedZone = data['zone'] ?? '';
    String selectedSortie = data['sortie'] ?? '';
    String selectedCategory = data['Category'] ?? '';
    String selectedType = data['Type'] ?? '';
    String selectedModel = data['Model'] ?? '';
    String selectedPoste = data['selectedPoste'] ?? data['poste'] ?? '';

    int step = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          MineData? mineData = selectedMine.isNotEmpty
              ? minesData.where((m) => m.name == selectedMine).isNotEmpty
                  ? minesData.firstWhere((m) => m.name == selectedMine)
                  : null
              : null;
          ZoneData? zoneData = (mineData != null && selectedZone.isNotEmpty)
              ? mineData.zones.where((z) => z.name == selectedZone).isNotEmpty
                  ? mineData.zones.firstWhere((z) => z.name == selectedZone)
                  : null
              : null;

          void goNext() => setDialogState(() => step++);
          void goBack() => setDialogState(() => step--);

          Widget content;
          if (step == 0) {
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedMine.isNotEmpty ? selectedMine : null,
                    decoration: const InputDecoration(
                        labelText: 'Mine', border: OutlineInputBorder()),
                    items: minesData
                        .map((mine) => DropdownMenuItem(
                            value: mine.name, child: Text(mine.name)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedMine = value ?? '';
                        selectedZone = '';
                        selectedSortie = '';
                        selectedPoste = '';
                        selectedCategory = '';
                        selectedType = '';
                        selectedModel = '';
                      });
                    },
                  ),
                ),
              ],
            );
          } else if (step == 1 && mineData != null) {
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedZone.isNotEmpty ? selectedZone : null,
                    decoration: const InputDecoration(
                        labelText: 'Zone', border: OutlineInputBorder()),
                    items: mineData.zones
                        .map((zone) => DropdownMenuItem(
                            value: zone.name, child: Text(zone.name)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedZone = value ?? '';
                        selectedSortie = '';
                        selectedPoste = '';
                        selectedCategory = '';
                        selectedType = '';
                        selectedModel = '';
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
                    value:
                        selectedCategory.isNotEmpty ? selectedCategory : null,
                    decoration: const InputDecoration(
                        labelText: 'Catégorie', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'ENGINS', child: Text('ENGINS')),
                      DropdownMenuItem(
                          value: 'MACHINES', child: Text('MACHINES')),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        selectedCategory = value ?? '';
                        selectedType = '';
                        selectedModel = '';
                      });
                    },
                  ),
                ),
              ],
            );
          } else if (step == 3 && selectedCategory.isNotEmpty) {
            final types = selectedCategory == 'ENGINS'
                ? enginsData.keys.toList()
                : machinesData.keys.toList();
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedType.isNotEmpty ? selectedType : null,
                    decoration: const InputDecoration(
                        labelText: 'Type', border: OutlineInputBorder()),
                    items: types
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedType = value ?? '';
                        selectedModel = '';
                      });
                    },
                  ),
                ),
              ],
            );
          } else if (step == 4 && selectedType.isNotEmpty) {
            final models = selectedCategory == 'ENGINS'
                ? enginsData[selectedType] ?? []
                : machinesData[selectedType] ?? [];
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedModel.isNotEmpty ? selectedModel : null,
                    decoration: const InputDecoration(
                        labelText: 'Modèle', border: OutlineInputBorder()),
                    items: models
                        .map((model) =>
                            DropdownMenuItem(value: model, child: Text(model)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedModel = value ?? '';
                      });
                    },
                  ),
                ),
              ],
            );
          } else if (step == 5 &&
              zoneData != null &&
              zoneData.sorties.isNotEmpty) {
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedSortie.isNotEmpty ? selectedSortie : null,
                    decoration: const InputDecoration(
                        labelText: 'Sortie', border: OutlineInputBorder()),
                    items: zoneData.sorties
                        .map((sortie) => DropdownMenuItem(
                            value: sortie, child: Text(sortie)))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSortie = value ?? '';
                        selectedPoste = '';
                      });
                    },
                  ),
                ),
              ],
            );
          } else if ((step == 5 &&
                  zoneData != null &&
                  zoneData.sorties.isEmpty) ||
              step == 6) {
            content = Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedPoste.isNotEmpty ? selectedPoste : null,
                    decoration: const InputDecoration(
                        labelText: 'Poste', border: OutlineInputBorder()),
                    items: posteOrder
                        .map((poste) => DropdownMenuItem(
                            value: poste, child: Text('$poste Poste')))
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedPoste = value ?? posteOrder.first;
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
          bool canFinish = selectedMine.isNotEmpty &&
              selectedZone.isNotEmpty &&
              selectedCategory.isNotEmpty &&
              selectedType.isNotEmpty &&
              selectedModel.isNotEmpty &&
              (zoneData == null ||
                  zoneData.sorties.isEmpty ||
                  selectedSortie.isNotEmpty) &&
              selectedPoste.isNotEmpty;

          return AlertDialog(
            title: const Text('Modifier les informations OIB/EE'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step == 0) ...[
                    const Text('Sélection de la Mine',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if (step == 1) ...[
                    const Text('Sélection de la Zone',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if (step == 2) ...[
                    const Text('Sélection Catégorie',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if (step == 3) ...[
                    const Text('Sélection Type',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if (step == 4) ...[
                    const Text('Sélection Modèle',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if (step == 5 &&
                      zoneData != null &&
                      zoneData.sorties.isNotEmpty) ...[
                    const Text('Sélection Sortie',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ] else if ((step == 5 &&
                          zoneData != null &&
                          zoneData.sorties.isEmpty) ||
                      step == 6) ...[
                    const Text('Sélection Poste',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    content,
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (step > 0)
                        TextButton(
                          onPressed: goBack,
                          child: const Text('Précédent'),
                        )
                      else
                        const SizedBox(),
                      if (step < 6 &&
                          (step != 5 ||
                              (zoneData != null &&
                                  zoneData.sorties.isNotEmpty)))
                        ElevatedButton(
                          onPressed: () {
                            if ((step == 0 && selectedMine.isNotEmpty) ||
                                (step == 1 && selectedZone.isNotEmpty) ||
                                (step == 2 && selectedCategory.isNotEmpty) ||
                                (step == 3 && selectedType.isNotEmpty) ||
                                (step == 4 && selectedModel.isNotEmpty) ||
                                (step == 5 &&
                                    ((zoneData != null &&
                                            zoneData.sorties.isEmpty) ||
                                        selectedSortie.isNotEmpty))) {
                              goNext();
                            }
                          },
                          child: const Text('Suivant'),
                        )
                      else if (canFinish)
                        ElevatedButton(
                          onPressed: () {
                            final updatedData = Map<String, dynamic>.from(data);
                            updatedData['mine'] = selectedMine;
                            updatedData['zone'] = selectedZone;
                            updatedData['sortie'] = selectedSortie;
                            updatedData['Category'] = selectedCategory;
                            updatedData['Type'] = selectedType;
                            updatedData['Model'] = selectedModel;
                            updatedData['selectedPoste'] = selectedPoste;

                            final updatedReport = Report(
                              id: report.id,
                              description: 'Rapport R0 - $selectedPoste',
                              type: selectedModel,
                              group: report.group,
                              date: report.date,
                              additionalData: updatedData,
                            );

                            Navigator.pop(context);
                            _saveReportUpdate(
                                updatedReport, scaffoldMessenger, l10n);
                          },
                          child: const Text('Modifier'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Add R0 Counter Dialog
  Future<void> _showAddR0CounterDialog(Report report, Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    String duree = '';
    String note = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter un compteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Début'),
                onChanged: (value) => setState(() => duree = value),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Fin'),
                onChanged: (value) => setState(() => note = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (duree.isNotEmpty || note.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['Compteurs'] == null) {
                    updatedData['Compteurs'] = [];
                  }
                  (updatedData['Compteurs'] as List).add({
                    'duree': duree,
                    'note': note,
                  });

                  // Recalculate hours
                  _recalculateR0Hours(updatedData);

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit R0 Counter Dialog
  Future<void> _showEditR0CounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final compteur = (data['Compteurs'] as List)[index];
    String duree = compteur['duree'] ?? '';
    String note = compteur['note'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier le compteur'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Début'),
                controller: TextEditingController(text: duree),
                onChanged: (value) => setState(() => duree = value),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Fin'),
                controller: TextEditingController(text: note),
                onChanged: (value) => setState(() => note = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedData = Map<String, dynamic>.from(data);
                (updatedData['Compteurs'] as List)[index] = {
                  'duree': duree,
                  'note': note,
                };

                // Recalculate hours
                _recalculateR0Hours(updatedData);

                final updatedReport = Report(
                  id: report.id,
                  description: report.description,
                  type: report.type,
                  group: report.group,
                  date: report.date,
                  additionalData: updatedData,
                );

                Navigator.pop(context);
                _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
              },
              child: const Text('Modifier'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete R0 Counter Dialog
  Future<void> _showDeleteR0CounterDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compteur'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce compteur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['Compteurs'] as List).removeAt(index);

              // Recalculate hours
              _recalculateR0Hours(updatedData);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Build Add/Edit R0 Stop Dialog (same as in R0 creation)
  Widget _buildAddR0StopDialog(BuildContext context,
      {Map<String, String>? initialItem}) {
    int step = 0;
    String? selectedCategory = initialItem != null
        ? arretCategories.keys.firstWhere(
            (cat) => arretCategories[cat]!.contains(initialItem['Arret']),
            orElse: () => '')
        : null;
    String? selectedType = initialItem?['Arret'];
    String startTime = initialItem?['Début'] ?? '';
    String endTime = initialItem?['Fin'] ?? '';
    return StatefulBuilder(
      builder: (context, setDialogState) {
        Widget content;
        if (step == 0) {
          content = Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Catégorie', border: OutlineInputBorder()),
                  items: arretCategories.keys
                      .map((cat) =>
                          DropdownMenuItem(value: cat, child: Text(cat)))
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
                  decoration: const InputDecoration(
                      labelText: 'Type d\'arrêt', border: OutlineInputBorder()),
                  items: arretCategories[selectedCategory]!
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
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
                subtitle: Text(
                    startTime.isEmpty ? 'Sélectionner l\'heure' : startTime),
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
                            normalTextStyle: const TextStyle(
                                fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(
                                fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(
                                  hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Heure fin'),
                subtitle:
                    Text(endTime.isEmpty ? 'Sélectionner l\'heure' : endTime),
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
                            normalTextStyle: const TextStyle(
                                fontSize: 18, color: Colors.black54),
                            highlightedTextStyle: const TextStyle(
                                fontSize: 24, color: Colors.black),
                            spacing: 50,
                            itemHeight: 60,
                            isForce2Digits: true,
                            onTimeChange: (dateTime) {
                              tempTime = TimeOfDay(
                                  hour: dateTime.hour, minute: dateTime.minute);
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annuler'),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(tempTime),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endTime =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
              const Text('Sélection de la catégorie',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 1) ...[
              const Text('Sélection du type d\'arrêt',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              content,
            ] else if (step == 2) ...[
              const Text('Saisie des détails',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
                            Navigator.of(context).pop({
                              'Arret': selectedType!,
                              'Début': startTime,
                              'Fin': endTime,
                            });
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

  // Add R0 Stop Dialog
  Future<void> _showAddR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un arrêt'),
        content: SingleChildScrollView(
          child: _buildAddR0StopDialog(context),
        ),
      ),
    );

    if (result != null) {
      if (data['Arrets'] == null) {
        data['Arrets'] = [];
      }
      (data['Arrets'] as List).add(result);

      // Recalculate hours
      _recalculateR0Hours(data);

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Edit R0 Stop Dialog
  Future<void> _showEditR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final arret = (data['Arrets'] as List)[index] as Map<String, dynamic>;
    final initialItem = {
      'Arret': (arret['Arret'] ?? '').toString(),
      'Début': (arret['Début'] ?? '').toString(),
      'Fin': (arret['Fin'] ?? '').toString(),
    };

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier l\'arrêt'),
        content: SingleChildScrollView(
          child: _buildAddR0StopDialog(context, initialItem: initialItem),
        ),
      ),
    );

    if (result != null) {
      (data['Arrets'] as List)[index] = result;

      // Recalculate hours
      _recalculateR0Hours(data);

      setDialogState(() {});

      final updatedReport = Report(
        id: report.id,
        description: report.description,
        type: report.type,
        group: report.group,
        date: report.date,
        additionalData: data,
      );

      _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
    }
  }

  // Delete R0 Stop Dialog
  Future<void> _showDeleteR0StopDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      StateSetter setDialogState,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer l\'arrêt'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet arrêt ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              (data['Arrets'] as List).removeAt(index);

              // Recalculate hours
              _recalculateR0Hours(data);

              setDialogState(() {});

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: data,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Edit R0 Exploitation Dialog
  Future<void> _showEditR0ExploitationDialog(
      Report report,
      Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final exploitation = data['exploitation'] ?? {};
    final hmController = TextEditingController(text: exploitation['H.M'] ?? '');
    final haController = TextEditingController(text: exploitation['H.A'] ?? '');
    final tonnageController =
        TextEditingController(text: exploitation['Tonnage'] ?? '');
    final rendemeController =
        TextEditingController(text: exploitation['Rendeme'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier l\'exploitation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'H.M'),
                    controller: hmController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'H.A'),
                    controller: haController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Tonnage'),
                    controller: tonnageController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Rendeme'),
                    controller: rendemeController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final updatedData = Map<String, dynamic>.from(data);
                  updatedData['exploitation'] = {
                    'H.M': hmController.text,
                    'H.A': haController.text,
                    'Tonnage': tonnageController.text,
                    'Rendeme': rendemeController.text,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      hmController.dispose();
      haController.dispose();
      tonnageController.dispose();
      rendemeController.dispose();
    }
  }

  // Add R0 Work Dialog
  Future<void> _showAddR0WorkDialog(Report report, Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    String chantier = '';
    String temps = '';
    String imputation = '';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajouter une répartition de travail'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Chantier'),
                onChanged: (value) => setState(() => chantier = value),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Temps'),
                onChanged: (value) => setState(() => temps = value),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Imputation'),
                onChanged: (value) => setState(() => imputation = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                if (chantier.isNotEmpty ||
                    temps.isNotEmpty ||
                    imputation.isNotEmpty) {
                  final updatedData = Map<String, dynamic>.from(data);
                  if (updatedData['Répartition Travail'] == null) {
                    updatedData['Répartition Travail'] = [];
                  }
                  (updatedData['Répartition Travail'] as List).add({
                    'Chantier': chantier,
                    'Temps': temps,
                    'Imputation': imputation,
                  });

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                }
              },
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit R0 Work Dialog
  Future<void> _showEditR0WorkDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final repartition = (data['Répartition Travail'] as List)[index];
    final chantierController = TextEditingController(
        text: repartition['Chantier'] ?? repartition['chantier'] ?? '');
    final tempsController = TextEditingController(
        text: repartition['Temps'] ?? repartition['temps'] ?? '');
    final imputationController = TextEditingController(
        text: repartition['Imputation'] ?? repartition['imputation'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier la répartition de travail'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Chantier'),
                    controller: chantierController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Temps'),
                    controller: tempsController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Imputation'),
                    controller: imputationController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final updatedData = Map<String, dynamic>.from(data);
                  (updatedData['Répartition Travail'] as List)[index] = {
                    'Chantier': chantierController.text,
                    'Temps': tempsController.text,
                    'Imputation': imputationController.text,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      chantierController.dispose();
      tempsController.dispose();
      imputationController.dispose();
    }
  }

  // Delete R0 Work Dialog
  Future<void> _showDeleteR0WorkDialog(
      Report report,
      Map<String, dynamic> data,
      int index,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la répartition de travail'),
        content: const Text(
            'Êtes-vous sûr de vouloir supprimer cette répartition de travail ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = Map<String, dynamic>.from(data);
              (updatedData['Répartition Travail'] as List).removeAt(index);

              final updatedReport = Report(
                id: report.id,
                description: report.description,
                type: report.type,
                group: report.group,
                date: report.date,
                additionalData: updatedData,
              );

              Navigator.pop(context);
              _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // Edit R0 Personnel Dialog
  Future<void> _showEditR0PersonnelDialog(
      Report report,
      Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final personnel = data['personnel'] ?? {};
    final conductrController =
        TextEditingController(text: personnel['conductr'] ?? '');
    final graisseurController =
        TextEditingController(text: personnel['graisseur'] ?? '');
    final matriculesController =
        TextEditingController(text: personnel['matricules'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier le personnel'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Conductr'),
                    controller: conductrController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Graisseur'),
                    controller: graisseurController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Matricules'),
                    controller: matriculesController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final updatedData = Map<String, dynamic>.from(data);
                  updatedData['personnel'] = {
                    'conductr': conductrController.text,
                    'graisseur': graisseurController.text,
                    'matricules': matriculesController.text,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      conductrController.dispose();
      graisseurController.dispose();
      matriculesController.dispose();
    }
  }

  // Edit R0 Consumption Dialog
  Future<void> _showEditR0ConsumptionDialog(
      Report report,
      Map<String, dynamic> data,
      ScaffoldMessengerState scaffoldMessenger,
      AppLocalizations l10n) async {
    final consommation = data['consommation'] ?? {};
    final triconeController =
        TextEditingController(text: consommation['tricone'] ?? '');
    final gasoilController =
        TextEditingController(text: consommation['gasoil'] ?? '');

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Modifier la consommation'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Tricone'),
                    controller: triconeController,
                  ),
                  TextField(
                    decoration: const InputDecoration(labelText: 'Gasoil'),
                    controller: gasoilController,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final updatedData = Map<String, dynamic>.from(data);
                  updatedData['consommation'] = {
                    'tricone': triconeController.text,
                    'gasoil': gasoilController.text,
                  };

                  final updatedReport = Report(
                    id: report.id,
                    description: report.description,
                    type: report.type,
                    group: report.group,
                    date: report.date,
                    additionalData: updatedData,
                  );

                  Navigator.pop(context);
                  _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                },
                child: const Text('Modifier'),
              ),
            ],
          ),
        ),
      );
    } finally {
      triconeController.dispose();
      gasoilController.dispose();
    }
  }

  // Generic Editor
  Future<void> _showGenericEditor(Report report,
      ScaffoldMessengerState scaffoldMessenger, AppLocalizations l10n) async {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Modifier - ${report.type}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Info Card
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Info',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: 'Description',
                                  value: report.description,
                                  isEditable: false,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: value,
                                      type: report.type,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableDateField(
                                  context: dialogContext,
                                  label: 'Date',
                                  value: report.date,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: report.group,
                                      date: value,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: 'Type',
                                  value: report.type,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: value,
                                      group: report.group,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                _buildEditableField(
                                  context: dialogContext,
                                  label: 'Groupe',
                                  value: report.group,
                                  onSave: (value) async {
                                    final navigator =
                                        Navigator.of(dialogContext);
                                    final updatedReport = Report(
                                      id: report.id,
                                      description: report.description,
                                      type: report.type,
                                      group: value,
                                      date: report.date,
                                      additionalData: report.additionalData,
                                    );
                                    await _saveReportUpdate(
                                        updatedReport, scaffoldMessenger, l10n);
                                    if (mounted) {
                                      navigator.pop();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Additional Data Card (if any)
                        if (report.additionalData != null &&
                            report.additionalData!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Données supplémentaires',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Divider(height: 16),
                                  _buildGenericAdditionalData(
                                      report.additionalData!),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to display generic additional data
  Widget _buildGenericAdditionalData(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${entry.key}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value.toString(),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
