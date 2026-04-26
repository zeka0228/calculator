import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// 앱 전역 sqflite DB 싱글톤. 버전을 올릴 때마다 `_onUpgrade`에 누적 마이그레이션을 추가한다.
/// 신규 설치는 `_onCreate` 한 번에 최신 스키마로 만들어진다.
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
      version: 5,
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
        created_at INTEGER NOT NULL,
        mode TEXT NOT NULL DEFAULT 'basic',
        metadata TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_history_created_at ON history(created_at)',
    );
    await _createMathNotesTable(db);
    await _createSettingsTable(db);
  }

  // 기존 사용자의 DB를 단계적으로 새 스키마로 끌어올린다.
  // 각 if 블록은 독립적으로, 낮은 버전부터 차례로 모두 적용되도록 작성한다.
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
    if (oldVersion < 5) {
      // history는 계산기/변환기 양쪽이 같은 테이블을 쓰므로 mode로 구분.
      // 변환 항목은 metadata에 카테고리/단위 인덱스 등이 JSON으로 들어간다.
      await db.execute(
        "ALTER TABLE history ADD COLUMN mode TEXT NOT NULL DEFAULT 'basic'",
      );
      await db.execute('ALTER TABLE history ADD COLUMN metadata TEXT');
      debugPrint('[db] history: added mode + metadata columns');
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
