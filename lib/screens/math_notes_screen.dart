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
    debugPrint(
        '[math-notes] created id=$id title="$title" chars=${content.length}');
    notifyListeners();
    return id;
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
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount: controller.notes.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Colors.grey[850], height: 1),
                      itemBuilder: (context, index) {
                        final note = controller.notes[index];
                        final inSelectionMode = controller.selectionMode;
                        final isSelected =
                            controller.selected.contains(note.id);
                        return InkWell(
                          onTap: inSelectionMode
                              ? () => controller.toggleSelected(note.id)
                              : () => _onOpenNote(context, note),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 8),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 180),
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
                                                color: isSelected
                                                    ? Colors.orange
                                                    : Colors.grey,
                                                width: 2,
                                              ),
                                              color: isSelected
                                                  ? Colors.orange
                                                  : Colors.transparent,
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check,
                                                    size: 16,
                                                    color: Colors.white)
                                                : null,
                                          ),
                                        )
                                      : null,
                                ),
                                Expanded(
                                  child: Text(
                                    note.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
