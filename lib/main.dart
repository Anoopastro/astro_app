import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/horoscope_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load cities.json
  final citiesJson = await rootBundle.loadString('assets/cities/cities.json');
  final cities = jsonDecode(citiesJson);

  // Load ephemeris file
  final ephemPath = await _loadEphemerisFile();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HoroscopeProvider>(
          create: (_) => HoroscopeProvider(cities, ephemPath),
        ),
      ],
      child: const AnoopAstroApp(),
    ),
  );
}

Future<String> _loadEphemerisFile() async {
  final byteData = await rootBundle.load('assets/ephem/ephem_1950_2050.dat');
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/ephem_1950_2050.dat');
  await file.writeAsBytes(byteData.buffer.asUint8List());
  return file.path;
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
      supportedLocales: const [
        Locale('en', ''),
        Locale('hi', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  String? selectedCity;
  double? latitude;
  double? longitude;
  DateTime birthDate = DateTime(2000, 1, 1, 12, 0);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HoroscopeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AnoopAstro Light')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // City Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Select City'),
              value: selectedCity,
              items: provider.cities.map<DropdownMenuItem<String>>((city) {
                return DropdownMenuItem<String>(
                  value: city['name'],
                  child: Text(city['name']),
                );
              }).toList(),
              onChanged: (value) {
                final city = provider.cities.firstWhere((c) => c['name'] == value);
                setState(() {
                  selectedCity = value;
                  latitude = city['latitude'];
                  longitude = city['longitude'];
                  provider.setCity(value!, latitude!, longitude!);
                });
              },
            ),
            const SizedBox(height: 16),
            // Birth Date Picker
            Row(
              children: [
                Expanded(
                  child: Text('Birth Date: ${birthDate.toLocal()}'.split('.')[0]),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: birthDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: birthDate.hour, minute: birthDate.minute),
                      );
                      if (time != null) {
                        setState(() {
                          birthDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                  child: const Text('Select Date & Time'),
                )
              ],
            ),
            const SizedBox(height: 16),
            // Calculate Horoscope Button
            ElevatedButton(
              onPressed: () async {
                if (selectedCity != null) {
                  await provider.calculateHoroscope(birthDate);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Horoscope Calculated!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a city!')),
                  );
                }
              },
              child: const Text('Calculate Horoscope'),
            ),
            const SizedBox(height: 16),
            // Horoscope Display
            Expanded(
              child: SingleChildScrollView(
                child: provider.horoscopeData.isEmpty
                    ? const Text('No data yet')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lagna: ${provider.horoscopeData['lagna'] ?? ''}'),
                          const SizedBox(height: 8),
                          Text('Nakshatra: ${provider.horoscopeData['nakshatra'] ?? ''}'),
                          const SizedBox(height: 8),
                          Text('Tithi: ${provider.horoscopeData['tithi'] ?? ''}'),
                          const SizedBox(height: 8),
                          const Text('Planets:'),
                          ...((provider.horoscopeData['planets'] as Map<String, dynamic>).entries.map(
                            (e) => Text('${e.key}: ${e.value[0].toStringAsFixed(2)}°'),
                          )),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // TODO: Call PDF generation
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF generation not implemented yet')),
                );
              },
              child: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
