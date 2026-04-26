import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'data/calc_history_repository.dart';
import 'data/converter_controller.dart';
import 'data/converter_data.dart';
import 'logic/calculator_base.dart';
import 'screens/basic_calculator_screen.dart';
import 'screens/scientific_calculator_screen.dart';
import 'screens/math_notes_screen.dart';
import 'screens/history_screen.dart';
import 'data/db_init.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initSqflite();
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iOS Calculator',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  // 변환 모드(_selectedIndex == 3) 진입 시 어느 계산기 키패드를 깔지 결정.
  // 0/1을 마지막으로 누른 시점을 기록해 둠.
  int _lastCalcIndex = 0;
  late final MathNotesController _mathNotesController;
  late final ConverterController _converterController;
  late final Widget _mathNotesScreen;
  // 계산기 화면을 변환 모드로 전환하면서도 expression 등 calc state를 보존하기 위한 키.
  // 같은 키를 normal/converter 모드 양쪽에서 재사용하면 State가 살아남는다.
  final GlobalKey _basicKey = GlobalKey();
  final GlobalKey _scientificKey = GlobalKey();
  final GlobalKey _overflowKey = GlobalKey();

  static const int _mathNotesIndex = 2;
  static const int _converterIndex = 3;

  final List<String> _labels = ['기본', '공학용', '수학 메모', '변환'];

  final List<IconData> _icons = [
    CupertinoIcons.divide,
    CupertinoIcons.function,
    CupertinoIcons.pencil_outline,
    CupertinoIcons.arrow_2_squarepath,
  ];

  @override
  void initState() {
    super.initState();
    _mathNotesController = MathNotesController();
    _converterController = ConverterController();
    unawaited(_mathNotesController.seedDummyDataIfMissing());
    _mathNotesScreen = MathNotesScreen(
      controller: _mathNotesController,
      onSwitchMode: _onItemTapped,
    );
  }

  @override
  void dispose() {
    _mathNotesController.dispose();
    _converterController.dispose();
    super.dispose();
  }

  // 변환 모드는 별도 화면이 아니라 마지막 사용 계산기의 디스플레이 영역만
  // ConverterDisplay로 교체한다. 키패드는 그대로 두고 expression을 source로 활용.
  Widget _buildCurrentScreen() {
    switch (_selectedIndex) {
      case 0:
        return BasicCalculatorScreen(key: _basicKey);
      case 1:
        return ScientificCalculatorScreen(key: _scientificKey);
      case _mathNotesIndex:
        return _mathNotesScreen;
      case _converterIndex:
        if (_lastCalcIndex == 1) {
          return ScientificCalculatorScreen(
            key: _scientificKey,
            showConverter: true,
            converterController: _converterController,
          );
        }
        return BasicCalculatorScreen(
          key: _basicKey,
          showConverter: true,
          converterController: _converterController,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0 || index == 1) {
        _lastCalcIndex = index;
      }
    });
  }

  // 기록 모달에서 항목을 탭했을 때 호출. mode에 따라 알맞은 모드로 전환하고
  // calc state(또는 변환 컨트롤러)를 복원한다. State는 build 이후에야 살아나므로
  // restore 호출은 postFrameCallback으로 미룬다.
  void _onHistoryEntrySelected(CalcHistoryEntry entry) {
    Navigator.of(context).pop();
    if (entry.mode == 'converter') {
      String resultExpression = entry.expression.split(' ').first;
      if (entry.metadata != null) {
        try {
          final m = jsonDecode(entry.metadata!) as Map<String, dynamic>;
          final categoryName = m['category'] as String?;
          if (categoryName != null) {
            for (final c in ConverterCategory.values) {
              if (c.name == categoryName) {
                _converterController.setCategory(c);
                break;
              }
            }
          }
          final srcIdx = m['sourceUnitIndex'];
          final tgtIdx = m['targetUnitIndex'];
          if (srcIdx is int) {
            _converterController.setUnitIndex(isSource: true, index: srcIdx);
          }
          if (tgtIdx is int) {
            _converterController.setUnitIndex(isSource: false, index: tgtIdx);
          }
          final editingSource = m['editingSource'];
          if (editingSource is bool) {
            _converterController.setEditingSource(editingSource);
          }
          final sourceValue = m['sourceValue'];
          if (sourceValue is String && sourceValue.isNotEmpty) {
            resultExpression = sourceValue;
          }
        } catch (e) {
          debugPrint('[history] converter metadata parse failed: $e');
        }
      }
      setState(() {
        _selectedIndex = _converterIndex;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final state = _lastCalcIndex == 1
            ? _scientificKey.currentState
            : _basicKey.currentState;
        if (state case CalcHistoryRestorable r) {
          r.restoreFromHistory('', resultExpression);
        }
      });
      return;
    }
    final isScientific = entry.mode == 'scientific';
    setState(() {
      _selectedIndex = isScientific ? 1 : 0;
      _lastCalcIndex = _selectedIndex;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = isScientific
          ? _scientificKey.currentState
          : _basicKey.currentState;
      if (state case CalcHistoryRestorable r) {
        r.restoreFromHistory(entry.expression, entry.result);
      }
    });
  }

  void _openHistory() {
    final sheetController = DraggableScrollableController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.grey[900]!.withValues(alpha: 0.7),
                child: HistoryScreen(
                  scrollController: scrollController,
                  sheetController: sheetController,
                  onSelectEntry: _onHistoryEntrySelected,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryButton() {
    return Material(
      color: Colors.grey[900],
      shape: CircleBorder(
        side: BorderSide(color: Colors.grey[700]!, width: 2),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openHistory,
        child: const SizedBox(
          width: 80,
          height: 80,
          child: Icon(
            CupertinoIcons.clock,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector({required bool hideConverter}) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[700]!, width: 2),
      ),
      child: PopupMenuButton<int>(
        padding: EdgeInsets.zero,
        offset: const Offset(0, 85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.grey[900],
        onSelected: _onItemTapped,
        icon: Container(
          width: 40,
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      3,
                      (row) => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          3,
                          (col) => Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        itemBuilder: (context) {
          List<PopupMenuEntry<int>> menuItems = [];
          for (int i = 0; i < _labels.length; i++) {
            if (hideConverter && i == _converterIndex) continue;
            menuItems.add(
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: _selectedIndex == i
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Icon(_icons[i], size: 20, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      _labels[i],
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            );
          }
          return menuItems;
        },
      ),
    );
  }

  Widget _buildMathNotesOverflowButton() {
    return Container(
      key: _overflowKey,
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey[700]!, width: 2),
      ),
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        offset: const Offset(0, 85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: Colors.grey[900],
        icon: const Icon(
          Icons.more_horiz,
          color: Colors.white,
          size: 36,
        ),
        onSelected: (value) {
          switch (value) {
            case 'select':
              _mathNotesController.enterSelectionMode();
              break;
            case 'sort':
              unawaited(_showSortSubMenu());
              break;
            case 'group':
              _mathNotesController.toggleGroupByDate();
              break;
          }
        },
        itemBuilder: (context) {
          final isTitleSort = _mathNotesController.sortOrder ==
              MathNotesSortOrder.title;
          return [
            const PopupMenuItem<String>(
              value: 'select',
              child: Row(
                children: [
                  SizedBox(width: 24),
                  SizedBox(width: 8),
                  Icon(Icons.check_circle_outline,
                      size: 20, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    '메모 선택',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'sort',
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  const SizedBox(width: 8),
                  const Icon(Icons.sort, size: 20, color: Colors.white),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '다음으로 정렬',
                        style: TextStyle(
                            color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _sortLabel(_mathNotesController.sortOrder),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isTitleSort)
              PopupMenuItem<String>(
                value: 'group',
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: _mathNotesController.groupByDate
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.calendar_today,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text(
                      '날짜별로 그룹화',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
          ];
        },
      ),
    );
  }

  static String _sortLabel(MathNotesSortOrder order) {
    switch (order) {
      case MathNotesSortOrder.dateModified:
        return '편집일';
      case MathNotesSortOrder.dateCreated:
        return '생성일';
      case MathNotesSortOrder.title:
        return '제목';
    }
  }

  Future<void> _showSortSubMenu() async {
    final keyContext = _overflowKey.currentContext;
    if (keyContext == null) return;
    final RenderBox button = keyContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final current = _mathNotesController.sortOrder;
    final result = await showMenu<MathNotesSortOrder>(
      context: context,
      position: position,
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        for (final option in MathNotesSortOrder.values)
          PopupMenuItem<MathNotesSortOrder>(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: current == option
                      ? const Icon(Icons.check,
                          size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  _sortLabel(option),
                  style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
      ],
    );
    if (result != null) {
      _mathNotesController.setSortOrder(result);
    }
  }

  Widget _buildMathNotesTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '수학 메모',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_mathNotesController.count}개의 메모',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionModeBar() {
    final selectedCount = _mathNotesController.selected.length;
    final hasSelection = selectedCount > 0;
    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 10.0),
            child: TextButton(
              onPressed: _mathNotesController.exitSelectionMode,
              child: const Text(
                '취소',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Text(
              hasSelection ? '$selectedCount개 선택됨' : '항목 선택',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 10.0),
            child: TextButton(
              onPressed: hasSelection
                  ? () => unawaited(_mathNotesController.deleteSelected())
                  : null,
              child: Text(
                '삭제',
                style: TextStyle(
                  color: hasSelection
                      ? Colors.red
                      : Colors.red.withValues(alpha: 0.4),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: AnimatedBuilder(
              animation: _mathNotesController,
              builder: (context, _) {
                final isMathNotes = _selectedIndex == _mathNotesIndex;
                if (isMathNotes && _mathNotesController.selectionMode) {
                  return _buildSelectionModeBar();
                }
                return Stack(
                  children: [
                    if (isMathNotes)
                      Align(
                        alignment: Alignment.center,
                        child: _buildMathNotesTitle(),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 16.0, top: 10.0),
                          child: _buildHistoryButton(),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding:
                            const EdgeInsets.only(right: 16.0, top: 10.0),
                        child: isMathNotes
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildModeSelector(hideConverter: true),
                                  const SizedBox(width: 12),
                                  _buildMathNotesOverflowButton(),
                                ],
                              )
                            : _buildModeSelector(hideConverter: false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _buildCurrentScreen(),
      ),
    );
  }
}
