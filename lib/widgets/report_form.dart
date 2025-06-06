import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';
import 'package:r0_app/models/report.dart';

class ReportForm extends StatefulWidget {
  final Report? initialReport;
  final String reportType;
  final Function(Report) onSubmit;
  final List<String> availableGroups;

  const ReportForm({
    super.key,
    this.initialReport,
    required this.reportType,
    required this.onSubmit,
    required this.availableGroups,
  });

  @override
  State<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<ReportForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedGroup;
  final Map<String, dynamic> _additionalData = {};

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialReport?.description ?? '',
    );
    _selectedDate = widget.initialReport?.date ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(
      widget.initialReport?.date ?? DateTime.now(),
    );
    _selectedGroup = widget.initialReport?.group ?? widget.availableGroups.first;
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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: l10n.description,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a description';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
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
          DropdownButtonFormField<String>(
            value: _selectedGroup,
            decoration: InputDecoration(
              labelText: l10n.selectGroup,
              border: const OutlineInputBorder(),
            ),
            items: widget.availableGroups.map((String group) {
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final dateTime = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                  _selectedTime.hour,
                  _selectedTime.minute,
                );

                final report = Report(
                  id: widget.initialReport?.id,
                  description: _descriptionController.text,
                  date: dateTime,
                  group: _selectedGroup,
                  type: widget.reportType,
                  additionalData: _additionalData,
                );

                widget.onSubmit(report);
              }
            },
            child: Text(widget.initialReport == null ? l10n.save : l10n.edit),
          ),
        ],
      ),
    );
  }
} 