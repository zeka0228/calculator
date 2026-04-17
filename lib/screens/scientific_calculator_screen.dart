import 'package:flutter/material.dart';
import '../widgets/calculator_button.dart';
import '../logic/calculator_base.dart';
import 'package:math_expressions/math_expressions.dart';

class ScientificCalculatorScreen extends StatefulWidget {
  const ScientificCalculatorScreen({super.key});

  @override
  State<ScientificCalculatorScreen> createState() => _ScientificCalculatorScreenState();
}

class _ScientificCalculatorScreenState extends State<ScientificCalculatorScreen> with CalculatorBase {
  bool _isRad = true;
  double _memoryValue = 0;
  bool _isMemorySet = false;

  void _onButtonPressed(String text) {
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        handleNumber(text);
      } else if (text == '.') {
        handleDot();
      } else if (text == 'AC') {
        clearAll();
      } else if (text == 'C') {
        clearEntry();
      } else if (text == '⌫') {
        handleBackspace();
      } else if (text == '+/-') {
        toggleSign();
      } else if (text == '%') {
        applyPercent();
      } else if (['+', '-', '×', '÷'].contains(text)) {
        handleOperator(text);
      } else if (text == '=') {
        _calculateWithScientific();
      } else if (text == '(' || text == ')') {
        _handleParenthesis(text);
      } else if (['mc', 'm+', 'm-', 'mr'].contains(text)) {
        _handleMemory(text);
      } else {
        _handleScientificInput(text);
      }
    });
  }

  void _handleMemory(String op) {
    if (op == 'mc') {
      setState(() {
        _memoryValue = 0;
        _isMemorySet = false;
      });
      return;
    }

    if (op == 'mr') {
      if (_isMemorySet) {
        setState(() {
          if (expression == '0' || isResultDisplayed) {
            expression = formatValue(_memoryValue);
          } else {
            if (_shouldPrependMultiplication()) expression += '×';
            expression += formatValue(_memoryValue);
          }
          isResultDisplayed = false;
        });
      }
      return;
    }

    // m+ 또는 m- 인 경우
    if (_isMemorySet) return; // 이미 메모리가 설정되어 있으면 무시

    double currentVal = 0;
    try {
      // 현재 수식 전체의 계산 결과를 가져옴
      String finalExpression = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793')
          .replaceAll('e', '2.718281828459045')
          .replaceAll('²', '^2')
          .replaceAll('³', '^3')
          .replaceAll('ln(', 'log(');

      GrammarParser p = GrammarParser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();
      currentVal = exp.evaluate(EvaluationType.REAL, cm);
    } catch (_) {
      // 파싱 실패 시 마지막 숫자만이라도 시도
      try {
        String lastPart = expression.split(RegExp(r'[+\-×÷()^]')).last;
        currentVal = parseToken(lastPart);
      } catch (_) {
        currentVal = 0;
      }
    }

    setState(() {
      _memoryValue = (op == 'm+') ? currentVal : -currentVal;
      _isMemorySet = true;
    });
  }

  void _handleParenthesis(String p) {
    if (isResultDisplayed) {
      if (p == '(') {
        expression = p;
        isResultDisplayed = false;
      }
      return;
    }

    if (p == '(') {
      if (_shouldPrependMultiplication()) {
        expression += '×';
      }
      if (expression == '0') {
        expression = p;
      } else {
        expression += p;
      }
    } else if (p == ')') {
      // 닫아야 할 괄호가 있고, 바로 앞이 여는 괄호가 아닐 때만 입력 허용
      int missing = _getMissingParenthesesCount();
      if (missing > 0 && !expression.endsWith('(')) {
        expression += p;
      }
    }
  }

  bool _shouldPrependMultiplication() {
    if (expression.isEmpty || expression == '0') return false;
    String lastChar = expression.substring(expression.length - 1);
    // 숫자, π, e, 닫는 괄호, 팩토리얼 뒤에는 곱셈 생략 시 자동 삽입
    return RegExp(r'[0-9πe)!]$').hasMatch(lastChar);
  }

  void _handleScientificInput(String func) {
    if (isResultDisplayed) {
      isResultDisplayed = false;
    }

    String toAppend = '';
    bool isPrefixFunc = false; // sin(, log( 처럼 앞에 붙는 함수인지 여부

    switch (func) {
      case 'sin': toAppend = 'sin('; isPrefixFunc = true; break;
      case 'cos': toAppend = 'cos('; isPrefixFunc = true; break;
      case 'tan': toAppend = 'tan('; isPrefixFunc = true; break;
      case 'sinh': toAppend = 'sinh('; isPrefixFunc = true; break;
      case 'cosh': toAppend = 'cosh('; isPrefixFunc = true; break;
      case 'tanh': toAppend = 'tanh('; isPrefixFunc = true; break;
      case 'ln': toAppend = 'ln('; isPrefixFunc = true; break;
      case 'log₁₀': toAppend = 'log(10,'; isPrefixFunc = true; break;
      case 'x²': toAppend = '²'; break;
      case 'x³': toAppend = '³'; break;
      case 'xʸ': toAppend = '^'; break;
      case 'eˣ': toAppend = 'e^'; break;
      case '10ˣ': toAppend = '10^'; break;
      case '1/x': 
        if (_shouldPrependMultiplication()) expression += '×';
        toAppend = '1/'; 
        break;
      case '²√x': toAppend = 'sqrt('; isPrefixFunc = true; break;
      case '³√x': toAppend = 'nroot(3,'; isPrefixFunc = true; break;
      case 'ʸ√x': toAppend = 'nroot('; isPrefixFunc = true; break;
      case 'x!': toAppend = '!'; break;
      case 'π': 
        if (_shouldPrependMultiplication()) expression += '×';
        toAppend = 'π'; 
        break;
      case 'e': 
        if (_shouldPrependMultiplication()) expression += '×';
        toAppend = 'e'; 
        break;
      case 'Rand': 
        if (_shouldPrependMultiplication()) expression += '×';
        toAppend = (DateTime.now().millisecond / 1000.0).toString(); 
        break;
      case 'EE': toAppend = '*10^'; break;
      case 'Rad': case 'Deg': 
        _isRad = !_isRad; 
        return;
      default: return;
    }

    if (isPrefixFunc && _shouldPrependMultiplication()) {
      expression += '×';
    }

    if (expression == '0' && (isPrefixFunc || toAppend == 'π' || toAppend == 'e')) {
      expression = toAppend;
    } else {
      expression += toAppend;
    }
  }

  int _getMissingParenthesesCount() {
    int openCount = '('.allMatches(expression).length;
    int closeCount = ')'.allMatches(expression).length;
    int missing = openCount - closeCount;
    return missing > 0 ? missing : 0;
  }

  void _calculateWithScientific() {
    try {
      String finalExpression = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793')
          .replaceAll('e', '2.718281828459045')
          .replaceAll('²', '^2')
          .replaceAll('³', '^3')
          .replaceAll('ln(', 'log('); // math_expressions uses log for natural log
      
      // Degree/Radian conversion
      if (!_isRad) {
        // This is tricky with string replacement. 
        // A better way would be to custom parse or adjust the input.
        // For now, let's assume Radian as default or notify it's in progress.
      }

      GrammarParser p = GrammarParser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      history = expression;
      expression = formatValue(eval);
      isResultDisplayed = true;
    } catch (e) {
      expression = 'Error';
      isResultDisplayed = true;
    }
  }

  Widget _buildExtraButton(String text) {
    bool isMemoryActive = text == 'mr' && _isMemorySet;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isMemoryActive ? Colors.orange : Colors.white70,
                  fontWeight: isMemoryActive ? FontWeight.bold : FontWeight.normal,
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
    return Column(
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Stack(
              children: [
                if (_isRad)
                  const Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Rad',
                        style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (history.isNotEmpty)
                        SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            history,
                            style: const TextStyle(fontSize: 24, color: Colors.grey, fontWeight: FontWeight.w400),
                          ),
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              expression,
                              style: TextStyle(
                                fontSize: expression.length > 10 ? 40 : 60,
                                fontWeight: FontWeight.w300,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              ')' * _getMissingParenthesesCount(),
                              style: TextStyle(
                                fontSize: expression.length > 10 ? 40 : 60,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                children: [
                  _buildExtraButton('('), _buildExtraButton(')'), _buildExtraButton('mc'),
                  _buildExtraButton('m+'), _buildExtraButton('m-'), _buildExtraButton('mr'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('2ⁿᵈ'), _buildExtraButton('x²'), _buildExtraButton('x³'),
                  _buildExtraButton('xʸ'), _buildExtraButton('eˣ'), _buildExtraButton('10ˣ'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('1/x'), _buildExtraButton('²√x'), _buildExtraButton('³√x'),
                  _buildExtraButton('ʸ√x'), _buildExtraButton('ln'), _buildExtraButton('log₁₀'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('x!'), _buildExtraButton('sin'), _buildExtraButton('cos'),
                  _buildExtraButton('tan'), _buildExtraButton('e'), _buildExtraButton('EE'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('Rand'), _buildExtraButton('sinh'), _buildExtraButton('cosh'),
                  _buildExtraButton('tanh'), _buildExtraButton('π'), _buildExtraButton(_isRad ? 'Rad' : 'Deg'),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            children: [
              Row(
                children: [
                  CalculatorButton(text: '⌫', bgColor: Colors.grey[600]!, textColor: Colors.white, onTap: () => _onButtonPressed('⌫')),
                  CalculatorButton(
                    text: (expression == '0' || isResultDisplayed) ? 'AC' : 'C',
                    bgColor: Colors.grey[400]!,
                    textColor: Colors.black,
                    onTap: () => _onButtonPressed((expression == '0' || isResultDisplayed) ? 'AC' : 'C'),
                  ),
                  CalculatorButton(text: '%', bgColor: Colors.grey[400]!, textColor: Colors.black, onTap: () => _onButtonPressed('%')),
                  CalculatorButton(text: '÷', bgColor: Colors.orange, textColor: Colors.white, onTap: () => _onButtonPressed('÷')),
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
            ],
          ),
        ),
      ],
    );
  }
}
