import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const AstroApp());
}

class AstroApp extends StatelessWidget {
  const AstroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astro App',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  DateTime? dob;
  List<String> cities = [];

  @override
  void initState() {
    super.initState();
    loadCities();
  }

  Future<void> loadCities() async {
    final data = await rootBundle.loadString("assets/cities.json");
    final List<dynamic> cityList = jsonDecode(data);
    setState(() {
      cities = cityList.cast<String>();
    });
  }

  Future<void> generatePdf(String name, String city, DateTime dob) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat("dd MMMM yyyy, hh:mm a");

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text("🌟 कुंडली रिपोर्ट 🌟", style: pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text("नाम: $name"),
              pw.Text("शहर: $city"),
              pw.Text("जन्म दिनांक: ${dateFormat.format(dob)}"),
              pw.SizedBox(height: 20),
              pw.Text("🔮 यह एक डेमो रिपोर्ट है।"),
            ],
          ),
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/kundali.pdf");
    await file.writeAsBytes(await pdf.save());

    Share.shareXFiles([XFile(file.path)], text: "मेरी कुंडली रिपोर्ट");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ऑफलाइन कुंडली ऐप")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "नाम"),
            ),
            const SizedBox(height: 10),
            TypeAheadFormField(
              textFieldConfiguration: TextFieldConfiguration(
                controller: cityController,
                decoration: const InputDecoration(labelText: "शहर"),
              ),
              suggestionsCallback: (pattern) {
                return cities.where((city) =>
                    city.toLowerCase().contains(pattern.toLowerCase()));
              },
              itemBuilder: (context, String suggestion) {
                return ListTile(title: Text(suggestion));
              },
              onSuggestionSelected: (String suggestion) {
                cityController.text = suggestion;
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(dob == null
                      ? "जन्म दिनांक चुनें"
                      : "जन्म: ${DateFormat("dd/MM/yyyy").format(dob!)}"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100),
                      initialDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => dob = picked);
                    }
                  },
                  child: const Text("तारीख चुनें"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    cityController.text.isNotEmpty &&
                    dob != null) {
                  generatePdf(
                      nameController.text, cityController.text, dob!);
                }
              },
              child: const Text("📄 कुंडली PDF बनाएँ"),
            ),
          ],
        ),
      ),
    );
  }
}
