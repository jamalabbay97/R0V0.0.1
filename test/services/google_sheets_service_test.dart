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

  group('GoogleSheetsService header detection', () {
    final service = GoogleSheetsService();

    test('prefers actual header row over title rows in template sheets', () {
      final rows = <List<Object?>>[
        ['Rapport Journalier', '', '', ''],
        ['Mine E / Sortie 3', '', '', ''],
        [
          'Date',
          'Mine',
          'Zone',
          'Sortie',
          'Poste',
          'Machine/Engins',
          'Catégorie',
          'Model',
          'Début Compteur',
          'Fin Compteur',
          'H.M',
          "Catégorie d'Arrêt",
          'Arrêt',
          "Début d'Arrêt",
          "Fin d'Arrêt",
          'H.A'
        ],
        [
          '2026-02-14',
          'Mine E',
          'Mine E1 Zone Dragline',
          'Sortie 2',
          '2ème',
          'MACHINES',
          'SONDEUSES Electrique',
          'PV275-2',
          '25',
          '29',
          '4.00',
          'Arrêt décidé',
          'Arrêt décidé ou Stand-by',
          '16:42',
          '17:42',
          '4.00'
        ],
      ];

      expect(service.detectHeaderRowIndexForTest(rows), 2);
    });
  });

  group('GoogleSheetRecord date inheritance', () {
    test('uses fallback date when row date is blank', () {
      final inherited = DateTime(2026, 2, 14);
      final record = GoogleSheetRecord.fromRaw(
        sheetName: 'TSUD',
        rowNumber: 8,
        details: {
          'Date': '',
          'Arrêt': 'Panne hydraulique',
        },
        fallbackDate: inherited,
      );

      expect(record.date, inherited);
      expect(record.dateLabel, '2026-02-14');
      expect(record.searchableText, contains('2026-02-14'));
    });

    test('keeps explicit row date when available', () {
      final fallback = DateTime(2026, 2, 14);
      final record = GoogleSheetRecord.fromRaw(
        sheetName: 'TSUD',
        rowNumber: 9,
        details: {
          'Date': '2026-02-15',
          'Arrêt': 'Stand-by',
        },
        fallbackDate: fallback,
      );

      expect(record.date, DateTime(2026, 2, 15));
      expect(record.dateLabel, '2026-02-15');
      expect(record.searchableText, contains('2026-02-15'));
      expect(record.searchableText, isNot(contains('2026-02-14')));
    });
  });
}
