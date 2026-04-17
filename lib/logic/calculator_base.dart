import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

mixin CalculatorBase<T extends StatefulWidget> on State<T> {
  String expression = '0';
  String history = '';
  bool isResultDisplayed = false;

  void handleNumber(String text) {
    if (expression == '0' || isResultDisplayed) {
      if (isResultDisplayed) history = '';
      expression = text;
      isResultDisplayed = false;
    } else {
      // 숫자를 그대로 붙임 (콤마 로직은 디스플레이 시점에 처리하는 것이 수식 파싱에 유리함)
      expression += text;
    }
  }

  void handleDot() {
    if (isResultDisplayed) {
      history = '';
      expression = '0.';
      isResultDisplayed = false;
      return;
    }
    // 마지막 숫자에 이미 점이 있는지 확인
    String lastPart = expression.split(RegExp(r'[+\-×÷()]')).last;
    if (!lastPart.contains('.')) {
      expression += '.';
    }
  }

  void handleOperator(String op) {
    if (isResultDisplayed) {
      isResultDisplayed = false;
      // 결과값에서 이어서 연산 가능하도록 유지
    }
    String trimmed = expression.trim();
    if (trimmed.isEmpty) return;

    if (RegExp(r'[+×÷-]$').hasMatch(trimmed)) {
      expression = trimmed.substring(0, trimmed.length - 1) + op;
    } else {
      expression = '$trimmed$op';
    }
  }

  void handleEquals() {
    calculateAdvanced();
  }

  void clearAll() {
    expression = '0';
    history = '';
    isResultDisplayed = false;
  }

  void clearEntry() {
    clearAll();
  }

  void handleBackspace() {
    if (isResultDisplayed) {
      history = '';
      return;
    }
    if (expression.length > 1) {
      expression = expression.substring(0, expression.length - 1);
    } else {
      expression = '0';
    }
  }

  void toggleSign() {
    if (isResultDisplayed) isResultDisplayed = false;
    if (expression == '0') return;
    
    if (expression.startsWith('-')) {
      expression = expression.substring(1);
    } else {
      expression = '-$expression';
    }
  }

  void applyPercent() {
    calculateAdvanced();
    if (expression != 'Error') {
      double val = double.tryParse(expression.replaceAll(',', '')) ?? 0;
      expression = formatValue(val / 100.0);
    }
  }

  double parseToken(String token) {
    String clean = token.replaceAll('(', '').replaceAll(')', '').replaceAll(',', '');
    return double.tryParse(clean) ?? 0;
  }

  String addCommas(String s) {
    if (s.isEmpty || s == 'Error') return s;
    List<String> parts = s.split('.');
    RegExp reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAll(reg, ',');
    return parts.join('.');
  }

  String formatValue(double result) {
    if (result.isInfinite) return '오버플로';
    if (result.isNaN) return 'Error';
    if (result == 0) return '0';
    
    // 소수점 이하 자리수 처리
    String s;
    if (result == result.toInt()) {
      s = result.toInt().toString();
    } else {
      s = result.toStringAsFixed(10);
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  void calculateAdvanced() {
    try {
      String finalExpression = expression
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793')
          .replaceAll('e', '2.718281828459045')
          .replaceAll('²', '^2')
          .replaceAll('³', '^3');
      
      // yroot(y, x) 처리를 위한 로직이나 기타 커스텀 변환 필요 시 추가
      
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
}
