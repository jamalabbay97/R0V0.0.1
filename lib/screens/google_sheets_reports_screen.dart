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
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 34),
              const SizedBox(height: 8),
              Text(
                'Failed to load records from Google Sheets.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
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
      return const Center(
        child: Text('No records match your filters.'),
      );
    }

    return ListView.builder(
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            title: Text(
              record.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${record.sheetName} • ${record.dateLabel} • Row ${record.rowNumber}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showRecordDetails(record),
          ),
        );
      },
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${record.sheetName} • ${record.dateLabel} • Row ${record.rowNumber}',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: _isR0Record(record)
                      ? _buildR0DetailsView(context, record)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: record.details.length,
                          itemBuilder: (context, index) {
                            final entry =
                                record.details.entries.elementAt(index);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(entry.value.isEmpty ? '-' : entry.value),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isR0Record(GoogleSheetRecord record) =>
      record.sheetName.toLowerCase().contains('r0');

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
        Center(
          child: Text('Stops Details',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              normalizedValue,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
