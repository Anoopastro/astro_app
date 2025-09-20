// lib/widgets/pdf_chakra_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';

class ChakraPainter extends CustomPainter {
  final List<double>? houses; // expected 16 values (deg)
  final Map<String,double>? planets; // name -> longitude (deg)

  ChakraPainter(this.houses, {this.planets});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width/2, size.height/2);
    final radius = min(size.width, size.height)/2 - 10;

    // outer circle
    canvas.drawCircle(center, radius, paint);

    // 16-house lines
    for (int i=0;i<16;i++) {
      final angle = 2 * pi / 16 * i - pi/2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x,y), paint);
    }

    // draw planets
    if (planets != null) {
      final textStyle = TextStyle(fontSize: 12, color: Colors.black);
      planets!.forEach((name, lon) {
        // map longitude to an angle
        final angle = (lon / 180 * pi) - pi/2;
        final px = center.dx + (radius - 30) * cos(angle);
        final py = center.dy + (radius - 30) * sin(angle);

        final tp = TextPainter(text: TextSpan(text: name.substring(0, min(4,name.length)), style: textStyle),
          textDirection: TextDirection.ltr);
        tp.layout();
        tp.paint(canvas, Offset(px - tp.width/2, py - tp.height/2));
      });
    }
  }

  @override
  bool shouldRepaint(covariant ChakraPainter oldDelegate) {
    return oldDelegate.houses != houses || oldDelegate.planets != planets;
  }
}
