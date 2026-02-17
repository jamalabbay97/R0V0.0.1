import 'package:flutter_test/flutter_test.dart';
import 'package:r0/services/google_sheets_service.dart';

void main() {
  group('GoogleSheetsService normalization', () {
    final service = GoogleSheetsService();

    test('normalizes spreadsheet serial date and french date format', () {
      expect(service.normalizeSheetDateForTest('45567'), '2024-10-02');
      expect(service.normalizeSheetDateForTest('02/10/2024'), '2024-10-02');
      expect(service.normalizeSheetDateForTest('2 octobre 2024'), '2024-10-02');
    });

    test('normalizes poste variants to french canonical labels', () {
      expect(service.normalizePosteForTest('3eme'), '3ème');
      expect(service.normalizePosteForTest('troisième'), '3ème');
      expect(service.normalizePosteForTest('1'), '1er');
      expect(service.normalizePosteForTest('2e'), '2ème');
    });
  });
}
