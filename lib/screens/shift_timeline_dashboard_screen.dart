import 'package:flutter/material.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';

typedef _TimelineExtractor = List<_DowntimeEntry> Function(
  Report report,
  DateTime timelineStart,
  DateTime timelineEnd,
);

class ShiftTimelineDashboardScreen extends StatefulWidget {
  const ShiftTimelineDashboardScreen({super.key});

  @override
  State<ShiftTimelineDashboardScreen> createState() =>
      _ShiftTimelineDashboardScreenState();
}

class _ShiftTimelineDashboardScreenState
    extends State<ShiftTimelineDashboardScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  bool _isLoading = true;
  List<Report> _r0Reports = [];
  List<Report> _tnbReports = [];
  List<Report> _tsudReports = [];
  DateTime? _selectedProductionDay;

  static const List<String> _shiftOrder = ['3ème', '1er', '2ème'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final allReports = await _databaseHelper.getReports();
      final r0Reports = allReports.where((r) {
        final poste = _extractPoste(r);
        return _shiftOrder.contains(poste);
      }).toList();
      final tnbReports = allReports
          .where((r) => r.type.trim().toLowerCase() == 'activity tnb')
          .toList();
      final tsudReports = allReports
          .where((r) => r.type.trim().toLowerCase() == 'daily tsud')
          .toList();

      final productionDays = _availableProductionDays([
        ...r0Reports,
        ...tnbReports,
        ...tsudReports,
      ]);

      setState(() {
        _r0Reports = r0Reports;
        _tnbReports = tnbReports;
        _tsudReports = tsudReports;
        _selectedProductionDay =
            productionDays.isNotEmpty ? productionDays.first : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsForDay = _selectedProductionDay == null
        ? const <Report>[]
        : _reportsForProductionDay(_selectedProductionDay!);
    final tnbReportsForDay = _selectedProductionDay == null
        ? const <Report>[]
        : _reportsForDay(_tnbReports, _selectedProductionDay!);
    final tsudReportsForDay = _selectedProductionDay == null
        ? const <Report>[]
        : _reportsForDay(_tsudReports, _selectedProductionDay!);
    final hasAnyTimelineReports = _r0Reports.isNotEmpty ||
        _tnbReports.isNotEmpty ||
        _tsudReports.isNotEmpty;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.timeline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Timeline',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '24h operation',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : !hasAnyTimelineReports
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                'No timeline reports found yet. Add R0, TNB, or TSUD reports to view the charts.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              DropdownButtonFormField<DateTime>(
                                initialValue: _selectedProductionDay,
                                decoration: const InputDecoration(
                                  labelText: 'Select production day',
                                  border: OutlineInputBorder(),
                                ),
                                items: _availableProductionDays([
                                  ..._r0Reports,
                                  ..._tnbReports,
                                  ..._tsudReports,
                                ]).map((day) {
                                  final label =
                                      '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
                                  return DropdownMenuItem(
                                      value: day, child: Text(label));
                                }).toList(),
                                onChanged: (value) {
                                  setState(
                                      () => _selectedProductionDay = value);
                                },
                              ),
                              const SizedBox(height: 18),
                              if (_selectedProductionDay != null &&
                                  reportsForDay.isNotEmpty)
                                _ShiftTimelineCard(
                                  title: 'R0',
                                  productionDay: _selectedProductionDay!,
                                  reports: reportsForDay,
                                  tracks: const [
                                    _TimelineTrackConfig(
                                      label: 'All reports',
                                      extractor: _extractR0DowntimeSegments,
                                    ),
                                  ],
                                ),
                              if (_selectedProductionDay != null &&
                                  tnbReportsForDay.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ShiftTimelineCard(
                                  title: 'TNB',
                                  productionDay: _selectedProductionDay!,
                                  reports: tnbReportsForDay,
                                  tracks: const [
                                    _TimelineTrackConfig(
                                      label: 'All reports',
                                      extractor: _extractTnbDowntimeSegments,
                                    ),
                                  ],
                                ),
                              ],
                              if (_selectedProductionDay != null &&
                                  tsudReportsForDay.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _ShiftTimelineCard(
                                  title: 'TSUD',
                                  productionDay: _selectedProductionDay!,
                                  reports: tsudReportsForDay,
                                  tracks: const [
                                    _TimelineTrackConfig(
                                      label: 'Module 1 model',
                                      extractor:
                                          _extractTsudModule1DowntimeSegments,
                                    ),
                                    _TimelineTrackConfig(
                                      label: 'Module 2 model',
                                      extractor:
                                          _extractTsudModule2DowntimeSegments,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<DateTime> _availableProductionDays(List<Report> reports) {
    final days = reports.map(_productionDayFromReport).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return days;
  }

  List<Report> _reportsForProductionDay(DateTime productionDay) {
    final reportsForDay = _reportsForDay(_r0Reports, productionDay);
    reportsForDay.sort((a, b) {
      final ai = _shiftOrder.indexOf(_extractPoste(a));
      final bi = _shiftOrder.indexOf(_extractPoste(b));
      return ai.compareTo(bi);
    });
    return reportsForDay;
  }

  List<Report> _reportsForDay(List<Report> reports, DateTime productionDay) {
    return reports
        .where((r) => _isSameDay(_productionDayFromReport(r), productionDay))
        .toList();
  }

  DateTime _productionDayFromReport(Report report) {
    final poste = _extractPoste(report);
    final date = DateTime(report.date.year, report.date.month, report.date.day);
    if (poste == '3ème') {
      return date.subtract(const Duration(days: 1));
    }
    return date;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _extractPoste(Report report) {
    final data = report.additionalData;
    if (data == null) return '-';
    return (data['selectedPoste'] ??
            data['poste'] ??
            data['posteSelected'] ??
            '-')
        .toString();
  }
}

List<_DowntimeEntry> _extractR0DowntimeSegments(
  Report report,
  DateTime timelineStart,
  DateTime timelineEnd,
) {
  final data = report.additionalData ?? const <String, dynamic>{};
  final rawArrets =
      (data['Arrets'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
  return _parseDowntimeRanges(
    report,
    rawArrets,
    timelineStart,
    timelineEnd,
    startKeys: const ['Début', 'debut', 'start', 'startTime'],
    endKeys: const ['Fin', 'fin', 'end', 'endTime'],
  );
}

List<_DowntimeEntry> _extractTnbDowntimeSegments(
  Report report,
  DateTime timelineStart,
  DateTime timelineEnd,
) {
  final data = report.additionalData ?? const <String, dynamic>{};
  final rawStops =
      (data['Arrets'] as List?)?.whereType<Map>().toList() ?? const <Map>[];
  return _parseDowntimeRanges(
    report,
    rawStops,
    timelineStart,
    timelineEnd,
    startKeys: const ['Début', 'debut', 'start', 'startTime'],
    endKeys: const ['Fin', 'fin', 'end', 'endTime'],
  );
}

List<_DowntimeEntry> _extractTsudModule1DowntimeSegments(
  Report report,
  DateTime timelineStart,
  DateTime timelineEnd,
) {
  final data = report.additionalData ?? const <String, dynamic>{};
  final module1 = (data['module1Stops'] as List?)?.whereType<Map>().toList() ??
      const <Map>[];
  return _parseDowntimeRanges(
    report,
    module1,
    timelineStart,
    timelineEnd,
    startKeys: const ['startTime', 'Début', 'debut', 'start'],
    endKeys: const ['endTime', 'Fin', 'fin', 'end'],
  );
}

List<_DowntimeEntry> _extractTsudModule2DowntimeSegments(
  Report report,
  DateTime timelineStart,
  DateTime timelineEnd,
) {
  final data = report.additionalData ?? const <String, dynamic>{};
  final module2 = (data['module2Stops'] as List?)?.whereType<Map>().toList() ??
      const <Map>[];
  return _parseDowntimeRanges(
    report,
    module2,
    timelineStart,
    timelineEnd,
    startKeys: const ['startTime', 'Début', 'debut', 'start'],
    endKeys: const ['endTime', 'Fin', 'fin', 'end'],
  );
}

List<_DowntimeEntry> _parseDowntimeRanges(
  report,
  List<Map> entries,
  DateTime timelineStart,
  DateTime timelineEnd, {
  required List<String> startKeys,
  required List<String> endKeys,
}) {
  final ranges = <_DowntimeEntry>[];
  for (final entry in entries) {
    final startStr = _firstText(entry, startKeys);
    final endStr = _firstText(entry, endKeys);
    if (startStr.isEmpty || endStr.isEmpty) continue;

    final start = _resolveTimeInWindow(startStr, timelineStart);
    var end = _resolveTimeInWindow(endStr, timelineStart);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final effectiveStart =
        start.isBefore(timelineStart) ? timelineStart : start;
    final effectiveEnd = end.isAfter(timelineEnd) ? timelineEnd : end;
    if (!effectiveEnd.isAfter(effectiveStart)) continue;

    final source = _DowntimeSource.fromReportEntry(
      report: report,
      rawEntry: Map<String, dynamic>.from(entry),
      effectiveStart: effectiveStart,
      effectiveEnd: effectiveEnd,
      startRaw: startStr,
      endRaw: endStr,
    );

    ranges.add(_DowntimeEntry(
      startMinute: effectiveStart.difference(timelineStart).inMinutes,
      endMinute: effectiveEnd.difference(timelineStart).inMinutes,
      startTime: effectiveStart,
      endTime: effectiveEnd,
      sources: [source],
    ));
  }

  ranges.sort((a, b) => a.startMinute.compareTo(b.startMinute));
  return ranges;
}

String _firstText(Map<dynamic, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

DateTime _resolveTimeInWindow(String value, DateTime timelineStart) {
  final parts = value.split(':');
  if (parts.length < 2) return timelineStart;

  final hour = int.tryParse(parts[0].trim()) ?? 0;
  final minute = int.tryParse(parts[1].trim()) ?? 0;

  var candidate = DateTime(
    timelineStart.year,
    timelineStart.month,
    timelineStart.day,
    hour,
    minute,
  );

  if (candidate.isBefore(timelineStart)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

class _ShiftTimelineCard extends StatelessWidget {
  const _ShiftTimelineCard(
      {required this.title,
      required this.productionDay,
      required this.reports,
      required this.tracks});

  final String title;
  final DateTime productionDay;
  final List<Report> reports;
  final List<_TimelineTrackConfig> tracks;

  static const List<String> _shiftOrder = ['3ème', '1er', '2ème'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timelineStart = DateTime(
      productionDay.year,
      productionDay.month,
      productionDay.day,
      22,
      30,
    );
    final timelineEnd = timelineStart.add(const Duration(hours: 24));
    final trackData = tracks
        .map((track) => _buildTrackData(track, timelineStart, timelineEnd))
        .toList();

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title • 24h operation timeline',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Order: 3rd Shift → 1st Shift → 2nd Shift',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              _coverageText(),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ...trackData.map((track) {
              final operatingPct =
                  ((1440 - track.totalDownMinutes) / 1440) * 100;
              final downtimePct = (track.totalDownMinutes / 1440) * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          track.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _PercentagePill(
                          label: 'Operating',
                          value: '${operatingPct.toStringAsFixed(1)}%',
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 8),
                        _PercentagePill(
                          label: 'Down',
                          value: '${downtimePct.toStringAsFixed(1)}%',
                          color: Colors.red.shade500,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        return SizedBox(
                          height: 62,
                          child: Stack(
                            children: [
                              CustomPaint(
                                painter: _TimelinePainter(
                                  segments: track.segments,
                                  upColor: Colors.green.shade500,
                                  downColor: Colors.red.shade400,
                                  dividerColor: theme.dividerColor,
                                ),
                                child: const SizedBox.expand(),
                              ),
                              ...track.downtime.map((down) {
                                final startX =
                                    (down.startMinute / 1440) * width;
                                final endX = (down.endMinute / 1440) * width;
                                return Positioned(
                                  left: startX,
                                  top: 14,
                                  width: (endX - startX).clamp(10.0, width),
                                  height: 22,
                                  child: GestureDetector(
                                    onTap: () => _showDowntimeDetails(
                                        context, down, track.label),
                                    behavior: HitTestBehavior.opaque,
                                    child: const SizedBox.expand(),
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 1),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('22:30'),
                        Text('06:30'),
                        Text('14:30'),
                        Text('22:30'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Operation: ${((1440 - track.totalDownMinutes) / 60).toStringAsFixed(2)}h • Downtime: ${(track.totalDownMinutes / 60).toStringAsFixed(2)}h',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendChip(color: Colors.green.shade500, text: '🟢 Operation'),
                const SizedBox(width: 8),
                _LegendChip(color: Colors.red.shade400, text: '🔴 Downtime'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _coverageText() {
    final present = reports.map(_extractPoste).toSet();
    final hasShiftMetadata = present.any(_shiftOrder.contains);
    if (!hasShiftMetadata) {
      return 'Reports loaded: ${reports.length}';
    }
    final coverage = _shiftOrder
        .map((shift) => present.contains(shift) ? '$shift ✓' : '$shift ✕')
        .join('   ');
    return 'Reports loaded: $coverage';
  }

  _TimelineTrackData _buildTrackData(
    _TimelineTrackConfig track,
    DateTime timelineStart,
    DateTime timelineEnd,
  ) {
    final ranges = <_DowntimeEntry>[];
    for (final report in reports) {
      ranges.addAll(track.extractor(report, timelineStart, timelineEnd));
    }

    final mergedDowntime = _merge(ranges);
    final totalDownMinutes = mergedDowntime.fold<int>(
      0,
      (sum, item) => sum + (item.endMinute - item.startMinute),
    );

    if (mergedDowntime.isEmpty) {
      return _TimelineTrackData(
        label: track.label,
        segments: const [
          _TimelineSegment(startMinute: 0, endMinute: 1440, isDowntime: false),
        ],
        downtime: const [],
        totalDownMinutes: 0,
      );
    }

    final segments = <_TimelineSegment>[];
    var cursor = 0;
    for (final down in mergedDowntime) {
      if (down.startMinute > cursor) {
        segments.add(_TimelineSegment(
          startMinute: cursor,
          endMinute: down.startMinute,
          isDowntime: false,
        ));
      }
      segments.add(
        _TimelineSegment(
          startMinute: down.startMinute,
          endMinute: down.endMinute,
          isDowntime: true,
        ),
      );
      cursor = down.endMinute;
    }
    if (cursor < 1440) {
      segments.add(
        _TimelineSegment(
            startMinute: cursor, endMinute: 1440, isDowntime: false),
      );
    }
    return _TimelineTrackData(
      label: track.label,
      segments: segments,
      downtime: mergedDowntime,
      totalDownMinutes: totalDownMinutes,
    );
  }

  List<_DowntimeEntry> _merge(List<_DowntimeEntry> ranges) {
    if (ranges.isEmpty) return ranges;

    final sorted = [...ranges]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final merged = <_DowntimeEntry>[sorted.first];
    for (final current in sorted.skip(1)) {
      final last = merged.last;
      if (current.startMinute <= last.endMinute) {
        final endTime =
            current.endMinute > last.endMinute ? current.endTime : last.endTime;
        merged[merged.length - 1] = _DowntimeEntry(
          startMinute: last.startMinute,
          endMinute: current.endMinute > last.endMinute
              ? current.endMinute
              : last.endMinute,
          startTime: last.startTime,
          endTime: endTime,
          sources: [...last.sources, ...current.sources],
        );
      } else {
        merged.add(current);
      }
    }
    return merged;
  }

  String _extractPoste(Report report) {
    final data = report.additionalData ?? const <String, dynamic>{};
    return (data['selectedPoste'] ??
            data['poste'] ??
            data['posteSelected'] ??
            '-')
        .toString();
  }

  void _showDowntimeDetails(
    BuildContext context,
    _DowntimeEntry downtime,
    String trackLabel,
  ) {
    final startLabel = _formatDateTime(downtime.startTime);
    final endLabel = _formatDateTime(downtime.endTime);
    final duration = downtime.endTime.difference(downtime.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final detailedSources = [...downtime.sources]
      ..sort((a, b) => a.effectiveStart.compareTo(b.effectiveStart));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Downtime details • $trackLabel',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 14),
                _detailRow('Start', startLabel),
                const SizedBox(height: 8),
                _detailRow('End', endLabel),
                const SizedBox(height: 8),
                _detailRow(
                  'Duration',
                  '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m',
                ),
                const SizedBox(height: 14),
                Text(
                  'Reported events (${detailedSources.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: detailedSources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final source = detailedSources[index];
                      final shiftSuffix = source.shiftLabel.isEmpty
                          ? ''
                          : ' • ${source.shiftLabel}';
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ${source.titleLine}$shiftSuffix',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              source.definitionLine,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Saved timing: ${source.startRaw} → ${source.endRaw}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Duree d\'arret: ${source.duration.inHours}h ${source.duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              'Report: ${source.reportDateLabel}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.segments,
    required this.upColor,
    required this.downColor,
    required this.dividerColor,
  });

  final List<_TimelineSegment> segments;
  final Color upColor;
  final Color downColor;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 14, size.width, 22);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final base = Paint()..color = upColor.withValues(alpha: 0.18);
    canvas.drawRRect(rrect, base);

    for (final segment in segments) {
      final startX = (segment.startMinute / 1440) * size.width;
      final endX = (segment.endMinute / 1440) * size.width;
      if (endX <= startX) continue;

      final segRect = Rect.fromLTWH(startX, 14, endX - startX, 22);
      final paint = Paint()..color = segment.isDowntime ? downColor : upColor;
      canvas.drawRect(segRect, paint);
    }

    final divider = Paint()
      ..color = dividerColor
      ..strokeWidth = 1;
    for (final hour in const [0, 8, 16, 24]) {
      final x = (hour / 24) * size.width;
      canvas.drawLine(Offset(x, 10), Offset(x, 40), divider);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text),
    );
  }
}

class _TimelineTrackConfig {
  const _TimelineTrackConfig({required this.label, required this.extractor});

  final String label;
  final _TimelineExtractor extractor;
}

class _TimelineTrackData {
  const _TimelineTrackData({
    required this.label,
    required this.segments,
    required this.downtime,
    required this.totalDownMinutes,
  });

  final String label;
  final List<_TimelineSegment> segments;
  final List<_DowntimeEntry> downtime;
  final int totalDownMinutes;
}

class _PercentagePill extends StatelessWidget {
  const _PercentagePill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DowntimeEntry {
  const _DowntimeEntry({
    required this.startMinute,
    required this.endMinute,
    required this.startTime,
    required this.endTime,
    required this.sources,
  });

  final int startMinute;
  final int endMinute;
  final DateTime startTime;
  final DateTime endTime;
  final List<_DowntimeSource> sources;
}

class _DowntimeSource {
  const _DowntimeSource({
    required this.titleLine,
    required this.definitionLine,
    required this.startRaw,
    required this.endRaw,
    required this.effectiveStart,
    required this.effectiveEnd,
    required this.shiftLabel,
    required this.reportDateLabel,
  });

  final String titleLine;
  final String definitionLine;
  final String startRaw;
  final String endRaw;
  final DateTime effectiveStart;
  final DateTime effectiveEnd;
  final String shiftLabel;
  final String reportDateLabel;

  Duration get duration => effectiveEnd.difference(effectiveStart);
  factory _DowntimeSource.fromReportEntry({
    required Report report,
    required Map<String, dynamic> rawEntry,
    required DateTime effectiveStart,
    required DateTime effectiveEnd,
    required String startRaw,
    required String endRaw,
  }) {
    final category = _valueOrDash(rawEntry, const [
      'Catégorie',
      'category',
      'Category',
    ]);
    final type = _valueOrDash(rawEntry, const [
      'Arret',
      'Arrêt',
      'stopType',
      'nature',
      'type',
      'Type',
    ]);
    final definition = _valueOrDash(rawEntry, const [
      'definition',
      'Définition',
      'Definition',
      'stopDetails',
      'Détails',
      'Détail',
      'detail',
      'description',
    ]);
    final location = _valueOrDash(rawEntry, const [
      'Lieu',
      'location',
      'stopLocation',
    ]);
    final shift = (report.additionalData?['selectedPoste'] ??
            report.additionalData?['poste'] ??
            report.additionalData?['posteSelected'] ??
            '')
        .toString()
        .trim();

    final day = report.date.day.toString().padLeft(2, '0');
    final month = report.date.month.toString().padLeft(2, '0');
    final year = report.date.year;
    final reportDateLabel = '$day/$month/$year';

    final title = '$category / $type';
    final details = 'Definition: $definition'
        '${location == '-' ? '' : ' • Location: $location'}';

    return _DowntimeSource(
      titleLine: title,
      definitionLine: details,
      startRaw: startRaw,
      endRaw: endRaw,
      effectiveStart: effectiveStart,
      effectiveEnd: effectiveEnd,
      shiftLabel: shift,
      reportDateLabel: reportDateLabel,
    );
  }
}

String _valueOrDash(Map<String, dynamic> raw, List<String> keys) {
  for (final key in keys) {
    final value = raw[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '-';
}

class _TimelineSegment {
  const _TimelineSegment({
    required this.startMinute,
    required this.endMinute,
    required this.isDowntime,
  });

  final int startMinute;
  final int endMinute;
  final bool isDowntime;
}
