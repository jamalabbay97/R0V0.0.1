import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:googleapis_auth/auth_io.dart';
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
    final baseRow = [
      savedAt,
      action,
      report.id?.toString() ?? '',
      report.firestoreId ?? '',
      report.type,
      report.group,
      reportDateIso,
      reportDateLocal,
      reportTimeLocal,
      report.description,
    ];

    final data = report.additionalData ?? {};
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
    final sheetName = _sanitizeSheetTitle('Activity TNB');
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
      'Saved At',
      'Action',
      'Local ID',
      'Report Date (ISO)',
      'Section',
      'Item Index',
      'Poste',
      'Park',
      'Stock Type',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Arrêts',
        i + 1,
        '',
        '',
        '',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Vibrator Counters',
        i + 1,
        counter['poste'] ?? '',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Liaison Counters',
        i + 1,
        counter['poste'] ?? '',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Stock',
        i + 1,
        entry['poste'] ?? '',
        entry['park'] ?? '',
        entry['type'] ?? '',
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
      detailsSheetName: _sanitizeSheetTitle('$sheetName - Détails'),
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
    final sheetName = _sanitizeSheetTitle('Daily TSUD');
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
      'Saved At',
      'Action',
      'Local ID',
      'Report Date (ISO)',
      'Section',
      'Item Index',
      'Poste',
      'Park',
      'Stock Type',
      'Duration',
      'Nature',
      'Quantity',
    ];

    final detailsRows = <List<Object?>>[];
    for (var i = 0; i < module1Stops.length; i++) {
      final stop = module1Stops[i];
      detailsRows.add([
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Arrêts M1',
        i + 1,
        '',
        '',
        '',
        stop['duration'] ?? '',
        stop['nature'] ?? '',
        '',
      ]);
    }
    for (var i = 0; i < module2Stops.length; i++) {
      final stop = module2Stops[i];
      detailsRows.add([
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Arrêts M2',
        i + 1,
        '',
        '',
        '',
        stop['duration'] ?? '',
        stop['nature'] ?? '',
        '',
      ]);
    }
    for (var i = 0; i < stock.length; i++) {
      final entry = stock[i];
      detailsRows.add([
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        'Stock',
        i + 1,
        entry['poste'] ?? '',
        entry['park'] ?? '',
        entry['type'] ?? '',
        '',
        '',
        entry['quantity'] ?? '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName - Détails'),
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
    final sheetName = _sanitizeSheetTitle('Truck Tracking');
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
      'Saved At',
      'Action',
      'Local ID',
      'Report Date (ISO)',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
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
          savedAt,
          action,
          report.id?.toString() ?? '',
          reportDateIso,
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
      detailsSheetName: _sanitizeSheetTitle('$sheetName - Détails'),
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
    final sheetName = _sanitizeSheetTitle('Machines & Engins arrêtés');
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
      'Saved At',
      'Action',
      'Local ID',
      'Report Date (ISO)',
      'Equipment Type',
      'Reason',
    ];

    final detailsRows = <List<Object?>>[];
    for (final entry in equipmentList) {
      detailsRows.add([
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
        entry['equipmentType'] ?? '',
        entry['Reason'] ?? '',
      ]);
    }

    return _ReportPayload(
      sheetName: sheetName,
      headers: headers,
      row: row,
      detailsSheetName: _sanitizeSheetTitle('$sheetName - Détails'),
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
    final sheetName = _sanitizeSheetTitle('R0 Reports');
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
      'Saved At',
      'Action',
      'Local ID',
      'Report Date (ISO)',
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
        savedAt,
        action,
        report.id?.toString() ?? '',
        reportDateIso,
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
        'Saved At',
        'Action',
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

enum _ReportCategory {
  activityTnb,
  dailyTsud,
  truckTracking,
  machinesStopped,
  r0,
  generic,
}

const List<String> _baseHeaders = [
  'Saved At',
  'Action',
  'Local ID',
  'Firestore ID',
  'Type',
  'Group',
  'Report Date (ISO)',
  'Report Date (Local)',
  'Report Time (Local)',
  'Description',
];

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
