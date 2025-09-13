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
  await ephem.init();

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

  @override
  Widget build(BuildContext context) {
    final cityCoords = widget.locProvider.getCoordinates(city)!;
    final jd = julianDayUtc(birthDate.toUtc());

    return FutureBuilder(
      future: Future.wait([
        widget.ephem.allPlanetsAt(jd),
        widget.ephem.calculateHouses(jd, cityCoords['lat']!, cityCoords['lon']!),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final planets = snapshot.data![0] as Map<String, double>;
        final houses = snapshot.data![1] as Map<String, double>;
        final dasha = DashaProvider().computeVimshottari(jd, planets['Moon'] ?? 0);

        return Scaffold(
          appBar: AppBar(title: const Text("Anoopastro Kundali")),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text("Birth: $city\nDate: $birthDate", style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 10),
                ChartDrawer(planets: planets, houses: houses).buildChart(),
                const SizedBox(height: 20),
                Text("Vimshottari Dasha", style: Theme.of(context).textTheme.titleLarge),
                for (var entry in dasha) Text(entry),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Export PDF"),
                  onPressed: () async {
                    final pdf = await PdfGenerator.generateKundaliPdf(
                      planets: planets,
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
      },
    );
  }
}
