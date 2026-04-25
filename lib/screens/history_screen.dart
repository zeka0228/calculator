import 'package:flutter/material.dart';
import '../data/calc_history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<CalcHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '기록 (지난 7일)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _confirmClearAll,
                child: const Text('전체 삭제',
                    style: TextStyle(color: Colors.orange)),
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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                separatorBuilder: (_, i) =>
                    Divider(color: Colors.grey[850], height: 1),
                itemBuilder: (_, i) {
                  final e = items[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SingleChildScrollView(
                          reverse: true,
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
                          reverse: true,
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
