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
  bool _is2nd = false;
  double _memoryValue = 0;
  bool _isMemorySet = false;

  // 펜딩 입력 상태 (y 같은 보조 인자를 나중에 입력받는 함수용)
  bool _awaitingPending = false;
  String _pendingPrefix = ''; // unwrap 시 제거할 앞부분
  String _pendingSuffix = ''; // unwrap 시 제거할 뒷부분
  int _pendingStart = 0; // 사용자 입력이 시작되는 위치
  int _pendingPos = 0; // 현재 삽입 위치
  bool _pendingSubscript = false; // 입력 숫자를 아래첨자로 변환할지 여부

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
        // 숫자·점 입력은 handleNumber/handleDot이 isResultDisplayed 보고 새로 시작
      }

      if (_awaitingPending) {
        // logᵧ 펜딩 중 또 logᵧ를 누르면 바깥 log로 감싸되 펜딩은 안쪽(기존 대상)에 유지
        if (_pendingSubscript && text == 'logᵧ' &&
            expression != '0' && expression.isNotEmpty) {
          expression = 'log($expression)';
          _pendingStart += 4;
          _pendingPos += 4;
          return;
        }
        if (RegExp(r'^[0-9]$').hasMatch(text)) {
          String toInsert = _pendingSubscript ? _toSubscript(text) : text;
          expression = expression.substring(0, _pendingPos) +
              toInsert +
              expression.substring(_pendingPos);
          _pendingPos += 1;
          return;
        }
        if (text == '.' && !_pendingSubscript) {
          String yPart = expression.substring(_pendingStart, _pendingPos);
          if (!yPart.contains('.')) {
            expression = expression.substring(0, _pendingPos) +
                text +
                expression.substring(_pendingPos);
            _pendingPos += 1;
          }
          return;
        }
        if (text == '⌫') {
          if (_pendingPos > _pendingStart) {
            expression = expression.substring(0, _pendingPos - 1) +
                expression.substring(_pendingPos);
            _pendingPos -= 1;
          } else {
            if (_pendingPrefix.isNotEmpty &&
                expression.startsWith(_pendingPrefix) &&
                expression.endsWith(_pendingSuffix)) {
              expression = expression.substring(
                  _pendingPrefix.length,
                  expression.length - _pendingSuffix.length);
              if (expression.isEmpty) expression = '0';
            }
            _awaitingPending = false;
          }
          return;
        }
        _awaitingPending = false;
      }

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
      String preprocessed = _convertScientificNotation(expression);
      preprocessed = _convertInverseHyperbolic(preprocessed);
      preprocessed = _convertHyperbolic(preprocessed);
      preprocessed = preprocessed
          .replaceAll('sin⁻¹(', 'arcsin(')
          .replaceAll('cos⁻¹(', 'arccos(')
          .replaceAll('tan⁻¹(', 'arctan(');
      if (!_isRad) {
        preprocessed = _convertDegrees(preprocessed);
      }
      String finalExpression = preprocessed
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793')
          .replaceAll('e', '2.718281828459045')
          ;
      finalExpression = _convertCubeRoot(finalExpression);
      finalExpression = _convertNRoot(finalExpression);
      finalExpression = _convertLogSubscript(finalExpression);
      finalExpression = finalExpression
          .replaceAll('√(', 'sqrt(')
          .replaceAll('²', '^2')
          .replaceAll('³', '^3');

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
        _activateLogSubscriptIfClosed();
      }
    }
  }

  /// 방금 닫은 ')'가 'log(' 여는 괄호와 매칭되면 아래첨자 입력 펜딩 활성화.
  void _activateLogSubscriptIfClosed() {
    if (!expression.endsWith(')')) return;
    int depth = 1;
    int i = expression.length - 2;
    while (i >= 0 && depth > 0) {
      if (expression[i] == ')') {
        depth++;
      } else if (expression[i] == '(') {
        depth--;
      }
      if (depth > 0) i--;
    }
    if (i < 3) return;
    if (expression.substring(i - 3, i) != 'log') return;
    // 'log' 앞에 글자가 이어져 있으면(예: 존재하지 않지만 혹시 'arclog' 같은) 건드리지 않음
    if (i - 3 > 0 && RegExp(r'[a-zA-Z]').hasMatch(expression[i - 4])) return;
    _awaitingPending = true;
    _pendingPrefix = 'log(';
    _pendingSuffix = ')';
    _pendingStart = i;
    _pendingPos = i;
    _pendingSubscript = true;
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

    switch (func) {
      case 'sin':
        if (expression != '0') {
          expression = 'sin($expression)';
        } else {
          expression = 'sin(';
        }
        return;
      case 'cos':
        if (expression != '0') {
          expression = 'cos($expression)';
        } else {
          expression = 'cos(';
        }
        return;
      case 'tan':
        if (expression != '0') {
          expression = 'tan($expression)';
        } else {
          expression = 'tan(';
        }
        return;
      case 'sinh':
        if (expression != '0') {
          expression = 'sinh($expression)';
        } else {
          expression = 'sinh(';
        }
        return;
      case 'cosh':
        if (expression != '0') {
          expression = 'cosh($expression)';
        } else {
          expression = 'cosh(';
        }
        return;
      case 'tanh':
        if (expression != '0') {
          expression = 'tanh($expression)';
        } else {
          expression = 'tanh(';
        }
        return;
      case 'ln':
        if (expression != '0') {
          expression = 'ln($expression)';
        } else {
          expression = 'ln(';
        }
        return;
      case 'log₁₀':
        if (expression != '0') {
          expression = 'log₁₀($expression)';
        } else {
          expression = 'log₁₀(';
        }
        return;
      case 'x²': 
        if (expression != '0') {
          expression = '($expression)²';
          return;
        }
        toAppend = '²'; 
        break;
      case 'x³': 
        if (expression != '0') {
          expression = '($expression)³';
          return;
        }
        toAppend = '³'; 
        break;
      case 'xʸ': 
        if (expression != '0' && !expression.endsWith('(')) {
          expression = '($expression)^';
          return;
        }
        toAppend = '^'; 
        break;
      case 'eˣ': 
        if (expression != '0') {
          expression = 'e^($expression)';
          return;
        }
        toAppend = 'e^'; 
        break;
      case '10ˣ': 
        if (expression != '0') {
          expression = '10^($expression)';
          return;
        }
        toAppend = '10^'; 
        break;
      case '1/x':
        if (expression != '0') {
          expression = '(1÷$expression)';
        } else {
          expression = '(1÷';
        }
        return;
      case '²√x':
        if (expression != '0') {
          expression = '√($expression)';
        } else {
          expression = '√(';
        }
        return;
      case '³√x':
        if (expression != '0') {
          expression = '³√($expression)';
        } else {
          expression = '³√(';
        }
        return;
      case 'ʸ√x':
        if (expression == '0' || expression.isEmpty) {
          return;
        }
        expression = '√($expression)';
        _awaitingPending = true;
        _pendingPrefix = '√(';
        _pendingSuffix = ')';
        _pendingStart = 0;
        _pendingPos = 0;
        _pendingSubscript = false;
        return;
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
      case 'EE':
        if (expression == '0' || expression.isEmpty) return;
        if (expression.endsWith('e')) return;
        expression += 'e';
        return;
      case 'Rad': case 'Deg':
        _isRad = !_isRad;
        return;
      case '2ⁿᵈ':
        _is2nd = !_is2nd;
        return;
      case 'yˣ':
        if (expression == '0' || expression.isEmpty) return;
        expression = '^($expression)';
        _awaitingPending = true;
        _pendingPrefix = '^(';
        _pendingSuffix = ')';
        _pendingStart = 0;
        _pendingPos = 0;
        _pendingSubscript = false;
        return;
      case '2ˣ':
        if (expression != '0') {
          expression = '2^($expression)';
          return;
        }
        toAppend = '2^';
        break;
      case 'logᵧ':
        if (expression == '0' || expression.isEmpty) {
          expression = 'log(';
          return;
        }
        // 열린 괄호로 끝나면 (log( 이나 log(log(...) 체이닝) 그대로 log( 이어붙임
        if (expression.endsWith('(')) {
          expression += 'log(';
          return;
        }
        expression = 'log($expression)';
        _awaitingPending = true;
        _pendingPrefix = 'log(';
        _pendingSuffix = ')';
        _pendingStart = 3; // 'log' 바로 뒤
        _pendingPos = 3;
        _pendingSubscript = true;
        return;
      case 'log₂':
        if (expression != '0') {
          expression = 'log₂($expression)';
        } else {
          expression = 'log₂(';
        }
        return;
      case 'sin⁻¹':
        if (expression != '0') {
          expression = 'sin⁻¹($expression)';
        } else {
          expression = 'sin⁻¹(';
        }
        return;
      case 'cos⁻¹':
        if (expression != '0') {
          expression = 'cos⁻¹($expression)';
        } else {
          expression = 'cos⁻¹(';
        }
        return;
      case 'tan⁻¹':
        if (expression != '0') {
          expression = 'tan⁻¹($expression)';
        } else {
          expression = 'tan⁻¹(';
        }
        return;
      case 'sinh⁻¹':
        if (expression != '0') {
          expression = 'sinh⁻¹($expression)';
        } else {
          expression = 'sinh⁻¹(';
        }
        return;
      case 'cosh⁻¹':
        if (expression != '0') {
          expression = 'cosh⁻¹($expression)';
        } else {
          expression = 'cosh⁻¹(';
        }
        return;
      case 'tanh⁻¹':
        if (expression != '0') {
          expression = 'tanh⁻¹($expression)';
        } else {
          expression = 'tanh⁻¹(';
        }
        return;
      default: return;
    }

    if (expression == '0' && (toAppend == 'π' || toAppend == 'e')) {
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

  /// y√(내용) → (내용)^(1/y) 변환. y는 √( 직전의 숫자 또는 괄호 그룹.
  String _convertNRoot(String expr) {
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      if (expr.startsWith('√(', i) && result.isNotEmpty) {
        String prefix = result.toString();
        String lastChar = prefix[prefix.length - 1];
        String? y;
        int? cutIdx;

        if (lastChar == ')') {
          int depth = 1;
          int j = prefix.length - 2;
          while (j >= 0 && depth > 0) {
            if (prefix[j] == ')') depth++;
            if (prefix[j] == '(') depth--;
            if (depth > 0) j--;
          }
          if (j >= 0) {
            y = prefix.substring(j);
            cutIdx = j;
          }
        } else if (RegExp(r'[0-9.]').hasMatch(lastChar)) {
          int j = prefix.length - 1;
          while (j >= 0 && RegExp(r'[0-9.]').hasMatch(prefix[j])) {
            j--;
          }
          y = prefix.substring(j + 1);
          cutIdx = j + 1;
        }

        if (y != null && y.isNotEmpty && cutIdx != null) {
          result.clear();
          result.write(prefix.substring(0, cutIdx));
          i += 2;
          int depth = 1;
          int start = i;
          while (i < expr.length && depth > 0) {
            if (expr[i] == '(') depth++;
            if (expr[i] == ')') depth--;
            if (depth > 0) i++;
          }
          String inner = _convertNRoot(expr.substring(start, i));
          result.write('($inner)^(1/$y)');
          if (i < expr.length) i++;
          continue;
        }
      }
      result.write(expr[i]);
      i++;
    }
    return result.toString();
  }

  String _toSubscript(String digit) {
    const map = {
      '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
      '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    };
    return map[digit] ?? digit;
  }

  /// log 아래첨자 처리: log(x) → ln(x), log₂(x) → log(2,x), log₁₀(x) → log(10,x) 등.
  String _convertLogSubscript(String expr) {
    return expr.replaceAllMapped(
      RegExp(r'log([₀₁₂₃₄₅₆₇₈₉]*)\('),
      (m) {
        String subDigits = m[1]!;
        if (subDigits.isEmpty) {
          return 'ln(';
        }
        String base = subDigits
            .replaceAll('₀', '0')
            .replaceAll('₁', '1')
            .replaceAll('₂', '2')
            .replaceAll('₃', '3')
            .replaceAll('₄', '4')
            .replaceAll('₅', '5')
            .replaceAll('₆', '6')
            .replaceAll('₇', '7')
            .replaceAll('₈', '8')
            .replaceAll('₉', '9');
        return 'log($base,';
      },
    );
  }

  /// Deg 모드일 때 sin/cos/tan 인자를 도→라디안으로 변환하고,
  /// arcsin/arccos/arctan 결과를 라디안→도로 변환.
  String _convertDegrees(String expr) {
    const argFuncs = ['sin(', 'cos(', 'tan('];
    const resultFuncs = ['arcsin(', 'arccos(', 'arctan('];
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      bool precededByLetter = i > 0 && RegExp(r'[a-zA-Z]').hasMatch(expr[i - 1]);

      // arcsin/arccos/arctan: 결과에 *180/π 적용
      String? resMatch;
      for (String f in resultFuncs) {
        if (expr.startsWith(f, i)) {
          resMatch = f;
          break;
        }
      }
      if (resMatch != null && !precededByLetter) {
        String name = resMatch.substring(0, resMatch.length - 1);
        i += resMatch.length;
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') {
            depth++;
          } else if (expr[i] == ')') {
            depth--;
          }
          if (depth > 0) i++;
        }
        String inner = _convertDegrees(expr.substring(start, i));
        result.write('($name($inner)*180/π)');
        if (i < expr.length) i++;
        continue;
      }

      // sin/cos/tan: 인자를 *π/180 래핑
      String? argMatch;
      for (String f in argFuncs) {
        if (expr.startsWith(f, i)) {
          argMatch = f;
          break;
        }
      }
      if (argMatch != null && !precededByLetter) {
        String name = argMatch.substring(0, argMatch.length - 1);
        i += argMatch.length;
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') {
            depth++;
          } else if (expr[i] == ')') {
            depth--;
          }
          if (depth > 0) i++;
        }
        String inner = _convertDegrees(expr.substring(start, i));
        result.write('$name(($inner)*π/180)');
        if (i < expr.length) i++;
        continue;
      }

      result.write(expr[i]);
      i++;
    }
    return result.toString();
  }

  /// sinh⁻¹/cosh⁻¹/tanh⁻¹(x)를 ln 기반 정체성으로 변환.
  /// e 치환 이전에 호출되어 π/e를 심볼 그대로 사용 가능.
  String _convertInverseHyperbolic(String expr) {
    const funcs = ['sinh⁻¹(', 'cosh⁻¹(', 'tanh⁻¹('];
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      String? matched;
      for (String f in funcs) {
        if (expr.startsWith(f, i)) {
          matched = f;
          break;
        }
      }
      if (matched != null) {
        String name = matched.substring(0, matched.length - 1);
        i += matched.length;
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') {
            depth++;
          } else if (expr[i] == ')') {
            depth--;
          }
          if (depth > 0) i++;
        }
        String inner = _convertInverseHyperbolic(expr.substring(start, i));
        switch (name) {
          case 'sinh⁻¹':
            // arcsinh(x) = ln(x + sqrt(x^2 + 1))
            result.write('ln(($inner)+sqrt(($inner)^2+1))');
            break;
          case 'cosh⁻¹':
            // arccosh(x) = ln(x + sqrt(x^2 - 1))
            result.write('ln(($inner)+sqrt(($inner)^2-1))');
            break;
          case 'tanh⁻¹':
            // arctanh(x) = 0.5 * ln((1+x)/(1-x))
            result.write('(ln((1+($inner))/(1-($inner)))/2)');
            break;
        }
        if (i < expr.length) i++;
      } else {
        result.write(expr[i]);
        i++;
      }
    }
    return result.toString();
  }

  /// 과학 표기(3e5 → (3*10^(5))) 변환. 숫자 바로 뒤의 e를 지수 표기로 해석.
  /// 뒤에 지수가 없는 dangling e(예: "3e")는 미완성으로 간주해 예외 발생.
  String _convertScientificNotation(String expr) {
    String converted = expr.replaceAllMapped(
      RegExp(r'(\d+(?:\.\d+)?)e([+-]?\d+)'),
      (m) => '(${m[1]}*10^(${m[2]}))',
    );
    if (RegExp(r'\de').hasMatch(converted)) {
      throw const FormatException('Incomplete scientific notation');
    }
    return converted;
  }

  /// sinh/cosh/tanh(x)를 e^x 기반 정체성으로 변환.
  /// e 치환 이전에 호출해야 함 (출력이 'e^' 문법을 사용).
  String _convertHyperbolic(String expr) {
    const funcs = ['sinh(', 'cosh(', 'tanh('];
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      String? matched;
      for (String f in funcs) {
        if (expr.startsWith(f, i)) {
          matched = f;
          break;
        }
      }
      if (matched != null) {
        String name = matched.substring(0, matched.length - 1);
        i += matched.length;
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') {
            depth++;
          } else if (expr[i] == ')') {
            depth--;
          }
          if (depth > 0) i++;
        }
        String inner = _convertHyperbolic(expr.substring(start, i));
        switch (name) {
          case 'sinh':
            result.write('((e^($inner)-e^(-($inner)))/2)');
            break;
          case 'cosh':
            result.write('((e^($inner)+e^(-($inner)))/2)');
            break;
          case 'tanh':
            result.write('((e^($inner)-e^(-($inner)))/(e^($inner)+e^(-($inner))))');
            break;
        }
        if (i < expr.length) i++;
      } else {
        result.write(expr[i]);
        i++;
      }
    }
    return result.toString();
  }

  /// ³√(내용) → (내용)^(1/3) 변환
  String _convertCubeRoot(String expr) {
    const prefix = '³√(';
    StringBuffer result = StringBuffer();
    int i = 0;
    while (i < expr.length) {
      if (expr.startsWith(prefix, i)) {
        i += prefix.length;
        // 매칭되는 닫는 괄호 찾기
        int depth = 1;
        int start = i;
        while (i < expr.length && depth > 0) {
          if (expr[i] == '(') depth++;
          if (expr[i] == ')') depth--;
          if (depth > 0) i++;
        }
        String inner = expr.substring(start, i);
        result.write('($inner)^(1/3)');
        if (i < expr.length) i++; // skip ')'
      } else {
        result.write(expr[i]);
        i++;
      }
    }
    return result.toString();
  }

  void _calculateWithScientific() {
    String savedExpression = expression;
    bool savedIsResultDisplayed = isResultDisplayed;
    String? savedLastOp = lastOp;
    String? savedLastOperandStr = lastOperandStr;

    if (!prepareEquals()) return;
    try {
      String preprocessed = _convertScientificNotation(expression);
      preprocessed = _convertInverseHyperbolic(preprocessed);
      preprocessed = _convertHyperbolic(preprocessed);
      preprocessed = preprocessed
          .replaceAll('sin⁻¹(', 'arcsin(')
          .replaceAll('cos⁻¹(', 'arccos(')
          .replaceAll('tan⁻¹(', 'arctan(');
      if (!_isRad) {
        preprocessed = _convertDegrees(preprocessed);
      }
      String finalExpression = preprocessed
          .replaceAll('×', '*')
          .replaceAll('÷', '/')
          .replaceAll('π', '3.141592653589793')
          .replaceAll('e', '2.718281828459045')
          ;
      finalExpression = _convertCubeRoot(finalExpression);
      finalExpression = _convertNRoot(finalExpression);
      finalExpression = _convertLogSubscript(finalExpression);
      finalExpression = finalExpression
          .replaceAll('√(', 'sqrt(')
          .replaceAll('²', '^2')
          .replaceAll('³', '^3');

      GrammarParser p = GrammarParser();
      Expression exp = p.parse(finalExpression);
      ContextModel cm = ContextModel();
      double eval = exp.evaluate(EvaluationType.REAL, cm);

      history = expression;
      expression = formatValue(eval);
      isResultDisplayed = true;
      saveCurrentToHistory();
    } catch (e) {
      String errMsg = e.toString().toLowerCase();
      if (errMsg.contains('infinity') || errMsg.contains('overflow')) {
        history = expression;
        expression = '오버플로';
        isResultDisplayed = true;
      } else {
        // 파싱/문법 오류 — 상태 복원 후 아무 동작도 하지 않음
        expression = savedExpression;
        isResultDisplayed = savedIsResultDisplayed;
        lastOp = savedLastOp;
        lastOperandStr = savedLastOperandStr;
      }
    }
  }

  /// expression 문자열을 파싱하여 ^ 뒤의 내용을 위첨자로 렌더링
  Widget _buildExpressionDisplay() {
    double baseFontSize = expression.length > 10 ? 40 : 60;
    double superFontSize = baseFontSize * 0.55;
    int missingParens = _getMissingParenthesesCount();

    // 1) expression을 세그먼트로 분리: {text, isSuperscript}
    List<_ExprSegment> segments = _parseExpressionSegments(expression);

    // 2) ghost 괄호를 마지막 세그먼트에 맞게 추가
    if (missingParens > 0) {
      String ghost = ')' * missingParens;
      if (segments.isNotEmpty && segments.last.isSuper) {
        // 위첨자 구간이 열려있으면 ghost도 위첨자로
        segments.add(_ExprSegment(ghost, true, true));
      } else {
        segments.add(_ExprSegment(ghost, false, true));
      }
    }

    // 3) InlineSpan 리스트 생성
    List<InlineSpan> spans = [];
    for (final seg in segments) {
      Color color = seg.isGhost
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.white;

      if (seg.isSuper) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: Offset(0, -baseFontSize * 0.35),
            child: Text(
              seg.text,
              style: TextStyle(
                fontSize: superFontSize,
                fontWeight: FontWeight.w300,
                color: color,
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: seg.text,
          style: TextStyle(
            fontSize: baseFontSize,
            fontWeight: FontWeight.w300,
            color: color,
          ),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// history 문자열을 위첨자 포함하여 렌더링
  Widget _buildHistoryDisplay() {
    const double fontSize = 24;
    const double superFontSize = fontSize * 0.55;
    List<_ExprSegment> segments = _parseExpressionSegments(history);

    List<InlineSpan> spans = [];
    for (final seg in segments) {
      if (seg.isSuper) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Transform.translate(
            offset: const Offset(0, -fontSize * 0.35),
            child: Text(
              seg.text,
              style: const TextStyle(
                fontSize: superFontSize,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: seg.text,
          style: const TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            color: Colors.grey,
          ),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// expression 문자열을 일반 텍스트 / 위첨자 구간으로 분리
  List<_ExprSegment> _parseExpressionSegments(String expr) {
    List<_ExprSegment> result = [];
    StringBuffer buf = StringBuffer();
    bool inSuper = false;
    int parenDepth = 0;

    for (int i = 0; i < expr.length; i++) {
      String ch = expr[i];

      // √ 를 만나면 직전의 y(숫자 또는 괄호 그룹)를 위첨자로 분리
      if (!inSuper && ch == '√') {
        String bufStr = buf.toString();
        int splitIdx = bufStr.length;
        if (bufStr.isNotEmpty) {
          String lastCh = bufStr[bufStr.length - 1];
          if (lastCh == ')') {
            int depth = 1;
            int j = bufStr.length - 2;
            while (j >= 0 && depth > 0) {
              if (bufStr[j] == ')') depth++;
              if (bufStr[j] == '(') depth--;
              if (depth > 0) j--;
            }
            if (j >= 0) splitIdx = j;
          } else if (RegExp(r'[0-9.]').hasMatch(lastCh)) {
            while (splitIdx > 0 && RegExp(r'[0-9.]').hasMatch(bufStr[splitIdx - 1])) {
              splitIdx--;
            }
          }
        }
        if (splitIdx < bufStr.length) {
          String normal = bufStr.substring(0, splitIdx);
          String superPart = bufStr.substring(splitIdx);
          buf.clear();
          if (normal.isNotEmpty) {
            result.add(_ExprSegment(normal, false, false));
          }
          if (superPart.startsWith('(') && superPart.endsWith(')')) {
            superPart = superPart.substring(1, superPart.length - 1);
          }
          result.add(_ExprSegment(superPart, true, false));
        }
        buf.write(ch);
        continue;
      }

      // ^ 를 만나면 일반 텍스트 flush 후 위첨자 모드 진입
      if (!inSuper && ch == '^') {
        if (buf.isNotEmpty) {
          result.add(_ExprSegment(buf.toString(), false, false));
          buf.clear();
        }
        inSuper = true;
        parenDepth = 0;
        continue; // ^ 자체는 표시하지 않음
      }

      if (inSuper) {
        buf.write(ch);

        if (ch == '(') {
          parenDepth++;
        } else if (ch == ')') {
          if (parenDepth > 0) parenDepth--;
          if (parenDepth == 0) {
            // 괄호 그룹 닫힘 → 위첨자 끝
            // 바깥 괄호 벗기기: "(내용)" → "내용"
            String superText = buf.toString();
            if (superText.startsWith('(') && superText.endsWith(')')) {
              superText = superText.substring(1, superText.length - 1);
            }
            result.add(_ExprSegment(superText, true, false));
            buf.clear();
            inSuper = false;
          }
        } else if (parenDepth == 0) {
          // 괄호 밖에서 숫자/점/π/e 가 아닌 문자 → 위첨자 종료
          if (!RegExp(r'[0-9.πe]').hasMatch(ch)) {
            // 현재 문자는 위첨자가 아님 → 되돌리기
            String superText = buf.toString();
            superText = superText.substring(0, superText.length - 1);
            if (superText.isNotEmpty) {
              result.add(_ExprSegment(superText, true, false));
            }
            buf.clear();
            buf.write(ch);
            inSuper = false;
          }
        }
      } else {
        buf.write(ch);
      }
    }

    // 남은 버퍼 flush
    if (buf.isNotEmpty) {
      result.add(_ExprSegment(buf.toString(), inSuper, false));
    }

    return result;
  }

  Widget _buildExtraButton(String text) {
    bool isMemoryActive = text == 'mr' && _isMemorySet;
    bool is2ndActive = text == '2ⁿᵈ' && _is2nd;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: InkWell(
          onTap: () => _onButtonPressed(text),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: is2ndActive ? Colors.orange : Colors.grey[900],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isMemoryActive
                      ? Colors.orange
                      : (is2ndActive ? Colors.black : Colors.white70),
                  fontWeight: (isMemoryActive || is2ndActive) ? FontWeight.bold : FontWeight.normal,
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
                          child: _buildHistoryDisplay(),
                        ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: _buildExpressionDisplay(),
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
                  _buildExtraButton('xʸ'),
                  _buildExtraButton(_is2nd ? 'yˣ' : 'eˣ'),
                  _buildExtraButton(_is2nd ? '2ˣ' : '10ˣ'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('1/x'), _buildExtraButton('²√x'), _buildExtraButton('³√x'),
                  _buildExtraButton('ʸ√x'),
                  _buildExtraButton(_is2nd ? 'logᵧ' : 'ln'),
                  _buildExtraButton(_is2nd ? 'log₂' : 'log₁₀'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('x!'),
                  _buildExtraButton(_is2nd ? 'sin⁻¹' : 'sin'),
                  _buildExtraButton(_is2nd ? 'cos⁻¹' : 'cos'),
                  _buildExtraButton(_is2nd ? 'tan⁻¹' : 'tan'),
                  _buildExtraButton('e'), _buildExtraButton('EE'),
                ],
              ),
              Row(
                children: [
                  _buildExtraButton('Rand'),
                  _buildExtraButton(_is2nd ? 'sinh⁻¹' : 'sinh'),
                  _buildExtraButton(_is2nd ? 'cosh⁻¹' : 'cosh'),
                  _buildExtraButton(_is2nd ? 'tanh⁻¹' : 'tanh'),
                  _buildExtraButton('π'), _buildExtraButton(_isRad ? 'Rad' : 'Deg'),
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

class _ExprSegment {
  final String text;
  final bool isSuper;
  final bool isGhost;

  _ExprSegment(this.text, this.isSuper, this.isGhost);
}
