import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/memo_math_eval.dart';
import '../widgets/calc_mode_icon.dart';
import 'math_notes_screen.dart';

enum NoteBackground { dark, light }
enum FormulaResultMode { insert, suggest, off }
enum AttachmentSizeMode { small, large }
enum LinesGridMode { none, lines, wavyLines, grid, dotGrid }

class _LinesGridPainter extends CustomPainter {
  final LinesGridMode mode;
  final Color color;
  final double spacing;

  _LinesGridPainter({
    required this.mode,
    required this.color,
    required this.spacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == LinesGridMode.none) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    switch (mode) {
      case LinesGridMode.none:
        return;
      case LinesGridMode.lines:
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        break;
      case LinesGridMode.wavyLines:
        final waveLen = spacing * 0.7;
        final amp = spacing * 0.12;
        for (double y = spacing; y < size.height; y += spacing) {
          final path = Path()..moveTo(0, y);
          for (double x = 0; x <= size.width; x += 2) {
            final yOff = math.sin(x / waveLen * 2 * math.pi) * amp;
            path.lineTo(x, y + yOff);
          }
          canvas.drawPath(path, paint);
        }
        break;
      case LinesGridMode.grid:
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
        }
        for (double x = spacing; x < size.width; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
        }
        break;
      case LinesGridMode.dotGrid:
        final dotPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        final dotR = math.max(1.0, spacing * 0.06);
        for (double y = spacing; y < size.height; y += spacing) {
          for (double x = spacing; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), dotR, dotPaint);
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LinesGridPainter old) =>
      old.mode != mode || old.color != color || old.spacing != spacing;
}

class NewMathNoteScreen extends StatefulWidget {
  final MathNotesController controller;
  final ValueChanged<int>? onSwitchMode;
  final MathNote? existingNote;

  const NewMathNoteScreen({
    super.key,
    required this.controller,
    this.onSwitchMode,
    this.existingNote,
  });

  @override
  State<NewMathNoteScreen> createState() => _NewMathNoteScreenState();
}

class _NewMathNoteScreenState extends State<NewMathNoteScreen> {
  final _PreviewTextEditingController _textController =
      _PreviewTextEditingController();
  final UndoHistoryController _undoController = UndoHistoryController();
  final FocusNode _focusNode = FocusNode();
  String _lastText = '';
  String? _activePreview;

  bool _pinned = false;
  NoteBackground _background = NoteBackground.dark;
  FormulaResultMode _formulaResult = FormulaResultMode.off;
  AttachmentSizeMode _attachmentSize = AttachmentSizeMode.small;
  LinesGridMode _linesGrid = LinesGridMode.none;

  static const int _modeMathNotes = 2;

  static const List<String> _modeLabels = ['기본', '공학용', '수학 메모'];
  static const List<IconData> _modeIcons = [
    CupertinoIcons.divide,
    CupertinoIcons.function,
    CupertinoIcons.pencil_outline,
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingNote;
    if (existing != null) {
      final initialText = existing.content.isEmpty
          ? existing.title
          : '${existing.title}\n${existing.content}';
      _textController.value = TextEditingValue(
        text: initialText,
        selection: TextSelection.collapsed(offset: initialText.length),
      );
    }
    _lastText = _textController.text;
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _undoController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final newText = _textController.text;
    final cursor = _textController.selection.baseOffset;

    if (_activePreview != null &&
        newText.length == _lastText.length + 1 &&
        cursor > 0 &&
        newText[cursor - 1] == '\n') {
      _acceptPreview(newlinePos: cursor - 1);
      return;
    }

    _lastText = newText;
    _updatePreview();
    if (mounted) setState(() {});
  }

  void _updatePreview() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    String? preview;
    if (cursor >= 0 && cursor <= text.length) {
      final lineStart =
          cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
      var lineEnd = text.indexOf('\n', cursor);
      if (lineEnd == -1) lineEnd = text.length;
      final currentLine = text.substring(lineStart, lineEnd);
      preview = evaluateMemoExpression(currentLine);
    }
    _activePreview = preview;
    _textController.setPreview(preview);
  }

  String _missingCloseParens(String text, int lineStart, int lineEnd) {
    final line = text.substring(lineStart, lineEnd);
    final open = '('.allMatches(line).length;
    final close = ')'.allMatches(line).length;
    return open > close ? ')' * (open - close) : '';
  }

  void _acceptPreview({required int newlinePos}) {
    final preview = _activePreview;
    if (preview == null) return;
    final text = _textController.text;
    final lineStart =
        newlinePos == 0 ? 0 : text.lastIndexOf('\n', newlinePos - 1) + 1;
    final closing = _missingCloseParens(text, lineStart, newlinePos);
    final accepted = '$closing = $preview';
    final newText = text.substring(0, newlinePos) +
        accepted +
        text.substring(newlinePos + 1);
    final newCursor = newlinePos + accepted.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _lastText = newText;
    _activePreview = null;
    _textController.setPreview(null);
    debugPrint('[math-notes] preview accepted "$preview" closing="$closing"');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.tab) {
      return KeyEventResult.ignored;
    }
    final preview = _activePreview;
    if (preview == null) return KeyEventResult.ignored;
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0) return KeyEventResult.ignored;
    final lineStart =
        cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd == -1) lineEnd = text.length;
    final closing = _missingCloseParens(text, lineStart, lineEnd);
    final accepted = '$closing = $preview';
    final newText =
        text.substring(0, lineEnd) + accepted + text.substring(lineEnd);
    final newCursor = lineEnd + accepted.length;
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    _lastText = newText;
    _activePreview = null;
    _textController.setPreview(null);
    debugPrint(
        '[math-notes] preview accepted via tab "$preview" closing="$closing"');
    return KeyEventResult.handled;
  }

  bool get _isEmpty => _textController.text.trim().isEmpty;
  bool get _isLight => _background == NoteBackground.light;
  Color get _bgColor => _isLight ? Colors.white : Colors.black;
  Color get _fgColor => _isLight ? Colors.black : Colors.white;
  Color get _hintColor =>
      _isLight ? Colors.grey.shade500 : Colors.grey.shade600;

  Future<void> _saveCurrentNote() async {
    final text = _textController.text;
    final existing = widget.existingNote;
    if (text.trim().isEmpty && existing == null) return;
    final firstNewline = text.indexOf('\n');
    final rawTitle =
        (firstNewline == -1 ? text : text.substring(0, firstNewline)).trim();
    final body = firstNewline == -1 ? '' : text.substring(firstNewline + 1);
    final title = rawTitle.isEmpty ? '제목 없음' : rawTitle;
    if (existing != null) {
      await widget.controller.updateNote(
        id: existing.id,
        title: title,
        content: body,
      );
    } else {
      await widget.controller.addNote(
        title: title,
        content: body,
      );
    }
  }

  Future<void> _saveAndExit() async {
    await _saveCurrentNote();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _saveAndSwitchMode(int modeIndex) async {
    await _saveCurrentNote();
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSwitchMode?.call(modeIndex);
  }

  Future<void> _discardAndExit() async {
    final existing = widget.existingNote;
    if (existing != null) {
      await widget.controller.deleteNote(existing.id);
    } else {
      debugPrint(
          '[math-notes] draft discarded chars=${_textController.text.length}');
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openOtherNote(MathNote target) async {
    if (widget.existingNote?.id == target.id) return;
    await _saveCurrentNote();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => NewMathNoteScreen(
          controller: widget.controller,
          onSwitchMode: widget.onSwitchMode,
          existingNote: target,
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'pin':
        setState(() => _pinned = !_pinned);
        break;
      case 'find_in_note':
        break;
      case 'recent':
        await _showRecentNotesSheet();
        break;
      case 'formula_result':
        await _showFormulaResultPicker();
        break;
      case 'lines_grid':
      case 'lines_grid_create':
        await _showLinesGridPicker();
        break;
      case 'attachments':
        await _showAttachmentSizePicker();
        break;
      case 'background':
        setState(() {
          _background = _isLight ? NoteBackground.dark : NoteBackground.light;
        });
        break;
      case 'delete':
        await _discardAndExit();
        break;
    }
  }

  Future<void> _showFormulaResultPicker() async {
    final result = await showCupertinoModalPopup<FormulaResultMode>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('수식 결과'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _formulaResult == FormulaResultMode.insert,
            onPressed: () =>
                Navigator.pop(context, FormulaResultMode.insert),
            child: const Text('결과 삽입'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _formulaResult == FormulaResultMode.suggest,
            onPressed: () =>
                Navigator.pop(context, FormulaResultMode.suggest),
            child: const Text('결과 제안'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _formulaResult == FormulaResultMode.off,
            onPressed: () => Navigator.pop(context, FormulaResultMode.off),
            child: const Text('끔'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _formulaResult = result);
    }
  }

  Future<void> _showLinesGridPicker() async {
    const options = <(LinesGridMode, String)>[
      (LinesGridMode.none, '없음'),
      (LinesGridMode.lines, '직선 줄'),
      (LinesGridMode.wavyLines, '구불 줄'),
      (LinesGridMode.grid, '격자'),
      (LinesGridMode.dotGrid, '점 격자'),
    ];

    final result = await showModalBottomSheet<LinesGridMode>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 12, 8, 16),
                  child: Text(
                    '줄 및 격자',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    for (final (mode, label) in options)
                      _PatternTile(
                        mode: mode,
                        label: label,
                        selected: _linesGrid == mode,
                        isLight: _isLight,
                        onTap: () => Navigator.of(ctx).pop(mode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null && mounted) {
      setState(() => _linesGrid = result);
    }
  }

  Future<void> _showAttachmentSizePicker() async {
    final result = await showCupertinoModalPopup<AttachmentSizeMode>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('첨부 파일 보기'),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: _attachmentSize == AttachmentSizeMode.small,
            onPressed: () =>
                Navigator.pop(context, AttachmentSizeMode.small),
            child: const Text('모두 작게 설정'),
          ),
          CupertinoActionSheetAction(
            isDefaultAction: _attachmentSize == AttachmentSizeMode.large,
            onPressed: () =>
                Navigator.pop(context, AttachmentSizeMode.large),
            child: const Text('모두 크게 설정'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _attachmentSize = result);
    }
  }

  Future<void> _showRecentNotesSheet() async {
    final cutoff =
        DateTime.now().subtract(const Duration(days: 7));
    final recent = widget.controller.notes
        .where((n) => n.createdAt.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  alignment: Alignment.center,
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: Text(
                    '최근 메모 (지난 7일)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Text(
                      '최근 메모가 없습니다',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: recent.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: Colors.grey[850], height: 1),
                    itemBuilder: (_, i) {
                      final n = recent[i];
                      return ListTile(
                        title: Text(
                          n.title,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openOtherNote(n);
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSelectorButton() {
    return PopupMenuButton<int>(
      tooltip: '모드',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey[900],
      onSelected: (value) {
        if (value == _modeMathNotes) return;
        _saveAndSwitchMode(value);
      },
      icon: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: CalcModeIcon(
            width: 24,
            height: 30,
            color: _fgColor,
            borderWidth: 2,
          ),
        ),
      ),
      itemBuilder: (context) {
        return List.generate(_modeLabels.length, (i) {
          return PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: i == _modeMathNotes
                      ? const Icon(Icons.check,
                          size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Icon(_modeIcons[i], size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  _modeLabels[i],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildOverflowMenu() {
    return PopupMenuButton<String>(
      tooltip: '메뉴',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey[900],
      onSelected: _onMenuSelected,
      icon: SizedBox(
        width: 44,
        height: 44,
        child: Icon(Icons.more_horiz, color: _fgColor, size: 28),
      ),
      itemBuilder: (context) {
        if (_isEmpty) {
          return [
            _menuItem(
              'lines_grid_create',
              Icons.grid_on,
              '줄이나 격자 만들기',
            ),
          ];
        }
        return [
          _menuItem(
            'pin',
            _pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
            _pinned ? '메모 고정 해제' : '메모 고정',
          ),
          _menuItem('find_in_note', CupertinoIcons.search, '메모에서 찾기'),
          _menuItem('recent', Icons.history, '최근 메모'),
          _menuItem('formula_result', Icons.functions, '수식 결과'),
          _menuItem('lines_grid', Icons.grid_on, '줄 및 격자'),
          _menuItem('attachments', Icons.attach_file, '첨부 파일 보기'),
          _menuItem(
            'background',
            _isLight ? Icons.dark_mode : Icons.light_mode,
            _isLight ? '어두운 배경 사용' : '밝은 배경 사용',
          ),
          _menuItem(
            'delete',
            CupertinoIcons.trash,
            '삭제',
            textColor: Colors.red,
          ),
        ];
      },
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    Color? textColor,
  }) {
    final color = textColor ?? Colors.white;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildCheckButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.orange,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _saveAndExit,
          child: const SizedBox(
            width: 40,
            height: 40,
            child: Icon(Icons.check, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: _fgColor, size: 32),
                    onPressed: _saveAndExit,
                  ),
                  const Spacer(),
                  ListenableBuilder(
                    listenable: _undoController,
                    builder: (context, _) {
                      final canUndo =
                          _undoController.value.canUndo;
                      return IconButton(
                        icon: Icon(
                          Icons.undo,
                          color: canUndo
                              ? _fgColor
                              : _fgColor.withValues(alpha: 0.3),
                          size: 24,
                        ),
                        onPressed: canUndo
                            ? () => _undoController.undo()
                            : null,
                      );
                    },
                  ),
                  _buildModeSelectorButton(),
                  _buildOverflowMenu(),
                  _buildCheckButton(),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Stack(
            children: [
              if (_linesGrid != LinesGridMode.none)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _LinesGridPainter(
                        mode: _linesGrid,
                        color: _isLight
                            ? Colors.grey.shade300
                            : Colors.grey.shade800,
                        spacing: 24,
                      ),
                    ),
                  ),
                ),
              Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  controller: _textController,
                  undoController: _undoController,
                  focusNode: _focusNode,
                  autofocus: true,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  cursorColor: Colors.orange,
                  style:
                      TextStyle(color: _fgColor, fontSize: 16, height: 1.5),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '제목과 내용을 입력하세요',
                    hintStyle: TextStyle(color: _hintColor, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  final LinesGridMode mode;
  final String label;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  const _PatternTile({
    required this.mode,
    required this.label,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 110,
            decoration: BoxDecoration(
              color: isLight ? Colors.white : Colors.black,
              border: Border.all(
                color: selected ? Colors.orange : Colors.grey.shade700,
                width: selected ? 2.5 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _LinesGridPainter(
                  mode: mode,
                  color:
                      isLight ? Colors.grey.shade400 : Colors.grey.shade600,
                  spacing: 14,
                ),
                size: const Size(88, 110),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.orange : Colors.white,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewTextEditingController extends TextEditingController {
  String? _preview;

  String? get preview => _preview;

  void setPreview(String? next) {
    if (_preview == next) return;
    _preview = next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final preview = _preview;
    if (preview == null || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final cursor = selection.baseOffset;
    int lineEnd;
    int lineStart;
    if (cursor < 0 || cursor > text.length) {
      lineEnd = text.length;
      lineStart = text.lastIndexOf('\n') + 1;
    } else {
      final next = text.indexOf('\n', cursor);
      lineEnd = next == -1 ? text.length : next;
      lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    }
    final line = text.substring(lineStart, lineEnd);
    final open = '('.allMatches(line).length;
    final close = ')'.allMatches(line).length;
    final closing = open > close ? ')' * (open - close) : '';
    final previewStyle =
        (style ?? const TextStyle()).copyWith(color: Colors.orange);
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: text.substring(0, lineEnd)),
        TextSpan(text: '$closing = $preview', style: previewStyle),
        if (lineEnd < text.length) TextSpan(text: text.substring(lineEnd)),
      ],
    );
  }
}
