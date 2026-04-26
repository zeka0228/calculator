import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// 앱 전역 키-값 설정 저장소 (settings 테이블 사용).
/// 메모 배경 모드 같이 컬럼을 따로 만들 정도가 아닌 작은 환경설정용.
class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  static const String _table = 'settings';

  Future<String?> get(String key) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query(
      _table,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      _table,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('[settings] $key = "$value"');
  }
}
