import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/converter_controller.dart';
import '../data/converter_data.dart';
import '../data/currency_repository.dart';
import '../logic/memo_math_eval.dart';

const List<String> _kCurrencyOrder = [
  'USD',
  'KRW',
  'EUR',
  'JPY',
  'GBP',
  'CNY',
  'AUD',
  'CAD',
  'CHF',
  'HKD',
  'SGD',
  'INR',
  'MXN',
  'BRL',
  'NZD',
  'SEK',
  'NOK',
  'TRY',
  'ZAR',
  'THB',
];

List<ConverterUnit> _unitsForCategory(ConverterCategory cat) {
  if (cat == ConverterCategory.currency) {
    final rates = CurrencyRepository.instance.rates;
    if (rates == null) return const [];
    final available = _kCurrencyOrder
        .where((c) => rates.rates.containsKey(c))
        .toList(growable: false);
    return [
      for (final code in available)
        ConverterUnit(code, _CurrencyConverter(code, rates)),
    ];
  }
  return categoryUnits[cat] ?? const [];
}

class _CurrencyConverter extends UnitConverter {
  final String code;
  final CurrencyRates rates;
  const _CurrencyConverter(this.code, this.rates);

  @override
  double toBase(double value) {
    final rate = rates.rates[code];
    if (rate == null || rate == 0) return 0;
    return value / rate;
  }

  @override
  double fromBase(double value) {
    final rate = rates.rates[code];
    if (rate == null) return 0;
    return value * rate;
  }
}

class ConverterDisplay extends StatefulWidget {
  final String sourceText;
  final ConverterController controller;

  const ConverterDisplay({
    super.key,
    required this.sourceText,
    required this.controller,
  });

  @override
  State<ConverterDisplay> createState() => _ConverterDisplayState();
}

class _ConverterDisplayState extends State<ConverterDisplay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    CurrencyRepository.instance.addListener(_onChanged);
    unawaited(CurrencyRepository.instance.ensureFresh());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    CurrencyRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  double _parseSource() {
    final text = widget.sourceText;
    final n = double.tryParse(text.replaceAll(',', ''));
    if (n != null) return n;
    final res = evaluateMemoExpression(text);
    if (res != null) return double.tryParse(res) ?? 0;
    return 0;
  }

  String _formatNumber(double v) {
    if (v.isNaN) return 'NaN';
    if (v.isInfinite) return '∞';
    if (v == v.truncateToDouble() && v.abs() < 1e15) {
      return v.toInt().toString();
    }
    var s = v.toStringAsFixed(8);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  String _formatRateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  ({String sourceDisplay, String targetDisplay}) _computeDisplay(
      List<ConverterUnit> units) {
    final c = widget.controller;
    final src = units[c.sourceUnitIndex.clamp(0, units.length - 1)];
    final tgt = units[c.targetUnitIndex.clamp(0, units.length - 1)];
    final input = _parseSource();
    if (c.editingSource) {
      final base = src.converter.toBase(input);
      final converted = tgt.converter.fromBase(base);
      return (
        sourceDisplay: widget.sourceText,
        targetDisplay: _formatNumber(converted),
      );
    } else {
      final base = tgt.converter.toBase(input);
      final converted = src.converter.fromBase(base);
      return (
        sourceDisplay: _formatNumber(converted),
        targetDisplay: widget.sourceText,
      );
    }
  }

  Future<void> _showUnitPicker(bool isSource) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UnitPickerSheet(
        controller: widget.controller,
        isSource: isSource,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final units = _unitsForCategory(widget.controller.category);
    final controller = widget.controller;
    final isCurrencyLoading =
        controller.category == ConverterCategory.currency &&
            CurrencyRepository.instance.loading &&
            CurrencyRepository.instance.rates == null;
    final isCurrencyError =
        controller.category == ConverterCategory.currency &&
            CurrencyRepository.instance.rates == null &&
            !CurrencyRepository.instance.loading;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: isCurrencyLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orange))
          : isCurrencyError
              ? _buildCurrencyError()
              : units.isEmpty
                  ? const Center(
                      child: Text('단위가 없습니다',
                          style: TextStyle(color: Colors.grey)))
                  : _buildRows(units),
    );
  }

  Widget _buildCurrencyError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '환율을 불러오지 못했습니다',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                unawaited(CurrencyRepository.instance.refresh()),
            child: const Text('다시 시도',
                style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildRows(List<ConverterUnit> units) {
    final controller = widget.controller;
    final display = _computeDisplay(units);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.category == ConverterCategory.currency &&
            CurrencyRepository.instance.rates != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '환율 ${_formatRateTime(CurrencyRepository.instance.rates!.fetchedAt)}',
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                const SizedBox(width: 6),
                if (CurrencyRepository.instance.loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        color: Colors.orange, strokeWidth: 1.5),
                  )
                else
                  GestureDetector(
                    onTap: () =>
                        unawaited(CurrencyRepository.instance.refresh()),
                    child: Icon(Icons.refresh,
                        size: 14, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        const Spacer(),
        _buildValueRow(
          value: display.sourceDisplay,
          unit: units[controller.sourceUnitIndex
                  .clamp(0, units.length - 1)]
              .label,
          isActive: controller.editingSource,
          onTap: () => controller.setEditingSource(true),
          onArrowsTap: () => unawaited(_showUnitPicker(true)),
        ),
        const SizedBox(height: 12),
        _buildValueRow(
          value: display.targetDisplay,
          unit: units[controller.targetUnitIndex
                  .clamp(0, units.length - 1)]
              .label,
          isActive: !controller.editingSource,
          onTap: () => controller.setEditingSource(false),
          onArrowsTap: () => unawaited(_showUnitPicker(false)),
        ),
      ],
    );
  }

  Widget _buildValueRow({
    required String value,
    required String unit,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onArrowsTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? Colors.orange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 12 ? 32 : 44,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onArrowsTap,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_arrow_up,
                        size: 18, color: Colors.grey[400]),
                    Icon(Icons.keyboard_arrow_down,
                        size: 18, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitPickerSheet extends StatefulWidget {
  final ConverterController controller;
  final bool isSource;
  const _UnitPickerSheet({
    required this.controller,
    required this.isSource,
  });

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    CurrencyRepository.instance.addListener(_onChanged);
    if (widget.controller.category == ConverterCategory.currency) {
      unawaited(CurrencyRepository.instance.ensureFresh());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    CurrencyRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final units = _unitsForCategory(controller.category);
    final currentIndex = widget.isSource
        ? controller.sourceUnitIndex
        : controller.targetUnitIndex;

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ScrollConfiguration(
                  behavior: const _DragAnyDeviceScrollBehavior(),
                  child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ConverterCategory.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                  final cat = ConverterCategory.values[i];
                  final selected = cat == controller.category;
                  return GestureDetector(
                    onTap: () {
                      controller.setCategory(cat);
                      if (cat == ConverterCategory.currency) {
                        unawaited(
                            CurrencyRepository.instance.ensureFresh());
                      }
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color:
                            selected ? Colors.orange : Colors.grey[850],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        categoryLabels[cat]!,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : Colors.grey[300],
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
                ),
            ),
            Divider(color: Colors.grey[800], height: 1),
            Flexible(
              child: units.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          controller.category ==
                                  ConverterCategory.currency
                              ? (CurrencyRepository.instance.loading
                                  ? '환율 불러오는 중...'
                                  : '환율을 불러오지 못했습니다')
                              : '단위가 없습니다',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ScrollConfiguration(
                      behavior: const _DragAnyDeviceScrollBehavior(),
                      child: ListView.separated(
                      itemCount: units.length,
                      separatorBuilder: (_, _) =>
                          Divider(color: Colors.grey[850], height: 1),
                      itemBuilder: (context, i) {
                        final u = units[i];
                        final isCurrent = i == currentIndex;
                        return ListTile(
                          dense: true,
                          title: Text(
                            u.label,
                            style: TextStyle(
                              color: isCurrent
                                  ? Colors.orange
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: isCurrent
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          trailing: isCurrent
                              ? const Icon(Icons.check,
                                  color: Colors.orange, size: 20)
                              : null,
                          onTap: () {
                            controller.setUnitIndex(
                                isSource: widget.isSource, index: i);
                            Navigator.of(context).pop();
                          },
                        );
                      },
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

class _DragAnyDeviceScrollBehavior extends MaterialScrollBehavior {
  const _DragAnyDeviceScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
