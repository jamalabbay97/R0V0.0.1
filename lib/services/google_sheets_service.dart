import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:intl/intl.dart';
import 'package:r0/models/report.dart';

class GoogleSheetsService {
  GoogleSheetsService({
    String? spreadsheetId,
    String? credentialsJson,
    String? credentialsAssetPath,
    DateTime Function()? nowProvider,
  })  : _spreadsheetId = spreadsheetId ??
            (const String.fromEnvironment('GOOGLE_SHEETS_SPREADSHEET_ID')
                    .isEmpty
                ? _hardcodedSpreadsheetId
                : const String.fromEnvironment('GOOGLE_SHEETS_SPREADSHEET_ID')),
        _credentialsJson = credentialsJson ??
            const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_JSON'),
        _credentialsAssetPath = credentialsAssetPath ??
            const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_ASSET_PATH',
                defaultValue:
                    'assets/credentials/r0v01-5b577-67d9e9bae92b.json'),
        _nowProvider = nowProvider ?? DateTime.now;

  static const String _hardcodedSpreadsheetId =
      '1WzdE8fl3BwatmMXw1mcIAebOndx41XvXWdahP7nEaVo'; // Hardcoded ID

  static const String _genericReportsSheet = 'Reports';
  static const String _genericDetailsSheet = 'Report Details';
  static const String _detailsSuffix = ' - Détails';
  static const String _activitySheet = 'TNB';
  static const String _dailySheet = 'TSUD';
  static const String _truckSheet = 'Poser les camions';
  static const String _machinesSheet = 'Machines et engins à l’arrêt';
  static const String _r0Sheet = 'R0';
  static const List<String> _scopes = [SheetsApi.spreadsheetsScope];

  final String _spreadsheetId;
  final String _credentialsJson;
  final String _credentialsAssetPath;
  final DateTime Function() _nowProvider;

  SheetsApi? _sheetsApi;
  AutoRefreshingAuthClient? _authClient;
  bool _loadedSheets = false;
  final Set<String> _knownSheets = {};
  final Map<String, int> _sheetIdsByName = {};

  Future<bool> recordReportSnapshot(
    Report report, {
    required String action,
  }) async {
    try {
      if (_spreadsheetId.isEmpty ||
          _spreadsheetId == 'ENTER_YOUR_SPREADSHEET_ID_HERE') {
        debugPrint(
          'Google Sheets sync skipped: GOOGLE_SHEETS_SPREADSHEET_ID is missing or set to placeholder.',
        );
        return false;
      }

      final api = await _getSheetsApi();
      if (api == null) {
        return false;
      }

      final savedAt = _nowProvider().toIso8601String();
      final reportDate = report.date;
      final reportDateIso = reportDate.toIso8601String();
      final reportLocalDate = reportDate.toLocal();
      final payload = _buildPayload(
        report,
        savedAt: savedAt,
        action: action,
        reportDateIso: reportDateIso,
        reportLocalDate: reportLocalDate,
      );

      final templateRows = _buildTemplateRows(report, reportLocalDate);
      if (templateRows != null) {
        await _appendRowsToTemplate(api, templateRows);
        return true;
      }

      await _ensureSheetWithHeaders(api, payload.sheetName, payload.headers);
      await api.spreadsheets.values.append(
        ValueRange(values: [payload.row]),
        _spreadsheetId,
        '${payload.sheetName}!A1',
        valueInputOption: 'RAW',
        insertDataOption: 'INSERT_ROWS',
      );

      if (payload.detailsRows.isNotEmpty &&
          payload.detailsSheetName != null &&
          payload.detailsHeaders != null) {
        await _ensureSheetWithHeaders(
          api,
          payload.detailsSheetName!,
          payload.detailsHeaders!,
        );
        await api.spreadsheets.values.append(
          ValueRange(values: payload.detailsRows),
          _spreadsheetId,
          '${payload.detailsSheetName}!A1',
          valueInputOption: 'RAW',
          insertDataOption: 'INSERT_ROWS',
        );
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint('Google Sheets sync failed for report ${report.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _appendRowsToTemplate(
    SheetsApi api,
    _TemplateRows templateRows,
  ) async {
    await _loadSheetNames(api);
    if (!_knownSheets.contains(templateRows.sheetName)) {
      await api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          requests: [
            Request(
              addSheet: AddSheetRequest(
                properties: SheetProperties(title: templateRows.sheetName),
              ),
            ),
          ],
        ),
        _spreadsheetId,
      );
      _knownSheets.add(templateRows.sheetName);
      _loadedSheets = false;
      await _loadSheetNames(api);
    }

    if (templateRows.rows.isEmpty) {
      return;
    }

    final appendResponse = await api.spreadsheets.values.append(
      ValueRange(values: templateRows.rows),
      _spreadsheetId,
      '${templateRows.sheetName}!A7',
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
    );

    final rowBounds = _extractRowBounds(appendResponse.updates?.updatedRange);
    if (rowBounds == null) {
      return;
    }

    final sheetId = _sheetIdsByName[templateRows.sheetName];
    if (sheetId == null) {
      debugPrint('Sheet ID for "${templateRows.sheetName}" not found.');
      return;
    }

    final requests = <Request>[];

    final formattedColumnCount = templateRows.rows
        .map((row) => row.length)
        .fold<int>(0, (max, count) => count > max ? count : max);
    if (formattedColumnCount > 0) {
      requests.add(
        Request(
          copyPaste: CopyPasteRequest(
            source: GridRange(
              sheetId: sheetId,
              startRowIndex: 6,
              endRowIndex: 7,
              startColumnIndex: 0,
              endColumnIndex: formattedColumnCount,
            ),
            destination: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: 0,
              endColumnIndex: formattedColumnCount,
            ),
            pasteType: 'PASTE_FORMAT',
            pasteOrientation: 'NORMAL',
          ),
        ),
      );
    }

    for (final mergeRange in templateRows.mergeRanges) {
      for (var columnIndex = mergeRange.startColumnIndex;
          columnIndex < mergeRange.endColumnIndex;
          columnIndex++) {
        requests.add(
          Request(
            mergeCells: MergeCellsRequest(
              range: GridRange(
                sheetId: sheetId,
                startRowIndex: rowBounds.startRowIndex,
                endRowIndex: rowBounds.endRowIndex,
                startColumnIndex: columnIndex,
                endColumnIndex: columnIndex + 1,
              ),
              mergeType: 'MERGE_ALL',
            ),
          ),
        );
      }
    }

    for (final merge in templateRows.customMerges) {
      requests.add(
        Request(
          mergeCells: MergeCellsRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex + merge.startRowOffset,
              endRowIndex: rowBounds.startRowIndex + merge.endRowOffset,
              startColumnIndex: merge.startColumnIndex,
              endColumnIndex: merge.endColumnIndex,
            ),
            mergeType: 'MERGE_ALL',
          ),
        ),
      );
    }

    final rowColumnCount = formattedColumnCount;
    final mergeColumnCount = templateRows.mergeRanges
        .map((range) => range.endColumnIndex)
        .fold<int>(0, (max, count) => count > max ? count : max);
    final customMergeColumnCount = templateRows.customMerges
        .map((range) => range.endColumnIndex)
        .fold<int>(0, (max, count) => count > max ? count : max);
    final separatorEndColumn = [
      rowColumnCount,
      mergeColumnCount,
      customMergeColumnCount,
    ].fold<int>(0, (max, count) => count > max ? count : max);

    if (separatorEndColumn > 0) {
      final lastRowStart = rowBounds.endRowIndex - 1;
      requests.add(
        Request(
          updateBorders: UpdateBordersRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: lastRowStart,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: 0,
              endColumnIndex: separatorEndColumn,
            ),
            bottom: Border(
              style: 'SOLID_THICK',
              color: Color(red: 0, green: 0, blue: 0),
            ),
          ),
        ),
      );
    }

    if (requests.isEmpty) {
      return;
    }

    await api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(requests: requests),
      _spreadsheetId,
    );
  }

  _RowBounds? _extractRowBounds(String? updatedRange) {
    if (updatedRange == null || updatedRange.isEmpty) {
      return null;
    }

    final rowMatch =
        RegExp(r'![A-Z]+(\d+):[A-Z]+(\d+)').firstMatch(updatedRange);
    if (rowMatch == null) {
      return null;
    }

    final startRow = int.tryParse(rowMatch.group(1) ?? '');
    final endRow = int.tryParse(rowMatch.group(2) ?? '');
    if (startRow == null || endRow == null) {
      return null;
    }

    return _RowBounds(
      startRowIndex: startRow - 1,
      endRowIndex: endRow,
    );
  }

  _TemplateRows? _buildTemplateRows(Report report, DateTime reportDateLocal) {
    final data = report.additionalData ?? {};
    final category = _categorizeReport(report, data);
    final date = DateFormat('yyyy-MM-dd').format(reportDateLocal);

    switch (category) {
      case _ReportCategory.dailyTsud:
        final rows = <List<Object?>>[];
        final module1Stops = _listOfMaps(data['module1Stops']);
        final module2Stops = _listOfMaps(data['module2Stops']);
        final stockEntries = _listOfMaps(data['stock']);
        final creator = _extractCreatorName(data);

        final stopRows = <List<Object?>>[];
        final customMerges = <_TemplateCustomMerge>[];

        String durationOrZero(Object? value) {
          final formatted = _formatDuration(value);
          return formatted.isEmpty ? '0h 00m' : formatted;
        }

        void addModuleRows(
          String moduleLabel,
          List<Map<String, dynamic>> stops,
          Object? totalDowntime,
          Object? totalOperating,
        ) {
          final moduleStartRow = stopRows.length;

          if (stops.isEmpty) {
            stopRows.add([
              moduleLabel,
              '------------------------------',
              '',
              durationOrZero(totalDowntime),
              durationOrZero(totalOperating),
            ]);
            return;
          }

          for (final stop in stops) {
            stopRows.add([
              moduleLabel,
              stop['nature'] ?? '',
              _formatDuration(stop['duration']),
              '',
              '',
            ]);
          }

          stopRows[moduleStartRow][3] = durationOrZero(totalDowntime);
          stopRows[moduleStartRow][4] = durationOrZero(totalOperating);

          if (stops.length > 1) {
            customMerges.addAll([
              _TemplateCustomMerge(
                startRowOffset: moduleStartRow,
                endRowOffset: moduleStartRow + stops.length,
                startColumnIndex: 1,
                endColumnIndex: 2,
              ),
              _TemplateCustomMerge(
                startRowOffset: moduleStartRow,
                endRowOffset: moduleStartRow + stops.length,
                startColumnIndex: 4,
                endColumnIndex: 5,
              ),
              _TemplateCustomMerge(
                startRowOffset: moduleStartRow,
                endRowOffset: moduleStartRow + stops.length,
                startColumnIndex: 5,
                endColumnIndex: 6,
              ),
            ]);
          }
        }

        addModuleRows('Module 1', module1Stops, data['T H.A1'], data['T H.M1']);
        addModuleRows('Module 2', module2Stops, data['T H.A2'], data['T H.M2']);
        final maxRows = [stopRows.length, stockEntries.length, 1]
            .reduce((a, b) => a > b ? a : b);

        for (var i = 0; i < maxRows; i++) {
          final stopRow =
              i < stopRows.length ? stopRows[i] : <Object?>['', '', '', '', ''];
          final stockEntry = i < stockEntries.length ? stockEntries[i] : null;
          final includeSharedValues = i == 0;

          rows.add([
            includeSharedValues ? date : '',
            ...stopRow,
            includeSharedValues ? creator : '',
            '',
            includeSharedValues ? date : '',
            _formatStockEntry(stockEntry),
          ]);
        }

        final mergeRanges = <_TemplateMergeRange>[];
        if (rows.length > 1) {
          mergeRanges.addAll([
            const _TemplateMergeRange(startColumnIndex: 0, endColumnIndex: 1),
            const _TemplateMergeRange(startColumnIndex: 6, endColumnIndex: 7),
            const _TemplateMergeRange(startColumnIndex: 8, endColumnIndex: 9),
          ]);
        }

        return _TemplateRows(
          sheetName: _dailySheet,
          rows: rows,
          mergeRanges: mergeRanges,
          customMerges: customMerges,
        );
      case _ReportCategory.activityTnb:
        final stops = _listOfMaps(data['Arrets']);
        final vibratorCounters = _listOfMaps(data['vibrator Counters']);
        final liaisonCounters = _listOfMaps(data['liaison Counters']);
        final stock = _listOfMaps(data['stock']);

        final maxRows = [
          stops.length,
          vibratorCounters.length,
          liaisonCounters.length,
          stock.length,
          1,
        ].reduce((a, b) => a > b ? a : b);

        final rows = <List<Object?>>[];
        for (var i = 0; i < maxRows; i++) {
          final stop = i < stops.length ? stops[i] : null;
          final vibrator =
              i < vibratorCounters.length ? vibratorCounters[i] : null;
          final liaison =
              i < liaisonCounters.length ? liaisonCounters[i] : null;
          final stockEntry = i < stock.length ? stock[i] : null;
          final includeSharedValues = i == 0;

          rows.add([
            includeSharedValues ? date : '',
            stop?['nature'] ?? '',
            _formatDuration(stop?['duration']),
            includeSharedValues ? _formatDuration(data['T H.A']) : '',
            includeSharedValues ? _formatDuration(data['T H.M']) : '',
            includeSharedValues ? _extractCreatorName(data) : '',
            '',
            includeSharedValues ? date : '',
            _formatCounterEntry(vibrator),
            includeSharedValues ? _formatDuration(data['T H.V']) : '',
            _formatCounterEntry(liaison),
            includeSharedValues ? _formatDuration(data['T H.L']) : '',
            _formatStockEntry(stockEntry),
          ]);
        }

        final mergeRanges = <_TemplateMergeRange>[];
        if (rows.length > 1) {
          mergeRanges.addAll([
            const _TemplateMergeRange(startColumnIndex: 0, endColumnIndex: 1),
            const _TemplateMergeRange(startColumnIndex: 3, endColumnIndex: 6),
            const _TemplateMergeRange(startColumnIndex: 7, endColumnIndex: 8),
            const _TemplateMergeRange(startColumnIndex: 9, endColumnIndex: 10),
            const _TemplateMergeRange(startColumnIndex: 11, endColumnIndex: 12),
          ]);
        }

        return _TemplateRows(
          sheetName: _activitySheet,
          rows: rows,
          mergeRanges: mergeRanges,
        );
      case _ReportCategory.r0:
        final rows = <List<Object?>>[];
        final exploitation = _mapOfStringDynamic(data['exploitation']);
        final repartition = _resolveR0Repartition(data);
        final personnel = _mapOfStringDynamic(data['personnel']);
        final consommation = _mapOfStringDynamic(data['consommation']);
        final compteurs = _mapOfStringDynamic(data['Compteurs']);
        final arrets = _listOfMaps(data['Arrets']);
        final creator = _extractCreatorName(data);

        List<Object?> sharedPrefix({required bool includeValues}) => [
              includeValues ? date : '',
              includeValues ? data['mine'] ?? '' : '',
              includeValues ? data['zone'] ?? '' : '',
              includeValues ? data['sortie'] ?? '' : '',
              includeValues ? data['selectedPoste'] ?? '' : '',
              includeValues ? data['Category'] ?? '' : '',
              includeValues ? data['Type'] ?? '' : '',
              includeValues ? data['Model'] ?? '' : '',
              includeValues ? compteurs['duree'] ?? '' : '',
              includeValues ? compteurs['note'] ?? '' : '',
              includeValues ? exploitation['H.M'] ?? '' : '',
            ];

        List<Object?> sharedSuffix({required bool includeValues}) => [
              includeValues ? exploitation['Tonnage'] ?? '' : '',
              includeValues ? exploitation['metrage fore'] ?? '' : '',
              includeValues ? exploitation['Nr de Trous Fores'] ?? '' : '',
              includeValues ? exploitation['Nr de Voyages'] ?? '' : '',
              includeValues ? exploitation['M³ Decapages'] ?? '' : '',
              includeValues ? exploitation['Nombre T.K.U'] ?? '' : '',
              includeValues
                  ? exploitation['Rendement %'] ?? exploitation['Rendeme'] ?? ''
                  : '',
              includeValues ? repartition['Chantier'] ?? '' : '',
              includeValues ? repartition['Temps'] ?? '' : '',
              includeValues ? repartition['Imputation'] ?? '' : '',
              includeValues ? personnel['conductr'] ?? '' : '',
              includeValues ? personnel['graisseur'] ?? '' : '',
              includeValues ? personnel['matricules'] ?? '' : '',
              includeValues ? consommation['tricone'] ?? '' : '',
              includeValues ? consommation['gasoil'] ?? '' : '',
              includeValues ? creator : '',
              includeValues ? date : '',
            ];

        if (arrets.isEmpty) {
          rows.add([
            ...sharedPrefix(includeValues: true),
            '',
            '',
            '',
            '',
            exploitation['H.A'] ?? '',
            ...sharedSuffix(includeValues: true),
          ]);
        }

        for (var i = 0; i < arrets.length; i++) {
          final arret = arrets[i];
          final includeSharedValues = i == 0;

          rows.add([
            ...sharedPrefix(includeValues: includeSharedValues),
            arret['Catégorie'] ?? '',
            arret['Arret'] ?? '',
            arret['Début'] ?? '',
            arret['Fin'] ?? '',
            includeSharedValues ? exploitation['H.A'] ?? '' : '',
            ...sharedSuffix(includeValues: includeSharedValues),
          ]);
        }

        final mergeRanges = <_TemplateMergeRange>[];
        if (rows.length > 1) {
          mergeRanges.addAll([
            const _TemplateMergeRange(startColumnIndex: 0, endColumnIndex: 11),
            const _TemplateMergeRange(startColumnIndex: 16, endColumnIndex: 26),
            const _TemplateMergeRange(startColumnIndex: 26, endColumnIndex: 29),
            const _TemplateMergeRange(startColumnIndex: 29, endColumnIndex: 33),
          ]);
        }

        return _TemplateRows(
          sheetName: _r0Sheet,
          rows: rows,
          mergeRanges: mergeRanges,
        );
      case _ReportCategory.truckTracking:
        final rows = <List<Object?>>[];
        final trucks = _listOfMaps(data['truckData']);
        final totalTrips = _resolveTotalTrips(data, trucks);
        final equipmentSummary = _formatEquipmentTripsForTemplate(trucks);
        final creator = _extractCreatorName(data);

        for (var i = 0; i < trucks.length; i++) {
          final truck = trucks[i];
          final includeSharedValues = i == 0;
          final trips = _listOfMaps(truck['counts']);
          final tripCells = trips
              .map((trip) => _formatTruckTripCell(
                    time: trip['time']?.toString() ?? '',
                    equipment: trip['equipment']?.toString() ?? '',
                    quality: trip['productQualityType'],
                  ))
              .toList();

          while (tripCells.length < 12) {
            tripCells.add('');
          }

          rows.add([
            includeSharedValues ? date : '',
            includeSharedValues ? data['mine'] ?? '' : '',
            includeSharedValues ? data['sortie'] ?? '' : '',
            includeSharedValues
                ? data['equipment'] ?? data['selectedQualite'] ?? ''
                : '',
            includeSharedValues ? data['distance'] ?? '' : '',
            includeSharedValues ? data['selectedQualiteType'] ?? '' : '',
            includeSharedValues ? data['operationType'] ?? '' : '',
            '',
            includeSharedValues ? data['selectedPoste'] ?? '' : '',
            truck['truckNumber'] ?? '',
            truck['driver1'] ?? '',
            ...tripCells.take(12),
            trips.length,
            includeSharedValues ? equipmentSummary : '',
            includeSharedValues ? totalTrips : '',
            includeSharedValues ? creator : '',
          ]);
        }
        if (rows.isEmpty) {
          rows.add([
            date,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['equipment'] ?? data['selectedQualite'] ?? '',
            data['distance'] ?? '',
            data['selectedQualiteType'] ?? '',
            data['operationType'] ?? '',
            '',
            data['selectedPoste'] ?? '',
            '',
            '',
            ...List.filled(12, ''),
            0,
            equipmentSummary,
            totalTrips,
            creator,
          ]);
        }
        final mergeRanges = <_TemplateMergeRange>[];
        if (rows.length > 1) {
          mergeRanges.addAll([
            const _TemplateMergeRange(startColumnIndex: 0, endColumnIndex: 9),
            const _TemplateMergeRange(startColumnIndex: 24, endColumnIndex: 27),
          ]);
        }
        return _TemplateRows(
          sheetName: _truckSheet,
          rows: rows,
          mergeRanges: mergeRanges,
        );
      case _ReportCategory.machinesStopped:
        final equipmentList = _listOfMaps(data['equipmentList']);
        final creator = _extractCreatorName(data);
        final rows = equipmentList.asMap().entries.map((item) {
          final index = item.key;
          final entry = item.value;
          final equipmentParts =
              _splitEquipmentType(entry['equipmentType']?.toString());
          return [
            index == 0 ? date : '',
            equipmentParts.mainCategory,
            equipmentParts.subCategory,
            equipmentParts.equipment,
            entry['Reason'] ?? '',
            index == 0 ? creator : '',
          ];
        }).toList();
        if (rows.isEmpty) {
          rows.add([date, '', '', '', '', creator]);
        }
        final mergeRanges = <_TemplateMergeRange>[];
        if (rows.length > 1) {
          mergeRanges.addAll([
            const _TemplateMergeRange(startColumnIndex: 0, endColumnIndex: 1),
            const _TemplateMergeRange(startColumnIndex: 5, endColumnIndex: 6),
          ]);
        }
        return _TemplateRows(
          sheetName: _machinesSheet,
          rows: rows,
          mergeRanges: mergeRanges,
        );
      case _ReportCategory.generic:
        return null;
    }
  }

  String _formatCounterEntry(Map<String, dynamic>? counter) {
    if (counter == null) {
      return '';
    }
    final poste = _posteLabel(counter['poste']);
    final start = counter['start']?.toString().trim() ?? '';
    final end = counter['end']?.toString().trim() ?? '';

    if (start.isEmpty && end.isEmpty) {
      return poste;
    }
    if (poste.isEmpty) {
      return '$start -> $end'.trim();
    }
    return '$poste / $start -> $end';
  }

  String _formatStockEntry(Map<String, dynamic>? stockEntry) {
    if (stockEntry == null) {
      return '';
    }
    final poste = _posteLabel(stockEntry['poste']);
    final park = _parkLabel(stockEntry['park']);
    final type = _stockTypeLabel(stockEntry['type']);
    return [poste, park, type].where((part) => part.isNotEmpty).join(' / ');
  }

  String _formatDuration(dynamic value) {
    final minutes = _durationToMinutes(value);
    if (minutes == null) {
      final asString = value?.toString().trim() ?? '';
      return asString;
    }
    return _minutesToHourMinuteLabel(minutes);
  }

  int? _durationToMinutes(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toInt();
    }

    final asString = value.toString().trim();
    if (asString.isEmpty) {
      return null;
    }

    final parsedMinutes = int.tryParse(asString);
    if (parsedMinutes != null) {
      return parsedMinutes;
    }

    final normalized = asString
        .toLowerCase()
        .replaceAll(',', ' ')
        .replaceAll('min', 'm')
        .replaceAll('mn', 'm')
        .replaceAll('heure', 'h')
        .replaceAll('heures', 'h')
        .replaceAll(RegExp(r'\s+'), '');

    final hhmmMatch = RegExp(r'^(\d+):(\d{1,2})$').firstMatch(normalized);
    if (hhmmMatch != null) {
      final hours = int.parse(hhmmMatch.group(1)!);
      final minutes = int.parse(hhmmMatch.group(2)!);
      return hours * 60 + minutes;
    }

    final hmMatch = RegExp(r'^(\d+)h(?:(\d{1,2})m?)?$').firstMatch(normalized);
    if (hmMatch != null) {
      final hours = int.parse(hmMatch.group(1)!);
      final minutes = int.tryParse(hmMatch.group(2) ?? '0') ?? 0;
      return hours * 60 + minutes;
    }

    final onlyMinutesMatch = RegExp(r'^(\d{1,4})m$').firstMatch(normalized);
    if (onlyMinutesMatch != null) {
      return int.parse(onlyMinutesMatch.group(1)!);
    }

    return null;
  }

  String _minutesToHourMinuteLabel(int totalMinutes) {
    final minutes = totalMinutes < 0 ? 0 : totalMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')}m';
  }

  String _extractCreatorName(Map<String, dynamic> data) {
    for (final key in const [
      'createdBy',
      'created_by',
      'createdByName',
      'userName',
      'author',
    ]) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _posteLabel(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) {
      switch (value.toInt()) {
        case 0:
          return '3ème';
        case 1:
          return '1er';
        case 2:
          return '2ème';
      }
    }
    return value.toString();
  }

  String _parkLabel(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) {
      switch (value.toInt()) {
        case 0:
          return 'PARK 1';
        case 1:
          return 'PARK 2';
        case 2:
          return 'PARK 3';
      }
    }
    return value.toString();
  }

  String _stockTypeLabel(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) {
      switch (value.toInt()) {
        case 0:
          return 'NORMAL';
        case 1:
          return 'OCEANE';
        case 2:
          return 'PB30';
      }
    }
    return value.toString();
  }

  int _resolveTotalTrips(
      Map<String, dynamic> data, List<Map<String, dynamic>> trucks) {
    final fromPayload = data['totalTrips'];
    if (fromPayload is num) {
      return fromPayload.toInt();
    }
    if (fromPayload is String) {
      final parsed = int.tryParse(fromPayload);
      if (parsed != null) {
        return parsed;
      }
    }
    return trucks.fold<int>(
      0,
      (sum, truck) => sum + _listOfMaps(truck['counts']).length,
    );
  }

  String _formatTruckTripCell({
    required String time,
    required String equipment,
    required dynamic quality,
  }) {
    final normalizedTime = time.trim();
    final normalizedEquipment = equipment.trim();
    final normalizedQuality = _normalizeTruckQualityLabel(quality);
    return [normalizedTime, normalizedEquipment, normalizedQuality]
        .where((value) => value.isNotEmpty)
        .join('\n');
  }

  String _formatEquipmentTripsForTemplate(List<Map<String, dynamic>> trucks) {
    final Map<String, int> equipmentTotals = {};
    final Map<String, Map<String, int>> qualityBreakdowns = {};

    for (final truck in trucks) {
      for (final trip in _listOfMaps(truck['counts'])) {
        final equipment = (trip['equipment']?.toString() ?? '').trim();
        if (equipment.isEmpty) {
          continue;
        }
        final quality = _normalizeTruckQualityLabel(trip['productQualityType']);

        equipmentTotals[equipment] = (equipmentTotals[equipment] ?? 0) + 1;
        qualityBreakdowns.putIfAbsent(equipment, () => {});
        if (quality.isNotEmpty) {
          qualityBreakdowns[equipment]![quality] =
              (qualityBreakdowns[equipment]![quality] ?? 0) + 1;
        }
      }
    }

    if (equipmentTotals.isEmpty) {
      return '';
    }

    final lines = <String>[];
    final sortedEquipment = equipmentTotals.keys.toList()..sort();
    for (final equipment in sortedEquipment) {
      final total = equipmentTotals[equipment] ?? 0;
      final qualityMap = qualityBreakdowns[equipment] ?? const {};
      if (qualityMap.isEmpty) {
        lines.add('$equipment ($total)');
        continue;
      }

      final qualityParts = <String>[];
      for (final quality in _qualityDisplayOrder) {
        final count = qualityMap[quality];
        if (count != null && count > 0) {
          qualityParts.add('$count ${_qualityAbbreviation(quality)}');
        }
      }
      qualityMap.forEach((quality, count) {
        if (count > 0 && !_qualityDisplayOrder.contains(quality)) {
          qualityParts.add('$count ${_qualityAbbreviation(quality)}');
        }
      });

      final breakdown = qualityParts.join(' + ');
      lines.add('$equipment ($total = $breakdown)');
    }
    return lines.join('\n');
  }

  static const List<String> _qualityDisplayOrder = [
    'NORMAL',
    'OCEANE',
    'PB30',
  ];

  String _qualityAbbreviation(String quality) {
    switch (quality) {
      case 'NORMAL':
        return 'Nor';
      case 'OCEANE':
        return 'OC';
      case 'PB30':
        return 'PB30';
      default:
        return quality;
    }
  }

  String _normalizeTruckQualityLabel(dynamic quality) {
    if (quality == null) {
      return '';
    }
    final normalized = quality.toString().trim().toUpperCase();
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized.contains('PB30')) {
      return 'PB30';
    }
    if (normalized.contains('OCEANE')) {
      return 'OCEANE';
    }
    if (normalized.contains('NORMAL')) {
      return 'NORMAL';
    }
    return quality.toString().trim();
  }

  _EquipmentTypeParts _splitEquipmentType(String? rawValue) {
    final normalized = (rawValue ?? '').trim();
    if (normalized.isEmpty) {
      return const _EquipmentTypeParts();
    }

    final parts = normalized
        .split(RegExp(r'\s*-\s*'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length >= 3) {
      return _EquipmentTypeParts(
        mainCategory: parts[0],
        subCategory: parts[1],
        equipment: parts.sublist(2).join(' - '),
      );
    }
    if (parts.length == 2) {
      return _EquipmentTypeParts(
        mainCategory: parts[0],
        equipment: parts[1],
      );
    }

    return _EquipmentTypeParts(equipment: normalized);
  }

  Future<SheetsApi?> _getSheetsApi() async {
    if (_sheetsApi != null) {
      return _sheetsApi;
    }

    final credentials = await _loadCredentials();
    if (credentials == null) {
      debugPrint(
        'Google Sheets sync skipped: credentials are not configured.',
      );
      return null;
    }

    _authClient = await clientViaServiceAccount(credentials, _scopes);
    _sheetsApi = SheetsApi(_authClient!);
    return _sheetsApi;
  }

  Future<ServiceAccountCredentials?> _loadCredentials() async {
    if (_credentialsJson.isNotEmpty) {
      return ServiceAccountCredentials.fromJson(
        jsonDecode(_credentialsJson) as Map<String, dynamic>,
      );
    }

    if (_credentialsAssetPath.isEmpty) {
      return null;
    }

    try {
      final data = await rootBundle.loadString(_credentialsAssetPath);
      return ServiceAccountCredentials.fromJson(
        jsonDecode(data) as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint(
        'Failed to load Google Sheets credentials from asset: $e',
      );
      return null;
    }
  }

  Future<void> _ensureSheetWithHeaders(
    SheetsApi api,
    String sheetName,
    List<String> headers,
  ) async {
    await _loadSheetNames(api);

    if (!_knownSheets.contains(sheetName)) {
      await api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          requests: [
            Request(
              addSheet: AddSheetRequest(
                properties: SheetProperties(title: sheetName),
              ),
            ),
          ],
        ),
        _spreadsheetId,
      );
      _knownSheets.add(sheetName);
    }

    final headerRange = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!1:1',
    );
    if (headerRange.values == null || headerRange.values!.isEmpty) {
      await api.spreadsheets.values.update(
        ValueRange(values: [headers]),
        _spreadsheetId,
        '$sheetName!1:1',
        valueInputOption: 'RAW',
      );
    }
  }

  Future<void> _loadSheetNames(SheetsApi api) async {
    if (_loadedSheets) {
      return;
    }

    final spreadsheet = await api.spreadsheets.get(_spreadsheetId);
    final sheets = spreadsheet.sheets ?? [];
    for (final sheet in sheets) {
      final title = sheet.properties?.title;
      final sheetId = sheet.properties?.sheetId;
      if (title != null) {
        _knownSheets.add(title);
        if (sheetId != null) {
          _sheetIdsByName[title] = sheetId;
        }
      }
    }
    _loadedSheets = true;
  }

  _ReportPayload _buildPayload(
    Report report, {
    required String savedAt,
    required String action,
    required String reportDateIso,
    required DateTime reportLocalDate,
  }) {
    final reportDateLocal = reportLocalDate.toIso8601String().split('T').first;
    final reportTimeLocal = reportLocalDate.toIso8601String().split('T').last;
    final displayTitle = _resolveDisplayTitle(report);
    final displayDate = _formatDisplayDate(reportLocalDate);
    final data = report.additionalData ?? {};
    final displayMineZone = _formatMineZone(data);
    final displayTotalTrips = _formatTotalTrips(data);
    final baseRow = [
      displayTitle,
      report.type,
      displayDate,
      report.group,
      displayMineZone,
      displayTotalTrips,
      report.description,
      savedAt,
      action,
      report.id?.toString() ?? '',
      report.firestoreId ?? '',
      reportDateIso,
      reportDateLocal,
      reportTimeLocal,
    ];

    final category = _categorizeReport(report, data);

    switch (category) {
      case _ReportCategory.activityTnb:
        return _activityPayload(
            report, data, baseRow, savedAt, action, reportDateIso);
      case _ReportCategory.dailyTsud:
        return _dailyPayload(
            report, data, baseRow, savedAt, action, reportDateIso);
      case _ReportCategory.truckTracking:
        return _truckTrackingPayload(
            report, data, baseRow, savedAt, action, reportDateIso);
      case _ReportCategory.machinesStopped:
        return _machinesPayload(
            report, data, baseRow, savedAt, action, reportDateIso);
      case _ReportCategory.r0:
        return _r0Payload(
            report, data, baseRow, savedAt, action, reportDateIso);
      case _ReportCategory.generic:
        return _genericPayload(
            report, data, baseRow, savedAt, action, reportDateIso);
    }
  }

  _ReportCategory _categorizeReport(
    Report report,
    Map<String, dynamic> data,
  ) {
    final type = report.type.trim().toLowerCase();
    if (type == 'activity tnb' || data.containsKey('vibrator Counters')) {
      return _ReportCategory.activityTnb;
    }
    if (type.contains('daily') || data.containsKey('module1Stops')) {
      return _ReportCategory.dailyTsud;
    }
    if (data.containsKey('truckData')) {
      return _ReportCategory.truckTracking;
    }
    if (data.containsKey('equipmentList')) {
      return _ReportCategory.machinesStopped;
    }
    final hasR0CoreFields = data.containsKey('exploitation') ||
        data.containsKey('Compteurs') ||
        data.containsKey('Arrets') ||
        data.containsKey('selectedPoste') ||
        data.containsKey('mine') ||
        data.containsKey('zone') ||
        data.containsKey('repartition') ||
        data.containsKey('Répartition Travail');
    final isR0ByType =
        type == 'r0' || type.contains('rapport r0') || type.contains('r0');
    if (hasR0CoreFields || isR0ByType) {
      return _ReportCategory.r0;
    }
    return _ReportCategory.generic;
  }

  Map<String, dynamic> _resolveR0Repartition(Map<String, dynamic> data) {
    final repartition = _mapOfStringDynamic(data['repartition']);
    final repartitionTravail = _listOfMaps(data['Répartition Travail'])
        .map(_mapOfStringDynamic)
        .where((entry) => entry.isNotEmpty)
        .toList();

    String joinDistinctValues(
      List<Map<String, dynamic>> entries,
      List<String> keys,
    ) {
      return entries
          .map((entry) {
            for (final key in keys) {
              final value = entry[key];
              if (value != null && value.toString().trim().isNotEmpty) {
                return value.toString().trim();
              }
            }
            return '';
          })
          .where((value) => value.isNotEmpty)
          .toSet()
          .join(' | ');
    }

    final chantierValues = joinDistinctValues(
      repartitionTravail,
      const ['Chantier', 'chantier'],
    );
    final tempsValues = joinDistinctValues(
      repartitionTravail,
      const ['Temps', 'temps'],
    );
    final imputationValues = joinDistinctValues(
      repartitionTravail,
      const ['Imputation', 'imputation'],
    );

    String mapValue(Map<String, dynamic> map, List<String> keys) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    return {
      ...repartition,
      'Chantier': chantierValues.isNotEmpty
          ? chantierValues
          : mapValue(repartition, const ['Chantier', 'chantier']),
      'Temps': tempsValues.isNotEmpty
          ? tempsValues
          : mapValue(repartition, const ['Temps', 'temps']),
      'Imputation': imputationValues.isNotEmpty
          ? imputationValues
          : mapValue(repartition, const ['Imputation', 'imputation']),
    };
  }

  _ReportPayload _activityPayload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final sheetName = _sanitizeSheetTitle(_activitySheet);
    final headers = [
      ..._baseHeaders,
      'T H.A (Downtime)',
      'T H.M (Operating)',
      'T H.V (Vibrator)',
      'T H.L (Liaison)',
      'T Nr.A (Stops)',
      'T Nr.V (Vibrators)',
      'T Nr.L (Liaisons)',
      'T Nr.S (Stock)',
    ];

    final row = [
      ...baseRow,
      data['T H.A'] ?? '',
      data['T H.M'] ?? '',
      data['T H.V'] ?? '',
      data['T H.L'] ?? '',
      data['T Nr.A'] ?? '',
      data['T Nr.V'] ?? '',
      data['T Nr.L'] ?? '',
      data['T Nr.S'] ?? '',
    ];

    final detailsHeaders = [
      ..._detailsBaseHeaders,
      'Section',
      'Item Index',
      'Poste',
      'Park',
      'Stock Type',
      'Category',
      'Duration',
      'Nature',
      'Start',
      'End',
      'Quantity',
    ];

    final detailsRows = <List<Object?>>[];
    final stops = _listOfMaps(data['Arrets']);
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Arrêts',
        i + 1,
        '',
        '',
        '',
        stop['Catégorie'] ?? '',
        stop['duration'] ?? '',
        stop['nature'] ?? '',
        '',
        '',
        '',
      ]);
    }

    final vibratorCounters = _listOfMaps(data['vibrator Counters']);
    for (var i = 0; i < vibratorCounters.length; i++) {
      final counter = vibratorCounters[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Vibrator Counters',
        i + 1,
        counter['poste'] ?? '',
        '',
        '',
        '',
        '',
        '',
        counter['start'] ?? '',
        counter['end'] ?? '',
        '',
      ]);
    }

    final liaisonCounters = _listOfMaps(data['liaison Counters']);
    for (var i = 0; i < liaisonCounters.length; i++) {
      final counter = liaisonCounters[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Liaison Counters',
        i + 1,
        counter['poste'] ?? '',
        '',
        '',
        '',
        '',
        '',
        counter['start'] ?? '',
        counter['end'] ?? '',
        '',
      ]);
    }

    final stock = _listOfMaps(data['stock']);
    for (var i = 0; i < stock.length; i++) {
      final entry = stock[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Stock',
        i + 1,
        entry['poste'] ?? '',
        entry['park'] ?? '',
        entry['type'] ?? '',
        '',
        '',
        '',
        '',
        '',
        entry['quantity'] ?? '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName$_detailsSuffix'),
      detailsHeaders: detailsHeaders,
      detailsRows: detailsRows,
    );
  }

  _ReportPayload _dailyPayload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final sheetName = _sanitizeSheetTitle(_dailySheet);
    final headers = [
      ..._baseHeaders,
      'T H.A1 (Downtime M1)',
      'T H.M1 (Operating M1)',
      'T H.A2 (Downtime M2)',
      'T H.M2 (Operating M2)',
      'Module 1 Stops',
      'Module 2 Stops',
      'Stock Entries',
    ];
    final module1Stops = _listOfMaps(data['module1Stops']);
    final module2Stops = _listOfMaps(data['module2Stops']);
    final stock = _listOfMaps(data['stock']);
    final row = [
      ...baseRow,
      data['T H.A1'] ?? '',
      data['T H.M1'] ?? '',
      data['T H.A2'] ?? '',
      data['T H.M2'] ?? '',
      module1Stops.length,
      module2Stops.length,
      stock.length,
    ];

    final detailsHeaders = [
      ..._detailsBaseHeaders,
      'Section',
      'Item Index',
      'Poste',
      'Park',
      'Stock Type',
      'Category',
      'Duration',
      'Nature',
      'Quantity',
      'Carry Over',
    ];

    final detailsRows = <List<Object?>>[];
    for (var i = 0; i < module1Stops.length; i++) {
      final stop = module1Stops[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Arrêts M1',
        i + 1,
        '',
        '',
        '',
        stop['Catégorie'] ?? 'Module 1',
        _formatDuration(stop['duration']),
        stop['nature'] ?? '',
        '',
        stop['CarryOver'] ?? false,
      ]);
    }
    for (var i = 0; i < module2Stops.length; i++) {
      final stop = module2Stops[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Arrêts M2',
        i + 1,
        '',
        '',
        '',
        stop['Catégorie'] ?? 'Module 2',
        _formatDuration(stop['duration']),
        stop['nature'] ?? '',
        '',
        stop['CarryOver'] ?? false,
      ]);
    }
    for (var i = 0; i < stock.length; i++) {
      final entry = stock[i];
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Stock',
        i + 1,
        entry['poste'] ?? '',
        entry['park'] ?? '',
        entry['type'] ?? '',
        '',
        '',
        '',
        entry['quantity'] ?? '',
        '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName$_detailsSuffix'),
      detailsHeaders: detailsHeaders,
      detailsRows: detailsRows,
    );
  }

  _ReportPayload _truckTrackingPayload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final sheetName = _sanitizeSheetTitle(_truckSheet);
    final headers = [
      ..._baseHeaders,
      'Mine',
      'Zone',
      'Sortie',
      'Poste',
      'Qualité',
      'Qualité Type',
      'Operation Type',
      'Distance',
      'Total Trips',
      'Camions',
    ];

    final row = [
      ...baseRow,
      data['mine'] ?? '',
      data['zone'] ?? '',
      data['sortie'] ?? '',
      data['selectedPoste'] ?? '',
      data['selectedQualite'] ?? '',
      data['selectedQualiteType'] ?? '',
      data['operationType'] ?? '',
      data['distance'] ?? '',
      data['totalTrips'] ?? '',
      data['camionsCount'] ?? '',
    ];

    final detailsHeaders = [
      ..._detailsBaseHeaders,
      'Section',
      'Truck Number',
      'Driver',
      'Trip Time',
      'Equipment',
      'Quality Type',
    ];

    final detailsRows = <List<Object?>>[];
    final trucks = _listOfMaps(data['truckData']);
    for (final truck in trucks) {
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        'Truck',
        truck['truckNumber'] ?? '',
        truck['driver1'] ?? '',
        '',
        '',
        '',
      ]);

      final trips = _listOfMaps(truck['counts']);
      for (final trip in trips) {
        detailsRows.add([
          ..._detailsBaseRow(savedAt, action, report, reportDateIso),
          'Trip',
          truck['truckNumber'] ?? '',
          truck['driver1'] ?? '',
          trip['time'] ?? '',
          trip['equipment'] ?? '',
          trip['productQualityType'] ?? '',
        ]);
      }
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName$_detailsSuffix'),
      detailsHeaders: detailsHeaders,
      detailsRows: detailsRows,
    );
  }

  _ReportPayload _machinesPayload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final sheetName = _sanitizeSheetTitle(_machinesSheet);
    final equipmentList = _listOfMaps(data['equipmentList']);
    final headers = [
      ..._baseHeaders,
      'Equipment Count',
    ];

    final row = [
      ...baseRow,
      equipmentList.length,
    ];

    final detailsHeaders = [
      ..._detailsBaseHeaders,
      'Equipment Type',
      'Reason',
    ];

    final detailsRows = <List<Object?>>[];
    for (final entry in equipmentList) {
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        entry['equipmentType'] ?? '',
        entry['Reason'] ?? '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName$_detailsSuffix'),
      detailsHeaders: detailsHeaders,
      detailsRows: detailsRows,
    );
  }

  _ReportPayload _r0Payload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final sheetName = _sanitizeSheetTitle(_r0Sheet);
    final exploitation = _mapOfStringDynamic(data['exploitation']);
    final repartition = _resolveR0Repartition(data);
    final personnel = _mapOfStringDynamic(data['personnel']);
    final consommation = _mapOfStringDynamic(data['consommation']);
    final compteurs = _mapOfStringDynamic(data['Compteurs']);
    final arrets = _listOfMaps(data['Arrets']);
    final headers = [
      ..._baseHeaders,
      'Mine',
      'Zone',
      'Sortie',
      'Poste',
      'Category',
      'Type',
      'Model',
      'Compteurs Durée',
      'Compteurs Note',
      'H.M',
      'H.A',
      'Tonnage',
      'Métrage foré',
      'Nr de Trous Forés',
      'Nr de Voyages',
      'M³ Décapages',
      'Nombre T.K.U',
      'Rendement %',
      'Chantier',
      'Temps',
      'Imputation',
      'Conducteur',
      'Graisseur',
      'Matricules',
      'Tricone',
      'Gasoil',
      'Arrêts Count',
    ];

    final row = [
      ...baseRow,
      data['mine'] ?? '',
      data['zone'] ?? '',
      data['sortie'] ?? '',
      data['selectedPoste'] ?? '',
      data['Category'] ?? '',
      data['Type'] ?? '',
      data['Model'] ?? '',
      compteurs['duree'] ?? '',
      compteurs['note'] ?? '',
      exploitation['H.M'] ?? '',
      exploitation['H.A'] ?? '',
      exploitation['Tonnage'] ?? '',
      exploitation['metrage fore'] ?? '',
      exploitation['Nr de Trous Fores'] ?? '',
      exploitation['Nr de Voyages'] ?? '',
      exploitation['M³ Decapages'] ?? '',
      exploitation['Nombre T.K.U'] ?? '',
      exploitation['Rendement %'] ?? exploitation['Rendeme'] ?? '',
      repartition['Chantier'] ?? '',
      repartition['Temps'] ?? '',
      repartition['Imputation'] ?? '',
      personnel['conductr'] ?? '',
      personnel['graisseur'] ?? '',
      personnel['matricules'] ?? '',
      consommation['tricone'] ?? '',
      consommation['gasoil'] ?? '',
      arrets.length,
    ];

    final detailsHeaders = [
      ..._detailsBaseHeaders,
      'Category',
      'Arret',
      'Start',
      'End',
      'Original Start',
      'Original End',
      'Carry Over',
    ];

    final detailsRows = <List<Object?>>[];
    for (final entry in arrets) {
      detailsRows.add([
        ..._detailsBaseRow(savedAt, action, report, reportDateIso),
        entry['Catégorie'] ?? '',
        entry['Arret'] ?? '',
        entry['Début'] ?? '',
        entry['Fin'] ?? '',
        entry['OriginalStart'] ?? '',
        entry['OriginalEnd'] ?? '',
        entry['CarryOver'] ?? '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName - Arrêts'),
      detailsHeaders: detailsHeaders,
      detailsRows: detailsRows,
    );
  }

  _ReportPayload _genericPayload(
    Report report,
    Map<String, dynamic> data,
    List<Object?> baseRow,
    String savedAt,
    String action,
    String reportDateIso,
  ) {
    final row = [
      ...baseRow,
      jsonEncode(data),
    ];
    final headers = [
      ..._baseHeaders,
      'Additional Data (JSON)',
    ];

    final detailsRows = _flattenAdditionalData(data).map((entry) {
      return [
        savedAt,
        action,
        report.id?.toString() ?? '',
        report.firestoreId ?? '',
        report.type,
        report.group,
        reportDateIso,
        entry.path,
        entry.value,
        entry.valueType,
      ];
    }).toList();

    return _ReportPayload(
      sheetName: _genericReportsSheet,
      headers: headers,
      row: row,
      detailsSheetName: _genericDetailsSheet,
      detailsHeaders: const [
        'Submitted At (ISO)',
        'Submission Source',
        'Local ID',
        'Firestore ID',
        'Type',
        'Group',
        'Report Date (ISO)',
        'Field Path',
        'Value',
        'Value Type',
      ],
      detailsRows: detailsRows,
    );
  }

  List<_FlattenedEntry> _flattenAdditionalData(Map<String, dynamic>? data) {
    if (data == null) {
      return [];
    }

    final entries = <_FlattenedEntry>[];

    void visit(dynamic value, String path) {
      if (value is Map) {
        value.forEach((key, nestedValue) {
          final nextPath = path.isEmpty ? '$key' : '$path.$key';
          visit(nestedValue, nextPath);
        });
        return;
      }

      if (value is List) {
        for (var i = 0; i < value.length; i++) {
          visit(value[i], '$path[$i]');
        }
        return;
      }

      entries.add(
        _FlattenedEntry(
          path: path,
          value: value,
          valueType: value == null ? 'null' : value.runtimeType.toString(),
        ),
      );
    }

    visit(data, '');
    return entries;
  }

  List<Map<String, dynamic>> _listOfMaps(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _mapOfStringDynamic(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  String _sanitizeSheetTitle(String title) {
    final sanitized = title.replaceAll('/', '-').trim();
    return sanitized.length > 90 ? sanitized.substring(0, 90) : sanitized;
  }
}

String _resolveDisplayTitle(Report report) {
  final typeLower = report.type.toLowerCase();
  if (typeLower == 'activity tnb') {
    return 'TNB';
  }
  if (typeLower == 'daily tsud') {
    return 'TSUD';
  }
  if (typeLower == 'suivi camion') {
    return 'Poser les camions';
  }
  if (typeLower == 'machine/engin arrêtés') {
    return 'Machine et engins à l’arrêt';
  }
  if (typeLower == 'r0') {
    return 'R0';
  }
  return report.description;
}

String _formatDisplayDate(DateTime reportDate) {
  return DateFormat('yyyy-MM-dd HH:mm').format(reportDate.toLocal());
}

String _formatMineZone(Map<String, dynamic> data) {
  final mine = data['mine'];
  if (mine == null) {
    return '';
  }
  final zone = data['zone'];
  if (zone == null || zone.toString().trim().isEmpty) {
    return mine.toString();
  }
  return '${mine.toString()} ${zone.toString()}';
}

String _formatTotalTrips(Map<String, dynamic> data) {
  final totalTrips = data['totalTrips'];
  return totalTrips?.toString() ?? '';
}

class _EquipmentTypeParts {
  const _EquipmentTypeParts({
    this.mainCategory = '',
    this.subCategory = '',
    this.equipment = '',
  });

  final String mainCategory;
  final String subCategory;
  final String equipment;
}

enum _ReportCategory {
  activityTnb,
  dailyTsud,
  truckTracking,
  machinesStopped,
  r0,
  generic,
}

const List<String> _baseHeaders = [
  'Title (as shown in app)',
  'Type (as shown in app)',
  'Date (as shown in app)',
  'Group (as shown in app)',
  'Mine/Zone (as shown in app)',
  'Total Trips (as shown in app)',
  'Description',
  'Submitted At (ISO)',
  'Submission Source',
  'Local ID',
  'Firestore ID',
  'Report Date (ISO)',
  'Report Date (Local)',
  'Report Time (Local)',
];

const List<String> _detailsBaseHeaders = [
  'Submitted At (ISO)',
  'Submission Source',
  'Local ID',
  'Report Date (ISO)',
  'Report Type',
  'Group',
];

List<Object?> _detailsBaseRow(
  String savedAt,
  String action,
  Report report,
  String reportDateIso,
) {
  return [
    savedAt,
    action,
    report.id?.toString() ?? '',
    reportDateIso,
    report.type,
    report.group,
  ];
}

class _ReportPayload {
  const _ReportPayload({
    required this.sheetName,
    required this.headers,
    required this.row,
    this.detailsSheetName,
    this.detailsHeaders,
    this.detailsRows = const [],
  });

  final String sheetName;
  final List<String> headers;
  final List<Object?> row;
  final String? detailsSheetName;
  final List<String>? detailsHeaders;
  final List<List<Object?>> detailsRows;
}

class _FlattenedEntry {
  const _FlattenedEntry({
    required this.path,
    required this.value,
    required this.valueType,
  });

  final String path;
  final Object? value;
  final String valueType;
}

class _TemplateRows {
  const _TemplateRows({
    required this.sheetName,
    required this.rows,
    this.mergeRanges = const [],
    this.customMerges = const [],
  });

  final String sheetName;
  final List<List<Object?>> rows;
  final List<_TemplateMergeRange> mergeRanges;
  final List<_TemplateCustomMerge> customMerges;
}

class _TemplateMergeRange {
  const _TemplateMergeRange({
    required this.startColumnIndex,
    required this.endColumnIndex,
  });

  final int startColumnIndex;
  final int endColumnIndex;
}

class _TemplateCustomMerge {
  const _TemplateCustomMerge({
    required this.startRowOffset,
    required this.endRowOffset,
    required this.startColumnIndex,
    required this.endColumnIndex,
  });

  final int startRowOffset;
  final int endRowOffset;
  final int startColumnIndex;
  final int endColumnIndex;
}

class _RowBounds {
  const _RowBounds({
    required this.startRowIndex,
    required this.endRowIndex,
  });

  final int startRowIndex;
  final int endRowIndex;
}
