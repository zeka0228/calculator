import 'dart:async';

import 'package:flutter/material.dart';
import '../data/converter_controller.dart';
import '../widgets/calculator_button.dart';
import '../logic/calculator_base.dart';
import 'converter_display.dart';

/// 기본 계산기 화면.
/// `showConverter`가 true이면 디스플레이만 ConverterDisplay로 교체되고,
/// 키패드는 그대로 동작한다 (변환 모드 호스트 역할).
class BasicCalculatorScreen extends StatefulWidget {
  final bool showConverter;
  final ConverterController? converterController;
  const BasicCalculatorScreen({
    super.key,
    this.showConverter = false,
    this.converterController,
  });

  @override
  State<BasicCalculatorScreen> createState() => _BasicCalculatorScreenState();
}

class _BasicCalculatorScreenState extends State<BasicCalculatorScreen> with CalculatorBase {
  void _onButtonPressed(String text) {
    setState(() {
      const errorStates = {'정의되지 않음', '오버플로', 'Error'};
      if (isResultDisplayed && errorStates.contains(expression)) {
        if (text == 'AC' || text == 'C' || text == '⌫') {
          clearAll();
          return;
        }
        bool isStartFresh = RegExp(r'^[0-9]$').hasMatch(text) || text == '.';
        if (!isStartFresh) return;
      }

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
        // 변환 모드에서 `=` 누르면 일반 계산 결과 외에 현재 변환 스냅샷도 history에 추가.
        const errorStates = {'정의되지 않음', '오버플로', 'Error'};
        final controller = widget.converterController;
        if (widget.showConverter &&
            controller != null &&
            !errorStates.contains(expression)) {
          unawaited(saveConversionToHistory(
            sourceText: expression,
            controller: controller,
          ));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showConverter =
        widget.showConverter && widget.converterController != null;
    return Column(
      children: [
        Expanded(
          child: showConverter
              ? ConverterDisplay(
                  sourceText: expression,
                  controller: widget.converterController!,
                )
              : Container(
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
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
                            style: const TextStyle(
                                fontSize: 24,
                                color: Colors.grey,
                                fontWeight: FontWeight.w400),
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
