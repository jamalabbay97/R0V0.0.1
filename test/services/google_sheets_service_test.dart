import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:r0/data/services/google_sheets_service.dart';
import 'package:r0/domain/models/report.dart';

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

  group('GoogleSheetsService TNB template rows', () {
    final service = GoogleSheetsService();

    test('writes TNB counters in the wide per-shift meter table', () {
      final reportDate = DateTime(2026, 5, 26, 15, 46);
      final report = Report(
        description: 'Activity TNB',
        date: reportDate,
        group: 'MIB/U/E/I',
        type: 'Activity TNB',
        additionalData: {
          'T H.A': 61,
          'T H.M': 1379,
          'T H.V': 9999,
          'T H.L': 9999,
          'vibrator Counters': [
            {'poste': 'Vibreur', 'start': '12', 'end': '34.98'},
          ],
          'liaison Counters': [
            {'poste': 'LN', 'start': '3', 'end': '25.98'},
            {'poste': 'L', 'start': '76', 'end': '98.98'},
            {'poste': 'G3', 'start': '100', 'end': '122.98'},
            {'poste': 'G6', 'start': '200', 'end': '222.98'},
          ],
          'tnbShiftCounters': {
            'Vibreur': [
              {
                'shiftLabel': '3ème poste',
                'start': '12',
                'end': '20',
              },
              {
                'shiftLabel': '1er poste',
                'start': '20',
                'end': '28',
              },
              {
                'shiftLabel': '2ème poste',
                'start': '28',
                'end': '34.98',
              },
            ],
            'LN': [
              {
                'shiftLabel': '3ème poste',
                'start': '3',
                'end': '11',
              },
              {
                'shiftLabel': '1er poste',
                'start': '11',
                'end': '19',
              },
              {
                'shiftLabel': '2ème poste',
                'start': '19',
                'end': '25.98',
              },
            ],
            'L': [
              {
                'shiftLabel': '3ème poste',
                'start': '76',
                'end': '84',
              },
              {
                'shiftLabel': '1er poste',
                'start': '84',
                'end': '92',
              },
              {
                'shiftLabel': '2ème poste',
                'start': '92',
                'end': '98.98',
              },
            ],
            'G3': [
              {
                'shiftLabel': '3ème poste',
                'start': '100',
                'end': '108',
              },
              {
                'shiftLabel': '1er poste',
                'start': '108',
                'end': '116',
              },
              {
                'shiftLabel': '2ème poste',
                'start': '119',
                'end': '122.98',
              },
            ],
            'G6': [
              {
                'shiftLabel': '3ème poste',
                'start': '200',
                'end': '208',
              },
              {
                'shiftLabel': '1er poste',
                'start': '208',
                'end': '216',
              },
              {
                'shiftLabel': '2ème poste',
                'start': '216',
                'end': '222.98',
              },
            ],
          },
          'stock': [
            {'poste': '2ème', 'park': 'PARK 2', 'type': 'PB30'},
            {'poste': '1er', 'park': 'PARK 1', 'type': 'OCEANE'},
            {'poste': '3ème', 'park': 'PARK 1', 'type': 'OCEANE'},
          ],
        },
      );
      final rows = service.buildTemplateRowsForTest(report, reportDate);
      final mergeRanges = service.buildTemplateMergeRangesForTest(
        report,
        reportDate,
      );

      expect(rows, hasLength(3));
      expect(rows.first.sublist(7, 30), [
        '2026-05-26 15:46:00',
        '22h 59m',
        '22h 59m',
        '2ème',
        '28',
        '34.98',
        '6.98',
        '2ème',
        '19',
        '25.98',
        '6.98',
        '2ème',
        '92',
        '98.98',
        '6.98',
        '2ème',
        '119',
        '122.98',
        '3.98',
        '2ème',
        '216',
        '222.98',
        '6.98',
      ]);
      expect(rows[1].sublist(10, 30), [
        '1er',
        '20',
        '28',
        '8',
        '1er',
        '11',
        '19',
        '8',
        '1er',
        '84',
        '92',
        '8',
        '1er',
        '108',
        '116',
        '8',
        '1er',
        '208',
        '216',
        '8',
      ]);
      expect(rows.map((row) => row[30]), [
        '2ème / PARK 2 / PB30',
        '1er / PARK 1 / OCEANE',
        '3ème / PARK 1 / OCEANE',
      ]);
      expect(
        mergeRanges,
        isNot(
          contains({'startColumnIndex': 30, 'endColumnIndex': 31}),
        ),
      );
    });
    test('synthesizes per-shift TNB counters for older saved reports', () {
      final reportDate = DateTime(2026, 7, 27, 14, 8, 54);
      final report = Report(
        description: 'Activity TNB',
        date: reportDate,
        group: 'MIB/U/E/I',
        type: 'Activity TNB',
        additionalData: {
          'vibrator Counters': [
            {'poste': 'Vibreur', 'start': '17', 'end': '41'},
          ],
          'liaison Counters': [
            {'poste': 'LN', 'start': '26', 'end': '50'},
            {'poste': 'L', 'start': '116', 'end': '140'},
            {'poste': 'G3', 'start': '216', 'end': '240'},
            {'poste': 'G6', 'start': '61', 'end': '85'},
          ],
        },
      );

      final rows = service.buildTemplateRowsForTest(report, reportDate);

      expect(rows, hasLength(3));
      expect(rows.map((row) => row.sublist(10, 30)).toList(), [
        [
          '2ème',
          '33',
          '41',
          '8',
          '2ème',
          '42',
          '50',
          '8',
          '2ème',
          '132',
          '140',
          '8',
          '2ème',
          '232',
          '240',
          '8',
          '2ème',
          '77',
          '85',
          '8',
        ],
        [
          '1er',
          '25',
          '33',
          '8',
          '1er',
          '34',
          '42',
          '8',
          '1er',
          '124',
          '132',
          '8',
          '1er',
          '224',
          '232',
          '8',
          '1er',
          '69',
          '77',
          '8',
        ],
        [
          '3ème',
          '17',
          '25',
          '8',
          '3ème',
          '26',
          '34',
          '8',
          '3ème',
          '116',
          '124',
          '8',
          '3ème',
          '216',
          '224',
          '8',
          '3ème',
          '61',
          '69',
          '8',
        ],
      ]);
    });
  });

  group('GoogleSheetsService truck template rows', () {
    final service = GoogleSheetsService();

    test(
        'places trip totals before truck details and preserves trips beyond 12',
        () {
      final reportDate = DateTime(2026, 5, 23, 19, 45);
      final trips = List.generate(
        18,
        (index) => {
          'time': '${index.toString().padLeft(2, '0')}:15',
          'equipment': 'Chargeuse 994H',
          'productQualityType': 'NORMAL',
        },
      );
      final report = Report(
        description: 'Truck Tracking',
        date: reportDate,
        group: '3ème',
        type: 'Truck Tracking',
        additionalData: {
          'mine': 'Mine G',
          'sortie': 'Sortie 2',
          'equipment': 'Chargeuse 994H',
          'distance': 'uelhs',
          'selectedQualiteType': 'NORMAL',
          'operationType': 'Reprise',
          'selectedPoste': '3ème',
          'totalTrips': 18,
          'createdBy': 'mahdi',
          'truckData': [
            {
              'truckNumber': 'TEREX 25',
              'driver1': 'gwjxlxb',
              'counts': trips,
            },
          ],
        },
      );

      final rows = service.buildTemplateRowsForTest(report, reportDate);

      expect(rows, hasLength(1));
      expect(rows.first.sublist(8, 15), [
        '3ème',
        18,
        'Chargeuse 994H (18 = 18 Nor)',
        18,
        'mahdi',
        'TEREX 25',
        'gwjxlxb',
      ]);
      expect(rows.first.length, 33);
      expect(rows.first[32], contains('17:15'));
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

  group('GoogleSheetsService IF downtime details', () {
    final service = GoogleSheetsService();

    test('uses table fallback when downtime equipment is empty', () {
      final row = service.buildIfDowntimeRowForTest(
        DateTime(2026, 1, 1),
        {
          'startTime': '03:30',
          'endTime': '10:00',
          'duration': '6h 30m',
          'category': 'MP',
          'nature': 'manque produit',
        },
        equipmentFallback: 'TSUD',
      );

      expect(row[5], 'TSUD');
    });

    test('keeps downtime equipment when provided', () {
      final row = service.buildIfDowntimeRowForTest(
        DateTime(2026, 1, 1),
        {
          'startTime': '13:00',
          'endTime': '13:40',
          'duration': '40',
          'category': 'AI',
          'location': 'M1_CV73',
          'nature': 'bavette',
        },
        equipmentFallback: 'TSUD',
      );

      expect(row[5], 'M1_CV73');
    });
  });
}
