import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:r0/models/report.dart';
import 'package:r0/services/google_sheets_service.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  final GoogleSheetsService _sheetsService = GoogleSheetsService();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'R0.db');
    return await openDatabase(
      path,
      version: 3, // Incremented to add indexes for performance
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
        additional_data TEXT
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

  Future<int> insertReport(Report report) async {
    final db = await database;
    final id = await db.insert('reports', report.toMap());
    await _recordSheetsSnapshot(report.copyWith(id: id), 'create');
    return id;
  }

  Future<List<Report>> getReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<List<Report>> getReportsPage({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<List<Report>> getReportsByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<Report?> getReport(int id) async {
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
    final db = await database;
    final updated = await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
    await _recordSheetsSnapshot(report, 'update');
    return updated;
  }

  Future<void> _recordSheetsSnapshot(Report report, String action) async {
    try {
      await _sheetsService.recordReportSnapshot(report, action: action);
    } catch (e) {
      // Avoid blocking local persistence if Sheets sync fails.
    }
  }

  Future<int> deleteReport(int id) async {
    final db = await database;
    return await db.delete(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
