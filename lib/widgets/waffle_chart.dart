import 'package:flutter/material.dart';

class WaffleSegment {
  final Color color;
  final int pct; // out of 100
  final String label;
  final int amount;

  const WaffleSegment({
    required this.color,
    required this.pct,
    required this.label,
    required this.amount,
  });
}

/// 10×10 waffle chart — each cell = 1% of total
class WaffleChart extends StatelessWidget {
  final List<WaffleSegment> segments;
  final double cellSize;
  final double cellGap;

  const WaffleChart({
    super.key,
    required this.segments,
    this.cellSize = 11,
    this.cellGap = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final cells = <Color>[];
    for (final seg in segments) {
      for (var i = 0; i < seg.pct; i++) {
        cells.add(seg.color);
      }
    }
    while (cells.length < 100) { cells.add(const Color(0xFFE5E7EB)); }

    final side = cellSize + cellGap * 2;
    return SizedBox(
      width: side * 10,
      height: side * 10,
      child: Wrap(
        spacing: cellGap * 2,
        runSpacing: cellGap * 2,
        children: List.generate(100, (i) {
          return Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: cells[i],
              borderRadius: BorderRadius.circular(2.5),
            ),
          );
        }),
      ),
    );
  }
}
