import 'package:flutter/material.dart';

class MathNotesScreen extends StatelessWidget {
  const MathNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Math Notes\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 24, color: Colors.white),
      ),
    );
  }
}
