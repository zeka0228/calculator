import 'package:flutter/material.dart';

void main() {
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
      home: const CalculatorHome(),
    );
  }
}

class CalculatorHome extends StatefulWidget {
  const CalculatorHome({super.key});

  @override
  State<CalculatorHome> createState() => _CalculatorHomeState();
}

class _CalculatorHomeState extends State<CalculatorHome> {
  String _expression = '0';
  String _history = '';
  bool _isResultDisplayed = false;
  String? _lastOperator;
  double? _lastOperand;

  void _onButtonPressed(String text) {
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        if (_expression == '0' || _isResultDisplayed) {
          if (_isResultDisplayed) _history = '';
          _expression = text;
          _isResultDisplayed = false;
        } else {
          List<String> tokens = _expression.split(' ');
          String lastToken = tokens.last;
          if (RegExp(r'^[0-9,.]+$').hasMatch(lastToken)) {
            String cleanNumber = lastToken.replaceAll(',', '');
            tokens[tokens.length - 1] = _addCommas(cleanNumber + text);
            _expression = tokens.join(' ');
          } else if (RegExp(r'^\(.*\)$').hasMatch(lastToken)) {
            String numberPart = lastToken.substring(2, lastToken.length - 1).replaceAll(',', '');
            tokens[tokens.length - 1] = '(-${_addCommas(numberPart + text)})';
            _expression = tokens.join(' ');
          } else {
            _expression += text;
          }
        }
      } else if (text == '.') {
        List<String> tokens = _expression.split(' ');
        String lastToken = tokens.last.replaceAll(',', '');
        if (!lastToken.contains('.')) {
          if (RegExp(r'^\(.*\)$').hasMatch(lastToken)) {
            String numberPart = lastToken.substring(2, lastToken.length - 1);
            tokens[tokens.length - 1] = '(-$numberPart.)';
            _expression = tokens.join(' ');
          } else {
            _expression += '.';
          }
        }
      } else if (text == '⌫') {
        _handleBackspace();
      } else if (text == 'AC' || text == 'C') {
        _expression = '0';
        _history = '';
        _isResultDisplayed = false;
        _lastOperator = null;
        _lastOperand = null;
      } else if (text == '+/-') {
        if (_isResultDisplayed) {
          _isResultDisplayed = false;
          _history = '';
          _lastOperator = null;
          _lastOperand = null;
        }
        _toggleSign();
      } else if (text == '%') {
        if (_isResultDisplayed) {
          _isResultDisplayed = false;
          _history = '';
          _lastOperator = null;
          _lastOperand = null;
        }
        _applyPercent();
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        if (_isResultDisplayed) {
          _isResultDisplayed = false;
          _history = '';
        }
        if (RegExp(r'[+×÷-]$').hasMatch(_expression.trim())) {
          _expression = _expression.trim().substring(0, _expression.trim().length - 1) + text + ' ';
        } else {
          _expression = '${_expression.trim()} $text ';
        }
      } else if (text == '=') {
        if (_isResultDisplayed && _lastOperator != null && _lastOperand != null) {
          _repeatLastOperation();
        } else {
          _calculate();
        }
      }
    });
  }

  void _repeatLastOperation() {
    double currentVal = _parseToken(_expression);
    double result = 0;
    
    if (_lastOperator == '%') {
      result = currentVal / 100.0;
      _history = "${_addCommas(_formatValue(currentVal))}%";
    } else {
      switch (_lastOperator) {
        case '+': result = currentVal + _lastOperand!; break;
        case '-': result = currentVal - _lastOperand!; break;
        case '×': result = currentVal * _lastOperand!; break;
        case '÷': result = currentVal / _lastOperand!; break;
      }
      _history = "${_addCommas(_formatValue(currentVal))} $_lastOperator ${_addCommas(_formatValue(_lastOperand!))}";
    }
    
    _expression = _formatResult(result);
    _isResultDisplayed = true;
  }

  void _handleBackspace() {
    if (_expression.endsWith(' ')) {
      _expression = _expression.trim();
      _expression = _expression.substring(0, _expression.length - 1).trim();
    } else {
      List<String> tokens = _expression.split(' ');
      String lastToken = tokens.last;
      if (lastToken.length > 1) {
        if (lastToken.endsWith('%')) {
          tokens[tokens.length - 1] = lastToken.substring(0, lastToken.length - 1);
        } else if (RegExp(r'^\(.*\)$').hasMatch(lastToken)) {
          String numberPart = lastToken.substring(2, lastToken.length - 1).replaceAll(',', '');
          if (numberPart.length > 1) {
            tokens[tokens.length - 1] = '(-${_addCommas(numberPart.substring(0, numberPart.length - 1))})';
          } else {
            tokens[tokens.length - 1] = '0';
          }
        } else {
          String cleanNumber = lastToken.replaceAll(',', '');
          tokens[tokens.length - 1] = _addCommas(cleanNumber.substring(0, cleanNumber.length - 1));
        }
        _expression = tokens.join(' ');
      } else {
        if (tokens.length > 1) {
          tokens.removeLast();
          _expression = tokens.join(' ');
        } else {
          _expression = '0';
        }
      }
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
    if (tokens.isEmpty) return;

    String lastToken = tokens.last;
    if (RegExp(r'^\(.*\)$').hasMatch(lastToken)) {
      tokens[tokens.length - 1] = lastToken.substring(2, lastToken.length - 1);
    } else {
      String cleanNumber = lastToken.replaceAll(',', '');
      if (double.tryParse(cleanNumber) != null && cleanNumber != '0') {
        tokens[tokens.length - 1] = '(-$lastToken)';
      }
    }
    _expression = tokens.join(' ');
  }

  void _applyPercent() {
    List<String> tokens = _expression.trim().split(' ');
    String lastToken = tokens.last;
    
    if (lastToken.isNotEmpty && !lastToken.endsWith('%') && 
        (RegExp(r'[0-9,.]+$').hasMatch(lastToken) || RegExp(r'^\(.*\)$').hasMatch(lastToken))) {
      tokens[tokens.length - 1] = '$lastToken%';
      _expression = tokens.join(' ');
    }
  }

  double _parseToken(String token) {
    String clean = token.replaceAll('(', '').replaceAll(')', '').replaceAll(',', '');
    bool isPercent = clean.endsWith('%');
    if (isPercent) {
      clean = clean.substring(0, clean.length - 1);
    }
    double val = double.tryParse(clean) ?? 0;
    return isPercent ? val / 100 : val;
  }

  String _formatValue(double result) {
    String fixed = result.toStringAsFixed(10);
    double rounded = double.parse(fixed);
    String s = rounded.toString();

    if (!s.contains('e') && s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    }

    if (s.length > 13) {
      s = result.toStringAsPrecision(9);
      if (s.contains('e')) {
        List<String> parts = s.split('e');
        if (parts[0].contains('.')) {
          parts[0] = parts[0].replaceAll(RegExp(r'0+$'), '');
          if (parts[0].endsWith('.')) parts[0] = parts[0].substring(0, parts[0].length - 1);
        }
        s = parts.join('e');
      }
    }
    
    return _addCommas(s);
  }

  void _calculate() {
    try {
      String trimmed = _expression.trim();
      if (RegExp(r'[+×÷-]$').hasMatch(trimmed)) return;

      List<String> tokens = trimmed.split(' ');
      if (tokens.isEmpty) return;
// 단일 토큰(예: "88%") 계산 지원
if (tokens.length == 1) {
  double val = _parseToken(tokens[0]);
  setState(() {
    _history = _expression;
    // 단일 %인 경우 반복 연산을 위해 % 연산자 저장
    if (tokens[0].endsWith('%')) {
      _lastOperator = '%';
      _lastOperand = 100.0;
    }
    _expression = _formatResult(val);
    _isResultDisplayed = true;
  });
  return;
}

      _history = _expression;
      List<dynamic> values = [];
      for (var t in tokens) {
        if (RegExp(r'[+×÷-]').hasMatch(t) && t.length == 1) {
          values.add(t);
        } else {
          values.add(_parseToken(t));
        }
      }

      // 마지막 연산 정보 저장 (반복 계산용)
      if (tokens.length >= 3) {
        _lastOperator = tokens[tokens.length - 2];
        _lastOperand = _parseToken(tokens.last);
      }

      for (int i = 0; i < values.length; i++) {
        if (values[i] == '×' || values[i] == '÷') {
          double left = values[i - 1];
          double right = values[i + 1];
          double res = (values[i] == '×') ? left * right : left / right;
          values.removeAt(i - 1);
          values.removeAt(i - 1);
          values.removeAt(i - 1);
          values.insert(i - 1, res);
          i--;
        }
      }

      double finalRes = values[0];
      for (int i = 1; i < values.length; i += 2) {
        String op = values[i];
        double nextVal = values[i + 1];
        if (op == '+') finalRes += nextVal;
        if (op == '-') finalRes -= nextVal;
      }

      setState(() {
        _expression = _formatResult(finalRes);
        _isResultDisplayed = true;
      });
    } catch (e) {
      setState(() {
        _expression = 'Error';
        _isResultDisplayed = true;
      });
    }
  }

  String _formatResult(double result) {
    if (result.isInfinite || result.isNaN) return 'Error';
    String formatted = _formatValue(result);
    return result < 0 ? '($formatted)' : formatted;
  }

  Widget _buildButton(String text, Color bgColor, Color textColor) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            height: 70,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: text == '⌫' ? 24 : 28,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
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
                    _buildButton('⌫', Colors.grey[600]!, Colors.white),
                    _buildButton(
                      (_expression == '0' || _isResultDisplayed) ? 'AC' : 'C',
                      Colors.grey[400]!,
                      Colors.black,
                    ),
                    _buildButton('%', Colors.grey[400]!, Colors.black),
                    _buildButton('÷', Colors.orange, Colors.white),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('7', Colors.grey[850]!, Colors.white),
                    _buildButton('8', Colors.grey[850]!, Colors.white),
                    _buildButton('9', Colors.grey[850]!, Colors.white),
                    _buildButton('×', Colors.orange, Colors.white),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('4', Colors.grey[850]!, Colors.white),
                    _buildButton('5', Colors.grey[850]!, Colors.white),
                    _buildButton('6', Colors.grey[850]!, Colors.white),
                    _buildButton('-', Colors.orange, Colors.white),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('1', Colors.grey[850]!, Colors.white),
                    _buildButton('2', Colors.grey[850]!, Colors.white),
                    _buildButton('3', Colors.grey[850]!, Colors.white),
                    _buildButton('+', Colors.orange, Colors.white),
                  ],
                ),
                Row(
                  children: [
                    _buildButton('+/-', Colors.grey[850]!, Colors.white),
                    _buildButton('0', Colors.grey[850]!, Colors.white),
                    _buildButton('.', Colors.grey[850]!, Colors.white),
                    _buildButton('=', Colors.orange, Colors.white),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
