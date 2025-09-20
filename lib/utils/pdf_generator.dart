// lib/utils/pdf_generator.dart
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfGenerator {
  /// Generate a professional PDF from provider data.
  /// `data` expects:
  /// {
  ///   'planets': Map<String,double>,
  ///   'houses': List<double> (16 values),
  ///   'ascendant': double,
  ///   'nakshatra': String,
  ///   'tithi': String,
  ///   'dasha': Map...
  /// }
  static Future<File> generateHoroscopePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    final planets = Map<String, double>.from(data['planets'] ?? {});
    final housesList = List<double>.from(data['houses'] ?? []);
    final asc = data['ascendant'] ?? 0.0;
    final nak = data['nakshatra'] ?? '';
    final tithi = data['tithi'] ?? '';
    final dasha = data['dasha'] ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(child: pw.Text('AnoopAstro Light Horoscope', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 8),
          pw.Text('Ascendant: ${asc.toStringAsFixed(2)}°'),
          pw.Text('Nakshatra: $nak'),
          pw.Text('Tithi: $tithi'),
          pw.SizedBox(height: 12),

          // Chart
          pw.Center(
            child: pw.Container(
              width: 330,
              height: 330,
              child: pw.CustomPaint(
                size: const PdfPoint(330,330),
                painter: (PdfGraphics canvas, PdfPoint size) {
                  final centerX = size.x / 2;
                  final centerY = size.y / 2;
                  final radius = size.x / 2 - 10;

                  // draw colored sectors (16)
                  final houseColors = [
                    PdfColors.cyan100, PdfColors.yellow100, PdfColors.orange100, PdfColors.green100,
                    PdfColors.pink100, PdfColors.lime100, PdfColors.red100, PdfColors.blue100,
                    PdfColors.teal100, PdfColors.amber100, PdfColors.purple100, PdfColors.indigo100,
                    PdfColors.brown100, PdfColors.grey300, PdfColors.lightGreen100, PdfColors.deepOrange100
                  ];

                  for (int i=0;i<16;i++) {
                    final startAngle = 2 * pi / 16 * i - pi/2;
                    final sweep = 2 * pi / 16;
                    canvas.setFillColor(houseColors[i % houseColors.length]);
                    // draw arc as a pie sector approximation using path
                    canvas.moveTo(centerX, centerY);
                    final steps = 36;
                    for (int s=0;s<=steps;s++) {
                      final a = startAngle + sweep * (s/steps);
                      final x = centerX + radius * cos(a);
                      final y = centerY + radius * sin(a);
                      if (s==0) canvas.lineTo(x,y); else canvas.lineTo(x,y);
                    }
                    canvas.closePath();
                    canvas.fillPath();
                  }

                  // outer circle border
                  canvas.setStrokeColor(PdfColors.deepPurple);
                  canvas.setLineWidth(1.5);
                  canvas.drawCircle(centerX, centerY, radius);
                  canvas.strokePath();

                  // 16 house lines
                  for (int i=0;i<16;i++){
                    final angle = 2 * pi / 16 * i - pi/2;
                    final x = centerX + radius * cos(angle);
                    final y = centerY + radius * sin(angle);
                    canvas.moveTo(centerX, centerY);
                    canvas.lineTo(x,y);
                    canvas.strokePath();
                  }

                  // house numbers
                  final tf = pw.Font.helvetica();
                  canvas.setFillColor(PdfColors.black);
                  for (int i=0;i<16;i++){
                    final angle = 2 * pi / 16 * i - pi/2 + (pi/16);
                    final px = centerX + (radius + 8) * cos(angle);
                    final py = centerY + (radius + 8) * sin(angle);
                    // draw text
                    canvas.drawString(tf, 10, '${i+1}', px-4, py-4);
                  }

                  // Draw planets positioned by longitude
                  final font = pw.Font.helvetica();
                  planets.forEach((name, lon) {
                    final angle = lon / 180 * pi - pi/2; // map 0..360 to angle
                    final px = centerX + (radius - 40) * cos(angle);
                    final py = centerY + (radius - 40) * sin(angle);
                    canvas.setFillColor(PdfColors.black);
                    canvas.drawString(font, 10, name, px-8, py-6);
                  });
                },
              ),
            ),
          ),

          pw.SizedBox(height: 14),
          pw.Text('Planet Positions:', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),

          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: planets.entries.map((e) => pw.Text('${e.key}: ${e.value.toStringAsFixed(2)}°')).toList(),
          ),

          pw.SizedBox(height: 10),

          pw.Text('Mahadasha (current): ${dasha['currentMahadasha']?['planet'] ?? 'N/A'}'),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/anoopastro_horoscope.pdf');
    await f.writeAsBytes(await pdf.save());
    return f;
  }
}
