import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../data/calc_history_repository.dart';

abstract interface class CalcHistoryRestorable {
  void restoreFromHistory(String historyText, String resultText);
}

mixin CalculatorBase<T extends StatefulWidget> on State<T>
    implements CalcHistoryRestorable {
  String expression = '0';
  String history = '';
  bool isResultDisplayed = false;
  String? lastOp;
  String? lastOperandStr;

  String get historyMode => 'basic';

  @override
  void restoreFromHistory(String historyText, String resultText) {
    setState(() {
      history = historyText;
      expression = resultText;
      isResultDisplayed = true;
      lastOp = null;
      lastOperandStr = null;
    });
  }

  /// 현재 수식에서 최상위 마지막 이항 연산자와 우항을 추출해 lastOp/lastOperandStr에 저장.
  /// 우항이 단순 숫자가 아니면 둘 다 null.
  void extractLastOp() {
    int depth = 0;
    for (int i = expression.length - 1; i >= 0; i--) {
      String ch = expression[i];
      if (ch == ')') {
        depth++;
      } else if (ch == '(') {
        depth--;
      } else if (depth == 0 && (ch == '+' || ch == '-' || ch == '×' || ch == '÷')) {
        if (ch == '-') {
          if (i == 0) continue;
          String prev = expression[i - 1];
          if ('+-×÷(^'.contains(prev)) continue;
        }
        String operand = expression.substring(i + 1);
        if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(operand)) {
          lastOp = ch;
          lastOperandStr = operand;
        } else {
          lastOp = null;
          lastOperandStr = null;
        }
        return;
      }
    }
    lastOp = null;
    lastOperandStr = null;
  }

  /// =을 누르기 직전에 호출. 반복 모드로 진입할 수 있으면 수식에 lastOp를 덧붙이고 true 반환.
  /// 반환값이 false면 =을 무시해야 함.
  bool prepareEquals() {
    if (isResultDisplayed) {
      if (lastOp == null || lastOperandStr == null) return false;
      expression = expression + lastOp! + lastOperandStr!;
      isResultDisplayed = false;
      return true;
    }
    extractLastOp();
    return true;
  }

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
    String savedExpression = expression;
    bool savedIsResultDisplayed = isResultDisplayed;
    String? savedLastOp = lastOp;
    String? savedLastOperandStr = lastOperandStr;

    if (!prepareEquals()) return;
    calculateAdvanced();

    if (expression == 'Error') {
      expression = savedExpression;
      isResultDisplayed = savedIsResultDisplayed;
      lastOp = savedLastOp;
      lastOperandStr = savedLastOperandStr;
      return;
    }

    saveCurrentToHistory();
  }

  /// 성공 결과를 history 테이블에 저장. expression이 에러 상태이거나
  /// history가 비어있으면 스킵. 양 계산기 화면이 공통으로 호출.
  void saveCurrentToHistory() {
    const errorStates = {'Error', '오버플로', '정의되지 않음'};
    if (errorStates.contains(expression) || history.isEmpty) {
      debugPrint(
          '[history] skipped (state="$expression", history="$history")');
      return;
    }
    final exprToSave = history;
    final resultToSave = expression;
    CalcHistoryRepository.instance
        .insert(exprToSave, resultToSave, mode: historyMode)
        .then(
      (id) {
        debugPrint(
            '[history] saved id=$id mode=$historyMode  $exprToSave = $resultToSave');
      },
      onError: (e, st) {
        debugPrint('[history] save FAILED: $e\n$st');
      },
    );
  }

  void clearAll() {
    expression = '0';
    history = '';
    isResultDisplayed = false;
    lastOp = null;
    lastOperandStr = null;
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
    if (result.isNaN) return '정의되지 않음';
    if (result.isInfinite) return '오버플로';
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
      String errMsg = e.toString().toLowerCase();
      if (errMsg.contains('infinity') || errMsg.contains('overflow')) {
        expression = '오버플로';
      } else {
        expression = 'Error';
      }
      isResultDisplayed = true;
    }
  }
}
