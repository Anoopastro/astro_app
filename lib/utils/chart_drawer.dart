import 'package:flutter/material.dart';

class ChartDrawer {
  final Map<String, double> planets;
  final List<double> houses;

  ChartDrawer({required this.planets, required this.houses});

  Widget buildChart() {
    return SizedBox(
      height: 300,
      width: 300,
      child: CustomPaint(
        painter: _ChartPainter(planets: planets, houses: houses),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Map<String, double> planets;
  final List<double> houses;

  _ChartPainter({required this.planets, required this.houses});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.deepPurple
      ..strokeWidth = 2;

    // Draw circle chart
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    canvas.drawCircle(center, radius, paint);

    // Draw houses (simplified)
    for (var angle in houses) {
      final rad = (angle - 90) * 3.14159 / 180;
      final x = center.dx + radius * cos(rad);
      final y = center.dy + radius * sin(rad);
      canvas.drawLine(center, Offset(x, y), paint);
    }

    // Draw planet markers
    final textPainter = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    planets.forEach((name, lon) {
      final rad = (lon - 90) * 3.14159 / 180;
      final x = center.dx + (radius - 20) * cos(rad);
      final y = center.dy + (radius - 20) * sin(rad);
      final textSpan = TextSpan(text: name[0], style: const TextStyle(color: Colors.red, fontSize: 14));
      textPainter.text = textSpan;
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 7, y - 7));
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
