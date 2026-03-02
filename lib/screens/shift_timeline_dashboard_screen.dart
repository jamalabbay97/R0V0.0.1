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
  Report? _selectedReport;

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
        final data = r.additionalData;
        if (data == null) return false;
        final poste =
            data['selectedPoste'] ?? data['poste'] ?? data['posteSelected'];
        return poste != null && _shiftOrder.contains(poste.toString());
      }).toList();

      setState(() {
        _r0Reports = r0Reports;
        _selectedReport = r0Reports.isNotEmpty ? r0Reports.first : null;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                      'No shift reports found yet. Add an R0 report to view the timeline.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    DropdownButtonFormField<Report>(
                      initialValue: _selectedReport,
                      decoration: const InputDecoration(
                        labelText: 'Select report',
                        border: OutlineInputBorder(),
                      ),
                      items: _r0Reports.map((report) {
                        final poste = _extractPoste(report);
                        final date = report.date;
                        final label =
                            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} • $poste • ${report.type}';
                        return DropdownMenuItem(
                            value: report, child: Text(label));
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedReport = value);
                      },
                    ),
                    const SizedBox(height: 18),
                    if (_selectedReport != null) ...[
                      _ShiftTimelineCard(
                          report: _selectedReport!, theme: theme),
                    ],
                  ],
                ),
    );
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
  const _ShiftTimelineCard({required this.report, required this.theme});

  final Report report;
  final ThemeData theme;

  static const _timelineStart = TimeOfDay(hour: 22, minute: 30);

  @override
  Widget build(BuildContext context) {
    final segments = _buildSegments();
    final totalDownMinutes = segments
        .where((s) => s.isDowntime)
        .fold<int>(0, (sum, s) => sum + (s.endMinute - s.startMinute));
    final uptimeHours = (1440 - totalDownMinutes) / 60;
    final downtimeHours = totalDownMinutes / 60;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '24h equipment operation vs downtime',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Order: 3rd shift → 1st shift → 2nd shift',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
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
                _LegendChip(color: Colors.green.shade500, text: 'Operation'),
                const SizedBox(width: 8),
                _LegendChip(color: Colors.red.shade400, text: 'Downtime'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Uptime: ${uptimeHours.toStringAsFixed(2)}h • Downtime: ${downtimeHours.toStringAsFixed(2)}h',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  List<_TimelineSegment> _buildSegments() {
    final window = _windowStartAndEnd();
    final downtime = _downtimeSegments(window.$1, window.$2);
    if (downtime.isEmpty) {
      return const [
        _TimelineSegment(startMinute: 0, endMinute: 1440, isDowntime: false)
      ];
    }

    final segments = <_TimelineSegment>[];
    int cursor = 0;
    for (final d in downtime) {
      if (d.startMinute > cursor) {
        segments.add(_TimelineSegment(
          startMinute: cursor,
          endMinute: d.startMinute,
          isDowntime: false,
        ));
      }
      segments.add(d);
      cursor = d.endMinute;
    }
    if (cursor < 1440) {
      segments.add(
        _TimelineSegment(
            startMinute: cursor, endMinute: 1440, isDowntime: false),
      );
    }
    return segments;
  }

  (DateTime, DateTime) _windowStartAndEnd() {
    final selectedPoste = _extractPoste(report);
    final date = report.date;

    final dayStart = DateTime(date.year, date.month, date.day);
    late DateTime timelineStart;

    if (selectedPoste == '3ème') {
      timelineStart = dayStart.add(
        Duration(hours: _timelineStart.hour, minutes: _timelineStart.minute),
      );
    } else {
      timelineStart = dayStart.subtract(const Duration(days: 1)).add(
          Duration(hours: _timelineStart.hour, minutes: _timelineStart.minute));
    }

    return (timelineStart, timelineStart.add(const Duration(hours: 24)));
  }

  List<_TimelineSegment> _downtimeSegments(
      DateTime timelineStart, DateTime timelineEnd) {
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
      DateTime end = _resolveTimeInWindow(endStr, timelineStart);
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
    return _merge(ranges);
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
    final merged = <_TimelineSegment>[ranges.first];
    for (final current in ranges.skip(1)) {
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

  String _extractPoste(Report r) {
    final data = r.additionalData ?? const <String, dynamic>{};
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
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
