import 'package:flutter/foundation.dart';
import 'database_helper.dart';

/// 메모 본문 배경 패턴. DB에는 `index`로 저장되므로 순서를 바꾸면
/// 기존 데이터가 다른 패턴으로 해석된다 — enum 항목 순서 변경 금지.
enum LinesGridMode { none, lines, wavyLines, grid, dotGrid }

class MathNote {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool pinned;
  final LinesGridMode linesGrid;

  const MathNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.pinned = false,
    this.linesGrid = LinesGridMode.none,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'pinned': pinned ? 1 : 0,
        'lines_grid': linesGrid.index,
      };

  factory MathNote.fromMap(Map<String, Object?> map) {
    final lgIdx = (map['lines_grid'] as int?) ?? 0;
    final lg = lgIdx >= 0 && lgIdx < LinesGridMode.values.length
        ? LinesGridMode.values[lgIdx]
        : LinesGridMode.none;
    return MathNote(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      pinned: ((map['pinned'] as int?) ?? 0) != 0,
      linesGrid: lg,
    );
  }
}

class MathNotesRepository {
  static final MathNotesRepository instance = MathNotesRepository._();
  MathNotesRepository._();

  static const String _table = 'math_notes';

  Future<int> insert({
    required String title,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
    bool pinned = false,
    LinesGridMode linesGrid = LinesGridMode.none,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert(_table, {
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'pinned': pinned ? 1 : 0,
      'lines_grid': linesGrid.index,
    });
    debugPrint(
        '[math-notes] db insert id=$id pinned=$pinned linesGrid=${linesGrid.name}');
    return id;
  }

  Future<int> update(MathNote note) async {
    final db = await DatabaseHelper.instance.database;
    final n = await db.update(
      _table,
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    debugPrint('[math-notes] db update id=${note.id} → $n row(s)');
    return n;
  }

  Future<int> deleteById(int id) async {
    final db = await DatabaseHelper.instance.database;
    final n = await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    debugPrint('[math-notes] db delete id=$id → $n row(s)');
    return n;
  }

  Future<int> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) return 0;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final n = await db.delete(
      _table,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    debugPrint('[math-notes] db delete ids=$ids → $n row(s)');
    return n;
  }

  Future<List<MathNote>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(_table, orderBy: 'updated_at DESC');
    debugPrint('[math-notes] db getAll → ${maps.length} row(s)');
    return maps.map(MathNote.fromMap).toList();
  }
}
