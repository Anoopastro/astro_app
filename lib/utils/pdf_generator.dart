import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<File> generateHoroscopePdf(Map<String, dynamic> horoscopeData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Center(
            child: pw.Text(
              "AnoopAstro Light Horoscope",
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 20),

          // Ascendant
          pw.Text("Ascendant: ${horoscopeData['ascendant']}"),
          pw.SizedBox(height: 20),

          // Planets
          pw.Text("Planetary Positions:", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (horoscopeData['planets'] as Map<String, double>).entries.map(
              (entry) => pw.Text("${entry.key}: ${entry.value.toStringAsFixed(2)}°"),
            ).toList(),
          ),
          pw.SizedBox(height: 20),

          // Houses
          pw.Text("Houses:", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: (horoscopeData['houses'] as Map<int, double>).entries.map(
              (entry) => pw.Text("House ${entry.key}: ${entry.value.toStringAsFixed(2)}°"),
            ).toList(),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/horoscope.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}
