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
  String _display = '0';
  double? _firstOperand;
  String? _operator;
  bool _shouldResetDisplay = false;

  void _onButtonPressed(String text) {
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        if (_display == '0' || _shouldResetDisplay) {
          _display = text;
          _shouldResetDisplay = false;
        } else {
          _display += text;
        }
      } else if (text == '.') {
        if (!_display.contains('.')) {
          _display += '.';
        }
      } else if (text == '⌫') {
        if (_display.startsWith('(') && _display.endsWith(')')) {
          _display = _display.substring(2, _display.length - 1);
          if (_display.isEmpty) _display = '0';
        } else if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (text == 'AC') {
        _display = '0';
        _firstOperand = null;
        _operator = null;
        _shouldResetDisplay = false;
      } else if (text == 'C') {
        _display = '0';
      } else if (text == '+/-') {
        if (_display != '0') {
          if (_display.startsWith('(') && _display.endsWith(')')) {
            _display = _display.substring(2, _display.length - 1);
          } else {
            _display = '(-$_display)';
          }
        }
      } else if (text == '%') {
        double val = _parseDisplay(_display) / 100;
        _display = _formatResult(val);
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        _firstOperand = _parseDisplay(_display);
        _operator = text;
        _shouldResetDisplay = true;
      } else if (text == '=') {
        if (_firstOperand != null && _operator != null) {
          double secondOperand = _parseDisplay(_display);
          double result = 0;
          switch (_operator) {
            case '+':
              result = _firstOperand! + secondOperand;
              break;
            case '-':
              result = _firstOperand! - secondOperand;
              break;
            case '×':
              result = _firstOperand! * secondOperand;
              break;
            case '÷':
              result = _firstOperand! / secondOperand;
              break;
          }
          _display = _formatResult(result);
          _firstOperand = null;
          _operator = null;
          _shouldResetDisplay = true;
        }
      }
    });
  }

  double _parseDisplay(String text) {
    String cleanText = text;
    if (text.startsWith('(') && text.endsWith(')')) {
      cleanText = text.substring(1, text.length - 1);
    }
    return double.tryParse(cleanText) ?? 0;
  }

  String _formatResult(double result) {
    if (result.isInfinite || result.isNaN) return 'Error';
    String formatted;
    if (result == result.toInt()) {
      formatted = result.toInt().toString();
    } else {
      String str = result.toString();
      formatted = str.length > 10 ? result.toStringAsPrecision(8) : str;
    }
    
    return result < 0 ? '($formatted)' : formatted;
  }

  Widget _buildButton(String text, Color bgColor, Color textColor, {bool isWide = false}) {
    return Expanded(
      flex: isWide ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          borderRadius: BorderRadius.circular(50),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: bgColor,
              shape: isWide ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isWide ? BorderRadius.circular(50) : null,
            ),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Text(
                  _display,
                  style: const TextStyle(
                    fontSize: 70,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    _buildButton('⌫', Colors.grey[600]!, Colors.white),
                    _buildButton(
                      (_display == '0' || _shouldResetDisplay) ? 'AC' : 'C',
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
