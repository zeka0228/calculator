import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// 계산 기록 한 건. 기본/공학용 계산 결과와 변환 결과를 같은 테이블에서 다룬다.
/// - mode: 'basic' / 'scientific' / 'converter' — 탭 시 어느 모드로 복원할지 결정
/// - metadata: 변환 항목의 카테고리·단위 인덱스·source 값을 JSON으로 보관
class CalcHistoryEntry {
  final int? id;
  final String expression;
  final String result;
  final DateTime createdAt;
  final String mode;
  final String? metadata;

  CalcHistoryEntry({
    this.id,
    required this.expression,
    required this.result,
    required this.createdAt,
    this.mode = 'basic',
    this.metadata,
  });

  Map<String, dynamic> toMap() => {
        'expression': expression,
        'result': result,
        'created_at': createdAt.millisecondsSinceEpoch,
        'mode': mode,
        'metadata': metadata,
      };

  factory CalcHistoryEntry.fromMap(Map<String, dynamic> map) =>
      CalcHistoryEntry(
        id: map['id'] as int?,
        expression: map['expression'] as String,
        result: map['result'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        mode: (map['mode'] as String?) ?? 'basic',
        metadata: map['metadata'] as String?,
      );
}

class CalcHistoryRepository {
  static final CalcHistoryRepository instance = CalcHistoryRepository._();
  CalcHistoryRepository._();

  Future<int> insert(
    String expression,
    String result, {
    String mode = 'basic',
    String? metadata,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final entry = CalcHistoryEntry(
      expression: expression,
      result: result,
      createdAt: DateTime.now(),
      mode: mode,
      metadata: metadata,
    );
    return await db.insert('history', entry.toMap());
  }

  Future<List<CalcHistoryEntry>> getRecent({int days = 7}) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final maps = await db.query(
      'history',
      where: 'created_at >= ?',
      whereArgs: [cutoff],
      orderBy: 'created_at DESC',
    );
    debugPrint('[history] getRecent(days=$days) → ${maps.length} rows');
    return maps.map(CalcHistoryEntry.fromMap).toList();
  }

  Future<int> deleteOlderThan({int days = 7}) async {
    final db = await DatabaseHelper.instance.database;
    final cutoff = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;
    final n = await db.delete(
      'history',
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );
    debugPrint('[history] pruned $n row(s) older than $days day(s)');
    return n;
  }

  Future<int> deleteAll() async {
    final db = await DatabaseHelper.instance.database;
    final n = await db.delete('history');
    debugPrint('[history] deleteAll → $n row(s)');
    return n;
  }

  Future<int> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) {
      debugPrint('[history] deleteByIds: empty list, skipped');
      return 0;
    }
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final n = await db.delete(
      'history',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    debugPrint('[history] deleteByIds=$ids → $n row(s)');
    return n;
  }
}
