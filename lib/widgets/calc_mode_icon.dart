import 'package:flutter/material.dart';

class CalcModeIcon extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double borderWidth;

  const CalcModeIcon({
    super.key,
    this.width = 40,
    this.height = 48,
    this.color = Colors.white,
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final scale = width / 40;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: borderWidth),
        borderRadius: BorderRadius.circular(6 * scale),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 4 * scale),
            height: 7 * scale,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          SizedBox(height: 5 * scale),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 4 * scale, vertical: 2 * scale),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (row) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      3,
                      (col) => Container(
                        width: 5 * scale,
                        height: 5 * scale,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
