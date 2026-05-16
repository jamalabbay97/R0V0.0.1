import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:r0/data/services/google_sheets_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('GoogleSheetsService normalization', () {
    final service = GoogleSheetsService();

    test('normalizes spreadsheet serial date and french date format', () {
      expect(service.normalizeSheetDateForTest('45567'), '2024-10-02');
      expect(service.normalizeSheetDateForTest('02/10/2024'), '2024-10-02');
      expect(service.normalizeSheetDateForTest('2 octobre 2024'), '2024-10-02');
      expect(
        service.normalizeSheetDateForTest('2026-05-16 14:03:27'),
        '2026-05-16',
      );
    });

    test('formats sheet and ISO timestamps with seconds', () {
      final timestamp = DateTime(2026, 5, 16, 14, 3, 27, 999);

      expect(
        service.formatSheetTimestampForTest(timestamp),
        '2026-05-16 14:03:27',
      );
      expect(
        service.formatIsoTimestampWithSecondsForTest(timestamp),
        '2026-05-16T14:03:27',
      );
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
  group('GoogleSheetsService R0 downtime details', () {
    final service = GoogleSheetsService();

    test('uses the dedicated R0 downtime details header layout', () {
      expect(service.r0DowntimeDetailsHeadersForTest(), [
        'Date',
        'Catégorie principale',
        'Sous-Catégorie',
        'Equipement',
        "Catégorie d'Arrét",
        "Type d'Arrét",
        "Designation d'Arrét",
        "Début d'Arret",
        "Fin d'Arret",
        'H.A',
      ]);
    });

    test('builds rows for the dedicated R0 downtime details sheet', () {
      final rows = service.buildR0DowntimeDetailsRowsForTest(
        DateTime(2026, 5, 15),
        {
          'Category': 'SONDEUSES',
          'Type': 'Electrique',
          'Model': 'PV275-2',
          'Arrets': [
            {
              'Catégorie': 'Arrêt non décidé',
              'Arret': 'Panne mécanique',
              'Detail': 'Flexible cassé',
              'Début': '08:15',
              'Fin': '09:45',
            },
          ],
        },
      );

      expect(rows, [
        [
          '2026-05-15 00:00:00',
          'SONDEUSES',
          'Electrique',
          'PV275-2',
          'Arrêt non décidé',
          'Panne mécanique',
          'Flexible cassé',
          '08:15:00',
          '09:45:00',
          '1.50',
        ],
      ]);
    });
  });
}
