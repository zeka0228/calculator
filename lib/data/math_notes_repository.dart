import 'package:flutter/foundation.dart';
import 'database_helper.dart';

class MathNote {
  final int id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MathNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory MathNote.fromMap(Map<String, Object?> map) => MathNote(
        id: map['id'] as int,
        title: map['title'] as String,
        content: map['content'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      );
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
  }) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert(_table, {
      'title': title,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    });
    debugPrint('[math-notes] db insert id=$id');
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
