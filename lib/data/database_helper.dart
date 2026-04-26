import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('calculator.db');
    return _database!;
  }

  Future<Database> _initDB(String filename) async {
    final String path;
    if (kIsWeb) {
      path = filename;
    } else {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filename);
    }
    debugPrint('[db] opening: $path');
    final db = await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    debugPrint('[db] opened (version=${await db.getVersion()})');
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[db] onCreate version=$version — creating tables');
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expression TEXT NOT NULL,
        result TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_history_created_at ON history(created_at)',
    );
    await _createMathNotesTable(db);
    await _createSettingsTable(db);
  }

  Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    debugPrint('[db] onUpgrade $oldVersion → $newVersion');
    if (oldVersion < 2) {
      await _createMathNotesTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE math_notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0',
      );
      debugPrint('[db] math_notes: added pinned column');
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE math_notes ADD COLUMN lines_grid INTEGER NOT NULL DEFAULT 0',
      );
      debugPrint('[db] math_notes: added lines_grid column');
      await _createSettingsTable(db);
    }
  }

  Future<void> _createMathNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE math_notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        pinned INTEGER NOT NULL DEFAULT 0,
        lines_grid INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_math_notes_updated_at ON math_notes(updated_at)',
    );
    debugPrint('[db] created math_notes table + index');
  }

  Future<void> _createSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    debugPrint('[db] created settings table');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
