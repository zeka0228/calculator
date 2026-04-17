import 'package:flutter/material.dart';
import '../widgets/calculator_button.dart';
import '../logic/calculator_base.dart';

class BasicCalculatorScreen extends StatefulWidget {
  const BasicCalculatorScreen({super.key});

  @override
  State<BasicCalculatorScreen> createState() => _BasicCalculatorScreenState();
}

class _BasicCalculatorScreenState extends State<BasicCalculatorScreen> with CalculatorBase {
  void _onButtonPressed(String text) {
    setState(() {
      if (RegExp(r'^[0-9]$').hasMatch(text)) {
        handleNumber(text);
      } else if (text == '.') {
        handleDot();
      } else if (text == '⌫') {
        handleBackspace();
      } else if (text == 'AC') {
        clearAll();
      } else if (text == 'C') {
        clearEntry();
      } else if (text == '+/-') {
        toggleSign();
      } else if (text == '%') {
        applyPercent();
      } else if (text == '+' || text == '-' || text == '×' || text == '÷') {
        handleOperator(text);
      } else if (text == '=') {
        handleEquals();
      }
    });
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
                  reverse: true,
                  scrollDirection: Axis.horizontal,
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
        ),
        Column(
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
            const SizedBox(height: 20),
          ],
        ),
      ],
    );
  }
}
