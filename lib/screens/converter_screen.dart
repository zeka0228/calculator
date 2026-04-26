import 'dart:async';

import 'package:flutter/material.dart';

import '../data/converter_data.dart';
import '../data/currency_repository.dart';
import '../widgets/calculator_button.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  ConverterCategory _category = ConverterCategory.length;
  int _sourceUnitIndex = 0;
  int _targetUnitIndex = 1;
  String _sourceText = '0';
  bool _resultDisplayed = false;
  bool _editingSource = true;

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
    CurrencyRepository.instance.addListener(_onCurrencyChanged);
    unawaited(CurrencyRepository.instance.ensureFresh());
  }

  @override
  void dispose() {
    CurrencyRepository.instance.removeListener(_onCurrencyChanged);
    super.dispose();
  }

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  List<ConverterUnit> get _units {
    if (_category == ConverterCategory.currency) {
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
    return categoryUnits[_category] ?? const [];
  }

  void _setCategory(ConverterCategory cat) {
    setState(() {
      _category = cat;
      _sourceUnitIndex = 0;
      _targetUnitIndex = _units.length > 1 ? 1 : 0;
      _sourceText = '0';
      _resultDisplayed = false;
      _editingSource = true;
    });
  }

  void _cycleUnit({required bool isSource, required int delta}) {
    final units = _units;
    if (units.isEmpty) return;
    setState(() {
      if (isSource) {
        _sourceUnitIndex =
            (_sourceUnitIndex + delta) % units.length;
        if (_sourceUnitIndex < 0) _sourceUnitIndex += units.length;
      } else {
        _targetUnitIndex =
            (_targetUnitIndex + delta) % units.length;
        if (_targetUnitIndex < 0) _targetUnitIndex += units.length;
      }
    });
  }

  void _onKey(String key) {
    setState(() {
      if (key == 'AC') {
        _sourceText = '0';
        _resultDisplayed = false;
        return;
      }
      if (key == '⌫') {
        if (_resultDisplayed) {
          _sourceText = '0';
          _resultDisplayed = false;
          return;
        }
        if (_sourceText.length <= 1 ||
            (_sourceText.length == 2 && _sourceText.startsWith('-'))) {
          _sourceText = '0';
        } else {
          _sourceText = _sourceText.substring(0, _sourceText.length - 1);
        }
        return;
      }
      if (key == '+/-') {
        if (_sourceText == '0') return;
        _sourceText = _sourceText.startsWith('-')
            ? _sourceText.substring(1)
            : '-$_sourceText';
        return;
      }
      if (key == '⇄') {
        final tmp = _sourceUnitIndex;
        _sourceUnitIndex = _targetUnitIndex;
        _targetUnitIndex = tmp;
        if (_editingSource) {
          final converted = _convertedValue();
          _sourceText = _formatNumber(converted);
          _resultDisplayed = false;
        }
        return;
      }
      if (key == '.') {
        if (_resultDisplayed) {
          _sourceText = '0.';
          _resultDisplayed = false;
          return;
        }
        if (!_sourceText.contains('.')) {
          _sourceText = '$_sourceText.';
        }
        return;
      }
      if (key == '00') {
        if (_sourceText == '0' || _resultDisplayed) {
          _sourceText = '0';
          _resultDisplayed = false;
        } else {
          _sourceText = '${_sourceText}00';
        }
        return;
      }
      // digit
      if (_sourceText == '0' || _resultDisplayed) {
        _sourceText = key;
        _resultDisplayed = false;
      } else {
        _sourceText = '$_sourceText$key';
      }
    });
  }

  double get _sourceValue => double.tryParse(_sourceText) ?? 0;

  double _convertedValue() {
    final units = _units;
    if (units.isEmpty) return 0;
    final src = units[_sourceUnitIndex.clamp(0, units.length - 1)];
    final tgt = units[_targetUnitIndex.clamp(0, units.length - 1)];
    final base = src.converter.toBase(_sourceValue);
    return tgt.converter.fromBase(base);
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

  @override
  Widget build(BuildContext context) {
    final units = _units;
    final isCurrencyLoading = _category == ConverterCategory.currency &&
        CurrencyRepository.instance.loading &&
        CurrencyRepository.instance.rates == null;
    final isCurrencyError = _category == ConverterCategory.currency &&
        CurrencyRepository.instance.rates == null &&
        !CurrencyRepository.instance.loading;

    return Column(
      children: [
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: ConverterCategory.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = ConverterCategory.values[i];
              final selected = cat == _category;
              return GestureDetector(
                onTap: () => _setCategory(cat),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: selected ? Colors.orange : Colors.grey[850],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    categoryLabels[cat]!,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey[300],
                      fontSize: 14,
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
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: isCurrencyLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Colors.orange),
                  )
                : isCurrencyError
                    ? _buildCurrencyError()
                    : units.isEmpty
                        ? const Center(
                            child: Text('단위가 없습니다',
                                style: TextStyle(color: Colors.grey)),
                          )
                        : _buildRows(units),
          ),
        ),
        _buildKeypad(),
        const SizedBox(height: 16),
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
            child: const Text(
              '다시 시도',
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRows(List<ConverterUnit> units) {
    final converted = _convertedValue();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_category == ConverterCategory.currency &&
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
          value: _sourceText,
          unit: units[_sourceUnitIndex.clamp(0, units.length - 1)].label,
          isActive: _editingSource,
          onTap: () => setState(() => _editingSource = true),
          onUp: () => _cycleUnit(isSource: true, delta: 1),
          onDown: () => _cycleUnit(isSource: true, delta: -1),
        ),
        const SizedBox(height: 12),
        _buildValueRow(
          value: _formatNumber(converted),
          unit: units[_targetUnitIndex.clamp(0, units.length - 1)].label,
          isActive: !_editingSource,
          onTap: () => setState(() => _editingSource = false),
          onUp: () => _cycleUnit(isSource: false, delta: 1),
          onDown: () => _cycleUnit(isSource: false, delta: -1),
        ),
      ],
    );
  }

  String _formatRateTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}.${two(t.month)}.${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
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
                    fontSize: value.length > 12 ? 36 : 48,
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

  Widget _buildKeypad() {
    Widget btn(String label, {Color? bg, Color? fg}) {
      return CalculatorButton(
        text: label,
        bgColor: bg ?? Colors.grey[850]!,
        textColor: fg ?? Colors.white,
        onTap: () => _onKey(label),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            btn('AC', bg: Colors.grey[400], fg: Colors.black),
            btn('+/-', bg: Colors.grey[400], fg: Colors.black),
            btn('⇄', bg: Colors.grey[400], fg: Colors.black),
            btn('⌫', bg: Colors.grey[600]),
          ],
        ),
        Row(
          children: [
            btn('7'),
            btn('8'),
            btn('9'),
            btn('.'),
          ],
        ),
        Row(
          children: [
            btn('4'),
            btn('5'),
            btn('6'),
            btn('0'),
          ],
        ),
        Row(
          children: [
            btn('1'),
            btn('2'),
            btn('3'),
            btn('00', bg: Colors.grey[850]),
          ],
        ),
      ],
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
