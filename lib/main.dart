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
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (text == 'AC' || text == 'C') {
        _display = '0';
        _firstOperand = null;
        _operator = null;
        _shouldResetDisplay = false;
      } else if (text == '+/-') {
        if (_display != '0') {
          if (_display.startsWith('-')) {
            _display = _display.substring(1);
          } else {
            _display = '-$_display';
          }
        }
      } else if (text == '%') {
        double val = double.parse(_display) / 100;
        _display = _formatResult(val);
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        _firstOperand = double.parse(_display);
        _operator = text;
        _shouldResetDisplay = true;
      } else if (text == '=') {
        if (_firstOperand != null && _operator != null) {
          double secondOperand = double.parse(_display);
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

  String _formatResult(double result) {
    if (result.isInfinite || result.isNaN) return 'Error';
    if (result == result.toInt()) {
      return result.toInt().toString();
    }
    String str = result.toString();
    if (str.length > 10) {
      return result.toStringAsPrecision(8);
    }
    return str;
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
                    _buildButton('AC', Colors.grey[400]!, Colors.black),
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
