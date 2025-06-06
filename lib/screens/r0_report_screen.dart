import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:r0_app/models/report.dart';
import 'package:r0_app/services/database_helper.dart';
import 'package:r0_app/widgets/report_form.dart';

class R0ReportScreen extends StatefulWidget {
  const R0ReportScreen({super.key});

  @override
  State<R0ReportScreen> createState() => _R0ReportScreenState();
}

class _R0ReportScreenState extends State<R0ReportScreen> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Report> _reports = [];
  bool _isLoading = true;
  DateTime selectedDate = DateTime.now();

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
      final reports = await _databaseHelper.getReportsByType('r0');
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reports: $e')),
        );
      }
    }
  }

  Future<void> _handleSubmit(Report report) async {
    try {
      if (report.id == null) {
        await _databaseHelper.insertReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.reportSaved)),
          );
        }
      } else {
        await _databaseHelper.updateReport(report);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.reportUpdated)),
          );
        }
      }
      _loadReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorSavingReport),
          ),
        );
      }
    }
  }

  Future<void> _handleDelete(Report report) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (confirmed == true && report.id != null) {
      try {
        await _databaseHelper.deleteReport(report.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.reportDeleted)),
          );
        }
        _loadReports();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorDeletingReport)),
          );
        }
      }
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.r0Report),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Choisir la date',
            onPressed: _pickDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.noDataMessage,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (context) => Padding(
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).viewInsets.bottom,
                              ),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: ReportForm(
                                    reportType: 'r0',
                                    onSubmit: _handleSubmit,
                                    availableGroups: const [
                                      'Group A',
                                      'Group B',
                                      'Group C',
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Text(l10n.addReport),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      child: ListTile(
                        title: Text(report.description),
                        subtitle: Text(
                          '${report.group} - ${report.date.toString()}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (context) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: ReportForm(
                                          initialReport: report,
                                          reportType: 'r0',
                                          onSubmit: _handleSubmit,
                                          availableGroups: const [
                                            'Group A',
                                            'Group B',
                                            'Group C',
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _handleDelete(report),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _reports.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Changer la date'),
            )
          : null,
    );
  }
} 