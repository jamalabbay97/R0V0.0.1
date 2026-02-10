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

  Future<void> recordReportSnapshot(
    Report report, {
    required String action,
  }) async {
    if (_spreadsheetId.isEmpty ||
        _spreadsheetId == 'ENTER_YOUR_SPREADSHEET_ID_HERE') {
      debugPrint(
        'Google Sheets sync skipped: GOOGLE_SHEETS_SPREADSHEET_ID is missing or set to placeholder.',
      );
      return;
    }

    final api = await _getSheetsApi();
    if (api == null) {
      return;
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
      return;
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
    }

    if (templateRows.rows.isEmpty) {
      return;
    }

    await api.spreadsheets.values.append(
      ValueRange(values: templateRows.rows),
      _spreadsheetId,
      '${templateRows.sheetName}!A7',
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
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

        for (final stop in module1Stops) {
          rows.add([
            date,
            'Module 1',
            stop['nature'] ?? '',
            stop['duration'] ?? '',
            data['T H.A1'] ?? '',
            data['T H.M1'] ?? '',
          ]);
        }
        for (final stop in module2Stops) {
          rows.add([
            date,
            'Module 2',
            stop['nature'] ?? '',
            stop['duration'] ?? '',
            data['T H.A2'] ?? '',
            data['T H.M2'] ?? '',
          ]);
        }

        if (rows.isEmpty) {
          rows.add(
              [date, '', '', '', data['T H.A1'] ?? '', data['T H.M1'] ?? '']);
        }

        return _TemplateRows(sheetName: _dailySheet, rows: rows);
      case _ReportCategory.activityTnb:
        final rows = <List<Object?>>[];
        final stops = _listOfMaps(data['Arrets']);
        final vibratorCounters = _listOfMaps(data['vibrator Counters']);
        final liaisonCounters = _listOfMaps(data['liaison Counters']);
        final stock = _listOfMaps(data['stock']);

        for (final stop in stops) {
          rows.add([
            date,
            stop['nature'] ?? '',
            stop['duration'] ?? '',
            data['T H.A'] ?? '',
            data['T H.M'] ?? '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
          ]);
        }
        for (final counter in vibratorCounters) {
          rows.add([
            date,
            '',
            '',
            data['T H.A'] ?? '',
            data['T H.M'] ?? '',
            _posteLabel(counter['poste']),
            counter['start'] ?? '',
            counter['end'] ?? '',
            '',
            data['T H.V'] ?? '',
            '',
            '',
            '',
            '',
            '',
            '',
          ]);
        }
        for (final counter in liaisonCounters) {
          rows.add([
            date,
            '',
            '',
            data['T H.A'] ?? '',
            data['T H.M'] ?? '',
            _posteLabel(counter['poste']),
            '',
            '',
            '',
            '',
            counter['start'] ?? '',
            counter['end'] ?? '',
            '',
            data['T H.L'] ?? '',
            '',
            '',
          ]);
        }
        for (final entry in stock) {
          rows.add([
            date,
            '',
            '',
            data['T H.A'] ?? '',
            data['T H.M'] ?? '',
            _posteLabel(entry['poste']),
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            _stockTypeLabel(entry['type']),
            _parkLabel(entry['park']),
          ]);
        }
        if (rows.isEmpty) {
          rows.add([
            date,
            '',
            '',
            data['T H.A'] ?? '',
            data['T H.M'] ?? '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
            ''
          ]);
        }

        return _TemplateRows(sheetName: _activitySheet, rows: rows);
      case _ReportCategory.r0:
        final rows = <List<Object?>>[];
        final exploitation = _mapOfStringDynamic(data['exploitation']);
        final repartition = _mapOfStringDynamic(data['repartition']);
        final personnel = _mapOfStringDynamic(data['personnel']);
        final consommation = _mapOfStringDynamic(data['consommation']);
        final compteurs = _mapOfStringDynamic(data['Compteurs']);
        final arrets = _listOfMaps(data['Arrets']);

        if (arrets.isEmpty) {
          rows.add([
            date,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['Model'] ?? '',
            data['selectedPoste'] ?? '',
            compteurs['duree'] ?? '',
            compteurs['note'] ?? '',
            '',
            '',
            '',
            '',
            '',
            exploitation['Tonnage'] ?? '',
            exploitation['Rendement %'] ?? exploitation['Rendeme'] ?? '',
            repartition['Chantier'] ?? '',
            repartition['Temps'] ?? '',
            repartition['Imputation'] ?? '',
            personnel['conductr'] ?? '',
            personnel['graisseur'] ?? '',
            personnel['matricules'] ?? '',
            consommation['tricone'] ?? '',
            consommation['gasoil'] ?? '',
          ]);
        }

        for (final arret in arrets) {
          rows.add([
            date,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['Model'] ?? '',
            data['selectedPoste'] ?? '',
            compteurs['duree'] ?? '',
            compteurs['note'] ?? '',
            '',
            arret['Catégorie'] ?? '',
            arret['Arret'] ?? '',
            arret['Début'] ?? '',
            arret['Fin'] ?? '',
            exploitation['Tonnage'] ?? '',
            exploitation['Rendement %'] ?? exploitation['Rendeme'] ?? '',
            repartition['Chantier'] ?? '',
            repartition['Temps'] ?? '',
            repartition['Imputation'] ?? '',
            personnel['conductr'] ?? '',
            personnel['graisseur'] ?? '',
            personnel['matricules'] ?? '',
            consommation['tricone'] ?? '',
            consommation['gasoil'] ?? '',
          ]);
        }
        return _TemplateRows(sheetName: _r0Sheet, rows: rows);
      case _ReportCategory.truckTracking:
        final rows = <List<Object?>>[];
        final trucks = _listOfMaps(data['truckData']);
        for (final truck in trucks) {
          final trips = _listOfMaps(truck['counts']);
          final tripTimes =
              trips.map((e) => e['time']?.toString() ?? '').toList();
          while (tripTimes.length < 16) {
            tripTimes.add('');
          }
          rows.add([
            date,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['selectedQualite'] ?? '',
            data['distance'] ?? '',
            data['selectedQualiteType'] ?? '',
            data['operationType'] ?? '',
            '',
            data['selectedPoste'] ?? '',
            truck['truckNumber'] ?? '',
            truck['driver1'] ?? '',
            ...tripTimes.take(16),
            '',
            _equipmentTripsLabel(data['equipmentTrips']),
            trips.length,
          ]);
        }
        if (rows.isEmpty) {
          rows.add([
            date,
            data['mine'] ?? '',
            data['sortie'] ?? '',
            data['selectedQualite'] ?? '',
            data['distance'] ?? '',
            data['selectedQualiteType'] ?? '',
            data['operationType'] ?? '',
            '',
            data['selectedPoste'] ?? '',
            '',
            '',
            ...List.filled(16, ''),
            '',
            _equipmentTripsLabel(data['equipmentTrips']),
            data['totalTrips'] ?? '',
          ]);
        }
        return _TemplateRows(sheetName: _truckSheet, rows: rows);
      case _ReportCategory.machinesStopped:
        final equipmentList = _listOfMaps(data['equipmentList']);
        final rows = equipmentList
            .map((entry) => [
                  date,
                  '',
                  '',
                  entry['equipmentType'] ?? '',
                  entry['Reason'] ?? '',
                ])
            .toList();
        if (rows.isEmpty) {
          rows.add([date, '', '', '', '']);
        }
        return _TemplateRows(sheetName: _machinesSheet, rows: rows);
      case _ReportCategory.generic:
        return null;
    }
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

  String _equipmentTripsLabel(dynamic value) {
    if (value is! Map) return '';
    final map = Map<String, dynamic>.from(value);
    if (map.isEmpty) return '';
    return map.entries.map((e) => '${e.key}:${e.value}').join(', ');
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
      if (title != null) {
        _knownSheets.add(title);
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
    final type = report.type.toLowerCase();
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
    if (data.containsKey('exploitation') && data.containsKey('repartition')) {
      return _ReportCategory.r0;
    }
    return _ReportCategory.generic;
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
        stop['Catégorie'] ?? '',
        stop['duration'] ?? '',
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
        stop['Catégorie'] ?? '',
        stop['duration'] ?? '',
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
    final repartition = _mapOfStringDynamic(data['repartition']);
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
  });

  final String sheetName;
  final List<List<Object?>> rows;
}
