import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AnoopAstroApp());
}

class AnoopAstroApp extends StatelessWidget {
  const AnoopAstroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AnoopAstro Light',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        textTheme: GoogleFonts.notoSansDevanagariTextTheme(),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('hi'), Locale('en')],
      home: const InputScreen(),
    );
  }
}

class InputData {
  String name;
  DateTime dob;
  String place;
  TimeOfDay tob;
  bool male;
  InputData({
    required this.name,
    required this.dob,
    required this.place,
    required this.tob,
    required this.male,
  });
}

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _place = TextEditingController(text: 'Etawah');
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 33);
  bool _male = true;
  bool _saved = true;
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _place.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('कुंडली (AnoopAstro Light)'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: isWide ? _buildWide(context) : _buildNarrow(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _leftColumn(context)),
        const SizedBox(width: 24),
        Expanded(child: _rightColumn(context)),
      ],
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return SingleChildScrollView(child: _leftColumn(context));
  }

  Widget _leftColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('नई कुंडली', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(
            labelText: 'अपना नाम दर्ज करें',
            prefixIcon: Icon(Icons.person_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'नाम आवश्यक है' : null,
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'जन्म तिथि',
                  prefixIcon: Icon(Icons.calendar_month),
                ),
                child: Text(DateFormat('dd - MMM - yyyy').format(_date)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _pickTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'जन्म समय',
                  prefixIcon: Icon(Icons.schedule),
                ),
                child: Text(_time.format(context)),
              ),
            ),
          )
        ]),
        const SizedBox(height: 12),
        TextFormField(
          controller: _place,
          decoration: const InputDecoration(
            labelText: 'स्थान (शहर)',
            prefixIcon: Icon(Icons.place_outlined),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'स्थान आवश्यक है' : null,
        ),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('पुरुष')),
            ButtonSegment(value: false, label: Text('स्त्री')),
          ],
          selected: {_male},
          onSelectionChanged: (s) => setState(() => _male = s.first),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _saved,
          onChanged: (v) => setState(() => _saved = v ?? false),
          title: const Text('सुरक्षित'),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.auto_awesome),
            label: const Text('कुंडली दिखाइये'),
            onPressed: _onGenerate,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'सूचना: यह डेमो गणना है। सटीक ज्योतिषीय गणना के लिये बाद में इंजन जोड़ें।',
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _rightColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 48),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Tablet UI'),
                SizedBox(height: 6),
                Text('Material 3 • देवनागरी फॉन्ट • PDF निर्यात'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
      initialDate: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _onGenerate() {
    if (!_formKey.currentState!.validate()) return;
    final input = InputData(
      name: _name.text.trim().isEmpty ? 'अज्ञात' : _name.text.trim(),
      dob: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
      place: _place.text.trim(),
      tob: _time,
      male: _male,
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ResultScreen(input: input)),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final InputData input;
  const ResultScreen({super.key, required this.input});

  @override
  Widget build(BuildContext context) {
    final kundali = DemoAstroEngine.generateKundali();
    final dashas = DemoAstroEngine.generateDashas();

    return Scaffold(
      appBar: AppBar(
        title: const Text('कुंडली परिणाम'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final doc = await _buildPdf(input, kundali, dashas);
              await Printing.layoutPdf(onLayout: (format) => doc.save());
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('नाम: ${input.name}'),
          Text('जन्म तिथि: ${DateFormat('dd MMM yyyy, hh:mm a').format(input.dob)}'),
          Text('स्थान: ${input.place}'),
          const SizedBox(height: 16),
          const Text('कुंडली (डेमो)'),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(
              painter: KundaliPainter(kundali),
            ),
          ),
          const SizedBox(height: 16),
          const Text('महादशा (डेमो)'),
          const SizedBox(height: 8),
          for (final d in dashas) Text(d),
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdf(
      InputData input, List<String> kundali, List<String> dashas) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
              level: 0,
              child: pw.Text("AnoopAstro Light Kundali",
                  style: pw.TextStyle(fontSize: 20))),
          pw.Text("नाम: ${input.name}"),
          pw.Text("जन्म तिथि: ${DateFormat('dd MMM yyyy, hh:mm a').format(input.dob)}"),
          pw.Text("स्थान: ${input.place}"),
          pw.SizedBox(height: 20),
          pw.Text("कुंडली (Demo Data):"),
          pw.Wrap(children: kundali.map((e) => pw.Text(e)).toList()),
          pw.SizedBox(height: 20),
          pw.Text("महादशा (Demo Data):"),
          pw.Column(children: dashas.map((e) => pw.Text(e)).toList()),
          pw.Positioned(
            bottom: 20,
            right: 20,
            child: pw.Opacity(
              opacity: 0.2,
              child: pw.Text("AnoopAstro Light",
                  style: pw.TextStyle(fontSize: 40, color: pdf.PdfColors.red)),
            ),
          )
        ],
      ),
    );
    return doc;
  }
}

/// Painter to draw a simple Kundali chart (demo only)
class KundaliPainter extends CustomPainter {
  final List<String> data;
  KundaliPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final w = size.width;
    final h = size.height;

    // Draw square
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Draw diagonals
    canvas.drawLine(Offset(0, 0), Offset(w, h), paint);
    canvas.drawLine(Offset(w, 0), Offset(0, h), paint);

    // Cross
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), paint);
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Demo astro engine (placeholder)
class DemoAstroEngine {
  static List<String> generateKundali() {
    return List.generate(12, (i) => "भाव ${i + 1}");
  }

  static List<String> generateDashas() {
    return [
      "केतु 2020 - 2027",
      "शुक्र 2027 - 2047",
      "सूर्य 2047 - 2053",
    ];
  }
}
