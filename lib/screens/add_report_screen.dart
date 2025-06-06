import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';

class AddReportScreen extends StatelessWidget {
  const AddReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addReport),
      ),
      body: const Center(
        child: Text('Add Report Screen - Coming Soon'),
      ),
    );
  }
} 