import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:intl/intl.dart';
import 'package:r0/domain/models/report.dart';
import 'package:r0/domain/services/stop_detail_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String _configValue(String key, String dartDefineValue) {
  if (dartDefineValue.isNotEmpty) {
    return dartDefineValue;
  }

  try {
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}

class GoogleSheetsService {
  GoogleSheetsService({
    String? spreadsheetId,
    String? credentialsJson,
    String? credentialsAssetPath,
    DateTime Function()? nowProvider,
  })  : _spreadsheetId = spreadsheetId ??
            _configValue(
              'GOOGLE_SHEETS_SPREADSHEET_ID',
              const String.fromEnvironment('GOOGLE_SHEETS_SPREADSHEET_ID'),
            ),
        _credentialsJson = credentialsJson ??
            _configValue(
              'GOOGLE_SHEETS_CREDENTIALS_JSON',
              const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_JSON'),
            ),
        _credentialsAssetPath = credentialsAssetPath ??
            _configValue(
              'GOOGLE_SHEETS_CREDENTIALS_ASSET_PATH',
              const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_ASSET_PATH'),
            ),
        _nowProvider = nowProvider ?? DateTime.now;

  static const String _genericReportsSheet = 'Reports';
  static const String _genericDetailsSheet = 'Report Details';
  static const String _detailsSuffix = ' - Détails';
  static const String _activitySheet = 'TNB';
  static const String _dailySheet = 'TSUD';
  static const String _ifDowntimeDetailsSheet =
      "détail d'arrêts IF (TNB, TSUD)";
  static const String _r0DowntimeDetailsSheet = "détails d'arrêts R0";
  static const List<String> _r0DowntimeDetailsHeaders = [
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
  ];
  static const String _truckSheet = 'Poser les camions';
  static const String _machinesSheet = 'Machines et engins à l\'arrêt';
  static const String _r0Sheet = 'R0';
  static const String _frenchLocale = 'fr_FR';
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
  final Map<String, String> _sheetNamesByNormalizedKey = {};
  List<GoogleSheetRecord>? _recordsCache;
  DateTime? _recordsCacheAt;

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
        final savedAt = _formatIsoTimestampWithSeconds(_nowProvider());
        final reportDate = report.date;
        final reportDateIso = _formatIsoTimestampWithSeconds(reportDate);
        final reportLocalDate = reportDate.toLocal();
        final payload = _buildPayload(
          report,
          savedAt: savedAt,
          action: action,
          reportDateIso: reportDateIso,
          reportLocalDate: reportLocalDate,
        );

        final templateRows = _buildTemplateRows(report, reportLocalDate);
        return await _recordReportSnapshotViaBackend(
          report,
          action: action,
          payload: payload,
          templateRows: templateRows,
          reportLocalDate: reportLocalDate,
        );
      }

      final savedAt = _formatIsoTimestampWithSeconds(_nowProvider());
      final reportDate = report.date;
      final reportDateIso = _formatIsoTimestampWithSeconds(reportDate);
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
        final shouldCheckForDuplicateDate =
            templateRows.sheetName == _activitySheet ||
                templateRows.sheetName == _dailySheet ||
                templateRows.sheetName == _machinesSheet;
        if (shouldCheckForDuplicateDate) {
          final hasDuplicateDate = await _sheetHasExistingTemplateDate(
            api,
            sheetName: templateRows.sheetName,
            reportDateLocal: reportLocalDate,
          );
          if (hasDuplicateDate) {
            final formattedDate =
                DateFormat('yyyy-MM-dd', _frenchLocale).format(reportLocalDate);
            throw DuplicateReportDateException(
              'Un rapport avec la date du jour existe déjà dans ${templateRows.sheetName} ($formattedDate).',
            );
          }
        }

        final data = report.additionalData ?? {};

        if (templateRows.sheetName == _r0Sheet) {
          final hasDuplicateR0Report = await _sheetHasExistingR0Report(
            api,
            reportDateLocal: reportLocalDate,
            poste: data['selectedPoste']?.toString() ?? '',
            module: data['Model']?.toString() ?? '',
          );
          if (hasDuplicateR0Report) {
            throw DuplicateReportDateException(
              "Un rapport avec la date d'aujourd'hui existe déjà pour ce poste et ce module.",
            );
          }
        }

        if (templateRows.sheetName == _truckSheet) {
          final hasDuplicateTruckReport = await _sheetHasExistingTruckReport(
            api,
            reportDateLocal: reportLocalDate,
            poste: data['selectedPoste']?.toString() ?? '',
          );
          if (hasDuplicateTruckReport) {
            throw DuplicateReportDateException(
              "Un rapport avec la date d'aujourd'hui existe déjà pour ce poste.",
            );
          }
        }

        await _appendRowsToTemplate(api, templateRows);
        await _syncIfDowntimeDetailsSheet(
          api,
          report: report,
          reportDateLocal: reportLocalDate,
          data: data,
        );
        await _syncR0DowntimeDetailsSheet(
          api,
          report: report,
          reportDateLocal: reportLocalDate,
          data: data,
        );
        return true;
      }

      await _ensureSheetWithHeaders(api, payload.sheetName, payload.headers);
      await _insertRowsSortedByDateTime(
        api,
        sheetName: payload.sheetName,
        rows: [payload.row],
        dateColumnIndex: 11,
        firstDataRowNumber: 2,
      );

      if (payload.detailsRows.isNotEmpty &&
          payload.detailsSheetName != null &&
          payload.detailsHeaders != null) {
        await _ensureSheetWithHeaders(
          api,
          payload.detailsSheetName!,
          payload.detailsHeaders!,
        );
        await _insertRowsSortedByDateTime(
          api,
          sheetName: payload.detailsSheetName!,
          rows: payload.detailsRows,
          dateColumnIndex: 6,
          firstDataRowNumber: 2,
        );
      }

      return true;
    } on DuplicateReportDateException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Google Sheets sync failed for report ${report.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _sheetHasExistingTemplateDate(
    SheetsApi api, {
    required String sheetName,
    required DateTime reportDateLocal,
  }) async {
    await _loadSheetNames(api);
    final resolvedSheetName = _resolveSheetName(sheetName);
    if (resolvedSheetName == null) {
      return false;
    }

    final targetDate =
        DateFormat('yyyy-MM-dd', _frenchLocale).format(reportDateLocal);
    final response = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$resolvedSheetName!A7:A',
    );
    final values = response.values ?? const [];

    for (final row in values) {
      if (row.isEmpty) {
        continue;
      }
      final rawDate = row.first?.toString().trim() ?? '';
      if (_isSameReportDate(rawDate, targetDate)) {
        return true;
      }
    }

    return false;
  }

  Future<void> _syncIfDowntimeDetailsSheet(
    SheetsApi api, {
    required Report report,
    required DateTime reportDateLocal,
    required Map<String, dynamic> data,
  }) async {
    final category = _categorizeReport(report, data);
    if (category != _ReportCategory.activityTnb &&
        category != _ReportCategory.dailyTsud) {
      return;
    }

    await _ensureSheetExists(api, _ifDowntimeDetailsSheet);
    await _ensureIfDowntimeDetailsLayout(api, _ifDowntimeDetailsSheet);

    if (category == _ReportCategory.activityTnb) {
      final rows = _listOfMaps(data['Arrets'])
          .map((stop) => _buildIfDowntimeRow(
                reportDateLocal,
                stop,
                equipmentFallback: 'TNB',
              ))
          .toList();
      await _appendIfDowntimeRows(
        api,
        sheetName: _ifDowntimeDetailsSheet,
        rangePrefix: 'A',
        rangeSuffix: 'G',
        rows: rows,
      );
      return;
    }

    final module1Rows = _listOfMaps(data['module1Stops'])
        .map((stop) => _buildIfDowntimeRow(
              reportDateLocal,
              stop,
              equipmentFallback: 'TSUD',
            ))
        .toList();
    final module2Rows = _listOfMaps(data['module2Stops'])
        .map((stop) => _buildIfDowntimeRow(
              reportDateLocal,
              stop,
              equipmentFallback: 'TSUD',
            ))
        .toList();

    await _appendIfDowntimeRows(
      api,
      sheetName: _ifDowntimeDetailsSheet,
      rangePrefix: 'I',
      rangeSuffix: 'O',
      rows: module1Rows,
    );
    await _appendIfDowntimeRows(
      api,
      sheetName: _ifDowntimeDetailsSheet,
      rangePrefix: 'Q',
      rangeSuffix: 'W',
      rows: module2Rows,
    );
  }

  Future<void> _syncR0DowntimeDetailsSheet(
    SheetsApi api, {
    required Report report,
    required DateTime reportDateLocal,
    required Map<String, dynamic> data,
  }) async {
    final category = _categorizeReport(report, data);
    if (category != _ReportCategory.r0) {
      return;
    }

    final rows = _buildR0DowntimeDetailsRows(reportDateLocal, data);
    if (rows.isEmpty) {
      return;
    }

    await _ensureSheetWithHeaders(
      api,
      _r0DowntimeDetailsSheet,
      _r0DowntimeDetailsHeaders,
    );
    await _insertRowsSortedByDateTime(
      api,
      sheetName: _r0DowntimeDetailsSheet,
      rows: rows,
      dateColumnIndex: 0,
      firstDataRowNumber: 2,
    );
  }

  List<List<Object?>> _buildR0DowntimeDetailsRows(
    DateTime reportDateLocal,
    Map<String, dynamic> data,
  ) {
    final arrets = _listOfMaps(data['Arrets']);
    if (arrets.isEmpty) {
      return const [];
    }

    final date = _formatSheetTimestamp(reportDateLocal);
    return arrets.map((arret) {
      return [
        date,
        data['Category'] ?? '',
        data['Type'] ?? '',
        data['Model'] ?? '',
        arret['Catégorie'] ?? arret['Categorie'] ?? '',
        arret['Arret'] ?? arret['Arrêt'] ?? '',
        StopDetailService.readDetail(arret),
        _formatStopClockTime(arret['OriginalStart'] ?? arret['Début']),
        _formatStopClockTime(arret['OriginalEnd'] ?? arret['Fin']),
        _formatR0StopDowntimeHours(arret),
      ];
    }).toList();
  }

  String _formatR0StopDowntimeHours(Map<String, dynamic> stop) {
    for (final key in const [
      'H.A',
      'HA',
      'ha',
      'duration',
      'Duration',
      'durée',
      'Durée',
    ]) {
      final value = stop[key];
      if (value == null || value.toString().trim().isEmpty) {
        continue;
      }

      if (key == 'H.A' || key == 'HA' || key == 'ha') {
        final hours = double.tryParse(
          value.toString().trim().replaceAll(',', '.'),
        );
        if (hours != null) {
          return hours.toStringAsFixed(2);
        }
      }

      final minutes = _durationToMinutes(value);
      if (minutes != null) {
        return (minutes / 60).toStringAsFixed(2);
      }

      return value.toString().trim();
    }

    final start = _clockTimeToMinutes(stop['OriginalStart'] ?? stop['Début']);
    final end = _clockTimeToMinutes(stop['OriginalEnd'] ?? stop['Fin']);
    if (start == null || end == null) {
      return '';
    }

    var durationMinutes = end - start;
    if (durationMinutes <= 0) {
      durationMinutes += 24 * 60;
    }

    return (durationMinutes / 60).toStringAsFixed(2);
  }

  int? _clockTimeToMinutes(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(value);
    if (match == null) {
      return null;
    }

    final hours = int.tryParse(match.group(1) ?? '');
    final minutes = int.tryParse(match.group(2) ?? '');
    if (hours == null || minutes == null) {
      return null;
    }
    if (hours < 0 || hours > 23 || minutes < 0 || minutes > 59) {
      return null;
    }

    return (hours * 60) + minutes;
  }

  Future<void> _ensureIfDowntimeDetailsLayout(
    SheetsApi api,
    String sheetName,
  ) async {
    const headers = [
      'jour',
      "Debut d'arret",
      "Fin d'arret",
      "durée d'arret",
      'STS',
      'equipement',
      'designation',
    ];

    await api.spreadsheets.values.update(
      ValueRange(values: const [
        ['TNB'],
        [],
      ]),
      _spreadsheetId,
      '$sheetName!A3',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      ValueRange(values: const [
        ['TSUD M1'],
        [],
      ]),
      _spreadsheetId,
      '$sheetName!I3',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      ValueRange(values: const [
        ['TSUD M2'],
        [],
      ]),
      _spreadsheetId,
      '$sheetName!Q3',
      valueInputOption: 'RAW',
    );

    await api.spreadsheets.values.update(
      ValueRange(values: [headers]),
      _spreadsheetId,
      '$sheetName!A4:G4',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      ValueRange(values: [headers]),
      _spreadsheetId,
      '$sheetName!I4:O4',
      valueInputOption: 'RAW',
    );
    await api.spreadsheets.values.update(
      ValueRange(values: [headers]),
      _spreadsheetId,
      '$sheetName!Q4:W4',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _appendIfDowntimeRows(
    SheetsApi api, {
    required String sheetName,
    required String rangePrefix,
    required String rangeSuffix,
    required List<List<Object?>> rows,
  }) async {
    if (rows.isEmpty) {
      return;
    }

    final existingRange = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!${rangePrefix}5:$rangeSuffix',
    );
    final existingRows = existingRange.values ?? const [];
    final nonEmptyRows = existingRows.where(_hasContent).length;
    final startRow = 5 + nonEmptyRows;
    final endRow = startRow + rows.length - 1;

    await api.spreadsheets.values.update(
      ValueRange(values: rows),
      _spreadsheetId,
      '$sheetName!$rangePrefix$startRow:$rangeSuffix$endRow',
      valueInputOption: 'RAW',
    );
  }

  List<Object?> _buildIfDowntimeRow(
    DateTime reportDateLocal,
    Map<String, dynamic> stop, {
    required String equipmentFallback,
  }) {
    final sts = _firstNonEmpty(stop, const ['Catégorie', 'category']);
    final equipment = _firstNonEmpty(
      stop,
      const [
        'equipment',
        'equipement',
        'Equipement',
        'location',
        'Lieu',
        'stopLocation',
      ],
    );
    final designation = _firstNonEmpty(
      stop,
      const ['detail', 'Détail', 'nature'],
    );

    return [
      DateFormat('M/d/yyyy').format(reportDateLocal),
      _formatStopClockTime(stop['startTime'] ?? stop['Début']),
      _formatStopClockTime(stop['endTime'] ?? stop['Fin']),
      _formatStopDurationClock(stop['duration']),
      sts,
      equipment.isEmpty ? equipmentFallback : equipment,
      designation,
    ];
  }

  String _firstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _formatStopClockTime(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'pending') {
      return value;
    }
    if (RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(value)) {
      return value;
    }
    if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(value)) {
      return '$value:00';
    }
    return value;
  }

  String _formatStopDurationClock(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      return '0:00:00';
    }
    if (RegExp(r'^\d{1,2}:\d{2}:\d{2}$').hasMatch(value)) {
      return value;
    }
    final hourMinuteMatch =
        RegExp(r'^(\d+)\s*h\s*(\d+)\s*m$', caseSensitive: false)
            .firstMatch(value);
    if (hourMinuteMatch != null) {
      final hours = int.tryParse(hourMinuteMatch.group(1) ?? '0') ?? 0;
      final minutes = int.tryParse(hourMinuteMatch.group(2) ?? '0') ?? 0;
      return '$hours:${minutes.toString().padLeft(2, '0')}:00';
    }
    final asInt = int.tryParse(value);
    if (asInt != null) {
      final hours = asInt ~/ 60;
      final minutes = asInt % 60;
      return '$hours:${minutes.toString().padLeft(2, '0')}:00';
    }
    return value;
  }

  Future<bool> _sheetHasExistingR0Report(
    SheetsApi api, {
    required DateTime reportDateLocal,
    required String poste,
    required String module,
  }) async {
    await _loadSheetNames(api);
    final resolvedSheetName = _resolveSheetName(_r0Sheet);
    if (resolvedSheetName == null) {
      return false;
    }

    final targetDate =
        DateFormat('yyyy-MM-dd', _frenchLocale).format(reportDateLocal);
    final targetPoste = poste.trim().toLowerCase();
    final targetModule = module.trim().toLowerCase();

    final response = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$resolvedSheetName!A7:H',
    );
    final values = response.values ?? const [];

    for (final row in values) {
      if (row.length < 8) {
        continue;
      }

      final rowDate = row[0]?.toString().trim() ?? '';
      final rowPoste = row[4]?.toString().trim().toLowerCase() ?? '';
      final rowModule = row[7]?.toString().trim().toLowerCase() ?? '';

      if (_isSameReportDate(rowDate, targetDate) &&
          rowPoste == targetPoste &&
          rowModule == targetModule) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _sheetHasExistingTruckReport(
    SheetsApi api, {
    required DateTime reportDateLocal,
    required String poste,
  }) async {
    await _loadSheetNames(api);
    final resolvedSheetName = _resolveSheetName(_truckSheet);
    if (resolvedSheetName == null) {
      return false;
    }

    final targetDate =
        DateFormat('yyyy-MM-dd', _frenchLocale).format(reportDateLocal);
    final targetPoste = _normalizePosteValue(poste);

    final response = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$resolvedSheetName!A7:I',
    );
    final values = response.values ?? const [];

    for (final row in values) {
      if (row.length < 9) {
        continue;
      }

      final rowDate = row[0]?.toString().trim() ?? '';
      final rowPoste = _normalizePosteValue(row[8]);

      if (_isSameReportDate(rowDate, targetDate) && rowPoste == targetPoste) {
        return true;
      }
    }

    return false;
  }

  Future<void> _appendRowsToTemplate(
    SheetsApi api,
    _TemplateRows templateRows,
  ) async {
    await _loadSheetNames(api);
    var targetSheetName = _resolveSheetName(templateRows.sheetName);
    if (targetSheetName == null) {
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
      targetSheetName = _resolveSheetName(templateRows.sheetName);
      if (targetSheetName == null) {
        debugPrint(
            'Failed to resolve target sheet for ${templateRows.sheetName}.');
        return;
      }
    }

    if (templateRows.rows.isEmpty) {
      return;
    }

    final rowBounds = await _insertTemplateRows(
      api,
      templateRows.copyWith(sheetName: targetSheetName),
    );
    if (rowBounds == null) {
      return;
    }

    final sheetId = _sheetIdsByName[targetSheetName];
    if (sheetId == null) {
      debugPrint('Sheet ID for "$targetSheetName" not found.');
      return;
    }

    final requests = <Request>[];
    final colorTheme = _selectColorTheme(
      sheetName: targetSheetName,
      startRowIndex: rowBounds.startRowIndex,
    );

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

    if (formattedColumnCount > 0) {
      requests.add(
        Request(
          repeatCell: RepeatCellRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: 0,
              endColumnIndex: formattedColumnCount,
            ),
            cell: CellData(
              userEnteredFormat: CellFormat(
                backgroundColor: colorTheme.primary,
              ),
            ),
            fields: 'userEnteredFormat.backgroundColor',
          ),
        ),
      );
    }

    for (final section in templateRows.colorSections) {
      requests.add(
        Request(
          repeatCell: RepeatCellRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: section.startColumnIndex,
              endColumnIndex: section.endColumnIndex,
            ),
            cell: CellData(
              userEnteredFormat: CellFormat(
                backgroundColor: colorTheme.secondary,
              ),
            ),
            fields: 'userEnteredFormat.backgroundColor',
          ),
        ),
      );
    }

    for (final separatorColumnIndex in templateRows.separatorColumnIndexes) {
      requests.add(
        Request(
          repeatCell: RepeatCellRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: separatorColumnIndex,
              endColumnIndex: separatorColumnIndex + 1,
            ),
            cell: CellData(
              userEnteredFormat: CellFormat(
                backgroundColor: Color(red: 1, green: 1, blue: 1),
              ),
            ),
            fields: 'userEnteredFormat.backgroundColor',
          ),
        ),
      );
      requests.add(
        Request(
          updateBorders: UpdateBordersRequest(
            range: GridRange(
              sheetId: sheetId,
              startRowIndex: rowBounds.startRowIndex,
              endRowIndex: rowBounds.endRowIndex,
              startColumnIndex: separatorColumnIndex,
              endColumnIndex: separatorColumnIndex + 1,
            ),
            top: Border(style: 'NONE'),
            bottom: Border(style: 'NONE'),
            left: Border(style: 'NONE'),
            right: Border(style: 'NONE'),
            innerHorizontal: Border(style: 'NONE'),
            innerVertical: Border(style: 'NONE'),
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

  Future<_RowBounds?> _insertTemplateRows(
    SheetsApi api,
    _TemplateRows templateRows,
  ) async {
    return _insertTemplateRowsSorted(api, templateRows);
  }

  Future<_RowBounds?> _insertTemplateRowsSorted(
    SheetsApi api,
    _TemplateRows templateRows,
  ) async {
    if (templateRows.rows.isEmpty) {
      return null;
    }

    final firstRow = templateRows.rows.first;
    final newDate = firstRow.isNotEmpty ? firstRow.first : null;
    final newPoste = firstRow.length > 8 ? firstRow[8] : null;
    final insertStartRowNumber = await _resolveTemplateInsertRowNumber(
      api,
      sheetName: templateRows.sheetName,
      reportDateValue: newDate,
      posteValue: newPoste,
    );

    final rowCount = templateRows.rows.length;
    final startRowIndex = insertStartRowNumber - 1;
    final endRowIndex = startRowIndex + rowCount;

    await api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: [
          Request(
            insertDimension: InsertDimensionRequest(
              range: DimensionRange(
                sheetId: _sheetIdsByName[templateRows.sheetName],
                dimension: 'ROWS',
                startIndex: startRowIndex,
                endIndex: endRowIndex,
              ),
              inheritFromBefore: startRowIndex > 6,
            ),
          ),
        ],
      ),
      _spreadsheetId,
    );

    final updatedRange = '${templateRows.sheetName}!A$insertStartRowNumber';
    await api.spreadsheets.values.update(
      ValueRange(values: templateRows.rows),
      _spreadsheetId,
      updatedRange,
      valueInputOption: 'RAW',
    );

    return _RowBounds(startRowIndex: startRowIndex, endRowIndex: endRowIndex);
  }

  Future<int> _resolveTemplateInsertRowNumber(
    SheetsApi api, {
    required String sheetName,
    required Object? reportDateValue,
    required Object? posteValue,
  }) async {
    final targetDateTime =
        _parseSheetDateTime(reportDateValue?.toString() ?? '');
    final targetDate = targetDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final targetPoste = _normalizePosteValue(posteValue);
    final response = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!A7:I',
    );
    final values = response.values ?? const [];

    for (var index = 0; index < values.length; index++) {
      final row = values[index];
      if (row.isEmpty) {
        continue;
      }

      final currentDate = _parseSheetDateTime(row.first?.toString() ?? '');
      if (currentDate == null) {
        continue;
      }

      final dateComparison = targetDate.compareTo(currentDate);
      if (dateComparison > 0) {
        return index + 7;
      }
      if (dateComparison < 0) {
        continue;
      }

      if (_normalizeHeaderKey(sheetName) == _normalizeHeaderKey(_truckSheet)) {
        final currentPoste = row.length > 8 ? _normalizePosteValue(row[8]) : '';
        final posteComparison =
            _posteSortRank(targetPoste).compareTo(_posteSortRank(currentPoste));
        if (posteComparison < 0) {
          return index + 7;
        }
      }
    }

    return values.length + 7;
  }

  int _posteSortRank(String poste) {
    switch (_normalizePosteValue(poste)) {
      case '2ème':
        return 0;
      case '1er':
        return 1;
      case '3ème':
        return 2;
      default:
        return 99;
    }
  }

  _ReportColorTheme _selectColorTheme({
    required String sheetName,
    required int startRowIndex,
  }) {
    final seed =
        sheetName.codeUnits.fold<int>(0, (sum, c) => sum + c) + startRowIndex;
    final paletteIndex = seed % _reportColorThemes.length;
    return _reportColorThemes[paletteIndex];
  }

  static final List<_ReportColorTheme> _reportColorThemes = [
    _ReportColorTheme(
      primary: Color(red: 0.97, green: 0.95, blue: 0.90),
      secondary: Color(red: 0.93, green: 0.96, blue: 0.98),
    ),
    _ReportColorTheme(
      primary: Color(red: 0.95, green: 0.92, blue: 0.96),
      secondary: Color(red: 0.90, green: 0.95, blue: 0.92),
    ),
    _ReportColorTheme(
      primary: Color(red: 0.94, green: 0.97, blue: 0.93),
      secondary: Color(red: 0.97, green: 0.94, blue: 0.90),
    ),
    _ReportColorTheme(
      primary: Color(red: 0.92, green: 0.95, blue: 0.98),
      secondary: Color(red: 0.96, green: 0.93, blue: 0.95),
    ),
    _ReportColorTheme(
      primary: Color(red: 0.96, green: 0.94, blue: 0.92),
      secondary: Color(red: 0.92, green: 0.96, blue: 0.94),
    ),
  ];

  _TemplateRows? _buildTemplateRows(Report report, DateTime reportDateLocal) {
    final data = report.additionalData ?? {};
    final category = _categorizeReport(report, data);
    final date = _formatSheetTimestamp(reportDateLocal);

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
          separatorColumnIndexes: const [7],
          colorSections: const [
            _TemplateColorSection(startColumnIndex: 0, endColumnIndex: 7),
            _TemplateColorSection(startColumnIndex: 8, endColumnIndex: 10),
          ],
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
          separatorColumnIndexes: const [6],
          colorSections: const [
            _TemplateColorSection(startColumnIndex: 0, endColumnIndex: 6),
            _TemplateColorSection(startColumnIndex: 7, endColumnIndex: 13),
          ],
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
            const _TemplateMergeRange(startColumnIndex: 15, endColumnIndex: 16),
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
        final truckDate = DateFormat('dd-MM-yyyy HH:mm:ss', _frenchLocale)
            .format(reportDateLocal);
        final frenchPoste = _toFrenchPosteLabel(data['selectedPoste']);
        final frenchQualityType =
            _toFrenchQualityTypeLabel(data['selectedQualiteType']);
        final frenchOperationType =
            _toFrenchOperationTypeLabel(data['operationType']);

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
            includeSharedValues ? truckDate : '',
            includeSharedValues ? data['mine'] ?? '' : '',
            includeSharedValues ? data['sortie'] ?? '' : '',
            includeSharedValues
                ? data['equipment'] ?? data['selectedQualite'] ?? ''
                : '',
            includeSharedValues ? data['distance'] ?? '' : '',
            includeSharedValues ? frenchQualityType : '',
            includeSharedValues ? frenchOperationType : '',
            '',
            includeSharedValues ? frenchPoste : '',
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
            truckDate,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['equipment'] ?? data['selectedQualite'] ?? '',
            data['distance'] ?? '',
            frenchQualityType,
            frenchOperationType,
            '',
            frenchPoste,
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
    const allowInRelease = bool.fromEnvironment('ALLOW_CLIENT_SHEETS_IN_RELEASE', defaultValue: false);
    if (kReleaseMode && !allowInRelease) {
      debugPrint(
        'Google Sheets client credentials are disabled in release builds. '
        'Use the backend submission endpoint instead.',
      );
      return null;
    }

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

  Future<void> _insertRowsSortedByDateTime(
    SheetsApi api, {
    required String sheetName,
    required List<List<Object?>> rows,
    required int dateColumnIndex,
    required int firstDataRowNumber,
  }) async {
    if (rows.isEmpty) {
      return;
    }

    await _loadSheetNames(api);
    final targetSheetName = _resolveSheetName(sheetName) ?? sheetName;
    final sheetId = _sheetIdsByName[targetSheetName];
    if (sheetId == null) {
      debugPrint('Sheet ID for "$targetSheetName" not found.');
      return;
    }

    final firstRow = rows.first;
    final targetDate = dateColumnIndex < firstRow.length
        ? _parseSheetDateTime(firstRow[dateColumnIndex]?.toString() ?? '')
        : null;
    final existingResponse = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$targetSheetName!A$firstDataRowNumber:AZ',
    );
    final existingRows = existingResponse.values ?? const [];
    var insertRowNumber = existingRows.length + firstDataRowNumber;

    for (var index = 0; index < existingRows.length; index++) {
      final row = existingRows[index];
      if (!_hasContent(row) || row.length <= dateColumnIndex) {
        continue;
      }

      final currentDate =
          _parseSheetDateTime(row[dateColumnIndex]?.toString() ?? '');
      if (targetDate != null &&
          currentDate != null &&
          targetDate.compareTo(currentDate) > 0) {
        insertRowNumber = index + firstDataRowNumber;
        break;
      }
    }

    final startRowIndex = insertRowNumber - 1;
    final endRowIndex = startRowIndex + rows.length;
    await api.spreadsheets.batchUpdate(
      BatchUpdateSpreadsheetRequest(
        requests: [
          Request(
            insertDimension: InsertDimensionRequest(
              range: DimensionRange(
                sheetId: sheetId,
                dimension: 'ROWS',
                startIndex: startRowIndex,
                endIndex: endRowIndex,
              ),
              inheritFromBefore: startRowIndex > firstDataRowNumber - 1,
            ),
          ),
        ],
      ),
      _spreadsheetId,
    );

    await api.spreadsheets.values.update(
      ValueRange(values: rows),
      _spreadsheetId,
      '$targetSheetName!A$insertRowNumber',
      valueInputOption: 'RAW',
    );
  }

  Future<void> _ensureSheetWithHeaders(
    SheetsApi api,
    String sheetName,
    List<String> headers,
  ) async {
    await _loadSheetNames(api);

    var targetSheetName = _resolveSheetName(sheetName);
    if (targetSheetName == null) {
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
      _loadedSheets = false;
      await _loadSheetNames(api);
      targetSheetName = _resolveSheetName(sheetName) ?? sheetName;
    }

    final headerRange = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$targetSheetName!1:1',
    );
    if (headerRange.values == null || headerRange.values!.isEmpty) {
      await api.spreadsheets.values.update(
        ValueRange(values: [headers]),
        _spreadsheetId,
        '$targetSheetName!1:1',
        valueInputOption: 'RAW',
      );
    }
  }

  Future<void> _ensureSheetExists(SheetsApi api, String sheetName) async {
    await _loadSheetNames(api);

    if (_resolveSheetName(sheetName) != null) {
      return;
    }

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
    _loadedSheets = false;
    await _loadSheetNames(api);
  }

  Future<void> _loadSheetNames(SheetsApi api) async {
    if (_loadedSheets) {
      return;
    }

    final spreadsheet = await api.spreadsheets.get(_spreadsheetId);
    final sheets = spreadsheet.sheets ?? [];
    _knownSheets.clear();
    _sheetIdsByName.clear();
    _sheetNamesByNormalizedKey.clear();
    for (final sheet in sheets) {
      final title = sheet.properties?.title;
      final sheetId = sheet.properties?.sheetId;
      if (title != null) {
        _knownSheets.add(title);
        _sheetNamesByNormalizedKey[_normalizeHeaderKey(title)] = title;
        if (sheetId != null) {
          _sheetIdsByName[title] = sheetId;
        }
      }
    }
    _loadedSheets = true;
  }

  String? _resolveSheetName(String candidate) {
    if (_knownSheets.contains(candidate)) {
      return candidate;
    }

    return _sheetNamesByNormalizedKey[_normalizeHeaderKey(candidate)];
  }

  _ReportPayload _buildPayload(
    Report report, {
    required String savedAt,
    required String action,
    required String reportDateIso,
    required DateTime reportLocalDate,
  }) {
    final reportDateLocal = DateFormat('yyyy-MM-dd').format(reportLocalDate);
    final reportTimeLocal = DateFormat('HH:mm:ss').format(reportLocalDate);
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
      _toFrenchPosteLabel(data['selectedPoste']),
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

    final detailsRows = _buildR0DowntimeDetailsRows(
      DateTime.tryParse(reportDateIso)?.toLocal() ?? report.date.toLocal(),
      data,
    );

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _r0DowntimeDetailsSheet,
      detailsHeaders: _r0DowntimeDetailsHeaders,
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

  String _formatIsoTimestampWithSeconds(DateTime value) {
    final normalized = value.isUtc ? value : value.toLocal();
    final date = normalized.toIso8601String().split('T').first;
    final time = DateFormat('HH:mm:ss').format(normalized);
    return normalized.isUtc ? '${date}T${time}Z' : '${date}T$time';
  }

  String _formatSheetTimestamp(DateTime value) {
    return DateFormat('yyyy-MM-dd HH:mm:ss', _frenchLocale)
        .format(value.toLocal());
  }

  DateTime? _parseSheetDateTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    final serial = double.tryParse(normalized.replaceAll(',', '.'));
    if (serial != null) {
      final excelEpoch = DateTime.utc(1899, 12, 30);
      final wholeDays = serial.floor();
      final seconds = ((serial - wholeDays) * Duration.secondsPerDay).round();
      return excelEpoch
          .add(Duration(days: wholeDays, seconds: seconds))
          .toLocal();
    }

    final isoParsed = DateTime.tryParse(normalized);
    if (isoParsed != null) {
      return isoParsed.toLocal();
    }

    const acceptedPatterns = [
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd-MM-yyyy HH:mm:ss',
      'dd-MM-yyyy HH:mm',
      'dd-MM-yyyy',
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'd/M/yyyy HH:mm:ss',
      'd/M/yyyy',
      'd MMM yyyy HH:mm:ss',
      'd MMM yyyy',
      'd/M/yyyy',
      'd MMM yyyy HH:mm:ss',
      'd MMM yyyy',
      'd MMMM yyyy HH:mm:ss',
      'd MMMM yyyy HH:mm',
      'd MMMM yyyy',
    ];

    for (final pattern in acceptedPatterns) {
      try {
        return DateFormat(pattern, _frenchLocale).parseStrict(normalized);
      } catch (_) {
        // Keep trying with the next pattern.
      }
    }

    return null;
  }

  bool _isSameReportDate(String rawDate, String targetDate) {
    if (rawDate == targetDate) {
      return true;
    }

    final parsedRawDate = _normalizeSheetDate(rawDate);
    final parsedTargetDate = _normalizeSheetDate(targetDate);
    return parsedRawDate.isNotEmpty && parsedRawDate == parsedTargetDate;
  }

  String _normalizeSheetDate(String value) {
    final parsed = _parseSheetDateTime(value);
    if (parsed == null) {
      return value.trim().replaceAll(RegExp(r'\s+'), ' ');
    }

    return DateFormat('yyyy-MM-dd', _frenchLocale).format(parsed);
  }

  String _normalizePosteValue(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return '';
    }

    final compact = normalized
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\b(shift|poste)\b'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();

    if (RegExp(r'^(3|3e|3eme|3ème|3rd|troisieme|troisième)$')
        .hasMatch(compact)) {
      return '3ème';
    }
    if (RegExp(r'^(1|1er|1st|premier)$').hasMatch(compact)) {
      return '1er';
    }
    if (RegExp(r'^(2|2e|2eme|2ème|2nd|2rd|deuxieme|deuxième)$')
        .hasMatch(compact)) {
      return '2ème';
    }

    return normalized;
  }

  String _toFrenchPosteLabel(Object? value) => _normalizePosteValue(value);

  String _toFrenchQualityTypeLabel(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized == 'normal') {
      return 'NORMAL';
    }
    if (normalized == 'oceane' || normalized == 'océane') {
      return 'OCEANE';
    }
    if (normalized == 'pb30') {
      return 'PB30';
    }
    return value.toString();
  }

  String _toFrenchOperationTypeLabel(Object? value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return '';
    }
    if (normalized == 'defeuitage' || normalized == 'défeuitage') {
      return 'Défeuitage';
    }
    if (normalized == 'reprise') {
      return 'Reprise';
    }
    if (normalized == 'sterile' || normalized == 'stérile') {
      return 'Stérile';
    }
    return value.toString();
  }

  @visibleForTesting
  String normalizeSheetDateForTest(String value) => _normalizeSheetDate(value);

  @visibleForTesting
  String normalizePosteForTest(Object? value) => _normalizePosteValue(value);

  @visibleForTesting
  String formatSheetTimestampForTest(DateTime value) =>
      _formatSheetTimestamp(value);

  @visibleForTesting
  String formatIsoTimestampWithSecondsForTest(DateTime value) =>
      _formatIsoTimestampWithSeconds(value);

  @visibleForTesting
  int detectHeaderRowIndexForTest(List<List<Object?>> rows) =>
      _detectHeaderRowIndex(rows);

  @visibleForTesting
  List<String> r0DowntimeDetailsHeadersForTest() =>
      List<String>.from(_r0DowntimeDetailsHeaders);

  @visibleForTesting
  List<List<Object?>> buildR0DowntimeDetailsRowsForTest(
    DateTime reportDateLocal,
    Map<String, dynamic> data,
  ) =>
      _buildR0DowntimeDetailsRows(reportDateLocal, data);

  @visibleForTesting
  List<Object?> buildIfDowntimeRowForTest(
    DateTime reportDateLocal,
    Map<String, dynamic> stop, {
    required String equipmentFallback,
  }) =>
      _buildIfDowntimeRow(
        reportDateLocal,
        stop,
        equipmentFallback: equipmentFallback,
      );

  /// Reads all sheets from Google Sheets and returns normalized searchable rows.
  ///
  /// This is used by the in-app explorer page to browse everything recorded,
  /// including template sheets and detailed rows.
  Future<List<GoogleSheetRecord>> fetchAllRecords({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _recordsCache != null && _recordsCacheAt != null) {
      final age = DateTime.now().difference(_recordsCacheAt!);
      if (age < const Duration(minutes: 2)) {
        return List<GoogleSheetRecord>.from(_recordsCache!);
      }
    }

    final api = await _getSheetsApi();
    if (api == null) {
      return [];
    }

    final spreadsheet = await api.spreadsheets.get(_spreadsheetId);
    final sheets = spreadsheet.sheets ?? const [];
    final List<GoogleSheetRecord> records = [];

    for (final sheet in sheets) {
      final sheetName = sheet.properties?.title;
      if (sheetName == null || sheetName.trim().isEmpty) {
        continue;
      }

      final templateHeaders = _templateHeadersForSheet(sheetName);
      if (templateHeaders != null) {
        final templateRecords = await _fetchTemplateSheetRecords(
          api,
          sheetName: sheetName,
          headers: templateHeaders,
        );
        records.addAll(templateRecords);
        continue;
      }

      final response = await api.spreadsheets.values.get(
        _spreadsheetId,
        '$sheetName!A1:AZ',
      );

      final rows = response.values ?? const [];
      if (rows.isEmpty) {
        continue;
      }

      final headerIndex = _detectHeaderRowIndex(rows);
      if (headerIndex < 0 || headerIndex >= rows.length) {
        continue;
      }

      final headers = _normalizeHeaders(rows[headerIndex]);
      DateTime? inheritedDate;

      if (_isTemplateGroupedSheet(headers)) {
        records.addAll(
          _buildGroupedTemplateRecords(
            sheetName: sheetName,
            rows: rows,
            headerIndex: headerIndex,
            headers: headers,
          ),
        );
        continue;
      }

      if (_normalizeHeaderKey(sheetName) ==
          _normalizeHeaderKey(_machinesSheet)) {
        records.addAll(
          _buildGroupedMachinesRecords(
            sheetName: sheetName,
            rows: rows,
            headerIndex: headerIndex,
            headers: headers,
          ),
        );
        continue;
      }

      for (var rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (!_hasContent(row)) {
          continue;
        }

        final details = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          final value = i < row.length ? row[i]?.toString().trim() ?? '' : '';
          details[headers[i]] = value;
        }

        final explicitDate = GoogleSheetRecord.resolveDateFromDetails(details);
        if (explicitDate != null) {
          inheritedDate = explicitDate;
        }

        if (explicitDate == null && inheritedDate != null) {
          _injectInheritedDate(details, inheritedDate);
        }

        records.add(
          GoogleSheetRecord.fromRaw(
            sheetName: sheetName,
            rowNumber: rowIndex + 1,
            details: details,
            fallbackDate: inheritedDate,
          ),
        );
      }
    }

    _recordsCache = records;
    _recordsCacheAt = DateTime.now();
    return List<GoogleSheetRecord>.from(records);
  }

  Future<List<GoogleSheetRecord>> _fetchTemplateSheetRecords(
    SheetsApi api, {
    required String sheetName,
    required List<String> headers,
  }) async {
    final response = await api.spreadsheets.values.get(
      _spreadsheetId,
      '$sheetName!A7:AZ',
    );

    final rows = response.values ?? const [];
    if (rows.isEmpty) {
      return const [];
    }

    return _buildGroupedTemplateRecords(
      sheetName: sheetName,
      rows: rows,
      headerIndex: -1,
      headers: headers,
      rowOffset: 7,
    );
  }

  List<String>? _templateHeadersForSheet(String sheetName) {
    switch (sheetName) {
      case _activitySheet:
        return const [
          'Date',
          'Arrêt',
          'Durée d\'arrêt',
          'T H.A',
          'T H.M',
          'Créé par',
          'Separator',
          'Date Counter',
          'Compteur Vibrateur',
          'T H.V',
          'Compteur Liaison',
          'T H.L',
          'Stock',
        ];
      case _dailySheet:
        return const [
          'Date',
          'Module',
          'Nature',
          'Durée d\'arrêt',
          'Durée marche',
          'Créé par',
          'Separator',
          'Date Stock',
          'Stock',
        ];
      case _r0Sheet:
        return const [
          'Date',
          'Mine',
          'Zone',
          'Sortie',
          'Poste',
          'Machine/Engins',
          'Type',
          'Model',
          'Début compteur',
          'Fin compteur',
          'H.M',
          'Catégorie d\'arrêt',
          'Arrêt',
          'Début d\'arrêt',
          'Fin d\'arrêt',
          'H.A',
          'Tonnage',
          'Métrage foré',
          'Nr de Trous Forés',
          'Nr de Voyages',
          'M³ Décapages',
          'Nr T.K.U',
          'Rendement',
          'Chantier',
          'Temps',
          'Imputation',
          'Conducteur',
          'Graisseur',
          'Matricules',
          'Gasoil',
          'Cree par',
        ];
      case _truckSheet:
        return const [
          'Date',
          'Mine',
          'Sortie',
          'Machine/Engins',
          'Distance',
          'Qualité',
          'Opération',
          'P pointeur',
          'Poste',
          'Camions',
          'Conducteur',
          'Voyage 1',
          'Voyage 2',
          'Voyage 3',
          'Voyage 4',
          'Voyage 5',
          'Voyage 6',
          'Voyage 7',
          'Voyage 8',
          'Voyage 9',
          'Voyage 10',
          'Voyage 11',
          'Voyage 12',
          'Total de Voyages Camions',
          'Total de Voyages par Equipment',
          'Total de Voyages',
          'Créé par',
          'Crée en',
        ];
      case _machinesSheet:
        return const [
          'Date',
          'Catégorie',
          'Sous-catégorie',
          'Équipement',
          'Raison',
          'Créé par',
        ];
      default:
        return null;
    }
  }

  bool _isTemplateGroupedSheet(List<String> headers) {
    final normalized = headers.map(_normalizeHeaderKey).toSet();
    return normalized.contains('date') &&
        normalized.contains('arret') &&
        normalized.contains('debutdarret') &&
        normalized.contains('findarret');
  }

  List<GoogleSheetRecord> _buildGroupedTemplateRecords({
    required String sheetName,
    required List<List<Object?>> rows,
    required int headerIndex,
    required List<String> headers,
    int rowOffset = 1,
  }) {
    final records = <GoogleSheetRecord>[];
    _TemplateGroupedRecordBuilder? current;
    String? currentDailyDateKey;
    final isDailyTemplate =
        _normalizeHeaderKey(sheetName) == _normalizeHeaderKey(_dailySheet);

    for (var rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (!_hasContent(row)) {
        continue;
      }

      final details = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        final value = i < row.length ? row[i]?.toString().trim() ?? '' : '';
        details[headers[i]] = value;
      }

      bool isNewGroup;
      if (isDailyTemplate) {
        final explicitDate = GoogleSheetRecord.resolveDateFromDetails(details);
        final nextDateKey = explicitDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(explicitDate);

        if (current == null) {
          isNewGroup = nextDateKey != null;
        } else if (nextDateKey == null) {
          isNewGroup = false;
        } else {
          isNewGroup = nextDateKey != currentDailyDateKey;
        }

        if (isNewGroup) {
          currentDailyDateKey = nextDateKey;
        }
      } else {
        isNewGroup = _isTemplateGroupStart(details);
      }

      if (isNewGroup) {
        if (current != null) {
          records.add(current.build(sheetName: sheetName));
        }
        current = _TemplateGroupedRecordBuilder(
          anchorRowNumber: rowIndex + rowOffset,
          baseDetails: Map<String, String>.from(details),
        );
      }

      if (current == null) {
        continue;
      }

      current.addRow(details);
    }

    if (current != null) {
      records.add(current.build(sheetName: sheetName));
    }

    return records;
  }

  List<GoogleSheetRecord> _buildGroupedMachinesRecords({
    required String sheetName,
    required List<List<Object?>> rows,
    required int headerIndex,
    required List<String> headers,
  }) {
    final grouped = <String, _MachinesGroupedRecordBuilder>{};
    DateTime? inheritedDate;

    for (var rowIndex = headerIndex + 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (!_hasContent(row)) {
        continue;
      }

      final details = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        final value = i < row.length ? row[i]?.toString().trim() ?? '' : '';
        details[headers[i]] = value;
      }

      final explicitDate = GoogleSheetRecord.resolveDateFromDetails(details);
      if (explicitDate != null) {
        inheritedDate = explicitDate;
      }

      if (explicitDate == null && inheritedDate != null) {
        _injectInheritedDate(details, inheritedDate);
      }

      final effectiveDate =
          GoogleSheetRecord.resolveDateFromDetails(details) ?? inheritedDate;
      if (effectiveDate == null) {
        continue;
      }

      final dateKey = DateFormat('yyyy-MM-dd').format(effectiveDate);
      final builder = grouped.putIfAbsent(
        dateKey,
        () => _MachinesGroupedRecordBuilder(
          anchorRowNumber: rowIndex + 1,
          date: effectiveDate,
        ),
      );
      builder.addRow(details);
    }

    return grouped.values
        .map((builder) => builder.build(sheetName: sheetName))
        .toList();
  }

  bool _isTemplateGroupStart(Map<String, String> details) {
    const startCandidateHeaders = [
      'Date',
      'Mine',
      'Zone',
      'Sortie',
      'Poste',
      'Machine/Engins',
      'Model',
    ];

    for (final key in startCandidateHeaders) {
      if ((details[key] ?? '').trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String _normalizeHeaderKey(String value) {
    final lower = value.toLowerCase();
    final normalized = lower
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('ï', 'i');
    return normalized.replaceAll(RegExp(r"[^a-z0-9]"), '');
  }

  int _detectHeaderRowIndex(List<List<Object?>> rows) {
    final candidates = rows.take(10).toList();
    const headerKeywords = {
      'date',
      'mine',
      'zone',
      'sortie',
      'poste',
      'machineengins',
      'model',
      'debutcompteur',
      'fincompteur',
      'hm',
      'categoriedarret',
      'arret',
      'debutdarret',
      'findarret',
      'ha',
      'tonnage',
      'nrvoyages',
      'nrtku',
      'imputation',
      'conducteur',
      'graisseur',
      'matricules',
      'gasoil',
      'creepar',
      'creen',
    };

    var bestIndex = -1;
    var bestScore = 0;

    for (var i = 0; i < candidates.length; i++) {
      final row = candidates[i];
      var nonEmptyCells = 0;
      var alphaCells = 0;
      var headerMatches = 0;

      for (final cell in row) {
        final text = cell?.toString().trim() ?? '';
        if (text.isEmpty) {
          continue;
        }
        nonEmptyCells += 1;
        if (RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(text)) {
          alphaCells += 1;
        }

        final normalized = _normalizeHeaderKey(text);
        if (headerKeywords.contains(normalized)) {
          headerMatches += 1;
        }
      }

      final score = (headerMatches * 100) + (alphaCells * 2) + nonEmptyCells;

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  bool _hasContent(List<Object?> row) {
    for (final cell in row) {
      if ((cell?.toString().trim() ?? '').isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  List<String> _normalizeHeaders(List<Object?> rawHeaders) {
    final headers = <String>[];
    final usedHeaders = <String, int>{};

    for (var i = 0; i < rawHeaders.length; i++) {
      var header = rawHeaders[i]?.toString().trim() ?? '';
      if (header.isEmpty) {
        header = 'Column ${i + 1}';
      }

      final existing = usedHeaders[header] ?? 0;
      usedHeaders[header] = existing + 1;
      if (existing > 0) {
        header = '$header (${existing + 1})';
      }

      headers.add(header);
    }

    return headers;
  }

  void _injectInheritedDate(Map<String, String> details, DateTime date) {
    for (final entry in details.entries) {
      if (entry.key.toLowerCase().contains('date') &&
          entry.value.trim().isEmpty) {
        details[entry.key] = DateFormat('yyyy-MM-dd').format(date);
        return;
      }
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
      return 'Machine et engins à l\'arrêt';
    }
    if (typeLower == 'r0') {
      return 'R0';
    }
    return report.description;
  }

  String _formatDisplayDate(DateTime reportDate) {
    return DateFormat('dd/MM/yyyy HH:mm:ss', _frenchLocale)
        .format(reportDate.toLocal());
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

  static const List<String> _baseHeaders = [
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

  static const List<String> _detailsBaseHeaders = [
    'Submitted At (ISO)',
    'Submission Source',
    'Local ID',
    'Report Date (ISO)',
    'Report Type',
    'Group',
  ];

  static List<Object?> _detailsBaseRow(
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

  Future<bool> _recordReportSnapshotViaBackend(
    Report report, {
    required String action,
    required _ReportPayload payload,
    _TemplateRows? templateRows,
    required DateTime reportLocalDate,
  }) async {
    try {
      final tasks = <Map<String, dynamic>>[];

      if (templateRows != null) {
        final checkDuplicate = (templateRows.sheetName == _activitySheet ||
                                templateRows.sheetName == _dailySheet ||
                                templateRows.sheetName == _machinesSheet)
            ? 'date'
            : (templateRows.sheetName == _r0Sheet)
                ? 'r0'
                : (templateRows.sheetName == _truckSheet)
                    ? 'truck'
                    : null;

        final dateStr = DateFormat('yyyy-MM-dd', _frenchLocale).format(reportLocalDate);
        final additionalData = report.additionalData ?? {};

        tasks.add({
          'type': 'appendTemplateRows',
          'sheetName': templateRows.sheetName,
          'rows': templateRows.rows,
          'mergeRanges': templateRows.mergeRanges.map((m) => {
            'startColumnIndex': m.startColumnIndex,
            'endColumnIndex': m.endColumnIndex,
          }).toList(),
          'customMerges': templateRows.customMerges.map((m) => {
            'startRowOffset': m.startRowOffset,
            'endRowOffset': m.endRowOffset,
            'startColumnIndex': m.startColumnIndex,
            'endColumnIndex': m.endColumnIndex,
          }).toList(),
          'colorSections': templateRows.colorSections.map((c) => {
            'startColumnIndex': c.startColumnIndex,
            'endColumnIndex': c.endColumnIndex,
          }).toList(),
          'separatorColumnIndexes': templateRows.separatorColumnIndexes,
          'checkDuplicate': checkDuplicate,
          'date': dateStr,
          'poste': additionalData['selectedPoste']?.toString() ?? '',
          'module': additionalData['Model']?.toString() ?? '',
        });

        // Add downtime details tasks if applicable (mimicking _syncIfDowntimeDetailsSheet)
        final category = _categorizeReport(report, additionalData);
        if (category == _ReportCategory.activityTnb) {
          final downtimeRows = _listOfMaps(additionalData['Arrets'])
              .map((stop) => _buildIfDowntimeRow(
                    reportLocalDate,
                    stop,
                    equipmentFallback: 'TNB',
                  ))
              .toList();
          if (downtimeRows.isNotEmpty) {
            tasks.add({
              'type': 'appendIfDowntimeRows',
              'sheetName': _ifDowntimeDetailsSheet,
              'rangePrefix': 'A',
              'rangeSuffix': 'G',
              'rows': downtimeRows,
            });
          }
        } else if (category == _ReportCategory.dailyTsud) {
          final module1Rows = _listOfMaps(additionalData['module1Stops'])
              .map((stop) => _buildIfDowntimeRow(
                    reportLocalDate,
                    stop,
                    equipmentFallback: 'TSUD',
                  ))
              .toList();
          final module2Rows = _listOfMaps(additionalData['module2Stops'])
              .map((stop) => _buildIfDowntimeRow(
                    reportLocalDate,
                    stop,
                    equipmentFallback: 'TSUD',
                  ))
              .toList();

          if (module1Rows.isNotEmpty) {
            tasks.add({
              'type': 'appendIfDowntimeRows',
              'sheetName': _ifDowntimeDetailsSheet,
              'rangePrefix': 'I',
              'rangeSuffix': 'O',
              'rows': module1Rows,
            });
          }
          if (module2Rows.isNotEmpty) {
            tasks.add({
              'type': 'appendIfDowntimeRows',
              'sheetName': _ifDowntimeDetailsSheet,
              'rangePrefix': 'Q',
              'rangeSuffix': 'W',
              'rows': module2Rows,
            });
          }
        }

        // Add R0 downtime details tasks if applicable (mimicking _syncR0DowntimeDetailsSheet)
        if (category == _ReportCategory.r0) {
          final r0Rows = _buildR0DowntimeDetailsRows(reportLocalDate, additionalData);
          if (r0Rows.isNotEmpty) {
            tasks.add({
              'type': 'appendFlatRows',
              'sheetName': _r0DowntimeDetailsSheet,
              'headers': _r0DowntimeDetailsHeaders,
              'rows': r0Rows,
              'dateColumnIndex': 0,
              'firstDataRowNumber': 2,
            });
          }
        }
      } else {
        // Flat rows
        tasks.add({
          'type': 'appendFlatRows',
          'sheetName': payload.sheetName,
          'headers': payload.headers,
          'rows': [payload.row],
          'dateColumnIndex': 11,
          'firstDataRowNumber': 2,
        });

        if (payload.detailsRows.isNotEmpty &&
            payload.detailsSheetName != null &&
            payload.detailsHeaders != null) {
          tasks.add({
            'type': 'appendFlatRows',
            'sheetName': payload.detailsSheetName!,
            'headers': payload.detailsHeaders!,
            'rows': payload.detailsRows,
            'dateColumnIndex': 11,
            'firstDataRowNumber': 2,
          });
        }
      }

      final reportId = report.firestoreId;
      if (reportId == null || reportId.isEmpty) {
        throw Exception(
          'Cannot sync report to Sheets via backend without a Firestore ID.',
        );
      }

      final callable = FirebaseFunctions.instance.httpsCallable('submitReportToSheets');
      final result = await callable.call<Map<dynamic, dynamic>>({
        'reportId': reportId,
        'action': action,
        'tasks': tasks,
      });

      return result.data['success'] == true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        throw DuplicateReportDateException(e.message ?? 'Un rapport avec la date du jour existe déjà.');
      }
      debugPrint('Backend Google Sheets sync failed: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Backend Google Sheets sync failed: $e');
      rethrow;
    }
  }
}

class GoogleSheetRecord {
  GoogleSheetRecord({
    required this.sheetName,
    required this.rowNumber,
    required this.details,
    required this.date,
    required this.dateLabel,
    required this.title,
    required this.searchableText,
  });

  factory GoogleSheetRecord.fromRaw({
    required String sheetName,
    required int rowNumber,
    required Map<String, String> details,
    DateTime? fallbackDate,
  }) {
    final title = _resolveTitle(details);
    final date = resolveDateFromDetails(details) ?? fallbackDate;

    return GoogleSheetRecord(
      sheetName: sheetName,
      rowNumber: rowNumber,
      details: details,
      date: date,
      dateLabel:
          date == null ? 'Unknown date' : DateFormat('yyyy-MM-dd').format(date),
      title: title,
      searchableText: _buildSearchableText(sheetName, details, title, date),
    );
  }

  final String sheetName;
  final int rowNumber;
  final Map<String, String> details;
  final DateTime? date;
  final String dateLabel;
  final String title;
  final String searchableText;

  static String _resolveTitle(Map<String, String> details) {
    const titleCandidates = [
      'Title (as shown in app)',
      'Type (as shown in app)',
      'Description',
      'Type',
      'Rapport',
      'Report',
    ];

    for (final key in titleCandidates) {
      final value = details[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    for (final entry in details.entries) {
      if (entry.value.trim().isNotEmpty) {
        return entry.value.trim();
      }
    }

    return 'Untitled report';
  }

  static DateTime? resolveDateFromDetails(Map<String, String> details) {
    for (final entry in details.entries) {
      if (entry.key.toLowerCase().contains('date')) {
        final parsed = DateTime.tryParse(entry.value);
        if (parsed != null) {
          return parsed;
        }

        for (final pattern in [
          'yyyy-MM-dd',
          'dd/MM/yyyy',
          'dd/MM/yyyy HH:mm'
        ]) {
          try {
            return DateFormat(pattern).parse(entry.value);
          } catch (_) {
            continue;
          }
        }
      }
    }

    return null;
  }

  static String _buildSearchableText(
    String sheetName,
    Map<String, String> details,
    String title,
    DateTime? date,
  ) {
    final parts = <String>[sheetName, title];
    parts.addAll(details.keys);
    parts.addAll(details.values);
    if (date != null) {
      parts.add(DateFormat('yyyy-MM-dd').format(date));
      parts.add(DateFormat('dd/MM/yyyy').format(date));
    }

    return parts.join(' ').toLowerCase();
  }
}

class _TemplateGroupedRecordBuilder {
  _TemplateGroupedRecordBuilder({
    required this.anchorRowNumber,
    required Map<String, String> baseDetails,
  }) : _details = Map<String, String>.from(baseDetails);

  final int anchorRowNumber;
  final Map<String, String> _details;
  final List<String> _stopReasons = [];
  final List<String> _stopTimes = [];
  final List<String> _activityStops = [];
  final List<String> _activityStopDurations = [];
  final List<String> _activityVibratorCounters = [];
  final List<String> _activityLiaisonCounters = [];
  final List<String> _activityStocks = [];
  final List<String> _dailyModule1Natures = [];
  final List<String> _dailyModule1Downtimes = [];
  final List<String> _dailyModule2Natures = [];
  final List<String> _dailyModule2Downtimes = [];
  final List<String> _dailyStocks = [];
  final List<_TruckTemplateRow> _truckRows = [];
  String _dailyModule1Operating = '';
  String _dailyModule2Operating = '';
  String _lastDailyModule = '';

  String _readField(Map<String, String> rowDetails, List<String> candidates) {
    for (final candidate in candidates) {
      final expected = _normalizeTemplateFieldKey(candidate);
      for (final entry in rowDetails.entries) {
        if (_normalizeTemplateFieldKey(entry.key) == expected) {
          final value = entry.value.trim();
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
    }
    return '';
  }

  String _normalizeTemplateFieldKey(String value) {
    final lower = value.toLowerCase();
    final normalized = lower
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('ù', 'u')
        .replaceAll('ô', 'o')
        .replaceAll('ï', 'i');
    return normalized.replaceAll(RegExp(r"[^a-z0-9]"), '');
  }

  void addRow(Map<String, String> rowDetails) {
    const inheritFieldCandidates = {
      'Date': ['Date'],
      'Mine': ['Mine'],
      'Zone': ['Zone'],
      'Sortie': ['Sortie'],
      'Poste': ['Poste'],
      'Machine/Engins': ['Machine/Engins', 'Machine Engins', 'Category'],
      'Catégorie': ['Catégorie', 'Categorie'],
      'Model': ['Model', 'Modèle'],
      'Début Compteur': ['Début Compteur', 'Debut Compteur'],
      'Fin Compteur': ['Fin Compteur'],
      'H.M': ['H.M'],
      'H.A': ['H.A'],
      'Tonnage': ['Tonnage'],
      'Metrage Fore': ['Metrage Fore', 'Métrage Foré', 'Métrage fore'],
      'Ir de Trous Fore': ['Ir de Trous Fore', 'Nr de Trous Forés'],
      'Nr Voyages': ['Nr Voyages', 'Nr de Voyages'],
      'M Decapages': ['M Decapages', 'M³ Décapages'],
      'Nr T.K.U': ['Nr T.K.U', 'Nombre T.K.U'],
      'Rendment': ['Rendment', 'Rendement', 'Rendement %'],
      'Chantier': ['Chantier'],
      'Temps': ['Temps'],
      'Imputation': ['Imputation'],
      'Conducteur': ['Conducteur'],
      'Graisseur': ['Graisseur'],
      'Matricules': ['Matricules'],
      'Tricone': ['Tricone', 'Tricône'],
      'Gasoil': ['Gasoil', 'Diesel'],
      'Cree par': ['Cree par', 'Créé par'],
      'Cree en': ['Cree en', 'Créé en'],
    };

    for (final entry in inheritFieldCandidates.entries) {
      final value = _readField(rowDetails, entry.value);
      if (value.isNotEmpty) {
        _details[entry.key] = value;
      }
    }

    final stopReason = _readField(rowDetails, ['Arrêt', 'Arret']);
    final stopDuration =
        _readField(rowDetails, ["Durée d'arrêt", 'Duree d arret', 'Duration']);
    final vibratorCounter =
        _readField(rowDetails, ['Compteur Vibrateur', 'Compteurs Vibreurs']);
    final liaisonCounter =
        _readField(rowDetails, ['Compteur Liaison', 'Compteurs Liaison']);
    final stock = _readField(rowDetails, ['Stock', 'Stocks']);
    final moduleRaw = _readField(rowDetails, [
      'Module',
      'Catégorie du module',
      'Categorie du module',
    ]);
    final module = moduleRaw.isNotEmpty ? moduleRaw : _lastDailyModule;
    if (moduleRaw.isNotEmpty) {
      _lastDailyModule = moduleRaw;
    }

    final nature = _readField(rowDetails, [
      'Nature',
      "Nature d'arrêt",
      'Nature d arret',
    ]);
    final operatingDuration = _readField(rowDetails, [
      'Durée marche',
      'Duree marche',
      'Total H.M',
      'Total H.M1',
      'Total H.M2',
    ]);
    final stopStart =
        _readField(rowDetails, ["Début d'Arrêt", 'Debut d Arret', 'Start']);
    final stopEnd =
        _readField(rowDetails, ["Fin d'Arrêt", 'Fin d Arret', 'End']);

    if (stopReason.isNotEmpty) {
      _activityStops.add(stopReason);
    }
    if (stopDuration.isNotEmpty) {
      _activityStopDurations.add(stopDuration);
    }
    if (vibratorCounter.isNotEmpty) {
      _activityVibratorCounters.add(vibratorCounter);
    }
    if (liaisonCounter.isNotEmpty) {
      _activityLiaisonCounters.add(liaisonCounter);
    }
    if (stock.isNotEmpty) {
      _activityStocks.add(stock);
    }

    final normalizedModule = module.toLowerCase();
    if (normalizedModule == 'module 1') {
      if (nature.isNotEmpty) {
        _dailyModule1Natures.add(nature);
      }
      if (stopDuration.isNotEmpty) {
        _dailyModule1Downtimes.add(stopDuration);
      }
      if (operatingDuration.isNotEmpty) {
        _dailyModule1Operating = operatingDuration;
      }
    } else if (normalizedModule == 'module 2') {
      if (nature.isNotEmpty) {
        _dailyModule2Natures.add(nature);
      }
      if (stopDuration.isNotEmpty) {
        _dailyModule2Downtimes.add(stopDuration);
      }
      if (operatingDuration.isNotEmpty) {
        _dailyModule2Operating = operatingDuration;
      }
    }

    if (stock.isNotEmpty) {
      _dailyStocks.add(stock);
    }

    if (stopReason.isNotEmpty || stopStart.isNotEmpty || stopEnd.isNotEmpty) {
      if (stopReason.isNotEmpty) {
        _stopReasons.add(stopReason);
      }
      if (stopStart.isNotEmpty || stopEnd.isNotEmpty) {
        final separator =
            (stopStart.isNotEmpty && stopEnd.isNotEmpty) ? ' - ' : '';
        _stopTimes.add('$stopStart$separator$stopEnd'.trim());
      }
    }
    _addTruckRow(rowDetails);
  }

  void _addTruckRow(Map<String, String> rowDetails) {
    final truckNumber = (rowDetails['Camions'] ?? '').trim();
    final driver = (rowDetails['Conducteur'] ?? '').trim();
    final trips = <_TruckTemplateTrip>[];

    for (var i = 1; i <= 12; i++) {
      final rawTrip = (rowDetails['Voyage $i'] ?? '').trim();
      if (rawTrip.isEmpty) continue;
      final parts = rawTrip
          .split('\n')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
      if (parts.isEmpty) continue;
      trips.add(
        _TruckTemplateTrip(
          time: parts.first,
          equipment: parts.length > 1 ? parts[1] : '',
          quality: parts.length > 2 ? parts[2] : '',
        ),
      );
    }

    if (truckNumber.isEmpty && driver.isEmpty && trips.isEmpty) {
      return;
    }

    _truckRows.add(
      _TruckTemplateRow(
        truckNumber: truckNumber,
        driver: driver,
        trips: trips,
      ),
    );
  }

  GoogleSheetRecord build({required String sheetName}) {
    if (_stopReasons.isNotEmpty) {
      _details['Stops Details'] = _stopReasons.join('\n');
    }
    if (_stopTimes.isNotEmpty) {
      _details['Stop Times'] = _stopTimes.join('\n');
    }
    if (_activityStops.isNotEmpty) {
      _details['Arrêts'] = _activityStops.join('\n');
    }
    if (_activityStopDurations.isNotEmpty) {
      _details['Durées d\'arrêt'] = _activityStopDurations.join('\n');
    }
    if (_activityVibratorCounters.isNotEmpty) {
      _details['Compteurs Vibreurs'] = _activityVibratorCounters.join('\n');
    }
    if (_activityLiaisonCounters.isNotEmpty) {
      _details['Compteurs Liaison'] = _activityLiaisonCounters.join('\n');
    }
    if (_activityStocks.isNotEmpty) {
      _details['Stocks'] = _activityStocks.join('\n');
    }
    if (_dailyModule1Natures.isNotEmpty) {
      _details['Détails Arrêts M1'] = _dailyModule1Natures.join('\n');
    }
    if (_dailyModule1Downtimes.isNotEmpty) {
      _details['Durées Arrêts M1'] = _dailyModule1Downtimes.join('\n');
    }
    if (_dailyModule2Natures.isNotEmpty) {
      _details['Détails Arrêts M2'] = _dailyModule2Natures.join('\n');
    }
    if (_dailyModule2Downtimes.isNotEmpty) {
      _details['Durées Arrêts M2'] = _dailyModule2Downtimes.join('\n');
    }
    if (_dailyModule1Operating.isNotEmpty) {
      _details['Durée Marche M1'] = _dailyModule1Operating;
    }
    if (_dailyModule2Operating.isNotEmpty) {
      _details['Durée Marche M2'] = _dailyModule2Operating;
    }
    if (_dailyStocks.isNotEmpty) {
      _details['Détails Stock'] = _dailyStocks.join('\n');
    }
    if (_truckRows.isNotEmpty) {
      _details['Camions List'] = _truckRows
          .map((row) => row.truckNumber)
          .where((value) => value.isNotEmpty)
          .join('\n');
      _details['Conducteurs List'] = _truckRows
          .map((row) => row.driver)
          .where((value) => value.isNotEmpty)
          .join('\n');
      _details['Trips per Truck'] = _truckRows
          .map((row) => '${row.truckNumber}: ${row.trips.length}')
          .join('\n');
      _details['Trip Details'] = _truckRows
          .expand((row) => row.trips.map((trip) {
                final qualityPart =
                    trip.quality.isEmpty ? '' : ' | ${trip.quality}';
                return '${trip.time} | ${row.truckNumber} | ${trip.equipment}$qualityPart';
              }))
          .join('\n');
    }

    return GoogleSheetRecord.fromRaw(
      sheetName: sheetName,
      rowNumber: anchorRowNumber,
      details: _details,
    );
  }
}

class _TruckTemplateRow {
  const _TruckTemplateRow({
    required this.truckNumber,
    required this.driver,
    required this.trips,
  });

  final String truckNumber;
  final String driver;
  final List<_TruckTemplateTrip> trips;
}

class _TruckTemplateTrip {
  const _TruckTemplateTrip({
    required this.time,
    required this.equipment,
    required this.quality,
  });

  final String time;
  final String equipment;
  final String quality;
}

class _MachinesGroupedRecordBuilder {
  _MachinesGroupedRecordBuilder({
    required this.anchorRowNumber,
    required this.date,
  });

  final int anchorRowNumber;
  final DateTime date;
  final List<String> _categories = [];
  final List<String> _subCategories = [];
  final List<String> _equipments = [];
  final List<String> _reasons = [];
  String _createdBy = '';

  void addRow(Map<String, String> rowDetails) {
    final category = _firstValue(rowDetails, const [
      'Catégorie',
      'Catégorie principale',
      'Category',
    ]);
    final subCategory = _firstValue(rowDetails, const [
      'Sous-catégorie',
      'Sous-Catégorie',
      'Sub Category',
    ]);
    final equipment = _firstValue(rowDetails, const [
      'Équipement',
      'Equipement',
      'Equipement ',
      'Equipment',
    ]);
    final reason = _firstValue(rowDetails, const [
      'Raison',
      "Raison De l'Arret",
      'Raison De l\'Arret',
      'Reason',
    ]);

    if (category.isNotEmpty) {
      _categories.add(category);
    }
    if (subCategory.isNotEmpty) {
      _subCategories.add(subCategory);
    }
    if (equipment.isNotEmpty) {
      _equipments.add(equipment);
    }
    if (reason.isNotEmpty) {
      _reasons.add(reason);
    }

    if (_createdBy.isEmpty) {
      _createdBy = _firstValue(rowDetails, const ['Créé par', 'Cree par']);
    }
  }

  GoogleSheetRecord build({required String sheetName}) {
    final details = <String, String>{
      'Date': DateFormat('yyyy-MM-dd').format(date),
      'Catégorie': _categories.join('\n'),
      'Sous-catégorie': _subCategories.join('\n'),
      'Équipement': _equipments.join('\n'),
      'Raison': _reasons.join('\n'),
      if (_createdBy.isNotEmpty) 'Créé par': _createdBy,
    };

    return GoogleSheetRecord.fromRaw(
      sheetName: sheetName,
      rowNumber: anchorRowNumber,
      details: details,
      fallbackDate: date,
    );
  }

  String _firstValue(Map<String, String> rowDetails, List<String> keys) {
    for (final key in keys) {
      final value = rowDetails[key]?.trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
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
    this.separatorColumnIndexes = const [],
    this.colorSections = const [],
  });

  final String sheetName;
  final List<List<Object?>> rows;
  final List<_TemplateMergeRange> mergeRanges;
  final List<_TemplateCustomMerge> customMerges;
  final List<int> separatorColumnIndexes;
  final List<_TemplateColorSection> colorSections;

  _TemplateRows copyWith({
    String? sheetName,
    List<List<Object?>>? rows,
    List<_TemplateMergeRange>? mergeRanges,
    List<_TemplateCustomMerge>? customMerges,
    List<int>? separatorColumnIndexes,
    List<_TemplateColorSection>? colorSections,
  }) {
    return _TemplateRows(
      sheetName: sheetName ?? this.sheetName,
      rows: rows ?? this.rows,
      mergeRanges: mergeRanges ?? this.mergeRanges,
      customMerges: customMerges ?? this.customMerges,
      separatorColumnIndexes:
          separatorColumnIndexes ?? this.separatorColumnIndexes,
      colorSections: colorSections ?? this.colorSections,
    );
  }
}

class DuplicateReportDateException implements Exception {
  DuplicateReportDateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _TemplateColorSection {
  const _TemplateColorSection({
    required this.startColumnIndex,
    required this.endColumnIndex,
  });

  final int startColumnIndex;
  final int endColumnIndex;
}

class _ReportColorTheme {
  const _ReportColorTheme({
    required this.primary,
    required this.secondary,
  });

  final Color primary;
  final Color secondary;
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
