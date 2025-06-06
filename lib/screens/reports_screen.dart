import 'package:flutter/material.dart';
import 'package:r0_app/l10n/app_localizations.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
      ),
      body: const Center(
        child: Text('Reports Screen - Coming Soon'),
      ),
    );
  }
} 