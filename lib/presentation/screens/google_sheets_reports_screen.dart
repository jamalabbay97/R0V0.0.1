import 'package:r0/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:r0/domain/models/report.dart';
import 'package:r0/data/services/google_sheets_service.dart';

class GoogleSheetsReportsScreen extends StatefulWidget {
  const GoogleSheetsReportsScreen({super.key});

  @override
  State<GoogleSheetsReportsScreen> createState() =>
      _GoogleSheetsReportsScreenState();
}

class _GoogleSheetsReportsScreenState extends State<GoogleSheetsReportsScreen> {
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<GoogleSheetRecord> _allRecords = [];
  List<GoogleSheetRecord> _filteredRecords = [];
  List<String> _availableSheets = [];
  bool _isLoading = true;
  String? _error;
  DateTime? _selectedDate;
  String? _selectedSheet;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRecords();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), _applyFilters);
  }

  Future<void> _loadRecords({bool forceRefresh = false}) async {
    final reportRepository = context.read<ReportRepository>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<GoogleSheetRecord> sheetsRecords = [];
      try {
        sheetsRecords = await _sheetsService.fetchAllRecords(
          forceRefresh: forceRefresh,
        );
      } catch (e) {
        debugPrint('Google Sheets fetch skipped or failed: $e');
      }

      final List<Report> localReports = await reportRepository.getReports();
      final List<GoogleSheetRecord> localMapped =
          localReports.map(_mapReportToGoogleSheetRecord).toList();

      final Set<String> seenKeys = {};
      final List<GoogleSheetRecord> combinedRecords = [];

      for (final record in sheetsRecords) {
        final dateKey = record.date != null
            ? DateFormat('yyyy-MM-dd').format(record.date!)
            : 'nodate';
        final key =
            '${record.sheetName.toLowerCase()}_${dateKey}_${record.title.toLowerCase()}';
        seenKeys.add(key);
        combinedRecords.add(record);
      }

      for (final localRecord in localMapped) {
        final dateKey = localRecord.date != null
            ? DateFormat('yyyy-MM-dd').format(localRecord.date!)
            : 'nodate';
        final key =
            '${localRecord.sheetName.toLowerCase()}_${dateKey}_${localRecord.title.toLowerCase()}';
        if (!seenKeys.contains(key)) {
          combinedRecords.add(localRecord);
          seenKeys.add(key);
        }
      }

      combinedRecords.sort((a, b) {
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });

      if (!mounted) return;

      final sheetNames = combinedRecords
          .map((record) => record.sheetName)
          .toSet()
          .toList()
        ..sort();

      setState(() {
        _allRecords = combinedRecords;
        _availableSheets = sheetNames;
        if (_selectedSheet != null && !sheetNames.contains(_selectedSheet)) {
          _selectedSheet = null;
        }
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _allRecords.where((record) {
      final matchesQuery =
          query.isEmpty || record.searchableText.contains(query);
      final matchesDate =
          _selectedDate == null || _sameDay(record.date, _selectedDate!);
      final matchesSheet =
          _selectedSheet == null || _selectedSheet == record.sheetName;
      return matchesQuery && matchesDate && matchesSheet;
    }).toList()
      ..sort((a, b) {
        final aDate = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    if (!mounted) return;
    setState(() {
      _filteredRecords = filtered;
    });
  }

  bool _sameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _applyFilters();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDate = null;
      _selectedSheet = null;
      _searchController.clear();
    });
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.insights_rounded,
                          color: theme.colorScheme.primary, size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports Archive',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'View and filter all reports',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _loadRecords(forceRefresh: true),
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.05),
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by report name, date, or details',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => _searchController.clear(),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(
                        _selectedDate == null
                            ? 'Date'
                            : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDate != null || _selectedSheet != null)
                      TextButton(
                        onPressed: _clearAllFilters,
                        child: Text(AppLocalizations.of(context)!.resetFilters),
                      ),
                    const Spacer(),
                    Text(
                      '${_filteredRecords.length}/${_allRecords.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (_availableSheets.isNotEmpty)
                SizedBox(
                  height: 42,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(AppLocalizations.of(context)!.allSheets),
                          selected: _selectedSheet == null,
                          onSelected: (_) {
                            setState(() {
                              _selectedSheet = null;
                            });
                            _applyFilters();
                          },
                        ),
                      ),
                      ..._availableSheets.map(
                        (sheet) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(sheet),
                            selected: _selectedSheet == sheet,
                            onSelected: (_) {
                              setState(() {
                                _selectedSheet = sheet;
                              });
                              _applyFilters();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(child: _buildContent(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _loadRecords(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context)!.tryAgain),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 64,
              color: theme.disabledColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No records found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.disabledColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              record.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${record.sheetName} • Row ${record.rowNumber}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      record.dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _showRecordDetails(record),
          ),
        );
      },
    );
  }

  _RecordTypeInfo _getRecordTypeInfo(GoogleSheetRecord record) {
    if (_isR0Record(record)) {
      return const _RecordTypeInfo(
        icon: Icons.precision_manufacturing_rounded,
        color: Colors.blue,
      );
    }
    if (_isActivityRecord(record)) {
      return const _RecordTypeInfo(
        icon: Icons.pending_actions_rounded,
        color: Colors.orange,
      );
    }
    if (_isDailyRecord(record)) {
      return const _RecordTypeInfo(
        icon: Icons.summarize_rounded,
        color: Colors.green,
      );
    }
    if (_isTruckRecord(record)) {
      return const _RecordTypeInfo(
        icon: Icons.local_shipping_rounded,
        color: Colors.deepPurple,
      );
    }
    if (_isMachinesRecord(record)) {
      return const _RecordTypeInfo(
        icon: Icons.settings_rounded,
        color: Colors.red,
      );
    }
    return const _RecordTypeInfo(
      icon: Icons.description_rounded,
      color: Colors.grey,
    );
  }

  void _showRecordDetails(GoogleSheetRecord record) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getRecordTypeInfo(record)
                              .color
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getRecordTypeInfo(record).icon,
                          color: _getRecordTypeInfo(record).color,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${record.sheetName} • ${record.dateLabel} • Row ${record.rowNumber}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: _buildDetailsView(context, record),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailsView(BuildContext context, GoogleSheetRecord record) {
    if (_isR0Record(record)) {
      return _buildR0DetailsView(context, record);
    }
    if (_isActivityRecord(record)) {
      return _buildActivityDetailsView(context, record);
    }
    if (_isDailyRecord(record)) {
      return _buildDailyDetailsView(context, record);
    }
    if (_isTruckRecord(record)) {
      return _buildTruckDetailsView(context, record);
    }
    if (_isMachinesRecord(record)) {
      return _buildMachinesDetailsView(context, record);
    }
    return _buildGenericFormattedDetailsView(record);
  }

  bool _isR0Record(GoogleSheetRecord record) =>
      record.sheetName.toLowerCase().contains('r0');

  bool _isActivityRecord(GoogleSheetRecord record) {
    final name = record.sheetName.toLowerCase();
    return name.contains('activity') || name.contains('tnb');
  }

  bool _isDailyRecord(GoogleSheetRecord record) {
    final name = record.sheetName.toLowerCase();
    return name.contains('daily') || name.contains('tsud');
  }

  bool _isTruckRecord(GoogleSheetRecord record) {
    final name = record.sheetName.toLowerCase();
    return name.contains('camion') || name.contains('truck');
  }

  bool _isMachinesRecord(GoogleSheetRecord record) {
    final name = record.sheetName.toLowerCase();
    return name.contains('engin') || name.contains('machine');
  }

  Widget _buildR0DetailsView(BuildContext context, GoogleSheetRecord record) {
    final details = record.details;
    final date = _field(details, ['Date', 'Date (as shown in app)']);
    final mine = _field(details, ['Mine']);
    final sortie = _field(details, ['Sortie']);
    final engine = _field(details, ['Machine/Engins', 'Category']);
    final type = _field(details, ['Type']);
    final model = _field(details, ['Model']);
    final shift = _field(details, ['Poste']);
    final counterStart = _field(details, ['Début compteur', 'Compteurs Durée']);
    final counterEnd = _field(details, ['Fin compteur', 'Compteurs Note']);

    final stopReasons = _extractStopReasons(details);
    final stopTimes = _extractStopTimes(details);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _r0Row('Date', date),
        _r0Row('Mine/Exit', '$mine / $sortie'),
        _r0Row('Engine', '$engine - $type $model'.trim()),
        _r0Row('Shift', shift),
        _r0Row('Counter', '$counterStart -> $counterEnd'),
        const Divider(height: 24),
        _sectionTitle(context, 'Stops Details'),
        ..._buildStopsRows(stopReasons, stopTimes),
        const Divider(height: 24),
        _r0Row('H.M', _field(details, ['H.M'])),
        _r0Row('H.A', _field(details, ['H.A'])),
        const Divider(height: 24),
        _r0Row('Drilling m', _field(details, ['Métrage foré'])),
        _r0Row('Nr Drilled', _field(details, ['Nr de Trous Forés'])),
        _r0Row('Nr Trips', _field(details, ['Nr de Voyages'])),
        _r0Row('M³ Strippe', _field(details, ['M³ Décapages'])),
        _r0Row('Tonnage', _field(details, ['Tonnage'])),
        _r0Row('Nr T.K.U', _field(details, ['Nr T.K.U', 'Nombre T.K.U'])),
        _r0Row('Efficiency', _field(details, ['Rendement', 'Rendement %'])),
        const Divider(height: 24),
        _r0Row('Conductor', _field(details, ['Conducteur'])),
        _r0Row('Greaser', _field(details, ['Graisseur'])),
        _r0Row('Serial Numbers', _field(details, ['Matricules'])),
        const Divider(height: 24),
        _r0Row('Worksite', _field(details, ['Chantier'])),
        _r0Row('Duration', _field(details, ['Temps'])),
        _r0Row('Imputation', _field(details, ['Imputation'])),
        const Divider(height: 24),
        _r0Row('Tricone', _field(details, ['Tricone'])),
        _r0Row('Diesel', _field(details, ['Gasoil'])),
      ],
    );
  }

  Widget _buildActivityDetailsView(
    BuildContext context,
    GoogleSheetRecord record,
  ) {
    final details = record.details;

    final stops = _splitFieldValues(
      _field(details, ['Arrêts', 'Arrêt', 'Nature']),
    );
    final stopDurations = _splitFieldValues(
      _field(details, ['Durées d\'arrêt', 'Durée d\'arrêt', 'Duration']),
    );
    final vibratorCounters = _splitFieldValues(
      _field(details, ['Compteurs Vibreurs', 'Compteur Vibrateur']),
    );
    final liaisonCounters = _splitFieldValues(
      _field(details, ['Compteurs Liaison', 'Compteur Liaison']),
    );
    final stocks = _splitFieldValues(
      _field(details, ['Stocks', 'Stock']),
    );

    final stopRows = _buildStopsRows(stops, stopDurations);

    List<Widget> buildCounterRows(List<String> counters) {
      final filledCounters =
          counters.where(_isMeaningfulActivityValue).toList(growable: false);
      if (filledCounters.isEmpty) {
        return const [];
      }
      return filledCounters
          .map((counter) => _r0Row('Poste / Début / Fin', counter))
          .toList();
    }

    List<Widget> buildStockRows(List<String> values) {
      final filledStocks =
          values.where(_isMeaningfulActivityValue).toList(growable: false);
      if (filledStocks.isEmpty) {
        return const [];
      }
      return filledStocks
          .map((stock) => _r0Row('Poste / Park / Type / Qte', stock))
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _r0Row('Date', _field(details, ['Date'])),
        const SizedBox(height: 8),
        _activitySection(
          context,
          title: 'Résumé des données',
          children: [
            _r0Row('T H.A', _field(details, ['T H.A'])),
            _r0Row('T H.M', _field(details, ['T H.M'])),
            _r0Row('T H.V', _field(details, ['T H.V'])),
            _r0Row('T H.L', _field(details, ['T H.L'])),
            const SizedBox(height: 6),
            _r0Row('T Nr.A', stops.length.toString()),
            _r0Row('T Nr.V', vibratorCounters.length.toString()),
            _r0Row('T Nr.L', liaisonCounters.length.toString()),
          ],
        ),
        const SizedBox(height: 12),
        _activitySection(
          context,
          title: 'Arrêts',
          children: stopRows,
        ),
        const SizedBox(height: 12),
        _activitySection(
          context,
          title: 'Compteurs Vibreurs',
          children: buildCounterRows(vibratorCounters),
        ),
        const SizedBox(height: 12),
        _activitySection(
          context,
          title: 'Compteurs Liaison',
          children: buildCounterRows(liaisonCounters),
        ),
        const SizedBox(height: 12),
        _activitySection(
          context,
          title: 'Stocks',
          children: buildStockRows(stocks),
        ),
      ],
    );
  }

  Widget _buildDailyDetailsView(
      BuildContext context, GoogleSheetRecord record) {
    final details = record.details;

    final module1Rows = _buildDailyModuleStopRows(details, moduleNumber: 1);
    final module2Rows = _buildDailyModuleStopRows(details, moduleNumber: 2);
    final stockRows = _splitFieldValues(
      _field(details, [
        'Détails Stock',
        'Stocks',
        'Stock Entries',
        'Stock',
        'Poste / Park / Type',
      ]),
    );

    final module1Operating = _field(details,
        ['Durée Marche M1', 'T H.M1 (Operating M1)', 'T H.M1', 'Total H.M M1']);
    final module1Hm = _resolveDailyModuleHm(
      details,
      moduleNumber: 1,
      operatingTime: module1Operating,
    );
    final module1Downtime = _field(details, [
      'T H.A1 (Downtime M1)',
      'Durée Arrêts Totale M1',
      'Temps d\'arrêt M1',
      'T H.A1',
      'Total H.A M1',
    ]);
    final module2Operating = _field(details,
        ['Durée Marche M2', 'T H.M2 (Operating M2)', 'T H.M2', 'Total H.M M2']);
    final module2Hm = _resolveDailyModuleHm(
      details,
      moduleNumber: 2,
      operatingTime: module2Operating,
    );
    final module2Downtime = _field(details, [
      'T H.A2 (Downtime M2)',
      'Durée Arrêts Totale M2',
      'Temps d\'arrêt M2',
      'T H.A2',
      'Total H.A M2',
    ]);

    final stockEntries = stockRows
        .map(_parseDailyStockEntry)
        .where((entry) => entry.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _activitySection(
          context,
          title: 'Date',
          children: [
            _r0Row('Date', _field(details, ['Date']))
          ],
        ),
        const SizedBox(height: 12),
        _buildDailyModuleCard(
          context: context,
          moduleTitle: 'Module 1',
          hm: module1Hm,
          operatingTime: module1Operating,
          downtime: module1Downtime,
          stopRows: module1Rows,
        ),
        const SizedBox(height: 12),
        _buildDailyModuleCard(
          context: context,
          moduleTitle: 'Module 2',
          hm: module2Hm,
          operatingTime: module2Operating,
          downtime: module2Downtime,
          stopRows: module2Rows,
        ),
        const SizedBox(height: 12),
        _activitySection(
          context,
          title: 'Stocks',
          children: [
            ...(stockEntries.isEmpty
                ? [_r0Row('-', '-')]
                : stockEntries.map(
                    (stock) => _r0Row(
                      'Poste / Park / Type',
                      stock.displayValue,
                    ),
                  )),
            const SizedBox(height: 6),
          ],
        ),
      ],
    );
  }

  String _resolveDailyModuleHm(
    Map<String, String> details, {
    required int moduleNumber,
    required String operatingTime,
  }) {
    final moduleHm = _field(details, [
      'Total H.M$moduleNumber',
      'Total H.M M$moduleNumber',
      'H.M$moduleNumber',
      'T H.M$moduleNumber',
      'Total HM$moduleNumber',
    ]);

    if (moduleHm != '-') {
      return moduleHm;
    }

    final genericHm = _field(details, [
      'Total H.M',
      'H.M',
      'T H.M',
      'Durée Marche',
      'Duree Marche',
    ]);

    if (genericHm != '-') {
      return genericHm;
    }

    return operatingTime == '-' ? '' : operatingTime;
  }

  Widget _buildDailyModuleCard({
    required BuildContext context,
    required String moduleTitle,
    required String hm,
    required String operatingTime,
    required String downtime,
    required List<String> stopRows,
  }) {
    return _activitySection(
      context,
      title: moduleTitle,
      children: [
        _r0Row('H.M', hm),
        _r0Row('Operating Time', operatingTime),
        _r0Row('Stop Time', downtime),
        const SizedBox(height: 6),
        ...((stopRows.isEmpty)
            ? [_r0Row('Stops', '-')]
            : stopRows.asMap().entries.map((entry) {
                final stopIndex = entry.key + 1;
                return _r0Row('Stop $stopIndex', entry.value);
              })),
      ],
    );
  }

  Iterable<String> _buildDurationReasonRows(
    List<String> durations,
    List<String> reasons,
  ) sync* {
    final itemCount =
        durations.length > reasons.length ? durations.length : reasons.length;
    for (var i = 0; i < itemCount; i++) {
      final duration = i < durations.length ? durations[i] : '-';
      final reason = i < reasons.length ? reasons[i] : '-';
      yield '$duration - $reason';
    }
  }

  List<String> _buildDailyModuleStopRows(
    Map<String, String> details, {
    required int moduleNumber,
  }) {
    final reasons = _splitFieldValues(_field(details, [
      'Détails Arrêts M$moduleNumber',
      'Arrêts M$moduleNumber',
      'Module $moduleNumber Stops',
      'Nature M$moduleNumber',
      'Module $moduleNumber Details',
      'Module $moduleNumber',
    ]));

    final durations = _splitFieldValues(_field(details, [
      'Durées Arrêts M$moduleNumber',
      'Durée Arrêts M$moduleNumber',
      'Durées M$moduleNumber',
      'Temps d\'arrêt M$moduleNumber',
      'Durée Module $moduleNumber',
      'Durées Module $moduleNumber',
    ]));

    final combinedRows = _splitFieldValues(_field(details, [
      'Arrêts + Durées M$moduleNumber',
      'Module $moduleNumber Arrêts',
      'Module $moduleNumber Détails',
    ]));

    final pairedRows = _buildDurationReasonRows(durations, reasons)
        .where((row) => row.trim() != '- -')
        .toList();

    if (pairedRows.length >= combinedRows.length || combinedRows.isEmpty) {
      return pairedRows;
    }

    return combinedRows;
  }

  _DailyStockEntry _parseDailyStockEntry(String raw) {
    if (raw.trim().isEmpty || raw == '-') {
      return const _DailyStockEntry();
    }

    final segments = raw
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (segments.isEmpty) {
      return const _DailyStockEntry();
    }

    final isDateOnlyEntry = segments.length == 1 &&
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(segments[0]);
    if (isDateOnlyEntry) {
      return const _DailyStockEntry();
    }

    return _DailyStockEntry(
      shift: segments.isNotEmpty ? segments[0] : '',
      park: segments.length > 1 ? segments[1] : '',
      type: segments.length > 2 ? segments[2] : '',
      qty: segments.length > 3 ? segments[3] : '',
    );
  }

  Widget _buildTruckDetailsView(
      BuildContext context, GoogleSheetRecord record) {
    final details = record.details;
    final truckList = _splitFieldValues(
      _field(details, ['Camions List', 'Camions']),
    );
    final driverList = _splitFieldValues(
      _field(details, ['Conducteurs List', 'Conducteur']),
    );
    final tripsPerTruck =
        _splitFieldValues(_field(details, ['Trips per Truck']));
    final tripDetails = _splitFieldValues(_field(details, ['Trip Details']));
    final tripsByEquipment = _splitFieldValues(_field(details, [
      'Total de Voyages par Equipment',
      'Total de voyage par équipement',
      'Trips per Equipment',
    ]));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionTitle(context, 'Truck Tracking Details'),
        _r0Row('Date', _field(details, ['Date'])),
        _r0Row('Mine/Exit',
            '${_field(details, ['Mine'])} / ${_field(details, ['Sortie'])}'),
        _r0Row('Equipment', _field(details, ['Machine/Engins'])),
        _r0Row('Distance', _field(details, ['Distance'])),
        _r0Row('Type', _field(details, ['Qualité', 'Type'])),
        _r0Row('Operation', _field(details, ['Opération', 'Operation'])),
        _r0Row('Shift', _field(details, ['Poste'])),
        _r0Row('Trucks', truckList.isEmpty ? '-' : '${truckList.length}'),
        _r0Row('Total Trips',
            _field(details, ['Total de Voyages', 'Total de Voyages Camions'])),
        const Divider(height: 24),
        _sectionTitle(context, 'Trips per Truck'),
        if (tripsPerTruck.isEmpty)
          _r0Row('-', '-')
        else
          ...tripsPerTruck.asMap().entries.map((tripEntry) {
            final index = tripEntry.key;
            final entry = tripEntry.value;
            final parts = entry.split(':');
            final truckName = parts.first.trim();
            final driverName =
                index < driverList.length ? driverList[index] : '';
            final truckWithDriver =
                driverName.isEmpty ? truckName : '$truckName - $driverName';

            if (parts.length < 2) {
              return _r0Row(truckWithDriver, '-');
            }
            return _r0Row(
                truckWithDriver, '${parts.sublist(1).join(':').trim()} trips');
          }),
        if (tripsByEquipment.isNotEmpty) ...[
          const Divider(height: 24),
          _sectionTitle(context, 'Total de voyage par équipement'),
          ...tripsByEquipment.map((entry) => _r0Row('-', entry)),
          const Divider(height: 24),
          _sectionTitle(context, 'Trip Details'),
          if (tripDetails.isEmpty)
            _r0Row('-', '-')
          else
            ...tripDetails.map((entry) {
              final parts = entry.split('|').map((e) => e.trim()).toList();
              final time = parts.isNotEmpty ? parts[0] : '-';
              final truck = parts.length > 1 ? parts[1] : '-';
              final equipment = parts.length > 2 ? parts[2] : '-';
              final quality = parts.length > 3 ? parts[3] : '';
              final subtitle =
                  quality.isEmpty ? equipment : '$equipment • $quality';
              return _r0Row('$time  $truck', subtitle);
            }),
        ],
      ],
    );
  }

  Widget _buildMachinesDetailsView(
    BuildContext context,
    GoogleSheetRecord record,
  ) {
    final details = record.details;
    final categories = _splitFieldValues(
        _field(details, ['Catégorie', 'Catégorie principale', 'Category']));
    final subCategories = _splitFieldValues(
        _field(details, ['Sous-catégorie', 'Sous-Catégorie', 'Sub Category']));
    final equipments = _splitFieldValues(
        _field(details, ['Équipement', 'Equipement', 'Equipment']));
    final reasons = _splitFieldValues(_field(details,
        ['Raison', "Raison De l'Arret", 'Raison De l\'Arret', 'Reason']));

    final count = [
      categories.length,
      subCategories.length,
      equipments.length,
      reasons.length,
    ].reduce((a, b) => a > b ? a : b);

    List<Widget> buildEquipmentCards() {
      if (count == 0) {
        return [_r0Row('-', '-')];
      }

      final cards = <Widget>[];
      for (var i = 0; i < count; i++) {
        final category = i < categories.length ? categories[i] : '-';
        final subCategory = i < subCategories.length ? subCategories[i] : '-';
        final equipment = i < equipments.length ? equipments[i] : '-';
        final reason = i < reasons.length ? reasons[i] : '-';

        final titleParts = [category, subCategory, equipment]
            .where((value) => value != '-' && value.trim().isNotEmpty)
            .toList();

        cards.add(
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
              ),
            ),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: const Icon(Icons.build_rounded, color: Colors.green),
              title: Text(
                titleParts.isEmpty ? '-' : titleParts.join(' - '),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason),
              ),
            ),
          ),
        );
      }

      return cards;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionTitle(context, 'Machines/Engins Details'),
        _r0Row('Date', _field(details, ['Date'])),
        const SizedBox(height: 12),
        _sectionTitle(context, 'Équipements Arrêtés'),
        ...buildEquipmentCards(),
      ],
    );
  }

  List<String> _splitFieldValues(String value) {
    if (value.trim().isEmpty || value == '-') {
      return const [];
    }
    return value
        .split(RegExp(r'\r?\n|\s*\|\s*|\s*•\s*|\s*;\s*'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Widget _buildGenericFormattedDetailsView(GoogleSheetRecord record) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        ...record.details.entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _r0Row(entry.key, entry.value.isEmpty ? '-' : entry.value),
          ),
        ),
      ],
    );
  }

  Widget _activitySection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const Divider(height: 16),
        ...children,
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Center(
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  List<Widget> _buildStopsRows(List<String> reasons, List<String> times) {
    final normalizedReasons = _mergeStopReasonDetails(reasons);
    final rows = <Widget>[];
    final itemCount = normalizedReasons.length > times.length
        ? normalizedReasons.length
        : times.length;
    if (itemCount == 0) {
      return const [];
    }

    for (var i = 0; i < itemCount; i++) {
      final reason = i < normalizedReasons.length ? normalizedReasons[i] : '';
      final time = i < times.length ? times[i] : '';
      rows.add(_r0Row(reason, time));
    }
    return rows;
  }

  List<String> _mergeStopReasonDetails(List<String> reasons) {
    if (reasons.length < 2) {
      return reasons;
    }

    final merged = <String>[];
    var index = 0;
    while (index < reasons.length) {
      final current = reasons[index];
      final nextIndex = index + 1;
      if (current.endsWith(':') &&
          nextIndex < reasons.length &&
          !reasons[nextIndex].endsWith(':')) {
        merged.add('$current\n${reasons[nextIndex]}');
        index += 2;
        continue;
      }

      merged.add(current);
      index++;
    }

    return merged;
  }

  bool _isMeaningfulActivityValue(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty || cleaned == '-') {
      return false;
    }

    final withoutSeparators = cleaned.replaceAll('/', '').replaceAll('|', '');
    final withoutSpaces = withoutSeparators.replaceAll(RegExp(r'\s+'), '');
    return withoutSpaces.replaceAll('-', '').isNotEmpty;
  }

  List<String> _extractStopReasons(Map<String, String> details) {
    final grouped = _field(details, ['Stops Details']);
    if (grouped != '-') {
      return grouped
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    final reason = _field(details, ['Arrêt', 'Arret']);
    if (reason == '-') return const [];
    final category = _field(details, ['Catégorie d\'arrêt', 'Category']);
    if (category == '-') {
      return [reason];
    }
    return ['$category / $reason'];
  }

  List<String> _extractStopTimes(Map<String, String> details) {
    final grouped = _field(details, ['Stop Times']);
    if (grouped != '-') {
      return grouped
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    }

    final start = _field(details, ['Début d\'arrêt', 'Start']);
    final end = _field(details, ['Fin d\'arrêt', 'End']);
    if (start == '-' && end == '-') {
      return const [];
    }
    if (start != '-' && end != '-') {
      return ['$start - $end'];
    }
    return [start != '-' ? start : end];
  }

  String _field(Map<String, String> details, List<String> keys) {
    for (final expected in keys) {
      final expectedNorm = _normalizeKey(expected);
      for (final entry in details.entries) {
        if (_normalizeKey(entry.key) == expectedNorm) {
          final value = entry.value.trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return '-';
  }

  String _normalizeKey(String key) => key
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('à', 'a')
      .replaceAll('ù', 'u')
      .replaceAll('ô', 'o')
      .replaceAll('ï', 'i')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  Widget _r0Row(String label, String value) {
    final normalizedLabel = label.trim() == '-' ? '' : label;
    final normalizedValue =
        (value.trim().isEmpty || value.trim() == '-') ? '' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              normalizedLabel,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              normalizedValue,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  GoogleSheetRecord _mapReportToGoogleSheetRecord(Report report) {
    final data = report.additionalData ?? {};
    final details = <String, String>{};

    details['Date'] = DateFormat('yyyy-MM-dd').format(report.date);
    details['Date (as shown in app)'] = details['Date']!;
    details['Description'] = report.description;
    details['Poste'] = report.group;
    details['Type (Report)'] = report.type;

    String sheetName = report.type;
    final typeLower = report.type.toLowerCase();

    if (typeLower == 'r0') {
      sheetName = 'R0';
      details['Mine'] = data['mine']?.toString() ?? '';
      details['Sortie'] = data['sortie']?.toString() ?? '';
      details['Machine/Engins'] = data['Category']?.toString() ?? '';
      details['Type'] = data['Type']?.toString() ?? '';
      details['Model'] = data['Model']?.toString() ?? '';
      details['Poste'] = data['selectedPoste']?.toString() ?? report.group;

      final compteurs = data['Compteurs'] as Map? ?? {};
      details['Début compteur'] = compteurs['duree']?.toString() ?? '';
      details['Fin compteur'] = compteurs['note']?.toString() ?? '';

      final exploitation = data['exploitation'] as Map? ?? {};
      details['H.M'] = exploitation['H.M']?.toString() ?? '';
      details['H.A'] = exploitation['H.A']?.toString() ?? '';
      details['Métrage foré'] =
          (exploitation['metrage fore'] ?? exploitation['metrage_fore'])
                  ?.toString() ??
              '';
      details['Nr de Trous Forés'] = (exploitation['Nr de Trous Fores'] ??
                  exploitation['nr_de_trous_fores'])
              ?.toString() ??
          '';
      details['Nr de Voyages'] =
          (exploitation['Nr de Voyages'] ?? exploitation['nr_de_voyages'])
                  ?.toString() ??
              '';
      details['M³ Décapages'] =
          (exploitation['M³ Decapages'] ?? exploitation['m3_decapages'])
                  ?.toString() ??
              '';
      details['Tonnage'] = exploitation['Tonnage']?.toString() ?? '';
      details['Nombre T.K.U'] =
          (exploitation['Nombre T.K.U'] ?? exploitation['nombre_t_k_u'])
                  ?.toString() ??
              '';
      details['Rendement %'] =
          (exploitation['Rendement %'] ?? exploitation['rendement'])
                  ?.toString() ??
              '';

      final personnel = data['personnel'] as Map? ?? {};
      details['Conducteur'] =
          (personnel['conductr'] ?? personnel['conducteur'])?.toString() ?? '';
      details['Graisseur'] = personnel['graisseur']?.toString() ?? '';
      details['Matricules'] = personnel['matricules']?.toString() ?? '';

      final repartition = data['repartition'] as Map? ?? {};
      details['Chantier'] = repartition['Chantier']?.toString() ?? '';
      details['Temps'] = repartition['Temps']?.toString() ?? '';
      details['Imputation'] = repartition['Imputation']?.toString() ?? '';

      final consommation = data['consommation'] as Map? ?? {};
      details['Tricone'] = consommation['tricone']?.toString() ?? '';
      details['Gasoil'] = consommation['gasoil']?.toString() ?? '';

      final arrets = data['Arrets'] as List? ?? [];
      final arretReasons = <String>[];
      final arretTimes = <String>[];
      for (final a in arrets) {
        if (a is Map) {
          final category = a['Catégorie'] ?? a['category'] ?? '';
          final name = a['Arret'] ?? a['nature'] ?? '';
          final start = a['Début'] ?? a['startTime'] ?? '';
          final end = a['Fin'] ?? a['endTime'] ?? '';
          arretReasons.add('$category - $name'.trim());
          arretTimes.add('$start - $end'.trim());
        }
      }
      details['Stops Details'] =
          arretReasons.isEmpty ? '-' : arretReasons.join('\n');
      details['Stop Times'] = arretTimes.isEmpty ? '-' : arretTimes.join('\n');
    } else if (typeLower.contains('activity') || typeLower.contains('tnb')) {
      sheetName = 'TNB';
      final exploitation = data['exploitation'] as Map? ?? {};
      details['T H.A'] =
          (exploitation['H.A'] ?? data['T H.A'] ?? '')?.toString() ?? '';
      details['T H.M'] =
          (exploitation['H.M'] ?? data['T H.M'] ?? '')?.toString() ?? '';
      details['T H.V'] =
          (exploitation['H.V'] ?? data['T H.V'] ?? '')?.toString() ?? '';
      details['T H.L'] =
          (exploitation['H.L'] ?? data['T H.L'] ?? '')?.toString() ?? '';

      final arrets = data['Arrets'] as List? ?? [];
      final arretReasons = <String>[];
      final arretDurations = <String>[];
      for (final a in arrets) {
        if (a is Map) {
          final category = a['category'] ?? a['Catégorie'] ?? '';
          final nature = a['nature'] ?? a['Arret'] ?? '';
          final start = a['startTime'] ?? a['Début'] ?? '';
          final end = a['endTime'] ?? a['Fin'] ?? '';
          final duration = a['duration'] ?? '';
          final location = a['location'] ?? a['Lieu'] ?? '';
          final detail = a['detail'] ?? a['Détail'] ?? '';

          arretReasons.add('$category / $nature / $location / $detail');
          arretDurations.add('$start -> $end ($duration)');
        }
      }
      details['Arrêts'] = arretReasons.join('\n');
      details['Durées d\'arrêt'] = arretDurations.join('\n');

      final vCounters = data['vibrator Counters'] as List? ??
          data['vibratorCounters'] as List? ??
          [];
      final vCounterDetails = <String>[];
      for (final c in vCounters) {
        if (c is Map) {
          final type = c['type'] ?? '';
          final start = c['start'] ?? '';
          final end = c['end'] ?? '';
          final shift = c['shiftKey'] ?? report.group;
          vCounterDetails.add('$shift / $start -> $end ($type)');
        }
      }
      details['Compteurs Vibreurs'] = vCounterDetails.join('\n');

      final lCounters = data['liaison Counters'] as List? ??
          data['liaisonCounters'] as List? ??
          [];
      final lCounterDetails = <String>[];
      for (final c in lCounters) {
        if (c is Map) {
          final type = c['type'] ?? '';
          final start = c['start'] ?? '';
          final end = c['end'] ?? '';
          final shift = c['shiftKey'] ?? report.group;
          lCounterDetails.add('$shift / $start -> $end ($type)');
        }
      }
      details['Compteurs Liaison'] = lCounterDetails.join('\n');

      final stocks = data['stock'] as List? ?? [];
      final stockDetails = <String>[];
      for (final s in stocks) {
        if (s is Map) {
          final park = s['park'] ?? '';
          final type = s['type'] ?? '';
          final qty = s['quantity'] ?? s['qty'] ?? '';
          final shift = s['shiftKey'] ?? report.group;
          stockDetails.add('$shift / $park / $type / $qty');
        }
      }
      details['Stocks'] = stockDetails.join('\n');
    } else if (typeLower.contains('daily') || typeLower.contains('tsud')) {
      sheetName = 'TSUD';
      final exploitation = data['exploitation'] as Map? ?? {};
      details['Tonnage global'] = exploitation['Tonnage']?.toString() ?? '';
      details['HM Global'] = exploitation['H.M']?.toString() ?? '';
      details['HA Global'] = exploitation['H.A']?.toString() ?? '';
      details['Rendement Global'] =
          (exploitation['Rendement %'] ?? exploitation['rendement'])
                  ?.toString() ??
              '';

      final m1 = data['module1'] as Map? ?? {};
      details['Total H.M M1'] = (m1['H.M'] ?? m1['HM'] ?? '')?.toString() ?? '';
      details['Total H.A M1'] = (m1['H.A'] ?? m1['HA'] ?? '')?.toString() ?? '';

      final m1Stops = data['module1Stops'] as List? ?? [];
      final m1Natures = <String>[];
      final m1Durations = <String>[];
      for (final s in m1Stops) {
        if (s is Map) {
          m1Natures.add(s['nature']?.toString() ?? '');
          m1Durations.add(s['duration']?.toString() ?? '');
        }
      }
      details['Arrêts M1'] = m1Natures.join('\n');
      details['Durées Arrêts M1'] = m1Durations.join('\n');

      final m2 = data['module2'] as Map? ?? {};
      details['Total H.M M2'] = (m2['H.M'] ?? m2['HM'] ?? '')?.toString() ?? '';
      details['Total H.A M2'] = (m2['H.A'] ?? m2['HA'] ?? '')?.toString() ?? '';

      final m2Stops = data['module2Stops'] as List? ?? [];
      final m2Natures = <String>[];
      final m2Durations = <String>[];
      for (final s in m2Stops) {
        if (s is Map) {
          m2Natures.add(s['nature']?.toString() ?? '');
          m2Durations.add(s['duration']?.toString() ?? '');
        }
      }
      details['Arrêts M2'] = m2Natures.join('\n');
      details['Durées Arrêts M2'] = m2Durations.join('\n');

      final stocks = data['stock'] as List? ?? [];
      final stockDetails = <String>[];
      for (final s in stocks) {
        if (s is Map) {
          final park = s['park'] ?? '';
          final type = s['type'] ?? '';
          final qty = s['quantity'] ?? s['qty'] ?? '';
          final shift = s['shiftKey'] ?? report.group;
          stockDetails.add('$shift / $park / $type / $qty');
        }
      }
      details['Stocks'] = stockDetails.join('\n');
    } else if (typeLower.contains('camion') ||
        typeLower.contains('truck') ||
        typeLower.contains('suivi')) {
      sheetName = 'Poser les camions';
      details['Poste'] = data['selectedPoste']?.toString() ?? report.group;
      details['Qualité'] = data['selectedQualiteType']?.toString() ?? '';
      details['Opération'] = data['operationType']?.toString() ?? '';
      details['Mine'] = data['mine']?.toString() ?? '';
      details['Sortie'] = data['sortie']?.toString() ?? '';
      details['Machine/Engins'] = data['Category']?.toString() ?? '';
      details['Distance'] = data['distance']?.toString() ?? '';

      final trucks = data['truckData'] as List? ?? [];
      final camions = <String>[];
      final conducteurs = <String>[];
      final tripsPerTruck = <String>[];
      final tripDetails = <String>[];
      final tripsByEquipmentMap = <String, int>{};
      var totalTripsCount = 0;

      for (final t in trucks) {
        if (t is Map) {
          final name = t['truck']?.toString() ?? '';
          final driver = t['driver']?.toString() ?? '';
          camions.add(name);
          conducteurs.add(driver);

          final counts = t['counts'] as List? ?? [];
          tripsPerTruck.add('$name: ${counts.length}');
          totalTripsCount += counts.length;

          for (final count in counts) {
            if (count is Map) {
              final time = count['time']?.toString() ?? '';
              final equip = count['equipment']?.toString() ?? '';
              final qual = count['productQualityType']?.toString() ?? '';
              tripDetails.add('$time | $name | $equip | $qual');

              if (equip.isNotEmpty) {
                tripsByEquipmentMap[equip] =
                    (tripsByEquipmentMap[equip] ?? 0) + 1;
              }
            }
          }
        }
      }
      details['Camions List'] = camions.join('\n');
      details['Conducteurs List'] = conducteurs.join('\n');
      details['Trips per Truck'] = tripsPerTruck.join('\n');
      details['Trip Details'] = tripDetails.join('\n');
      details['Total de Voyages'] = totalTripsCount.toString();

      final tripsByEquipment = tripsByEquipmentMap.entries
          .map((e) => '${e.key}: ${e.value} voyages')
          .toList();
      details['Total de Voyages par Equipment'] = tripsByEquipment.join('\n');
    } else if (typeLower.contains('engin') ||
        typeLower.contains('machine') ||
        typeLower.contains('arr')) {
      sheetName = 'Machines et engins à l\'arrêt';
      final machineStops = data['machineStops'] as List? ?? [];
      final categories = <String>[];
      final subCategories = <String>[];
      final equipments = <String>[];
      final reasons = <String>[];

      for (final ms in machineStops) {
        if (ms is Map) {
          categories.add(ms['machineCategory']?.toString() ??
              ms['mainCategory']?.toString() ??
              '');
          subCategories.add(ms['machineSubCategory']?.toString() ??
              ms['subCategory']?.toString() ??
              '');
          equipments.add(ms['machineName']?.toString() ??
              ms['equipment']?.toString() ??
              '');
          reasons.add(ms['reason']?.toString() ?? '');
        }
      }
      details['Catégorie'] = categories.join('\n');
      details['Sous-catégorie'] = subCategories.join('\n');
      details['Équipement'] = equipments.join('\n');
      details['Raison'] = reasons.join('\n');
    } else {
      data.forEach((key, val) {
        if (val is Map) {
          val.forEach((subKey, subVal) {
            details['$key - $subKey'] = subVal?.toString() ?? '';
          });
        } else if (val is List) {
          details[key] = val.map((e) => e.toString()).join('\n');
        } else {
          details[key] = val?.toString() ?? '';
        }
      });
    }

    return GoogleSheetRecord(
      sheetName: sheetName,
      rowNumber: report.id ?? 1,
      details: details,
      date: report.date,
      dateLabel: DateFormat('yyyy-MM-dd').format(report.date),
      title: report.description,
      searchableText:
          '${report.description} ${report.type} ${report.group} ${details.values.join(' ')}'
              .toLowerCase(),
    );
  }
}

class _RecordTypeInfo {
  final IconData icon;
  final Color color;

  const _RecordTypeInfo({
    required this.icon,
    required this.color,
  });
}

class _DailyStockEntry {
  const _DailyStockEntry({
    this.shift = '',
    this.park = '',
    this.type = '',
    this.qty = '',
  });

  final String shift;
  final String park;
  final String type;
  final String qty;

  String get displayValue => [shift, park, type, qty]
      .where((value) => value.trim().isNotEmpty)
      .join(' / ');

  bool get isNotEmpty =>
      shift.isNotEmpty || park.isNotEmpty || type.isNotEmpty || qty.isNotEmpty;
}
