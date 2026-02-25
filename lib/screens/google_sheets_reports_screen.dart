import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:r0/services/google_sheets_service.dart';

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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await _sheetsService.fetchAllRecords(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;

      final sheetNames =
          records.map((record) => record.sheetName).toSet().toList()..sort();

      setState(() {
        _allRecords = records;
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Icon(Icons.insights_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reports',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _loadRecords(forceRefresh: true),
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
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
                    child: const Text('Reset filters'),
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
                      label: const Text('All sheets'),
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
                label: const Text('Try again'),
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
        final typeInfo = _getRecordTypeInfo(record);

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
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeInfo.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                typeInfo.icon,
                color: typeInfo.color,
                size: 24,
              ),
            ),
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
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
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
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.disabledColor.withValues(alpha: 0.3),
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
      if (counters.isEmpty) {
        return [_r0Row('-', '-')];
      }
      return counters
          .map((counter) => _r0Row('Poste / Début / Fin', counter))
          .toList();
    }

    List<Widget> buildStockRows(List<String> values) {
      if (values.isEmpty) {
        return [_r0Row('-', '-')];
      }
      return values
          .map((stock) => _r0Row('Poste / Park / Type / Qte', stock))
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _r0Row('Date', _field(details, ['Date'])),
        const SizedBox(height: 8),
        _activitySectionCard(
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
        _activitySectionCard(
          context,
          title: 'Arrêts',
          children: stopRows,
        ),
        const SizedBox(height: 12),
        _activitySectionCard(
          context,
          title: 'Compteurs Vibreurs',
          children: buildCounterRows(vibratorCounters),
        ),
        const SizedBox(height: 12),
        _activitySectionCard(
          context,
          title: 'Compteurs Liaison',
          children: buildCounterRows(liaisonCounters),
        ),
        const SizedBox(height: 12),
        _activitySectionCard(
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionTitle(context, 'Daily TSUD Details'),
        _r0Row('Date', _field(details, ['Date'])),
        _r0Row('Module', _field(details, ['Module'])),
        _r0Row('Nature', _field(details, ['Nature'])),
        _r0Row('Downtime', _field(details, ['Durée d\'arrêt'])),
        _r0Row('Operating', _field(details, ['Durée marche'])),
        _r0Row('Stock', _field(details, ['Stock'])),
      ],
    );
  }

  Widget _buildTruckDetailsView(
      BuildContext context, GoogleSheetRecord record) {
    final details = record.details;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        _sectionTitle(context, 'Truck Tracking Details'),
        _r0Row('Date', _field(details, ['Date'])),
        _r0Row('Mine/Exit',
            '${_field(details, ['Mine'])} / ${_field(details, ['Sortie'])}'),
        _r0Row('Equipment', _field(details, ['Machine/Engins'])),
        _r0Row('Distance', _field(details, ['Distance'])),
        _r0Row('Operation', _field(details, ['Opération', 'Operation'])),
        _r0Row('Shift', _field(details, ['Poste'])),
        _r0Row('Driver', _field(details, ['Conducteur'])),
        _r0Row('Total Trips',
            _field(details, ['Total de Voyages', 'Total de Voyages Camions'])),
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
        .split('\n')
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

  Widget _activitySectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.08),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
        ),
      ),
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
    final rows = <Widget>[];
    final itemCount =
        reasons.length > times.length ? reasons.length : times.length;
    if (itemCount == 0) {
      return [_r0Row('-', '-')];
    }
    for (var i = 0; i < itemCount; i++) {
      final reason = i < reasons.length ? reasons[i] : '-';
      final time = i < times.length ? times[i] : '-';
      rows.add(_r0Row(reason, time));
    }
    return rows;
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
    final normalizedValue = value.trim().isEmpty ? '-' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
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
}

class _RecordTypeInfo {
  final IconData icon;
  final Color color;

  const _RecordTypeInfo({
    required this.icon,
    required this.color,
  });
}
