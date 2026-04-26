import 'dart:async';

import 'package:flutter/material.dart';

import '../data/converter_controller.dart';
import '../data/converter_data.dart';
import '../data/currency_repository.dart';
import '../logic/memo_math_eval.dart';

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
  static const List<String> _currencyOrder = [
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

  List<ConverterUnit> _units() {
    final cat = widget.controller.category;
    if (cat == ConverterCategory.currency) {
      final rates = CurrencyRepository.instance.rates;
      if (rates == null) return const [];
      final available = _currencyOrder
          .where((c) => rates.rates.containsKey(c))
          .toList(growable: false);
      return [
        for (final code in available)
          ConverterUnit(code, _CurrencyConverter(code, rates)),
      ];
    }
    return categoryUnits[cat] ?? const [];
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

  @override
  Widget build(BuildContext context) {
    final units = _units();
    final controller = widget.controller;
    final isCurrencyLoading =
        controller.category == ConverterCategory.currency &&
            CurrencyRepository.instance.loading &&
            CurrencyRepository.instance.rates == null;
    final isCurrencyError =
        controller.category == ConverterCategory.currency &&
            CurrencyRepository.instance.rates == null &&
            !CurrencyRepository.instance.loading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: ConverterCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final cat = ConverterCategory.values[i];
              final selected = cat == controller.category;
              return GestureDetector(
                onTap: () => controller.setCategory(cat),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: selected ? Colors.orange : Colors.grey[850],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    categoryLabels[cat]!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[300],
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          ),
        ),
      ],
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
        _buildValueRow(
          value: display.sourceDisplay,
          unit: units[controller.sourceUnitIndex
                  .clamp(0, units.length - 1)]
              .label,
          isActive: controller.editingSource,
          onTap: () => controller.setEditingSource(true),
          onUp: () => controller.cycleUnit(
              isSource: true, delta: 1, total: units.length),
          onDown: () => controller.cycleUnit(
              isSource: true, delta: -1, total: units.length),
        ),
        const SizedBox(height: 12),
        _buildValueRow(
          value: display.targetDisplay,
          unit: units[controller.targetUnitIndex
                  .clamp(0, units.length - 1)]
              .label,
          isActive: !controller.editingSource,
          onTap: () => controller.setEditingSource(false),
          onUp: () => controller.cycleUnit(
              isSource: false, delta: 1, total: units.length),
          onDown: () => controller.cycleUnit(
              isSource: false, delta: -1, total: units.length),
        ),
      ],
    );
  }

  Widget _buildValueRow({
    required String value,
    required String unit,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onUp,
    required VoidCallback onDown,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onUp,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Icon(Icons.keyboard_arrow_up,
                          size: 18, color: Colors.grey[400]),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Icon(Icons.keyboard_arrow_down,
                          size: 18, color: Colors.grey[400]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
