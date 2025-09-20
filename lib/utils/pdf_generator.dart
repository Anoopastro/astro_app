// lib/utils/pdf_generator.dart
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../providers/horoscope_provider.dart';
import 'dart:math';

Future<void> generateProfessionalHoroscopePDF(HoroscopeProvider provider) async {
  final pdf = pw.Document();

  final planets = provider.horoscopeData['planets'] as Map<String, List<double>>;
  final houses = provider.horoscopeData['houses'] as List<dynamic>;
  final lagna = provider.horoscopeData['lagna'];
  final nakshatra = provider.horoscopeData['nakshatra'];
  final tithi = provider.horoscopeData['tithi'];
  final currentMahadasha = provider.horoscopeData['dasha']['currentMahadasha']['planet'];
  final antardasha = provider.horoscopeData['dasha']['antardashas'][0]['planet'];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('AnoopAstro Light Horoscope', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 10),
          pw.Text('City: ${provider.selectedCity}'),
          pw.Text('Lagna: $lagna'),
          pw.Text('Nakshatra: $nakshatra'),
          pw.Text('Tithi: $tithi'),
          pw.Text('Mahadasha: $currentMahadasha'),
          pw.Text('Antardasha: $antardasha'),
          pw.SizedBox(height: 20),
          pw.Center(child: _buildChakraChart(houses, planets)),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(onLayout: (format) => pdf.save());
}

/// Builds a 16-house circular chart with planets
pw.Widget _buildChakraChart(List<dynamic> houses, Map<String, List<double>> planets) {
  return pw.Container(
    width: 300,
    height: 300,
    child: pw.CustomPaint(
      size: const PdfPoint(300, 300),
      painter: (PdfGraphics canvas, PdfPoint size) {
        final centerX = size.x / 2;
        final centerY = size.y / 2;
        final radius = size.x / 2 - 10;

        // Draw circle
        canvas.setStrokeColor(PdfColors.deepPurple);
        canvas.setLineWidth(2);
        canvas.drawCircle(centerX, centerY, radius);
        canvas.strokePath();

        // Draw 16-house lines
        for (int i = 0; i < 16; i++) {
          final angle = 2 * pi / 16 * i - pi / 2;
          final x = centerX + radius * cos(angle);
          final y = centerY + radius * sin(angle);
          canvas.moveTo(centerX, centerY);
          canvas.lineTo(x, y);
          canvas.strokePath();
        }

        // Draw planet positions
        final planetNames = planets.keys.toList();
        for (int i = 0; i < planetNames.length; i++) {
          final planet = planetNames[i];
          final angle = 2 * pi / planetNames.length * i - pi / 2;
          final px = centerX + (radius - 20) * cos(angle);
          final py = centerY + (radius - 20) * sin(angle);

          canvas.setFillColor(PdfColors.black);
          canvas.drawString(pw.Font.helvetica(), 10, planet, px, py);
        }
      },
    ),
  );
}
