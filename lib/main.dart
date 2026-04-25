import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'screens/basic_calculator_screen.dart';
import 'screens/scientific_calculator_screen.dart';
import 'screens/converter_screen.dart';
import 'screens/math_notes_screen.dart';
import 'screens/history_screen.dart';
import 'data/db_init.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initSqflite();
  runApp(const CalculatorApp());
}

class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iOS Calculator',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const BasicCalculatorScreen(),
    const ScientificCalculatorScreen(),
    const MathNotesScreen(),
    const ConverterScreen(),
  ];

  final List<String> _labels = ['기본', '공학용', '수학 메모', '변환'];

  final List<IconData> _icons = [
    CupertinoIcons.divide,
    CupertinoIcons.function,
    CupertinoIcons.pencil_outline,
    CupertinoIcons.arrow_2_squarepath,
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openHistory() {
    final sheetController = DraggableScrollableController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (_) => DraggableScrollableSheet(
        controller: sheetController,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 1.0,
        expand: false,
        builder: (ctx, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.grey[900]!.withValues(alpha: 0.7),
                child: HistoryScreen(
                  scrollController: scrollController,
                  sheetController: sheetController,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 10.0),
                    child: Material(
                      color: Colors.grey[900],
                      shape: CircleBorder(
                        side: BorderSide(color: Colors.grey[700]!, width: 2),
                      ),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _openHistory,
                        child: const SizedBox(
                          width: 80,
                          height: 80,
                          child: Icon(
                            CupertinoIcons.clock,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 10.0),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[700]!, width: 2),
                      ),
                      child: PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 85),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: Colors.grey[900],
                    onSelected: _onItemTapped,
                    icon: Container(
                      width: 40,
                      height: 48,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 7,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(3, (row) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(3, (col) => Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  )),
                                )),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (context) {
                      List<PopupMenuEntry<int>> menuItems = [];
                      for (int i = 0; i < _labels.length; i++) {
                        if (i == 4) {
                          menuItems.add(const PopupMenuDivider(height: 1));
                        }
                        menuItems.add(
                          PopupMenuItem<int>(
                            value: i,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: _selectedIndex == i
                                      ? const Icon(Icons.check, size: 18, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Icon(_icons[i], size: 20, color: Colors.white),
                                const SizedBox(width: 12),
                                Text(
                                  _labels[i],
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return menuItems;
                    },
                  ),
                ),
              ),
            ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _screens[_selectedIndex],
      ),
    );
  }
}
