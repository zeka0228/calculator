import 'package:flutter/material.dart';
import '../data/calc_history_repository.dart';

class HistoryScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  const HistoryScreen({
    super.key,
    this.scrollController,
    this.sheetController,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<CalcHistoryEntry>> _future;
  bool _editMode = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _enterEditMode() {
    setState(() {
      _editMode = true;
      _selected.clear();
    });
    debugPrint('[history] edit mode: ON');
  }

  void _cancelEditMode() {
    setState(() {
      _editMode = false;
      _selected.clear();
    });
    debugPrint('[history] edit mode: OFF (cancel)');
  }

  Future<void> _commitDelete() async {
    if (_selected.isEmpty) {
      _cancelEditMode();
      return;
    }
    final ids = _selected.toList();
    debugPrint('[history] deleting selected ids=$ids');
    try {
      await CalcHistoryRepository.instance.deleteByIds(ids);
    } catch (e, st) {
      debugPrint('[history] delete by ids FAILED: $e\n$st');
    }
    if (!mounted) return;
    setState(() {
      _editMode = false;
      _selected.clear();
      _load();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    debugPrint('[history] selection=$_selected');
  }

  void _load() {
    _future = _fetchAndPrune();
  }

  Future<List<CalcHistoryEntry>> _fetchAndPrune() async {
    await CalcHistoryRepository.instance.deleteOlderThan(days: 7);
    return CalcHistoryRepository.instance.getRecent(days: 7);
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('전체 삭제',
            style: TextStyle(color: Colors.white)),
        content: const Text('모든 계산 기록을 삭제할까요?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await CalcHistoryRepository.instance.deleteAll();
      if (!mounted) return;
      setState(_load);
    }
  }

  void _onHandleDrag(DragUpdateDetails details) {
    final ctrl = widget.sheetController;
    if (ctrl == null || !ctrl.isAttached) return;
    final screenHeight = MediaQuery.of(context).size.height;
    final newSize = ctrl.size - details.delta.dy / screenHeight;
    ctrl.jumpTo(newSize.clamp(0.4, 1.0));
  }

  void _onHandleDragEnd(DragEndDetails details) {
    final ctrl = widget.sheetController;
    if (ctrl == null || !ctrl.isAttached) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    final size = ctrl.size;
    double target;
    if (velocity < -500) {
      target = 1.0;
    } else if (velocity > 500) {
      target = size > 0.7 ? 0.7 : 0.4;
    } else {
      target = size > 0.85 ? 1.0 : (size > 0.55 ? 0.7 : 0.4);
    }
    ctrl.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onHandleDrag,
          onVerticalDragEnd: _onHandleDragEnd,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed:
                          _editMode ? _commitDelete : _enterEditMode,
                      child: Text(
                        _editMode
                            ? '삭제${_selected.isEmpty ? '' : ' (${_selected.length})'}'
                            : '편집',
                        style: TextStyle(
                          color:
                              _editMode ? Colors.redAccent : Colors.orange,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _editMode ? _cancelEditMode : _confirmClearAll,
                      child: Text(
                        _editMode ? '취소' : '전체 삭제',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '기록 (지난 7일)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CalcHistoryEntry>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.orange),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '기록을 불러오지 못했습니다\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                );
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    '기록이 없습니다',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, i) =>
                    Divider(color: Colors.grey[850], height: 1),
                itemBuilder: (_, i) {
                  final e = items[i];
                  final id = e.id;
                  final isSelected = id != null && _selected.contains(id);
                  final entry = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          e.expression,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          e.result,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _editMode && id != null
                        ? () => _toggleSelect(id)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            width: _editMode ? 36 : 0,
                            child: _editMode
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
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  )
                                : null,
                          ),
                          Expanded(child: entry),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
