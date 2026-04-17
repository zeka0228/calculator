import 'package:flutter/material.dart';

class ScientificCalculatorScreen extends StatelessWidget {
  const ScientificCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Scientific Calculator\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, color: Colors.white),
      ),
    );
  }
}
