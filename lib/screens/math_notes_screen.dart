import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'new_math_note_screen.dart';

enum MathNotesSortOrder {
  dateModifiedDesc,
  dateModifiedAsc,
  dateCreatedDesc,
  dateCreatedAsc,
  titleAsc,
}

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
}

class MathNotesController extends ChangeNotifier {
  final List<MathNote> _notes = [];
  MathNotesSortOrder _sortOrder = MathNotesSortOrder.dateModifiedDesc;
  bool _groupByDate = false;
  bool _selectionMode = false;
  final Set<int> _selected = {};
  int _nextId = 1;

  List<MathNote> get notes => List.unmodifiable(_notes);
  int get count => _notes.length;
  MathNotesSortOrder get sortOrder => _sortOrder;
  bool get groupByDate => _groupByDate;
  bool get selectionMode => _selectionMode;
  Set<int> get selected => Set.unmodifiable(_selected);

  int addNote({
    required String title,
    required String content,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.now();
    final id = _nextId++;
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      itemCount: controller.notes.length,
                      itemBuilder: (context, index) {
                        final note = controller.notes[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            note.title,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 16),
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
