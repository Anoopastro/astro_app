import 'package:flutter/material.dart';
import 'providers/ephemeris_provider.dart';
import 'providers/location_provider.dart';
import 'providers/dasha_provider.dart';
import 'utils/pdf_generator.dart';
import 'utils/chart_drawer.dart';
import 'utils/julian.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ephem = EphemerisProvider();
  await ephem.init(); // पहले initialize करेंगे

  final locProvider = LocationProvider();
  await locProvider.loadCities('assets/cities/cities.json');

  runApp(AnoopAstroApp(ephem: ephem, locProvider: locProvider));
}

class AnoopAstroApp extends StatelessWidget {
  final EphemerisProvider ephem;
  final LocationProvider locProvider;

  const AnoopAstroApp({super.key, required this.ephem, required this.locProvider});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anoopastro',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'Roboto'),
        ),
      ),
      home: HomePage(ephem: ephem, locProvider: locProvider),
    );
  }
}

class HomePage extends StatefulWidget {
  final EphemerisProvider ephem;
  final LocationProvider locProvider;

  const HomePage({super.key, required this.ephem, required this.locProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime birthDate = DateTime(1990, 1, 1, 12, 0);
  String city = "Delhi";

  Map<String, double>? planets;
  Map<String, double>? houses;
  List<String>? dasha;

  @override
  void initState() {
    super.initState();
    _calculateKundali();
  }

  Future<void> _calculateKundali() async {
    final cityCoords = widget.locProvider.getCoordinates(city);
    final jd = julianDayUtc(birthDate.toUtc());

    final p = await widget.ephem.calculatePlanets(jd);
    final h = await widget.ephem.calculateHouses(jd, cityCoords['lat'], cityCoords['lon']);
    final d = DashaProvider().computeVimshottari(jd, p['Moon'] ?? 0);

    setState(() {
      planets = p;
      houses = h;
      dasha = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (planets == null || houses == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Anoopastro Kundali")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Birth Place: $city\nDate: $birthDate", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),

            /// Chart Drawing (dummy planets for now)
            ChartDrawer(planets: planets!).buildChart(),
            const SizedBox(height: 20),

            /// Show Lagna & Houses
            Text("Ascendant & Houses", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var entry in houses!.entries)
              Text("${entry.key}: ${entry.value.toStringAsFixed(2)}°"),

            const SizedBox(height: 20),

            /// Show Planets
            Text("Planets", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (var entry in planets!.entries)
              Text("${entry.key}: ${entry.value.toStringAsFixed(2)}°"),

            const SizedBox(height: 20),

            /// Vimshottari Dasha
            Text("Vimshottari Dasha", style: Theme.of(context).textTheme.titleLarge),
            for (var entry in dasha!) Text(entry),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF"),
              onPressed: () async {
                final pdf = await PdfGenerator.generateKundaliPdf(
                  planets: planets!,
                  city: city,
                  birthDate: birthDate,
                );
                await PdfGenerator.saveAndShare(pdf);
              },
            )
          ],
        ),
      ),
    );
  }
}
