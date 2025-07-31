import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';
import 'package:intl/intl.dart';

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

  // Available postes for filtering
  List<String> _availablePostes = [
    '3ème',
    '1er', 
    '2ème',
  ];

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
          SnackBar(content: Text(AppLocalizations.of(context)!.errorSavingReport)),
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
        if (kDebugMode && (report.type == 'R0' || report.type == 'Suivi Camion')) {
          debugPrint('Report ${report.id}: type=${report.type}, poste=$poste, filter=$_selectedPosteFilter');
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
          SnackBar(content: Text(AppLocalizations.of(context)!.errorDeletingReport)),
        );
      }
    }
  }

  Future<void> _editReport(Report report) async {
    if (!mounted) return;
    final context = this.context;
    final l10n = AppLocalizations.of(context)!;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Get the steps from additionalData
    final steps = report.additionalData?.entries ?? [];
    
    // First show the list of steps
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.editReport),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Basic report info
              ListTile(
                title: Text(l10n.description),
                subtitle: Text(report.description),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _editStep(
                    context: context,
                    title: l10n.description,
                    initialValue: report.description,
                    onSave: (value) async {
                      final updatedReport = Report(
                        id: report.id,
                        description: value,
                        type: report.type,
                        group: report.group,
                        date: report.date,
                        additionalData: report.additionalData,
                      );
                      await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                    },
                  );
                },
              ),
              ListTile(
                title: Text(l10n.type),
                subtitle: Text(report.type),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _editStep(
                    context: context,
                    title: l10n.type,
                    initialValue: report.type,
                    onSave: (value) async {
                      final updatedReport = Report(
                        id: report.id,
                        description: report.description,
                        type: value,
                        group: report.group,
                        date: report.date,
                        additionalData: report.additionalData,
                      );
                      await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                    },
                  );
                },
              ),
              ListTile(
                title: Text(l10n.group),
                subtitle: Text(report.group),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _editStep(
                    context: context,
                    title: l10n.group,
                    initialValue: report.group,
                    onSave: (value) async {
                      final updatedReport = Report(
                        id: report.id,
                        description: report.description,
                        type: report.type,
                        group: value,
                        date: report.date,
                        additionalData: report.additionalData,
                      );
                      await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                    },
                  );
                },
              ),
              ListTile(
                title: Text(l10n.date),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(report.date)),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _editDate(
                    context: context,
                    initialDate: report.date,
                    onSave: (value) async {
                      final updatedReport = Report(
                        id: report.id,
                        description: report.description,
                        type: report.type,
                        group: report.group,
                        date: value,
                        additionalData: report.additionalData,
                      );
                      await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                    },
                  );
                },
              ),
              const Divider(),
              // Additional data steps
              ...steps.map((step) => ListTile(
                title: Text(step.key),
                subtitle: Text(step.value.toString()),
                onTap: () async {
                  Navigator.pop(dialogContext);
                  await _editStep(
                    context: context,
                    title: step.key,
                    initialValue: step.value.toString(),
                    onSave: (value) async {
                      final updatedAdditionalData = Map<String, dynamic>.from(report.additionalData ?? {});
                      updatedAdditionalData[step.key] = value;
                      final updatedReport = Report(
                        id: report.id,
                        description: report.description,
                        type: report.type,
                        group: report.group,
                        date: report.date,
                        additionalData: updatedAdditionalData,
                      );
                      await _saveReportUpdate(updatedReport, scaffoldMessenger, l10n);
                    },
                  );
                },
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _editStep({
    required BuildContext context,
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final TextEditingController controller = TextEditingController(text: initialValue);
    final l10n = AppLocalizations.of(context)!;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: title,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await onSave(controller.text);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
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
                title: Text(DateFormat('yyyy-MM-dd HH:mm').format(selectedDate)),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      final TimeOfDay? time = await showTimePicker(
                        context: dialogContext,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        if (mounted) {
                          setState(() {
                            selectedDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
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
    final l10n = AppLocalizations.of(context)!;

    // Special handling for R0 report
    if (report.type == 'R0') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.reportDetails),
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
                        Text('Date', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Info OIB/EE Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Info OIB/EE', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (data['selectedPoste'] != null) Text('Poste: ${data['selectedPoste']}'),
                        if (data['equipment'] != null) Text('Équipement: ${data['equipment']}'),
                        if (data['mine'] != null) Text('Mine: ${data['mine']}'),
                        if (data['zone'] != null) Text('Zone: ${data['zone']}'),
                        if (data['sortie'] != null) Text('Sortie: ${data['sortie']}'),
                        if (data['operationType'] != null) Text('Type d\'opération: ${data['operationType']}'),
                        if (data['production'] != null) Text('Production: ${data['production']}'),
                      ],
                    ),
                  ),
                ),
                // Compteurs Card
                if (data['indexCompteurs'] is List && (data['indexCompteurs'] as List).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Compteurs', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...List.from(data['indexCompteurs']).map((ic) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• Début: ${ic['duree'] ?? '-'}, Fin: ${ic['note'] ?? '-'}'),
                          )),
                        ],
                      ),
                    ),
                  ),
                // Arrets Card
                if (data['ventilation'] is List && (data['ventilation'] as List).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Arrêts', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...List.from(data['ventilation']).map((v) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• ${v['label'] ?? '-'} - Début: ${v['duree'] ?? '-'}, Fin: ${v['note'] ?? '-'}'),
                          )),
                        ],
                      ),
                    ),
                  ),
                // Exploitation Card
                if (data['exploitation'] is Map && (data['exploitation'] as Map).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Exploitation', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...((data['exploitation'] as Map).entries.map<Widget>((e) => Text('${e.key}: ${e.value}'))),
                        ],
                      ),
                    ),
                  ),
                // Répartition Card
                if (data['repartitionTravail'] is List && (data['repartitionTravail'] as List).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Répartition', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          ...List.from(data['repartitionTravail']).map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• Chantier: ${r['chantier'] ?? '-'}, Temps: ${r['temps'] ?? '-'}, Imputation: ${r['imputation'] ?? '-'}'),
                          )),
                        ],
                      ),
                    ),
                  ),
                // Personnel Card
                if (data['personnel'] is Map && (data['personnel'] as Map).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Personnel', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Conducteur: ${(data['personnel'] as Map)['conducteur'] ?? '-'}'),
                          Text('Graisseur: ${(data['personnel'] as Map)['graisseur'] ?? '-'}'),
                          Text('Matricules: ${(data['personnel'] as Map)['matricules'] ?? '-'}'),
                        ],
                      ),
                    ),
                  ),
                // Consommation Card
                if (data['consommation'] is Map && (data['consommation'] as Map).isNotEmpty)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Consommation', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('Tricone: ${(data['consommation'] as Map)['tricone'] ?? '-'}'),
                          Text('Gasoil: ${(data['consommation'] as Map)['gasoil'] ?? '-'}'),
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

    // Special handling for daily TSUD report
    if (report.type == 'daily TSUD') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.reportDetails),
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
                        Text('Date', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(DateFormat('yyyy-MM-dd').format(report.date)),
                      ],
                    ),
                  ),
                ),
                // Module 1 Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Module 1', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Temps de fonctionnement: ${_formatMinutesToHoursMinutes(data['module1OperatingTime'] ?? 0)}'),
                        Text('Temps d\'arrêt: ${_formatMinutesToHoursMinutes(data['module1TotalDowntime'] ?? 0)}'),
                        if (data['module1Stops'] is List && (data['module1Stops'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Arrêts:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...List.from(data['module1Stops']).map((stop) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text('${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                          )),
                        ],
                      ],
                    ),
                  ),
                ),
                // Module 2 Card
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Module 2', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text('Temps de fonctionnement: ${_formatMinutesToHoursMinutes(data['module2OperatingTime'] ?? 0)}'),
                        Text('Temps d\'arrêt: ${_formatMinutesToHoursMinutes(data['module2TotalDowntime'] ?? 0)}'),
                        if (data['module2Stops'] is List && (data['module2Stops'] as List).isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Arrêts:', style: TextStyle(fontWeight: FontWeight.bold)),
                          ...List.from(data['module2Stops']).map((stop) => Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
                            child: Text('${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                          )),
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

    // Special handling for Machine/Engin Arrêtés report
    if (report.type == 'Machine/Engin Arrêtés') {
      final data = report.additionalData ?? {};
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.reportDetails),
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
                        Text('Date', style: Theme.of(context).textTheme.titleMedium),
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
                        Text('Équipements arrêtés', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        if (data['equipmentList'] is List && (data['equipmentList'] as List).isNotEmpty) ...[
                          ...List.from(data['equipmentList']).asMap().entries.map((entry) {
                            final index = entry.key;
                            final equipment = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Équipement ${index + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Type: ${equipment['equipmentType'] ?? '-'}'),
                                  Text('Raison: ${equipment['stopReason'] ?? '-'}'),
                                  if (index < (data['equipmentList'] as List).length - 1) const Divider(),
                                ],
                              ),
                            );
                          }),
                        ] else ...[
                          const Text('Aucun équipement arrêté', style: TextStyle(color: Colors.grey)),
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

    // Special handling for Suivi Camion report
    if (report.type == 'Suivi Camion') {
      final data = report.additionalData ?? {};
      final truckData = (data['truckData'] is List) ? List.from(data['truckData']) : [];
      
      // Calculate summary data
      final allTrips = truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).toList();
      final Map<String, int> equipmentCounts = {};
      for (var trip in allTrips) {
        final eq = trip['equipment'] ?? '-';
        equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
      }
      
      await showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 600,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
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
                        'Détails du rapport - Suivi Camion',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(dialogContext),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text('${report.date.day}/${report.date.month}/${report.date.year}'),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text(data['poste'] ?? data['selectedPoste'] ?? '-'),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                Text('Opération: ${data['operationType'] ?? '-'}'),
                                if (data['equipment'] != null) Text('Type: ${data['equipment']}'),
                                if (data['selectedEquipment'] != null) Text('Type: ${data['selectedEquipment']}'),
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
                                  style: Theme.of(context).textTheme.titleMedium,
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const Divider(height: 16),
                                if (truckData.isEmpty)
                                  const Text('Aucun camion ajouté.', style: TextStyle(color: Colors.grey)),
                                if (truckData.isNotEmpty)
                                  ...truckData.map((truck) => Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Camion ${truck['truckNumber']}',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Chauffeur: ${truck['driver1'] ?? '-'}'),
                                      if (truck['counts'] != null && (truck['counts'] is List) && (truck['counts'] as List).isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Voyages',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                            color: Colors.green[700],
                                          ),
                                        ),
                                        ...List.generate((truck['counts'] as List).length, (index) {
                                          final count = (truck['counts'] as List)[index];
                                          return Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'v${index + 1}: ',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                                Text(
                                                  count['time'] ?? '-',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                                const SizedBox(width: 12),
                                                const Text('|'),
                                                const SizedBox(width: 12),
                                                Text(
                                                  count['equipment'] ?? '-',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      if (truck != truckData.last) const Divider(),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Résumé', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text('Total de voyages: ${allTrips.length}'),
                                      const SizedBox(height: 8),
                                      ...equipmentCounts.entries.map((e) => Text('Total pour ${e.key}: ${e.value}')),
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
        title: Text(l10n.reportDetails),
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
                      Text(l10n.description, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(report.description.isNotEmpty ? report.description : 'Not filled'),
                    ],
                  ),
                ),
              ),
                const SizedBox(height: 8),
                Text(l10n.additionalData, style: Theme.of(context).textTheme.titleLarge),
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
      case 'activity TNB':
        return _buildActivityReportAdditionalData(data);
      case 'R0':
        return _buildR0ReportAdditionalData(data);
      case 'daily TSUD':
        return _buildDailyReportAdditionalData(data);
      case 'Machine/Engin Arrêtés':
        return _buildMachinesEquipmentStoppedAdditionalData(data);
      case 'Suivi Camion':
        return _buildTruckTrackingAdditionalData(data);
      default:
        // Fallback: show all additionalData key-value pairs
        if (data.isEmpty) return const Text('No additional data');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.entries.map<Widget>((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(entry.value.toString())),
              ],
            ),
          )).toList(),
        );
    }
  }

  Widget _buildActivityReportAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text('Aucune donnée d\'activité disponible.');

    String formatMinutesToHoursMinutes(int? totalMinutes) {
      if (totalMinutes == null || totalMinutes <= 0) return "0h 0m";
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    }

    final stops = (data['stops'] is List) ? List.from(data['stops']) : [];
    final vibratorCounters = (data['vibratorCounters'] is List) ? List.from(data['vibratorCounters']) : [];
    final liaisonCounters = (data['liaisonCounters'] is List) ? List.from(data['liaisonCounters']) : [];
    final stockEntries = (data['stockEntries'] is List) ? List.from(data['stockEntries']) : [];

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
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('T H.A:', formatMinutesToHoursMinutes(data['totalDowntime'] is int ? data['totalDowntime'] : 0)),
                _buildSummaryRow('T H.M:', formatMinutesToHoursMinutes(data['operatingTime'] is int ? data['operatingTime'] : 0)),
                _buildSummaryRow('T H.V:', formatMinutesToHoursMinutes(data['totalVibratorMinutes'] is int ? data['totalVibratorMinutes'] : 0)),
                _buildSummaryRow('T H.L:', formatMinutesToHoursMinutes(data['totalLiaisonMinutes'] is int ? data['totalLiaisonMinutes'] : 0)),
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
                  const Text('Arrêts', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...stops.map((stop) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
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
                  const Text('Compteurs Vibreurs', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...vibratorCounters.map((counter) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('Poste: 9${counter['poste'] ?? '-'}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
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
                  const Text('Compteurs Liaison', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...liaisonCounters.map((counter) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('Poste: \t${counter['poste'] ?? '-'}, Début: ${counter['start'] ?? '-'}, Fin: ${counter['end'] ?? '-'}'),
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
                  const Text('Stocks', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...stockEntries.map((entry) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('Poste: ${entry['poste'] ?? '-'}, Parc: ${entry['park'] ?? '-'}, Type: ${entry['type'] ?? '-'}, Qté: ${entry['quantity'] ?? '-'}, Début: ${entry['startTime'] ?? '-'}'),
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

  Widget _buildR0ReportAdditionalData(Map<String, dynamic> data) {
    // Debug: print the raw additionalData to console
    // ignore: avoid_print
    print('R0 additionalData: $data');
    if (data.isEmpty) return const Text('Aucune donnée R0 disponible.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['mine'] != null) Text('Mine: ${data['mine']}'),
        if (data['zone'] != null) Text('Zone: ${data['zone']}'),
        if (data['sortie'] != null) Text('Sortie: ${data['sortie']}'),
        if (data['rapportNo'] != null) Text('Rapport N°: ${data['rapportNo']}'),
        if (data['unite'] != null) Text('Unité: ${data['unite']}'),
        if (data['indexCompteurs'] is List && (data['indexCompteurs'] as List).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Index Compteurs :', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.from(data['indexCompteurs']).map((ic) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• Durée: ${ic['duree'] ?? '-'}, Note: ${ic['note'] ?? '-'}'),
                  )),
                ],
              ),
            ),
          ),
        if (data['shifts'] != null) Text('Shifts: ${data['shifts']}'),
        if (data['selectedPoste'] != null) Text('Poste sélectionné: ${data['selectedPoste']}'),
        if (data['ventilation'] is List && (data['ventilation'] as List).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ventilation :', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.from(data['ventilation']).map((v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• [${v['code'] ?? '-'}] ${v['label'] ?? '-'} - Durée: ${v['duree'] ?? '-'}, Note: ${v['note'] ?? '-'}'),
                  )),
                ],
              ),
            ),
          ),
        if (data['arretsExplication'] != null) Text('Explication Arrêts: ${data['arretsExplication']}'),
        if (data['exploitation'] is Map && (data['exploitation'] as Map).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exploitation :', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...((data['exploitation'] as Map).entries.map<Widget>((e) => Text('${e.key}: ${e.value}'))),
                ],
              ),
            ),
          ),
        if (data['bulls'] != null) Text('Bulls: ${data['bulls']}'),
        if (data['repartitionTravail'] is List && (data['repartitionTravail'] as List).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Répartition Travail :', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.from(data['repartitionTravail']).map((r) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• Chantier: ${r['chantier'] ?? '-'}, Temps: ${r['temps'] ?? '-'}, Imputation: ${r['imputation'] ?? '-'}'),
                  )),
                ],
              ),
            ),
          ),
        if (data['personnel'] is Map && (data['personnel'] as Map).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Personnel :', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Conducteur: ${(data['personnel'] as Map)['conducteur'] ?? '-'}'),
                  Text('Graisseur: ${(data['personnel'] as Map)['graisseur'] ?? '-'}'),
                  Text('Matricules: ${(data['personnel'] as Map)['matricules'] ?? '-'}'),
                ],
              ),
            ),
          ),
        if (data['consommation'] is Map && (data['consommation'] as Map).isNotEmpty)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Consommation :', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Tricone: ${(data['consommation'] as Map)['tricone'] ?? '-'}'),
                  Text('Gasoil: ${(data['consommation'] as Map)['gasoil'] ?? '-'}'),
                ],
              ),
            ),
          ),
        // Fallback: show any unknown keys in a card layout
        ...data.entries.where((entry) => ![
           'mine', 'zone', 'sortie', 'rapportNo', 'unite', 'indexCompteurs', 'shifts', 'selectedPoste', 'ventilation', 'arretsExplication', 'exploitation', 'bulls', 'repartitionTravail', 'personnel', 'consommation'
        ].contains(entry.key)).map((entry) =>
          Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(entry.value.toString())),
                ],
              ),
            ),
          ),
        ),
        if ((data['mine'] == null) &&
            (data['zone'] == null) &&
            (data['sortie'] == null) &&
            (data['rapportNo'] == null) &&
            (data['unite'] == null) &&
            ((data['indexCompteurs'] == null) || (data['indexCompteurs'] is List && (data['indexCompteurs'] as List).isEmpty)) &&
            (data['shifts'] == null) &&
            (data['selectedPoste'] == null) &&
            ((data['ventilation'] == null) || (data['ventilation'] is List && (data['ventilation'] as List).isEmpty)) &&
            (data['arretsExplication'] == null) &&
            ((data['exploitation'] == null) || (data['exploitation'] is Map && (data['exploitation'] as Map).isEmpty)) &&
            (data['bulls'] == null) &&
            ((data['repartitionTravail'] == null) || (data['repartitionTravail'] is List && (data['repartitionTravail'] as List).isEmpty)) &&
            ((data['personnel'] == null) || (data['personnel'] is Map && (data['personnel'] as Map).isEmpty)) &&
            ((data['consommation'] == null) || (data['consommation'] is Map && (data['consommation'] as Map).isEmpty)))
          const Text('Aucune donnée R0 disponible.'),
      ],
    );
  }

  Widget _buildDailyReportAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text('Aucune donnée quotidienne disponible.');

    String formatMinutesToHoursMinutes(int? totalMinutes) {
      if (totalMinutes == null || totalMinutes <= 0) return "0h 0m";
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      return "${hours}h ${minutes}m";
    }

    final module1Stops = (data['module1Stops'] is List) ? List.from(data['module1Stops']) : [];
    final module2Stops = (data['module2Stops'] is List) ? List.from(data['module2Stops']) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (data['secteur'] != null)
          Text('Secteur: ${data['secteur']}'),
        if (data['rapportNo'] != null)
          Text('Rapport N°: ${data['rapportNo']}'),
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
                const Text('Module 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text('Temps de fonctionnement: ${formatMinutesToHoursMinutes(data['module1OperatingTime'] is int ? data['module1OperatingTime'] : 0)}'),
                Text('Temps d\'arrêt: ${formatMinutesToHoursMinutes(data['module1TotalDowntime'] is int ? data['module1TotalDowntime'] : 0)}'),
                if (module1Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Arrêts:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...module1Stops.map((stop) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
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
                const Text('Module 2', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(height: 16),
                Text('Temps de fonctionnement: ${formatMinutesToHoursMinutes(data['module2OperatingTime'] is int ? data['module2OperatingTime'] : 0)}'),
                Text('Temps d\'arrêt: ${formatMinutesToHoursMinutes(data['module2TotalDowntime'] is int ? data['module2TotalDowntime'] : 0)}'),
                if (module2Stops.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Arrêts:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...module2Stops.map((stop) => Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text('${stop['duration'] ?? '-'} - ${stop['nature'] ?? '-'}'),
                  )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMachinesEquipmentStoppedAdditionalData(Map<String, dynamic> data) {
    if (data.isEmpty) return const Text('Aucune donnée d\'équipement arrêtée disponible.');
    final equipmentList = (data['equipmentList'] is List) ? List.from(data['equipmentList']) : [];
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
                const Text('Date du rapport', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (data['date'] != null)
                  Text(data['date'].toString()),
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
                const Text('Équipements arrêtés', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (equipmentList.isEmpty)
                  const Text('Aucun équipement ajouté', style: TextStyle(color: Colors.grey)),
                if (equipmentList.isNotEmpty)
                  ...equipmentList.asMap().entries.map((entry) {
                    final index = entry.key;
                    final equipment = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Équipement ${index + 1}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Type: ${equipment['equipmentType'] ?? '-'}'),
                          Text('Raison: ${equipment['stopReason'] ?? '-'}'),
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${equipmentList.length} équipement${equipmentList.length > 1 ? 's' : ''} prêt${equipmentList.length > 1 ? 's' : ''} à être soumis',
                      style: TextStyle(
                        color: Colors.green[700],
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
    if (data.isEmpty) return const Text('Aucune donnée de suivi camion disponible.');
    final truckData = (data['truckData'] is List) ? List.from(data['truckData']) : [];
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
                const Text('Mine et Sortie', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const Text('Equipement', style: TextStyle(fontWeight: FontWeight.bold)),
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
                const Text('Camions', style: TextStyle(fontWeight: FontWeight.bold)),
                const Divider(height: 16),
                if (truckData.isEmpty)
                  const Text('Aucun camion ajouté.'),
                if (truckData.isNotEmpty)
                  ...truckData.map((truck) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Camion: ${truck['truckNumber'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Chauffeur: ${truck['driver1'] ?? '-'}'),
                      if (truck['counts'] != null && (truck['counts'] is List) && (truck['counts'] as List).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Voyages:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ...List.generate((truck['counts'] as List).length, (index) {
                          final count = (truck['counts'] as List)[index];
                          return Padding(
                            padding: const EdgeInsets.only(left: 16, top: 4),
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
                    const Text('Résumé des voyages', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Total de voyages: ${truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).length}'),
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
    final allTrips = truckData.expand((truck) => (truck['counts'] is List) ? truck['counts'] : []).toList();
    final Map<String, int> equipmentCounts = {};
    for (var trip in allTrips) {
      final eq = trip['equipment'] ?? '-';
      equipmentCounts[eq] = (equipmentCounts[eq] ?? 0) + 1;
    }
    return equipmentCounts.entries
        .map((e) => Text('Total pour ${e.key}: ${e.value}'))
        .toList();
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
      await _showReportDetails(updatedReport);
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
              hint: const Text('Tous les postes', style: TextStyle(color: Colors.white)),
              dropdownColor: Theme.of(context).colorScheme.surface,
              underline: Container(),
              icon: const Icon(Icons.filter_list, color: Colors.white),
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
                      const Icon(Icons.description_outlined, size: 64, color: Colors.grey),
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
                        color: Colors.blue[50],
                        child: Row(
                          children: [
                            Icon(Icons.filter_list, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${_filteredReports.length} rapport${_filteredReports.length > 1 ? 's' : ''} trouvé${_filteredReports.length > 1 ? 's' : ''} pour le poste $_selectedPosteFilter',
                              style: TextStyle(
                                color: Colors.blue[700],
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
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(report.description),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Type: ${report.type}'),
                                    Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(report.date)}'),
                                    Text('Group: ${report.group}'),
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
                                    if (value == 'delete') {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(l10n.delete),
                                          content: const Text('Are you sure you want to delete this report?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
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
                                    } else if (value == 'edit') {
                                      _editReport(report);
                                    }
                                  },
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
}