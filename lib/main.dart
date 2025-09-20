import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweph/sweph.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load cities.json
  final citiesJson = await rootBundle.loadString('assets/cities/cities.json');
  final cities = jsonDecode(citiesJson);

  // Load ephemeris
  final ephemPath = await _loadEphemerisFile();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
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

// ---------------------- VIMSHOTTARI DASHAS ----------------------
class VimshottariDasha {
  static const mahadashaYears = {
    'Ketu': 7,
    'Venus': 20,
    'Sun': 6,
    'Moon': 10,
    'Mars': 7,
    'Rahu': 18,
    'Jupiter': 16,
    'Saturn': 19,
    'Mercury': 17,
  };

  static const nakshatraSequence = [
    'Ketu', 'Venus', 'Sun', 'Moon', 'Mars', 'Rahu', 'Jupiter', 'Saturn', 'Mercury'
  ];

  static Map<String, dynamic> calculate(double moonLongitude, double jdBirth) {
    final nakshatraIndex = (moonLongitude / 13.3333333).floor() % 27;
    final remainingFraction = (13.3333333 - (moonLongitude % 13.3333333)) / 13.3333333;
    int dashaStartIndex = nakshatraIndex % 9;

    final List<Map<String, dynamic>> dashaPeriods = [];
    double jdStart = jdBirth;

    for (int i = 0; i < 9; i++) {
      final planet = nakshatraSequence[(dashaStartIndex + i) % 9];
      double years = mahadashaYears[planet]!.toDouble();
      if (i == 0) years *= remainingFraction;
      double jdEnd = jdStart + years * 365.25;
      dashaPeriods.add({
        'planet': planet,
        'startJD': jdStart,
        'endJD': jdEnd,
        'years': years,
      });
      jdStart = jdEnd;
    }

    final currentDasha = dashaPeriods.firstWhere(
        (d) => jdBirth >= d['startJD'] && jdBirth <= d['endJD'],
        orElse: () => dashaPeriods[0]);

    final antardashas = _calculateAntardasha(currentDasha);

    return {
      'mahadashas': dashaPeriods,
      'currentMahadasha': currentDasha,
      'antardashas': antardashas,
    };
  }

  static List<Map<String, dynamic>> _calculateAntardasha(Map<String, dynamic> mahadasha) {
    final planet = mahadasha['planet'] as String;
    final totalYears = mahadasha['years'] as double;

    final fractions = [7, 20, 6, 10, 7, 18, 16, 19, 17];
    final totalFraction = fractions.reduce((a, b) => a + b);
    List<Map<String, dynamic>> antardasha = [];
    double jdStart = mahadasha['startJD'];

    for (int i = 0; i < 9; i++) {
      double fractionYears = totalYears * (fractions[i] / totalFraction);
      double jdEnd = jdStart + fractionYears * 365.25;
      antardasha.add({
        'planet': nakshatraSequence[i],
        'startJD': jdStart,
        'endJD': jdEnd,
        'years': fractionYears,
      });
      jdStart = jdEnd;
    }
    return antardasha;
  }
}

// ---------------------- HOROSCOPE PROVIDER ----------------------
class HoroscopeProvider extends ChangeNotifier {
  final List<dynamic> cities;
  final String ephemPath;
  late Sweph sweph;

  Map<String, dynamic> horoscopeData = {};
  String selectedCity = '';
  double latitude = 0.0;
  double longitude = 0.0;

  HoroscopeProvider(this.cities, this.ephemPath) {
    sweph = Sweph();
    sweph.swe_set_ephe_path(ephemPath);
  }

  void setCity(String cityName, double lat, double lon) {
    selectedCity = cityName;
    latitude = lat;
    longitude = lon;
    notifyListeners();
  }

  Future<void> calculateHoroscope(DateTime birthDate) async {
    final jd = sweph.swe_julday(
      birthDate.year,
      birthDate.month,
      birthDate.day,
      birthDate.hour + birthDate.minute / 60.0,
      Sweph.SE_GREG_CAL,
    );

    Map<String, List<double>> planets = {};
    final planetIds = {
      'Sun': Sweph.SE_SUN,
      'Moon': Sweph.SE_MOON,
      'Mercury': Sweph.SE_MERCURY,
      'Venus': Sweph.SE_VENUS,
      'Mars': Sweph.SE_MARS,
      'Jupiter': Sweph.SE_JUPITER,
      'Saturn': Sweph.SE_SATURN,
      'Rahu': Sweph.SE_NODE,
      'Ketu': Sweph.SE_TRUE_NODE,
    };

    for (var entry in planetIds.entries) {
      planets[entry.key] = sweph.swe_calc_ut(jd, entry.value, Sweph.SEFLG_SWIEPH);
    }

    final houses = sweph.swe_houses(jd, latitude, longitude);
    final ascendant = houses[0][0];

    final moonPos = planets['Moon']![0];
    final nakshatra = _getNakshatra(moonPos);
    final tithi = _getTithi(jd);
    final dasha = VimshottariDasha.calculate(moonPos, jd);

    horoscopeData = {
      'planets': planets,
      'lagna': ascendant,
      'houses': houses[0],
      'nakshatra': nakshatra,
      'tithi': tithi,
      'dasha': dasha,
    };
    notifyListeners();
  }

  String _getNakshatra(double moonLongitude) {
    final nakshatras = [
      'Ashwini','Bharani','Krittika','Rohini','Mrigashirsha','Ardra','Punarvasu','Pushya','Ashlesha','Magha',
      'Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula',
      'Purva Ashadha','Uttara Ashadha','Shravana','Dhanishta','Shatabhisha','Purva Bhadrapada','Uttara Bhadrapada','Revati'
    ];
    final index = ((moonLongitude / 13.3333333).floor()) % 27;
    return nakshatras[index];
  }

  String _getTithi(double jd) => 'Shukla Paksha 5';
}

// ---------------------- HOME PAGE ----------------------
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _dateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HoroscopeProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AnoopAstro Light')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text('Select City'),
              value: provider.selectedCity.isEmpty ? null : provider.selectedCity,
              isExpanded: true,
              items: provider.cities.map<DropdownMenuItem<String>>((city) {
                return DropdownMenuItem<String>(
                  value: city['name'],
                  child: Text(city['name']),
                  onTap: () {
                    provider.setCity(
                      city['name'],
                      city['latitude'].toDouble(),
                      city['longitude'].toDouble(),
                    );
                  },
                );
              }).toList(),
              onChanged: (_) {},
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: 'Birth Date (YYYY-MM-DD HH:mm)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_dateController.text.isEmpty) return;
                final input = DateTime.parse(_dateController.text);
                await provider.calculateHoroscope(input);
              },
              child: const Text('Calculate Horoscope'),
            ),
            const SizedBox(height: 20),
            if (provider.horoscopeData.isNotEmpty) ...[
              Text('Nakshatra: ${provider.horoscopeData['nakshatra']}', style: const TextStyle(fontSize: 18)),
              Text('Tithi: ${provider.horoscopeData['tithi']}', style: const TextStyle(fontSize: 18)),
              Text('Lagna: ${provider.horoscopeData['lagna']}', style: const TextStyle(fontSize: 18)),
              Text('Current Mahadasha: ${provider.horoscopeData['dasha']['currentMahadasha']['planet']}', style: const TextStyle(fontSize: 18)),
              Text('Antardasha: ${provider.horoscopeData['dasha']['antardashas'][0]['planet']}', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 300,
                child: CustomPaint(
                  painter: ChakraPainter(provider.horoscopeData['houses']),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _generatePDF(provider),
                child: const Text('Generate PDF with Chart'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generatePDF(HoroscopeProvider provider) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text('AnoopAstro Light Horoscope', style: const pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 10),
            pw.Text('City: ${provider.selectedCity}'),
            pw.Text('Lagna: ${provider.horoscopeData['lagna']}'),
            pw.Text('Nakshatra: ${provider.horoscopeData['nakshatra']}'),
            pw.Text('Tithi: ${provider.horoscopeData['tithi']}'),
            pw.Text('Mahadasha: ${provider.horoscopeData['dasha']['currentMahadasha']['planet']}'),
            pw.Text('Antardasha: ${provider.horoscopeData['dasha']['antardashas'][0]['planet']}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

// ---------------------- 16-HOUSE CHAKRA ----------------------
class ChakraPainter extends CustomPainter {
  final List<dynamic>? houses;

  ChakraPainter(this.houses);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    canvas.drawCircle(center, radius, paint);

    for (int i = 0; i < 16; i++) {
      final angle = 2 * pi / 16 * i;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
