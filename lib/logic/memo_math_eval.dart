import 'package:math_expressions/math_expressions.dart';

/// 메모의 한 줄을 수식으로 평가해 결과 문자열을 반환.
/// 수식이 아니거나 파싱/계산 실패 시 null.
String? evaluateMemoExpression(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.contains('=')) return null;
  if (!RegExp(
    r'[+\-*/^×÷]|\b(sin|cos|tan|sinh|cosh|tanh|log|ln|sqrt|exp|abs)\b|[π²³√]',
  ).hasMatch(trimmed)) {
    return null;
  }

  final openCount = '('.allMatches(trimmed).length;
  final closeCount = ')'.allMatches(trimmed).length;
  if (closeCount > openCount) return null;
  String balanced = trimmed + ')' * (openCount - closeCount);

  String expr = balanced
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('²', '^2')
      .replaceAll('³', '^3')
      .replaceAll('√(', 'sqrt(')
      .replaceAll('π', '(3.141592653589793)');
  expr = expr.replaceAll(RegExp(r'\blog\('), 'ln(');
  expr = expr.replaceAll(RegExp(r'\bpi\b'), '(3.141592653589793)');
  expr = expr.replaceAllMapped(
    RegExp(r'(?<![0-9.])e(?![0-9])'),
    (_) => '(2.718281828459045)',
  );

  try {
    final parser = GrammarParser();
    final parsed = parser.parse(expr);
    final result =
        parsed.evaluate(EvaluationType.REAL, ContextModel()) as double;
    if (result.isNaN || result.isInfinite) return null;
    return _formatResult(result);
  } catch (_) {
    return null;
  }
}

String _formatResult(double v) {
  if (v == v.truncateToDouble() && v.abs() < 1e15) {
    return v.toInt().toString();
  }
  String s = v.toStringAsFixed(10);
  s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  return s;
}
