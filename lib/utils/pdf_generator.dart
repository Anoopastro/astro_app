import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import '../providers/horoscope_provider.dart';

class PDFGenerator {
  static Future<pw.Document> generatePDF(HoroscopeProvider provider) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('AnoopAstro Light Horoscope', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('City: ${provider.selectedCity}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Lagna: ${provider.horoscopeData['lagna']}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Nakshatra: ${provider.horoscopeData['nakshatra']}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Tithi: ${provider.horoscopeData['tithi']}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Mahadasha: ${provider.horoscopeData['dasha']['currentMahadasha']['planet']}', style: const pw.TextStyle(fontSize: 16)),
              pw.Text('Antardasha: ${provider.horoscopeData['dasha']['antardashas'][0]['planet']}', style: const pw.TextStyle(fontSize: 16)),
              pw.SizedBox(height: 20),
              pw.Center(
                child: _drawChakra(provider.horoscopeData['houses']),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  // ---------------- Chakra Chart Drawing ----------------
  static pw.Widget _drawChakra(List<dynamic> houses) {
    return pw.CustomPaint(
      size: const pw.PdfPoint(300, 300),
      painter: (context, canvas, size) {
        final paint = pw.Paint()
          ..color = PdfColors.deepPurple
          ..strokeWidth = 2
          ..style = pw.PaintingStyle.stroke;

        final center = pw.PdfPoint(size.x / 2, size.y / 2);
        final radius = size.x / 2 - 10;

        // Draw outer circle
        canvas.drawCircle(center, radius, paint);

        // Draw 16-house lines
        for (int i = 0; i < 16; i++) {
          final angle = 2 * 3.1415926535 / 16 * i;
          final x = center.x + radius * cos(angle);
          final y = center.y + radius * sin(angle);
          canvas.drawLine(center, pw.PdfPoint(x, y), paint);
        }

        // Draw house numbers (1-16)
        for (int i = 0; i < 16; i++) {
          final angle = 2 * 3.1415926535 / 16 * i - 3.1415926535 / 16;
          final px = center.x + (radius + 10) * cos(angle);
          final py = center.y + (radius + 10) * sin(angle);
          final text = pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 10, color: PdfColors.black));
          canvas.drawText(text, pw.PdfPoint(px - 3, py - 3));
        }
      },
    );
  }
}
