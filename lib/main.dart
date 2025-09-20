import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/horoscope_provider.dart';
import 'utils/pdf_generator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HoroscopeProvider()),
      ],
      child: MaterialApp(
        title: 'AnoopAstro Light',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          fontFamily: 'Roboto',
        ),
        home: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime? birthDate;
  double latitude = 28.6139; // default Delhi
  double longitude = 77.2090;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HoroscopeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("AnoopAstro Light")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: DateTime(1990, 1, 1),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                );
                if (selected != null) {
                  setState(() {
                    birthDate = selected;
                  });
                }
              },
              child: const Text("Select Birth Date"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (birthDate != null) {
                  await provider.generateHoroscope(birthDate!, latitude, longitude);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Horoscope Generated!")),
                  );
                }
              },
              child: const Text("Generate Horoscope"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (provider.horoscopeData.isNotEmpty) {
                  final file = await PdfGenerator.generateHoroscopePdf(provider.horoscopeData);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("PDF Saved: ${file.path}")),
                  );
                }
              },
              child: const Text("Export PDF"),
            ),
          ],
        ),
      ),
    );
  }
}
