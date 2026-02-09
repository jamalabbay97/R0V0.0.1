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
            const String.fromEnvironment(
                '1WzdE8fl3BwatmMXw1mcIAebOndx41XvXWdahP7nEaVo'),
        _credentialsJson = credentialsJson ??
            const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_JSON'),
        _credentialsAssetPath = credentialsAssetPath ??
            const String.fromEnvironment('GOOGLE_SHEETS_CREDENTIALS_ASSET'),
        _nowProvider = nowProvider ?? DateTime.now;

  static const String _reportsSheet = 'Reports';
  static const String _detailsSheet = 'Report Details';
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
    if (_spreadsheetId.isEmpty) {
      debugPrint(
        'Google Sheets sync skipped: GOOGLE_SHEETS_SPREADSHEET_ID is missing.',
      );
      return;
    }

    final api = await _getSheetsApi();
    if (api == null) {
      return;
    }

    await _ensureSheetWithHeaders(api, _reportsSheet, const [
      'Saved At',
      'Action',
      'Local ID',
      'Firestore ID',
      'Type',
      'Group',
      'Report Date',
      'Description',
      'Additional Data (JSON)',
    ]);

    await _ensureSheetWithHeaders(api, _detailsSheet, const [
      'Saved At',
      'Action',
      'Local ID',
      'Firestore ID',
      'Type',
      'Group',
      'Report Date',
      'Field Path',
      'Value',
      'Value Type',
    ]);

    final savedAt = _nowProvider().toIso8601String();
    final reportDate = report.date.toIso8601String();
    final row = [
      savedAt,
      action,
      report.id?.toString() ?? '',
      report.firestoreId ?? '',
      report.type,
      report.group,
      reportDate,
      report.description,
      jsonEncode(report.additionalData ?? {}),
    ];

    await api.spreadsheets.values.append(
      ValueRange(values: [row]),
      _spreadsheetId,
      '$_reportsSheet!A1',
      valueInputOption: 'RAW',
      insertDataOption: 'INSERT_ROWS',
    );

    final detailsRows = _flattenAdditionalData(report.additionalData).map(
      (entry) {
        return [
          savedAt,
          action,
          report.id?.toString() ?? '',
          report.firestoreId ?? '',
          report.type,
          report.group,
          reportDate,
          entry.path,
          entry.value,
          entry.valueType,
        ];
      },
    ).toList();

    if (detailsRows.isNotEmpty) {
      await api.spreadsheets.values.append(
        ValueRange(values: detailsRows),
        _spreadsheetId,
        '$_detailsSheet!A1',
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
          value: value?.toString() ?? '',
          valueType: value == null ? 'null' : value.runtimeType.toString(),
        ),
      );
    }

    visit(data, '');
    return entries;
  }
}

class _FlattenedEntry {
  const _FlattenedEntry({
    required this.path,
    required this.value,
    required this.valueType,
  });

  final String path;
  final String value;
  final String valueType;
}
