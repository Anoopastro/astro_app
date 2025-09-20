// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/horoscope_provider.dart';
import 'utils/pdf_generator.dart';
import 'widgets/pdf_chakra_painter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // load cities.json from assets (you should have this file)
  final citiesJson = await rootBundle.loadString('assets/cities/cities.json');
  final cities = jsonDecode(citiesJson) as List<dynamic>;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HoroscopeProvider(cities)),
      ],
      child: const AnoopAstroApp(),
    ),
  );
}

class AnoopAstroApp extends StatelessWidget {
  const AnoopAstroApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnoopAstro Light',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        textTheme: GoogleFonts.notoSansTextTheme(),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selectedDate = DateTime(1990,1,1,12,0);
  String? selectedCity;
  double latitude = 28.6139;
  double longitude = 77.2090;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HoroscopeProvider>(context);
    final cities = provider.cities;

    return Scaffold(
      appBar: AppBar(title: const Text('AnoopAstro Light')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select City'),
              value: selectedCity,
              items: cities.map<DropdownMenuItem<String>>((city) {
                return DropdownMenuItem<String>(
                  value: city['name'],
                  child: Text(city['name']),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                final city = cities.firstWhere((c) => c['name'] == value);
                setState(() {
                  selectedCity = value;
                  latitude = (city['latitude'] as num).toDouble();
                  longitude = (city['longitude'] as num).toDouble();
                });
                provider.setCity(value, latitude, longitude);
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(child: Text('Birth: ${selectedDate.toLocal()}'.split('.')[0])),
                ElevatedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d == null) return;
                    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: selectedDate.hour, minute: selectedDate.minute));
                    if (t == null) return;
                    setState(() {
                      selectedDate = DateTime(d.year,d.month,d.day,t.hour,t.minute);
                    });
                  },
                  child: const Text('Pick Date & Time'),
                )
              ],
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: () async {
                if (selectedCity == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a city')));
                  return;
                }
                await provider.calculateHoroscope(selectedDate);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horoscope calculated')));
              },
              child: const Text('Calculate Horoscope'),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: provider.planets.isEmpty
              ? const Center(child: Text('No horoscope calculated yet'))
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected city: ${provider.selectedCity}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Nakshatra: ${provider.nakshatra}', style: const TextStyle(fontSize: 16)),
                    Text('Tithi: ${provider.tithi}', style: const TextStyle(fontSize: 16)),
                    Text('Ascendant: ${provider.ascendant?.toStringAsFixed(2)}°', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),

                    // planets list
                    const Text('Planets:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ...provider.planets.entries.map((e) => Text('${e.key}: ${e.value.toStringAsFixed(2)}°')),

                    const SizedBox(height: 12),
                    Center(
                      child: SizedBox(width: 300, height: 300,
                        child: ChakraPainter(provider.houses, planets: provider.planets),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton(
              onPressed: provider.planets.isEmpty ? null : () async {
                final file = await PdfGenerator.generateHoroscopePdf({
                  'planets': provider.planets,
                  'houses': provider.houses,
                  'ascendant': provider.ascendant,
                  'nakshatra': provider.nakshatra,
                  'tithi': provider.tithi,
                  'dasha': provider.dasha,
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF saved: ${file.path}')));
              },
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
