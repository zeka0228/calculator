import 'package:flutter/material.dart';
import '../widgets/calculator_button.dart';

class BasicCalculatorScreen extends StatefulWidget {
  const BasicCalculatorScreen({super.key});

  @override
  State<BasicCalculatorScreen> createState() => _BasicCalculatorScreenState();
}

class _BasicCalculatorScreenState extends State<BasicCalculatorScreen> {
  String _expression = '0';
  String _history = '';
  bool _isResultDisplayed = false;
  String? _lastOperator;
  double? _lastOperand;

  void _onButtonPressed(String text) {
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        _handleNumber(text);
      } else if (text == '.') {
        _handleDot();
      } else if (text == '⌫') {
        _handleBackspace();
      } else if (text == 'AC') {
        _clearAll();
      } else if (text == 'C') {
        _clearEntry();
      } else if (text == '+/-') {
        _toggleSign();
      } else if (text == '%') {
        _applyPercent();
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        _handleOperator(text);
      } else if (text == '=') {
        _handleEquals();
      }
    });
  }

  void _handleNumber(String text) {
    if (_expression == '0' || _isResultDisplayed) {
      if (_isResultDisplayed) _history = '';
      _expression = text;
      _isResultDisplayed = false;
    } else {
      List<String> tokens = _expression.split(' ');
      String lastToken = tokens.last;
      
      if (RegExp(r'^[0-9,.]+$').hasMatch(lastToken)) {
        String cleanNumber = lastToken.replaceAll(',', '');
        if (cleanNumber == '0') {
          tokens[tokens.length - 1] = text;
        } else {
          tokens[tokens.length - 1] = _addCommas(cleanNumber + text);
        }
        _expression = tokens.join(' ');
      } else if (lastToken.startsWith('(-')) {
        String numberPart = lastToken.substring(2, lastToken.length - 1).replaceAll(',', '');
        tokens[tokens.length - 1] = '(-${_addCommas(numberPart + text)})';
        _expression = tokens.join(' ');
      } else {
        _expression += text;
      }
    }
  }

  void _handleDot() {
    if (_isResultDisplayed) {
      _history = '';
      _expression = '0.';
      _isResultDisplayed = false;
      return;
    }

    List<String> tokens = _expression.split(' ');
    String lastToken = tokens.last;

    if (RegExp(r'[+×÷-]$').hasMatch(lastToken)) {
      _expression += '0.';
    } else if (!lastToken.contains('.')) {
      if (lastToken.startsWith('(-')) {
        String numberPart = lastToken.substring(2, lastToken.length - 1);
        tokens[tokens.length - 1] = '(-$numberPart.)';
        _expression = tokens.join(' ');
      } else {
        _expression += '.';
      }
    }
  }

  void _handleOperator(String op) {
    if (_isResultDisplayed) {
      _isResultDisplayed = false;
      _history = '';
    }

    String trimmed = _expression.trim();
    if (RegExp(r'[+×÷-]$').hasMatch(trimmed)) {
      _expression = trimmed.substring(0, trimmed.length - 1) + op + ' ';
    } else {
      _expression = '$trimmed $op ';
    }
  }

  void _handleEquals() {
    List<String> tokens = _expression.trim().split(' ');
    if (tokens.length == 1) {
      if (_lastOperator != null && _lastOperand != null) {
        _repeatLastOperation();
      }
    } else {
      _calculate();
    }
  }

  void _clearAll() {
    _expression = '0';
    _history = '';
    _isResultDisplayed = false;
    _lastOperator = null;
    _lastOperand = null;
  }

  void _clearEntry() {
    List<String> tokens = _expression.trim().split(' ');
    if (tokens.isNotEmpty && !RegExp(r'[+×÷-]$').hasMatch(tokens.last)) {
      tokens.removeLast();
      _expression = tokens.isEmpty ? '0' : '${tokens.join(' ')} ';
    } else {
      _clearAll();
    }
  }

  void _repeatLastOperation() {
    double currentVal = _parseToken(_expression);
    double result = 0;
    
    switch (_lastOperator) {
      case '+': result = currentVal + _lastOperand!; break;
      case '-': result = currentVal - _lastOperand!; break;
      case '×': result = currentVal * _lastOperand!; break;
      case '÷': result = currentVal / _lastOperand!; break;
    }
    
    _history = "${_formatValue(currentVal)} $_lastOperator ${_formatValue(_lastOperand!)}";
    _expression = _formatValue(result);
    _isResultDisplayed = true;
  }

  void _handleBackspace() {
    if (_isResultDisplayed) {
      _history = '';
      return;
    }

    if (_expression.endsWith(' ')) {
      _expression = _expression.trim().substring(0, _expression.length - 2);
    } else if (_expression.length > 1) {
      List<String> tokens = _expression.split(' ');
      String lastToken = tokens.last;

      if (lastToken.startsWith('(-')) {
        String num = lastToken.substring(2, lastToken.length - 1).replaceAll(',', '');
        if (num.length > 1) {
          tokens[tokens.length - 1] = '(-${_addCommas(num.substring(0, num.length - 1))})';
        } else {
          tokens[tokens.length - 1] = '0';
        }
      } else {
        String clean = lastToken.replaceAll(',', '');
        String newNum = clean.substring(0, clean.length - 1);
        tokens[tokens.length - 1] = newNum.isEmpty ? '0' : _addCommas(newNum);
      }
      _expression = tokens.join(' ');
    } else {
      _expression = '0';
    }

    if (_expression.isEmpty) _expression = '0';
  }

  String _addCommas(String s) {
    if (s.isEmpty) return '';
    List<String> parts = s.split('.');
    RegExp reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAll(reg, ',');
    return parts.join('.');
  }

  void _toggleSign() {
    List<String> tokens = _expression.trim().split(' ');
    String lastToken = tokens.last;

    if (RegExp(r'[+×÷-]$').hasMatch(lastToken)) return;

    if (lastToken.startsWith('(-')) {
      tokens[tokens.length - 1] = lastToken.substring(2, lastToken.length - 1);
    } else if (lastToken != '0') {
      tokens[tokens.length - 1] = '(-$lastToken)';
    }
    _expression = tokens.join(' ');
  }

  void _applyPercent() {
    List<String> tokens = _expression.trim().split(' ');
    String lastToken = tokens.last;
    
    if (!RegExp(r'[+×÷-]$').hasMatch(lastToken)) {
      double val = _parseToken(lastToken) / 100.0;
      tokens[tokens.length - 1] = _formatValue(val);
      _expression = tokens.join(' ');
      if (_isResultDisplayed) _history = '';
    }
  }

  double _parseToken(String token) {
    String clean = token.replaceAll('(', '').replaceAll(')', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0;
  }

  String _formatValue(double result) {
    if (result.isInfinite || result.isNaN) return 'Error';
    if (result == 0) return '0';

    // 정수면 정수로 출력
    if (result == result.toInt()) {
      return _addCommas(result.toInt().toString());
    }

    // 소수점 아래 불필요한 0 제거 (최대 10자리)
    String s = result.toStringAsFixed(10);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    
    return _addCommas(s);
  }

  void _calculate() {
    try {
      String trimmed = _expression.trim();
      List<String> tokens = trimmed.split(' ');
      if (tokens.length < 3) return;

      _history = trimmed;
      List<dynamic> values = [];
      for (var t in tokens) {
        if (RegExp(r'^[+×÷-]$').hasMatch(t)) {
          values.add(t);
        } else {
          values.add(_parseToken(t));
        }
      }

      // 연산자 및 피연산자 저장 (연속 계산용)
      _lastOperator = tokens[tokens.length - 2];
      _lastOperand = _parseToken(tokens.last);

      // 곱셈, 나눗셈 우선 처리
      for (int i = 0; i < values.length; i++) {
        if (values[i] == '×' || values[i] == '÷') {
          double left = values[i - 1];
          double right = values[i + 1];
          double res = (values[i] == '×') ? left * right : left / right;
          values.replaceRange(i - 1, i + 2, [res]);
          i--;
        }
      }

      // 덧셈, 뺄셈 처리
      double finalRes = values[0];
      for (int i = 1; i < values.length; i += 2) {
        String op = values[i];
        double nextVal = values[i + 1];
        if (op == '+') finalRes += nextVal;
        if (op == '-') finalRes -= nextVal;
      }

      _expression = _formatValue(finalRes);
      _isResultDisplayed = true;
    } catch (e) {
      _expression = 'Error';
      _isResultDisplayed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_history.isNotEmpty)
                  SingleChildScrollView(
                    reverse: true,
                    scrollDirection: Axis.horizontal,
                    child: Text(
                      _history,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  reverse: true,
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _expression,
                    style: TextStyle(
                      fontSize: _expression.length > 10 ? 40 : 60,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Column(
          children: [
            Row(
              children: [
                CalculatorButton(
                  text: '⌫',
                  bgColor: Colors.grey[600]!,
                  textColor: Colors.white,
                  onTap: () => _onButtonPressed('⌫'),
                ),
                CalculatorButton(
                  text: (_expression == '0' || _isResultDisplayed) ? 'AC' : 'C',
                  bgColor: Colors.grey[400]!,
                  textColor: Colors.black,
                  onTap: () => _onButtonPressed((_expression == '0' || _isResultDisplayed) ? 'AC' : 'C'),
                ),
                CalculatorButton(
                  text: '%',
                  bgColor: Colors.grey[400]!,
                  textColor: Colors.black,
                  onTap: () => _onButtonPressed('%'),
                ),
                CalculatorButton(
                  text: '÷',
                  bgColor: Colors.orange,
                  textColor: Colors.white,
                  onTap: () => _onButtonPressed('÷'),
                ),
              ],
            ),
            Row(
              children: [
                CalculatorButton(text: '7', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('7')),
                CalculatorButton(text: '8', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('8')),
                CalculatorButton(text: '9', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('9')),
                CalculatorButton(text: '×', bgColor: Colors.orange, textColor: Colors.white, onTap: () => _onButtonPressed('×')),
              ],
            ),
            Row(
              children: [
                CalculatorButton(text: '4', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('4')),
                CalculatorButton(text: '5', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('5')),
                CalculatorButton(text: '6', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('6')),
                CalculatorButton(text: '-', bgColor: Colors.orange, textColor: Colors.white, onTap: () => _onButtonPressed('-')),
              ],
            ),
            Row(
              children: [
                CalculatorButton(text: '1', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('1')),
                CalculatorButton(text: '2', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('2')),
                CalculatorButton(text: '3', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('3')),
                CalculatorButton(text: '+', bgColor: Colors.orange, textColor: Colors.white, onTap: () => _onButtonPressed('+')),
              ],
            ),
            Row(
              children: [
                CalculatorButton(text: '+/-', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('+/-')),
                CalculatorButton(text: '0', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('0')),
                CalculatorButton(text: '.', bgColor: Colors.grey[850]!, textColor: Colors.white, onTap: () => _onButtonPressed('.')),
                CalculatorButton(text: '=', bgColor: Colors.orange, textColor: Colors.white, onTap: () => _onButtonPressed('=')),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }
}
