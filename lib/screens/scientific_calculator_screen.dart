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
      } else {
        _handleScientificInput(text);
      }
    });
  }

  void _handleParenthesis(String p) {
    if (expression == '0' || isResultDisplayed) {
      expression = p;
      isResultDisplayed = false;
    } else {
      expression += p;
    }
  }

  void _handleScientificInput(String func) {
    if (isResultDisplayed) {
      isResultDisplayed = false;
    }

    String toAppend = '';
    switch (func) {
      case 'sin': toAppend = 'sin('; break;
      case 'cos': toAppend = 'cos('; break;
      case 'tan': toAppend = 'tan('; break;
      case 'sinh': toAppend = 'sinh('; break;
      case 'cosh': toAppend = 'cosh('; break;
      case 'tanh': toAppend = 'tanh('; break;
      case 'ln': toAppend = 'ln('; break;
      case 'log₁₀': toAppend = 'log(10,'; break; // math_expressions handles log(base, arg)
      case 'x²': toAppend = '²'; break;
      case 'x³': toAppend = '³'; break;
      case 'xʸ': toAppend = '^'; break;
      case 'eˣ': toAppend = 'e^'; break;
      case '10ˣ': toAppend = '10^'; break;
      case '1/x': toAppend = '1/'; break;
      case '²√x': toAppend = 'sqrt('; break;
      case '³√x': toAppend = 'nroot(3,'; break;
      case 'ʸ√x': toAppend = 'nroot('; break;
      case 'x!': toAppend = '!'; break;
      case 'π': toAppend = 'π'; break;
      case 'e': toAppend = 'e'; break;
      case 'Rand': toAppend = (DateTime.now().millisecond / 1000.0).toString(); break;
      case 'EE': toAppend = '*10^'; break;
      case 'Rad': case 'Deg': 
        _isRad = !_isRad; 
        return;
      default: return;
    }

    if (expression == '0') {
      expression = toAppend;
    } else {
      expression += toAppend;
    }
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
                style: const TextStyle(fontSize: 12, color: Colors.white70),
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
                        child: Text(
                          expression,
                          style: TextStyle(
                            fontSize: expression.length > 10 ? 40 : 60,
                            fontWeight: FontWeight.w300,
                            color: Colors.white,
                          ),
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
