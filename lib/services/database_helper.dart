import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:r0/models/report.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

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
      version: 2, // Incremented to add firestore_id column
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add firestore_id column for existing databases
      await db.execute('ALTER TABLE reports ADD COLUMN firestore_id TEXT');
    }
  }

  Future<int> insertReport(Report report) async {
    final db = await database;
    return await db.insert('reports', report.toMap());
  }

  Future<List<Report>> getReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reports');
    return List.generate(maps.length, (i) => Report.fromMap(maps[i]));
  }

  Future<List<Report>> getReportsByType(String type) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reports',
      where: 'type = ?',
      whereArgs: [type],
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
    return await db.update(
      'reports',
      report.toMap(),
      where: 'id = ?',
      whereArgs: [report.id],
    );
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