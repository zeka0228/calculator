import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/math_notes_repository.dart';
import 'new_math_note_screen.dart';

export '../data/math_notes_repository.dart' show MathNote;

enum MathNotesSortOrder {
  dateModifiedDesc,
  dateModifiedAsc,
  dateCreatedDesc,
  dateCreatedAsc,
  titleAsc,
}

class MathNotesController extends ChangeNotifier {
  final List<MathNote> _notes = [];
  MathNotesSortOrder _sortOrder = MathNotesSortOrder.dateModifiedDesc;
  bool _groupByDate = false;
  bool _selectionMode = false;
  final Set<int> _selected = {};
  bool _loaded = false;

  List<MathNote> get notes => List.unmodifiable(_notes);
  int get count => _notes.length;
  MathNotesSortOrder get sortOrder => _sortOrder;
  bool get groupByDate => _groupByDate;
  bool get selectionMode => _selectionMode;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final loaded = await MathNotesRepository.instance.getAll();
    _notes
      ..clear()
      ..addAll(loaded);
    _loaded = true;
    debugPrint('[math-notes] loaded ${loaded.length} note(s) from DB');
    notifyListeners();
  }

  Future<int> addNote({
    required String title,
    required String content,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.now();
    final id = await MathNotesRepository.instance.insert(
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    _notes.add(MathNote(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    ));
    _sortByUpdatedDesc();
    debugPrint(
        '[math-notes] created id=$id title="$title" chars=${content.length}');
    notifyListeners();
    return id;
  }

  void _sortByUpdatedDesc() {
    _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<bool> updateNote({
    required int id,
    required String title,
    required String content,
  }) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      debugPrint('[math-notes] update SKIPPED (not found) id=$id');
      return false;
    }
    final old = _notes[index];
    if (old.title == title && old.content == content) {
      return false;
    }
    final updated = MathNote(
      id: old.id,
      title: title,
      content: content,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    await MathNotesRepository.instance.update(updated);
    _notes[index] = updated;
    _sortByUpdatedDesc();
    debugPrint(
        '[math-notes] updated id=$id title="$title" chars=${content.length}');
    notifyListeners();
    return true;
  }

  Future<bool> deleteNote(int id) async {
    final index = _notes.indexWhere((n) => n.id == id);
    if (index == -1) {
      debugPrint('[math-notes] delete SKIPPED (not found) id=$id');
      return false;
    }
    final removed = _notes.removeAt(index);
    _selected.remove(id);
    await MathNotesRepository.instance.deleteById(id);
    debugPrint('[math-notes] deleted id=$id title="${removed.title}"');
    notifyListeners();
    return true;
  }

  Future<void> seedDummyDataIfMissing() async {
    if (!_loaded) await load();
    final existingTitles = _notes.map((n) => n.title).toSet();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final rng = math.Random();
    DateTime atRandomTime(DateTime day) => day.add(Duration(
          hours: rng.nextInt(24),
          minutes: rng.nextInt(60),
        ));
    final samples = [
      ('점메추', atRandomTime(today.subtract(const Duration(days: 1)))),
      ('저메추', atRandomTime(today.subtract(const Duration(days: 7)))),
      ('여긴어디나는누구', atRandomTime(today.subtract(const Duration(days: 30)))),
    ];
    var seeded = 0;
    for (final (title, at) in samples) {
      if (existingTitles.contains(title)) continue;
      await addNote(title: title, content: '', createdAt: at);
      seeded++;
    }
    if (seeded > 0) {
      debugPrint('[math-notes] seeded $seeded dummy note(s)');
    } else {
      debugPrint('[math-notes] dummy seed skipped (all titles present)');
    }
  }

  Future<int> deleteSelected() async {
    if (_selected.isEmpty) {
      _selectionMode = false;
      notifyListeners();
      return 0;
    }
    final ids = _selected.toList();
    final n = await MathNotesRepository.instance.deleteByIds(ids);
    final idSet = ids.toSet();
    _notes.removeWhere((note) => idSet.contains(note.id));
    _selected.clear();
    _selectionMode = false;
    debugPrint('[math-notes] deleted via selection ids=$ids removed=$n');
    notifyListeners();
    return n;
  }

  void enterSelectionMode() {
    if (_selectionMode) return;
    _selectionMode = true;
    _selected.clear();
    notifyListeners();
  }

  void exitSelectionMode() {
    if (!_selectionMode) return;
    _selectionMode = false;
    _selected.clear();
    notifyListeners();
  }

  void toggleSelected(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    notifyListeners();
  }

  void setSortOrder(MathNotesSortOrder order) {
    if (_sortOrder == order) return;
    _sortOrder = order;
    notifyListeners();
  }

  void toggleGroupByDate() {
    _groupByDate = !_groupByDate;
    notifyListeners();
  }
}

class MathNotesScreen extends StatelessWidget {
  final MathNotesController controller;
  final ValueChanged<int>? onSwitchMode;
  const MathNotesScreen({
    super.key,
    required this.controller,
    this.onSwitchMode,
  });

  void _onCreateNote(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMathNoteScreen(
          controller: controller,
          onSwitchMode: onSwitchMode,
        ),
      ),
    );
  }

  void _onOpenNote(BuildContext context, MathNote note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMathNoteScreen(
          controller: controller,
          onSwitchMode: onSwitchMode,
          existingNote: note,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final rows = _buildRows(controller.notes, controller.groupByDate);
        return Column(
          children: [
            Expanded(
              child: controller.count == 0
                  ? const Center(
                      child: Text(
                        '메모가 없습니다',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        final grouped = controller.groupByDate;
                        if (row is _HeaderRow) {
                          return _buildGroupHeader(row.label,
                              isFirst: index == 0);
                        }
                        final note = (row as _ItemRow).note;
                        final showTopDivider =
                            index > 0 && rows[index - 1] is _ItemRow;
                        return Column(
                          children: [
                            if (showTopDivider)
                              Divider(
                                color: Colors.grey[850],
                                height: 1,
                                indent: grouped ? 24 : 0,
                              ),
                            _buildNoteTile(context, note,
                                indented: grouped),
                          ],
                        );
                      },
                    ),
            ),
            _buildBottomBar(context),
          ],
        );
      },
    );
  }

  Widget _buildGroupHeader(String label, {required bool isFirst}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(8, isFirst ? 4 : 24, 8, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildNoteTile(BuildContext context, MathNote note,
      {bool indented = false}) {
    final inSelectionMode = controller.selectionMode;
    final isSelected = controller.selected.contains(note.id);
    final preview = _firstLine(note.content);
    final subtitleStyle = TextStyle(
      color: Colors.grey[500],
      fontSize: 13,
    );
    return InkWell(
      onTap: inSelectionMode
          ? () => controller.toggleSelected(note.id)
          : () => _onOpenNote(context, note),
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 24 : 8, 14, 8, 14),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: inSelectionMode ? 36 : 0,
              child: inSelectionMode
                  ? Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.orange : Colors.grey,
                            width: 2,
                          ),
                          color: isSelected
                              ? Colors.orange
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    note.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDateTime(note.createdAt),
                        style: subtitleStyle,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preview.isEmpty ? '텍스트 없음' : preview,
                          style: subtitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstLine(String content) {
    if (content.isEmpty) return '';
    final newlineIdx = content.indexOf('\n');
    final line = newlineIdx == -1 ? content : content.substring(0, newlineIdx);
    return line.trim();
  }

  static String _formatDateTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}. ${dt.month}. ${dt.day}. ${two(dt.hour)}:${two(dt.minute)}';
  }

  static String _groupLabelFor(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final whenDay = DateTime(when.year, when.month, when.day);
    final daysDiff = today.difference(whenDay).inDays;
    if (daysDiff <= 0) return '오늘';
    if (daysDiff == 1) return '어제';
    if (daysDiff <= 7) return '최근 7일';
    if (daysDiff <= 30) return '최근 30일';
    return '이전';
  }

  static List<_NoteRow> _buildRows(List<MathNote> notes, bool grouped) {
    if (!grouped) {
      return [for (final n in notes) _ItemRow(n)];
    }
    const order = ['오늘', '어제', '최근 7일', '최근 30일', '이전'];
    final groups = <String, List<MathNote>>{};
    for (final n in notes) {
      final label = _groupLabelFor(n.updatedAt);
      groups.putIfAbsent(label, () => []).add(n);
    }
    final rows = <_NoteRow>[];
    for (final label in order) {
      final list = groups[label];
      if (list == null || list.isEmpty) continue;
      rows.add(_HeaderRow(label));
      rows.addAll(list.map(_ItemRow.new));
    }
    return rows;
  }

  Widget _buildBottomBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[400], size: 20),
                  const SizedBox(width: 6),
                  Text(
                    '검색',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(
              CupertinoIcons.square_pencil,
              color: Colors.orange,
              size: 30,
            ),
            onPressed: () => _onCreateNote(context),
          ),
        ],
      ),
    );
  }
}

sealed class _NoteRow {}

class _HeaderRow extends _NoteRow {
  final String label;
  _HeaderRow(this.label);
}

class _ItemRow extends _NoteRow {
  final MathNote note;
  _ItemRow(this.note);
}
