// ignore_for_file: avoid_print

class IndexCompteurPoste {
  String duree;
  String note;
  IndexCompteurPoste({this.duree = '', this.note = ''});
}

class VentilationItem {
  int code;
  String label;
  String duree;
  String note;
  VentilationItem(
      {required this.code,
      required this.label,
      this.duree = '',
      this.note = ''});
}

class FormData {
  List<IndexCompteurPoste> indexCompteurs =
      List.generate(3, (_) => IndexCompteurPoste());
  List<VentilationItem> ventilation = [];
  Map<String, String> exploitation = {
    'H.M': '',
    'H.A': '',
  };
}

void main() {
  print('--- Reproduction of H.M Calculation Issue ---');

  final formData = FormData();

  // 1. Simulate setting a counter for "1er Poste" (Index 1)
  // 10.0 to 18.0 = 8.0 hours
  formData.indexCompteurs[1].duree = '';
  formData.indexCompteurs[1].note = '';

  // 2. Simulate adding an Arret
  // 10:00 to 11:00 = 1.0 hour
  formData.ventilation.add(
      VentilationItem(code: 1, label: 'Panne', duree: '10:00', note: '11:00'));

  // 3. Run Calculation Logic
  _calculateHoursReal(formData);

  print('Compteur: 8.0 hours (Gross)');
  print('Arrets: 1.0 hour (Stops)');
  print('Calculated H.M: ${formData.exploitation['H.M']}');
  print('Calculated H.A: ${formData.exploitation['H.A']}');

  double gross = 8.0;
  double stops = 1.0;
  double expectedNet = gross - stops; // 7.0

  if (formData.exploitation['H.M'] == expectedNet.toStringAsFixed(2)) {
    print('RESULT: H.M is NET hours (Gross - Stops). [FIXED behavior]');
  } else if (formData.exploitation['H.M'] == gross.toStringAsFixed(2)) {
    print('RESULT: H.M is GROSS hours (Ignored Stops). [CURRENT BUG/BEHAVIOR]');
  } else {
    print('RESULT: Unknown calculation. H.M=${formData.exploitation['H.M']}');
  }
}

double _parseNumeric(String value) {
  if (value.isEmpty) return 0.0;
  return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
}

// Corrected _calculateHours matching current codebase
void _calculateHoursReal(FormData formData) {
  // Calculate gross hours from compteur indexes
  double totalGrossHours = 0;
  for (int i = 0; i < formData.indexCompteurs.length; i++) {
    final start = _parseNumeric(formData.indexCompteurs[i].duree);
    final end = _parseNumeric(formData.indexCompteurs[i].note);
    if (end > start) {
      final shiftHours =
          (end - start) / 1; // Assuming compteur is in 1.0 hour units
      totalGrossHours += shiftHours;
    }
  }

  formData.exploitation['H.M'] = totalGrossHours.toStringAsFixed(2);

  // Calculate total stoppage time from ventilation data
  double totalStoppageHours = 0;
  for (var item in formData.ventilation) {
    if (item.duree.isNotEmpty && item.note.isNotEmpty) {
      // Parse time format HH:MM
      final startParts = item.duree.split(':');
      final endParts = item.note.split(':');
      if (startParts.length == 2 && endParts.length == 2) {
        final startHour = int.parse(startParts[0]);
        final startMin = int.parse(startParts[1]);
        final endHour = int.parse(endParts[0]);
        final endMin = int.parse(endParts[1]);

        final startTotal = startHour * 60 + startMin;
        final endTotal = endHour * 60 + endMin;
        int diff = endTotal - startTotal;
        if (diff <= 0) diff += 24 * 60; // Handle overnight periods

        totalStoppageHours += diff / 60.0;
      }
    }
  }

  formData.exploitation['H.A'] = totalStoppageHours.toStringAsFixed(2);

  // Calculate net hours - REMOVED logic in real code
  final gross = _parseNumeric(formData.exploitation['H.M'] ?? '');
  final stops = _parseNumeric(formData.exploitation['H.A'] ?? '');
  final net = (gross - stops).clamp(0, double.infinity);
  formData.exploitation['H.M'] = net.toStringAsFixed(2);
}
