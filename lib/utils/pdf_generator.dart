import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/horoscope_provider.dart';
import 'dart:math';

Future<void> generateProfessionalHoroscopePDF(HoroscopeProvider provider) async {
  final pdf = pw.Document();

  final houses = provider.horoscopeData['houses'] as List<dynamic>? ?? [];
  final planets = provider.horoscopeData['planets'] as Map<String, List<double>>? ?? {};

  pdf.addPage(
    pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AnoopAstro Light Horoscope', style: const pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 10),
          pw.Text('City: ${provider.selectedCity}'),
          pw.Text('Lagna: ${provider.horoscopeData['lagna']}'),
          pw.Text('Nakshatra: ${provider.horoscopeData['nakshatra']}'),
          pw.Text('Tithi: ${provider.horoscopeData['tithi']}'),
          pw.Text('Mahadasha: ${provider.horoscopeData['dasha']['currentMahadasha']['planet']}'),
          pw.Text('Antardasha: ${provider.horoscopeData['dasha']['antardashas'][0]['planet']}'),
          pw.SizedBox(height: 20),
          // Chart
          pw.Container(
            width: 300,
            height: 300,
            child: pw.CustomPaint(
              painter: _PDFChakraPainter(houses, planets),
            ),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
  );
}

// ---------------------- PDF Chakra Painter ----------------------
class _PDFChakraPainter extends pw.CustomPainter {
  final List<dynamic> houses;
  final Map<String, List<double>> planets;

  _PDFChakraPainter(this.houses, this.planets);

  @override
  void paint(pw.Context context, pw.Canvas canvas, pw.Size size) {
    final paint = pw.Paint()
      ..color = PdfColors.deepPurple
      ..strokeWidth = 2
      ..style = pw.PaintingStyle.stroke;

    final center = pw.Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw outer circle
    canvas.drawCircle(center, radius, paint);

    // Draw 16 house lines
    for (int i = 0; i < 16; i++) {
      final angle = 2 * pi / 16 * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, pw.Offset(x, y), paint);
    }

    // Draw planets inside the chart
    final textPainter = pw.TextPainter();
    planets.forEach((name, pos) {
      final longitude = pos[0]; // ecliptic longitude
      final angle = (longitude / 360) * 2 * pi - pi / 2;
      final px = center.dx + (radius - 30) * cos(angle);
      final py = center.dy + (radius - 30) * sin(angle);

      textPainter.text = pw.TextSpan(
        text: name,
        style: pw.TextStyle(fontSize: 10, color: PdfColors.black),
      );
      textPainter.layout();
      textPainter.paint(canvas, pw.Offset(px - textPainter.width / 2, py - textPainter.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant pw.CustomPainter oldDelegate) => false;
}
