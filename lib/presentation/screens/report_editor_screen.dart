import 'package:flutter/material.dart';
import 'package:r0/l10n/app_localizations.dart';
import 'package:r0/domain/models/report.dart';
import 'package:r0/domain/repositories/report_repository.dart';
import 'package:provider/provider.dart';
import 'package:r0/presentation/screens/activity_report_screen.dart';
import 'package:r0/presentation/screens/daily_report_screen.dart';
import 'package:r0/presentation/screens/r0_report_screen.dart';
import 'package:r0/presentation/screens/truck_tracking_screen.dart';
import 'package:r0/presentation/screens/machines_equipment_stopped_screen.dart';
import 'package:r0/presentation/widgets/spinner_time_picker_dialog.dart';

/// ReportEditorScreen provides a comprehensive editing interface for all report types.
/// It opens the appropriate form based on the report type, pre-populated with existing data.
class ReportEditorScreen extends StatefulWidget {
  final Report report;

  const ReportEditorScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.editReportType(widget.report.type)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildEditorForReportType(),
    );
  }

  Widget _buildEditorForReportType() {
    final typeLower = widget.report.type.toLowerCase();

    // Route to the appropriate editor based on report type
    switch (typeLower) {
      case 'activity tnb':
        return _buildActivityReportEditor();
      case 'daily tsud':
        return _buildDailyReportEditor();
      case 'machine/engin arrêtés':
        return _buildMachinesEquipmentStoppedEditor();
      case 'suivi camion':
      case 'chargeuse':
      case 'pelle':
        return _buildTruckTrackingEditor();
      case 'r0':
        return _buildR0ReportEditor();
      default:
        // Check if this is an R0 report by looking for mine and selectedPoste
        if (widget.report.additionalData != null &&
            widget.report.additionalData!.containsKey('mine') &&
            widget.report.additionalData!.containsKey('selectedPoste')) {
          return _buildR0ReportEditor();
        }
        // Check if this is a truck tracking report by looking for truckData
        if (widget.report.additionalData != null &&
            widget.report.additionalData!.containsKey('truckData')) {
          return _buildTruckTrackingEditor();
        }
        // Fallback to generic editor
        return _buildGenericEditor();
    }
  }

  Widget _buildActivityReportEditor() {
    return ActivityReportEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Widget _buildDailyReportEditor() {
    return DailyReportEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Widget _buildMachinesEquipmentStoppedEditor() {
    return MachinesEquipmentStoppedEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Widget _buildTruckTrackingEditor() {
    return TruckTrackingEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Widget _buildR0ReportEditor() {
    return R0ReportEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Widget _buildGenericEditor() {
    return GenericReportEditor(
      report: widget.report,
      onSave: _handleReportSave,
    );
  }

  Future<void> _handleReportSave(Report updatedReport) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Validate that the report has at least one persistent identifier.
      // Some shared/cloud reports may not have a local SQLite id, but do have
      // a valid Firestore id and are still editable.
      if (updatedReport.id == null && updatedReport.firestoreId == null) {
        throw Exception(
            'Report identifiers are missing. Cannot update report without local or cloud ID.');
      }

      final reportRepository = context.read<ReportRepository>();
      await reportRepository.updateReport(updatedReport);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reportUpdated),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // Wait a bit for the SnackBar to be visible, then navigate back
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Return true to indicate successful update
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorUpdate(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );

        // Log the error for debugging
        debugPrint('Error updating report: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Activity Report Editor - Wraps the original form with pre-populated data
class ActivityReportEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const ActivityReportEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<ActivityReportEditor> createState() => _ActivityReportEditorState();
}

class _ActivityReportEditorState extends State<ActivityReportEditor> {
  @override
  Widget build(BuildContext context) {
    return ActivityReportScreen(
      initialReport: widget.report,
      onSave: widget.onSave,
      isEditing: true,
    );
  }
}

/// Daily Report Editor - Wraps the original form with pre-populated data
class DailyReportEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const DailyReportEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<DailyReportEditor> createState() => _DailyReportEditorState();
}

class _DailyReportEditorState extends State<DailyReportEditor> {
  @override
  Widget build(BuildContext context) {
    return DailyReportScreen(
      initialReport: widget.report,
      onSave: widget.onSave,
      isEditing: true,
    );
  }
}

/// Machines Equipment Stopped Editor - Wraps the original form with pre-populated data
class MachinesEquipmentStoppedEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const MachinesEquipmentStoppedEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<MachinesEquipmentStoppedEditor> createState() =>
      _MachinesEquipmentStoppedEditorState();
}

class _MachinesEquipmentStoppedEditorState
    extends State<MachinesEquipmentStoppedEditor> {
  @override
  Widget build(BuildContext context) {
    return MachinesEquipmentStoppedScreen(
      initialReport: widget.report,
      onSave: widget.onSave,
      isEditing: true,
    );
  }
}

/// Truck Tracking Editor - Wraps the original form with pre-populated data
class TruckTrackingEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const TruckTrackingEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<TruckTrackingEditor> createState() => _TruckTrackingEditorState();
}

class _TruckTrackingEditorState extends State<TruckTrackingEditor> {
  @override
  Widget build(BuildContext context) {
    return TruckTrackingScreen(
      formKey: GlobalKey<FormState>(),
      initialReport: widget.report,
      onSave: widget.onSave,
      isEditing: true,
    );
  }
}

/// R0 Report Editor - Wraps the original form with pre-populated data
class R0ReportEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const R0ReportEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<R0ReportEditor> createState() => _R0ReportEditorState();
}

class _R0ReportEditorState extends State<R0ReportEditor> {
  @override
  Widget build(BuildContext context) {
    return R0Report(
      initialReport: widget.report,
      onSave: widget.onSave,
      isEditing: true,
    );
  }
}

/// Generic Report Editor - For reports without specific form types
class GenericReportEditor extends StatefulWidget {
  final Report report;
  final Function(Report) onSave;

  const GenericReportEditor({
    super.key,
    required this.report,
    required this.onSave,
  });

  @override
  State<GenericReportEditor> createState() => _GenericReportEditorState();
}

class _GenericReportEditorState extends State<GenericReportEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedGroup;
  late String _selectedType;
  final Map<String, dynamic> _additionalData = {};

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.report.description);
    _selectedDate = widget.report.date;
    _selectedTime = TimeOfDay.fromDateTime(widget.report.date);
    _selectedGroup = widget.report.group;
    _selectedType = widget.report.type;

    // Copy additional data
    if (widget.report.additionalData != null) {
      _additionalData.addAll(widget.report.additionalData!);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showSpinnerTimePickerDialog(
      context: context,
      initialTime: _selectedTime,
      title: 'Choisir l\'heure',
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _saveReport() {
    if (_formKey.currentState!.validate()) {
      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final updatedReport = Report(
        id: widget.report.id,
        description: _descriptionController.text,
        date: dateTime,
        group: _selectedGroup,
        type: _selectedType,
        additionalData: _additionalData,
      );

      widget.onSave(updatedReport);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Modifier le rapport',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Veuillez entrer une description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDate(context),
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectTime(context),
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Group
            DropdownButtonFormField<String>(
              initialValue: _selectedGroup,
              decoration: const InputDecoration(
                labelText: 'Groupe',
                border: OutlineInputBorder(),
              ),
              items: ['Groupe 1', 'Groupe 2', 'Groupe 3'].map((String group) {
                return DropdownMenuItem<String>(
                  value: group,
                  child: Text(group),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedGroup = newValue;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Type
            TextFormField(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type de rapport',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _selectedType = value;
              },
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _saveReport,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(AppLocalizations.of(context)!.saveChanges),
            ),
          ],
        ),
      ),
    );
  }
}
