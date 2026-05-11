import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:r0/domain/models/report.dart';
import 'package:r0/data/services/google_sheets_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();
  static const String _webReportsKey = 'reports_web_storage';
  static const String _webNextIdKey = 'reports_web_next_id';
  static final List<Map<String, dynamic>> _webMemoryReports =
      <Map<String, dynamic>>[];
  static int _webMemoryNextId = 1;
  static bool _webPersistenceUnavailable = false;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite database access is not available on web. '
        'Use DatabaseHelper CRUD methods instead.',
      );
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'R0.db');
    return await openDatabase(
      path,
      version: 4, // Incremented to add indexes for performance
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reports(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firestore_id TEXT,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        group_name TEXT NOT NULL,
        type TEXT NOT NULL,
        additional_data TEXT,
        sheets_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add firestore_id column for existing databases
      await db.execute('ALTER TABLE reports ADD COLUMN firestore_id TEXT');
    }
    if (oldVersion < 3) {
      await _createIndexes(db);
    }
    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE reports ADD COLUMN sheets_synced INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reports_firestore_id ON reports(firestore_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reports_type ON reports(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reports_date ON reports(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_reports_group ON reports(group_name)',
    );
  }

  static const String _reportsOrderBy =
      "date DESC, CASE group_name WHEN '3ème' THEN 1 WHEN '1er' THEN 2 WHEN '2ème' THEN 3 ELSE 4 END ASC";

  Future<int> insertReport(Report report) async {
    if (kIsWeb) {
      return _insertWebReport(report);
    }
    final db = await database;
    final id = await db.insert('reports', report.toMap());
    return id;
  }

  Future<List<Report>> getReports() async {
    if (kIsWeb) {
      return _getWebReports();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      orderBy: _reportsOrderBy,
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<List<Report>> getReportsPage({
    int limit = 50,
    int offset = 0,
  }) async {
    if (kIsWeb) {
      final reports = await _getWebReports();
      if (offset >= reports.length) {
        return <Report>[];
      }
      final end =
          (offset + limit) > reports.length ? reports.length : offset + limit;
      return reports.sublist(offset, end);
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      orderBy: _reportsOrderBy,
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<List<Report>> getReportsByType(String type) async {
    if (kIsWeb) {
      final reports = await _getWebReports();
      return reports.where((report) => report.type == type).toList();
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: _reportsOrderBy,
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<Report?> getReport(int id) async {
    if (kIsWeb) {
      final reports = await _getWebReports();
      for (final report in reports) {
        if (report.id == id) {
          return report;
        }
      }
      return null;
    }
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Report.fromMap(maps.first);
  }

  Future<int> updateReport(Report report) async {
    if (kIsWeb) {
      return _updateWebReport(report);
    }
    final db = await database;
    final updated = await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
    return updated;
  }

  Future<void> sendReportToSheets(Report report) async {
    final sent = await _sheetsService.recordReportSnapshot(
      report,
      action: 'explicit_submit',
    );

    if (!sent) {
      throw Exception('Failed to save report to Google Sheets');
    }

    if (kIsWeb) {
      await updateReport(report.copyWith(isSentToSheets: true));
      return;
    }

    final db = await database;
    await db.update(
      'reports',
      report.copyWith(isSentToSheets: true).toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
  }

  Future<int> deleteReport(int id) async {
    if (kIsWeb) {
      final prefs = await _getWebPrefsSafely();
      final storedMaps = await _readWebReportMaps(prefs);
      final initialLength = storedMaps.length;
      storedMaps.removeWhere((map) => map['id'] == id);
      await _writeWebReportMaps(prefs, storedMaps);
      if (_webMemoryNextId <= id) {
        _webMemoryNextId = id + 1;
      }
      return initialLength - storedMaps.length;
    }
    final db = await database;
    return await db.delete(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    if (kIsWeb) {
      return;
    }
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<int> _insertWebReport(Report report) async {
    final prefs = await _getWebPrefsSafely();
    final storedMaps = await _readWebReportMaps(prefs);
    final nextId = _readWebNextId(prefs);
    final reportWithId = report.copyWith(id: nextId);
    storedMaps.add(reportWithId.toMap());
    await _writeWebReportMaps(prefs, storedMaps);
    await _writeWebNextId(prefs, nextId + 1);
    return nextId;
  }

  Future<List<Report>> _getWebReports() async {
    final prefs = await _getWebPrefsSafely();
    final storedMaps = await _readWebReportMaps(prefs);
    final reports = storedMaps.map(Report.fromMap).toList();
    reports.sort(_compareReports);
    return reports;
  }

  Future<int> _updateWebReport(Report report) async {
    if (report.id == null) {
      throw ArgumentError('Cannot update report without an id.');
    }

    final prefs = await _getWebPrefsSafely();
    final storedMaps = await _readWebReportMaps(prefs);
    final index = storedMaps.indexWhere((map) => map['id'] == report.id);

    if (index == -1) {
      return 0;
    }

    storedMaps[index] = report.toMap();
    await _writeWebReportMaps(prefs, storedMaps);
    return 1;
  }

  Future<List<Map<String, dynamic>>> _readWebReportMaps(
    SharedPreferences? prefs,
  ) {
    if (prefs == null || _webPersistenceUnavailable) {
      return Future.value(
        _webMemoryReports
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    }

    final jsonString = prefs.getString(_webReportsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return Future.value(<Map<String, dynamic>>[]);
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return Future.value(<Map<String, dynamic>>[]);
      }

      return Future.value(
        decoded.map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      );
    } catch (_) {
      // Some older mobile browsers/WebViews may leave partially written values.
      // Falling back avoids breaking report reads and subsequent writes.
      _webPersistenceUnavailable = true;
      return Future.value(
        _webMemoryReports
            .map((item) => Map<String, dynamic>.from(item))
            .toList(),
      );
    }
  }

  Future<void> _writeWebReportMaps(
    SharedPreferences? prefs,
    List<Map<String, dynamic>> reports,
  ) async {
    if (prefs == null || _webPersistenceUnavailable) {
      _webMemoryReports
        ..clear()
        ..addAll(reports.map((item) => Map<String, dynamic>.from(item)));
      if (reports.isNotEmpty) {
        final maxId = reports
            .map((item) => item['id'])
            .whereType<int>()
            .fold<int>(0, (previous, id) => id > previous ? id : previous);
        _webMemoryNextId = maxId + 1;
      }
      return;
    }

    try {
      await prefs.setString(_webReportsKey, jsonEncode(reports));
    } catch (_) {
      _webPersistenceUnavailable = true;
      _webMemoryReports
        ..clear()
        ..addAll(reports.map((item) => Map<String, dynamic>.from(item)));
    }
  }

  Future<SharedPreferences?> _getWebPrefsSafely() async {
    if (_webPersistenceUnavailable) {
      return null;
    }
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      _webPersistenceUnavailable = true;
      return null;
    }
  }

  int _readWebNextId(SharedPreferences? prefs) {
    if (prefs == null || _webPersistenceUnavailable) {
      return _webMemoryNextId;
    }
    return prefs.getInt(_webNextIdKey) ?? _webMemoryNextId;
  }

  Future<void> _writeWebNextId(SharedPreferences? prefs, int nextId) async {
    _webMemoryNextId = nextId;
    if (prefs == null || _webPersistenceUnavailable) {
      return;
    }
    try {
      await prefs.setInt(_webNextIdKey, nextId);
    } catch (_) {
      _webPersistenceUnavailable = true;
    }
  }

  int _compareReports(Report a, Report b) {
    final dateComparison = b.date.compareTo(a.date);
    if (dateComparison != 0) {
      return dateComparison;
    }

    final groupOrder = <String, int>{
      '3ème': 1,
      '1er': 2,
      '2ème': 3,
    };

    return (groupOrder[a.group] ?? 4).compareTo(groupOrder[b.group] ?? 4);
  }
}
