import 'package:flutter/material.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/database_helper.dart';

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

      final productionDays = _availableProductionDays(r0Reports);

      setState(() {
        _r0Reports = r0Reports;
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _r0Reports.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No shift reports found yet. Add R0 reports to view the timeline.',
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
                      items: _availableProductionDays(_r0Reports).map((day) {
                        final label =
                            '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
                        return DropdownMenuItem(value: day, child: Text(label));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedProductionDay = value);
                      },
                    ),
                    const SizedBox(height: 18),
                    if (_selectedProductionDay != null)
                      _ShiftTimelineCard(
                        productionDay: _selectedProductionDay!,
                        reports: reportsForDay,
                      ),
                  ],
                ),
    );
  }

  List<DateTime> _availableProductionDays(List<Report> reports) {
    final days = reports.map(_productionDayFromReport).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return days;
  }

  List<Report> _reportsForProductionDay(DateTime productionDay) {
    final reportsForDay = _r0Reports
        .where((r) => _isSameDay(_productionDayFromReport(r), productionDay))
        .toList();
    reportsForDay.sort((a, b) {
      final ai = _shiftOrder.indexOf(_extractPoste(a));
      final bi = _shiftOrder.indexOf(_extractPoste(b));
      return ai.compareTo(bi);
    });
    return reportsForDay;
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

class _ShiftTimelineCard extends StatelessWidget {
  const _ShiftTimelineCard(
      {required this.productionDay, required this.reports});

  final DateTime productionDay;
  final List<Report> reports;

  static const List<String> _shiftOrder = ['3ème', '1er', '2ème'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segments = _buildSegments();
    final totalDownMinutes = segments
        .where((s) => s.isDowntime)
        .fold<int>(0, (sum, s) => sum + (s.endMinute - s.startMinute));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24h operation timeline',
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
            SizedBox(
              height: 62,
              child: CustomPaint(
                painter: _TimelinePainter(
                  segments: segments,
                  upColor: Colors.green.shade500,
                  downColor: Colors.red.shade400,
                  dividerColor: theme.dividerColor,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('22:30 (3rd)'),
                Text('06:30 (1st)'),
                Text('14:30 (2nd)'),
                Text('22:30'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _LegendChip(color: Colors.green.shade500, text: '🟢 Operation'),
                const SizedBox(width: 8),
                _LegendChip(color: Colors.red.shade400, text: '🔴 Downtime'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Operation: ${((1440 - totalDownMinutes) / 60).toStringAsFixed(2)}h • Downtime: ${(totalDownMinutes / 60).toStringAsFixed(2)}h',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _coverageText() {
    final present = reports.map(_extractPoste).toSet();
    final coverage = _shiftOrder
        .map((shift) => present.contains(shift) ? '$shift ✓' : '$shift ✕')
        .join('   ');
    return 'Reports loaded: $coverage';
  }

  List<_TimelineSegment> _buildSegments() {
    final timelineStart = DateTime(
      productionDay.year,
      productionDay.month,
      productionDay.day,
      22,
      30,
    );
    final timelineEnd = timelineStart.add(const Duration(hours: 24));

    final ranges = <_TimelineSegment>[];
    for (final report in reports) {
      ranges.addAll(_downtimeSegments(report, timelineStart, timelineEnd));
    }

    final mergedDowntime = _merge(ranges);
    if (mergedDowntime.isEmpty) {
      return const [
        _TimelineSegment(startMinute: 0, endMinute: 1440, isDowntime: false),
      ];
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
      segments.add(down);
      cursor = down.endMinute;
    }
    if (cursor < 1440) {
      segments.add(
        _TimelineSegment(
            startMinute: cursor, endMinute: 1440, isDowntime: false),
      );
    }
    return segments;
  }

  List<_TimelineSegment> _downtimeSegments(
    Report report,
    DateTime timelineStart,
    DateTime timelineEnd,
  ) {
    final data = report.additionalData ?? const <String, dynamic>{};
    final rawArrets =
        (data['Arrets'] as List?)?.whereType<Map>().toList() ?? const <Map>[];

    final ranges = <_TimelineSegment>[];
    for (final arret in rawArrets) {
      final startStr =
          (arret['Début'] ?? arret['debut'] ?? arret['start'] ?? '')
              .toString()
              .trim();
      final endStr = (arret['Fin'] ?? arret['fin'] ?? arret['end'] ?? '')
          .toString()
          .trim();
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

      ranges.add(_TimelineSegment(
        startMinute: effectiveStart.difference(timelineStart).inMinutes,
        endMinute: effectiveEnd.difference(timelineStart).inMinutes,
        isDowntime: true,
      ));
    }

    ranges.sort((a, b) => a.startMinute.compareTo(b.startMinute));
    return ranges;
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

  List<_TimelineSegment> _merge(List<_TimelineSegment> ranges) {
    if (ranges.isEmpty) return ranges;

    final sorted = [...ranges]
      ..sort((a, b) => a.startMinute.compareTo(b.startMinute));
    final merged = <_TimelineSegment>[sorted.first];
    for (final current in sorted.skip(1)) {
      final last = merged.last;
      if (current.startMinute <= last.endMinute) {
        merged[merged.length - 1] = _TimelineSegment(
          startMinute: last.startMinute,
          endMinute: current.endMinute > last.endMinute
              ? current.endMinute
              : last.endMinute,
          isDowntime: true,
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
