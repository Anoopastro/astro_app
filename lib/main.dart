import 'package:flutter/material.dart';
import 'package:sweph/sweph.dart'; // Swiss Ephemeris binding
import 'providers/location_provider.dart';
import 'providers/dasha_provider.dart';
import 'utils/pdf_generator.dart';
import 'utils/chart_drawer.dart';
import 'utils/julian.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Location provider load
  final locProvider = LocationProvider();
  await locProvider.loadCities('assets/cities/cities.json');

  runApp(AnoopAstroApp(locProvider: locProvider));
}

class AnoopAstroApp extends StatelessWidget {
  final LocationProvider locProvider;

  const AnoopAstroApp({super.key, required this.locProvider});

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
      home: HomePage(locProvider: locProvider),
    );
  }
}

class HomePage extends StatefulWidget {
  final LocationProvider locProvider;

  const HomePage({super.key, required this.locProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime birthDate = DateTime(1990, 1, 1, 12, 0);
  String city = "Delhi";
  Map<String, double> planets = {};
  List<String> dasha = [];

  @override
  void initState() {
    super.initState();
    _calculateChart();
  }

  Future<void> _calculateChart() async {
    final cityCoords = widget.locProvider.getCoordinates(city);
    final jd = julianDayUtc(birthDate.toUtc());

    // Calculate planetary positions with Swiss Ephemeris
    final swe = Sweph();
    await swe.init();

    final planetNames = {
      SweConst.SE_SUN: "Sun",
      SweConst.SE_MOON: "Moon",
      SweConst.SE_MERCURY: "Mercury",
      SweConst.SE_VENUS: "Venus",
      SweConst.SE_MARS: "Mars",
      SweConst.SE_JUPITER: "Jupiter",
      SweConst.SE_SATURN: "Saturn",
      SweConst.SE_URANUS: "Uranus",
      SweConst.SE_NEPTUNE: "Neptune",
      SweConst.SE_PLUTO: "Pluto",
      SweConst.SE_TRUE_NODE: "Rahu"
    };

    Map<String, double> result = {};
    for (var entry in planetNames.entries) {
      final pos = await swe.calcUt(jd, entry.key, SweConst.SEFLG_SWIEPH);
      result[entry.value] = pos.longitude;
    }
    await swe.close();

    // Compute Dasha (Moon आधारित)
    final moonLong = result["Moon"] ?? 0.0;
    final dashaList = DashaProvider().computeVimshottari(jd, moonLong);

    setState(() {
      planets = result;
      dasha = dashaList;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Anoopastro Kundali")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Birth: $city\nDate: $birthDate",
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            if (planets.isNotEmpty) ChartDrawer(planets: planets).buildChart(),
            const SizedBox(height: 20),
            Text("Vimshottari Dasha",
                style: Theme.of(context).textTheme.titleLarge),
            for (var entry in dasha) Text(entry),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text("Export PDF"),
              onPressed: planets.isEmpty
                  ? null
                  : () async {
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
  }
}
