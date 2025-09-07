import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  runApp(const AstroApp());
}

class AstroApp extends StatelessWidget {
  const AstroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'कुंडली',
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        fontFamily: 'NotoSansDevanagari',
      ),
      home: const KundaliInputScreen(),
    );
  }
}

class KundaliInputScreen extends StatefulWidget {
  const KundaliInputScreen({super.key});

  @override
  State<KundaliInputScreen> createState() => _KundaliInputScreenState();
}

class _KundaliInputScreenState extends State<KundaliInputScreen> {
  final nameController = TextEditingController();
  final placeController = TextEditingController();
  DateTime? birthDate;
  TimeOfDay? birthTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('कुंडली')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'नाम'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(1990),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => birthDate = picked);
                      }
                    },
                    child: Text(birthDate == null
                        ? 'जन्मतिथि चुनें'
                        : 'तिथि: ${birthDate!.day}-${birthDate!.month}-${birthDate!.year}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: const TimeOfDay(hour: 12, minute: 0),
                      );
                      if (picked != null) {
                        setState(() => birthTime = picked);
                      }
                    },
                    child: Text(birthTime == null
                        ? 'जन्मसमय चुनें'
                        : 'समय: ${birthTime!.hour}:${birthTime!.minute.toString().padLeft(2, '0')}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: placeController,
              decoration: const InputDecoration(labelText: 'जन्मस्थान'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () {
                  if (birthDate != null && birthTime != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ResultScreen(
                          name: nameController.text,
                          birthDate: birthDate!,
                          birthTime: birthTime!,
                          place: placeController.text,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('कुंडली दिखाइये', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String name;
  final DateTime birthDate;
  final TimeOfDay birthTime;
  final String place;

  const ResultScreen({
    super.key,
    required this.name,
    required this.birthDate,
    required this.birthTime,
    required this.place,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return [
            pw.Text("कुंडली परिणाम",
                style: pw.TextStyle(
                    fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Basic Details
            pw.Text("नाम: ${widget.name}"),
            pw.Text(
                "जन्मतिथि: ${widget.birthDate.day}-${widget.birthDate.month}-${widget.birthDate.year}"),
            pw.Text(
                "जन्मसमय: ${widget.birthTime.hour}:${widget.birthTime.minute.toString().padLeft(2, '0')}"),
            pw.Text("जन्मस्थान: ${widget.place}"),
            pw.Text("लग्न: सिंह १५°२०′"),
            pw.SizedBox(height: 20),

            // Planetary positions
            pw.Text("ग्रह स्थिति",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ["ग्रह", "राशि", "अंश", "नक्षत्र"],
              data: [
                ["सूर्य", "सिंह", "१५°२०′", "मघा"],
                ["चन्द्र", "कर्क", "२३°१०′", "आश्रेषा"],
                ["मंगल", "मेष", "०५°०५′", "अश्विनी"],
                ["बुध", "सिंह", "१०°४५′", "पूर्वा फाल्गुनी"],
                ["गुरु", "मीन", "२७°५०′", "रेवती"],
                ["शुक्र", "कन्या", "०८°१५′", "उत्तर फाल्गुनी"],
                ["शनि", "कुंभ", "१२°३५′", "शतभिषा"],
                ["राहु", "मेष", "१८°१०′", "भरणी"],
                ["केतु", "तुला", "१८°१०′", "स्वाति"],
              ],
            ),
            pw.SizedBox(height: 20),

            // Dasha
            pw.Text("महादशा",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Table.fromTextArray(
              headers: ["ग्रह", "प्रारम्भ", "समाप्ति"],
              data: [
                ["चन्द्र", "०१-०१-२०२०", "०१-०१-२०३०"],
                ["मंगल", "०१-०१-२०३०", "०१-०१-२०३७"],
                ["राहु", "०१-०१-२०३७", "०१-०१-२०५५"],
              ],
            ),
            pw.SizedBox(height: 20),

            // Chart (simplified)
            pw.Text("उत्तर भारतीय शैली का चार्ट",
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Container(
                width: 250,
                height: 250,
                child: pw.Stack(children: [
                  pw.Positioned.fill(
                    child: pw.CustomPaint(
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        final paint = PdfPaint()
                          ..color = PdfColors.black
                          ..strokeWidth = 1;

                        // Square + diagonals
                        canvas.drawRect(0, 0, size.x, size.y);
                        canvas.strokePath(paint);

                        canvas.drawLine(0, 0, size.x, size.y);
                        canvas.drawLine(size.x, 0, 0, size.y);

                        canvas.drawLine(size.x / 2, 0, 0, size.y / 2);
                        canvas.drawLine(size.x / 2, 0, size.x, size.y / 2);
                        canvas.drawLine(0, size.y / 2, size.x / 2, size.y);
                        canvas.drawLine(size.x / 2, size.y, size.x, size.y / 2);

                        canvas.strokePath(paint);

                        // Planets text
                        final tp = pw.TextStyle(fontSize: 10);
                        canvas.drawString(tp, 40, size.y - 30, "सूर्य");
                        canvas.drawString(tp, size.x - 70, size.y - 30, "चन्द्र");
                        canvas.drawString(tp, size.x - 40, size.y / 2, "मंगल");
                        canvas.drawString(tp, size.x - 70, 20, "बुध");
                        canvas.drawString(tp, 40, 20, "गुरु");
                        canvas.drawString(tp, 10, size.y / 2, "शुक्र");
                        canvas.drawString(tp, size.x / 2 - 20, size.y / 2, "शनि");
                        canvas.drawString(tp, size.x / 2 - 20, size.y - 60, "राहु");
                        canvas.drawString(tp, size.x / 2 - 20, 40, "केतु");
                      },
                    ),
                  ),
                ]),
              ),
            ),
            pw.SizedBox(height: 40),
            pw.Center(
                child: pw.Text("© AnoopAstro Light",
                    style: pw.TextStyle(
                        fontSize: 12, color: PdfColors.grey))),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('कुंडली परिणाम'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePdf,
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'मूल विवरण'),
            Tab(text: 'ग्रह स्थिति'),
            Tab(text: 'दशा'),
            Tab(text: 'कुंडली'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicDetails(),
          _buildPlanetaryPositions(),
          _buildDasha(),
          _buildChart(),
        ],
      ),
    );
  }

  Widget _buildBasicDetails() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('नाम: ${widget.name}'),
          Text(
              'जन्मतिथि: ${widget.birthDate.day}-${widget.birthDate.month}-${widget.birthDate.year}'),
          Text(
              'जन्मसमय: ${widget.birthTime.hour}:${widget.birthTime.minute.toString().padLeft(2, '0')}'),
          Text('जन्मस्थान: ${widget.place}'),
          const SizedBox(height: 10),
          const Text('लग्न: सिंह १५°२०′'),
        ],
      ),
    );
  }

  Widget _buildPlanetaryPositions() {
    final planets = [
      {'ग्रह': 'सूर्य', 'राशि': 'सिंह', 'अंश': '१५°२०′', 'नक्षत्र': 'मघा'},
      {'ग्रह': 'चन्द्र', 'राशि': 'कर्क', 'अंश': '२३°१०′', 'नक्षत्र': 'आश्रेषा'},
      {'ग्रह': 'मंगल', 'राशि': 'मेष', 'अंश': '०५°०५′', 'नक्षत्र': 'अश्विनी'},
      {'ग्रह': 'बुध', 'राशि': 'सिंह', 'अंश': '१०°४५′', 'नक्षत्र': 'पूर्वा फाल्गुनी'},
      {'ग्रह': 'गुरु', 'राशि': 'मीन', 'अंश': '२७°५०′', 'नक्षत्र': 'रेवती'},
      {'ग्रह': 'शुक्र', 'राशि': 'कन्या', 'अंश': '०८°१५′', 'नक्षत्र': 'उत्तर फाल्गुनी'},
      {'ग्रह': 'शनि', 'राशि': 'कुंभ', 'अंश': '१२°३५′', 'नक्षत्र': 'शतभिषा'},
      {'ग्रह': 'राहु', 'राशि': 'मेष', 'अंश': '१८°१०′', 'नक्षत्र': 'भरणी'},
      {'ग्रह': 'केतु', 'राशि': 'तुला', 'अंश': '१८°१०′', 'नक्षत्र': 'स्वाति'},
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: planets
          .map((p) => ListTile(
                title: Text('${p['ग्रह']} – ${p['राशि']} ${p['अंश']} – ${p['नक्षत्र']}'),
              ))
          .toList(),
    );
  }

  Widget _buildDasha() {
    final dashas = [
      {'ग्रह': 'चन्द्र', 'प्रारम्भ': '०१-०१-२०२०', 'समाप्ति': '०१-०१-२०३०'},
      {'ग्रह': 'मंगल', 'प्रारम्भ': '०१-०१-२०३०', 'समाप्ति': '०१-०१-२०३७'},
      {'ग्रह': 'राहु', 'प्रारम्भ': '०१-०१-२०३७', 'समाप्ति': '०१-०१-२०५५'},
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: dashas
          .map((d) => ListTile(
                title: Text('${d['ग्रह']} महादशा'),
                subtitle:
                    Text('प्रारम्भ: ${d['प्रारम्भ']}  |  समाप्ति: ${d['समाप्ति']}'),
              ))
          .toList(),
    );
  }

  Widget _buildChart() {
    return Center(
      child: CustomPaint(
        size: const Size(300, 300),
        painter: NorthIndianChartPainter(),
      ),
    );
  }
}

class NorthIndianChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final double w = size.width;
    final double h = size.height;

    // Outer square
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Diagonals
    canvas.drawLine(Offset(0, 0), Offset(w, h), paint);
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);

    // Mid lines
    canvas.drawLine(Offset(w / 2, 0), Offset(0, h / 2), paint);
    canvas.drawLine(Offset(w / 2, 0), Offset(w, h / 2), paint);
    canvas.drawLine(Offset(0, h / 2), Offset(w / 2, h), paint);
    canvas.drawLine(Offset(w / 2, h), Offset(w, h / 2), paint);

    final textPainter = (String text, double x, double y) {
      final span =
          TextSpan(style: const TextStyle(color: Colors.black, fontSize: 14), text: text);
      final tp =
          TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    };

    // Example planet placements
    textPainter('सूर्य', w * 0.25, h * 0.1);
    textPainter('चन्द्र', w * 0.75, h * 0.1);
    textPainter('मंगल', w * 0.9, h * 0.5);
    textPainter('बुध', w * 0.75, h * 0.9);
    textPainter('गुरु', w * 0.25, h * 0.9);
    textPainter('शुक्र', w * 0.1, h * 0.5);
    textPainter('शनि', w * 0.5, h * 0.5);
    textPainter('राहु', w * 0.5, h * 0.25);
    textPainter('केतु', w * 0.5, h * 0.75);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
