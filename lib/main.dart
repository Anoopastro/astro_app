import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ephemeris_provider.dart';
import 'widgets/chart_widget.dart';
import 'utils/pdf_generator.dart';

void main() {
  runApp(const AnoopAstroApp());
}

class AnoopAstroApp extends StatelessWidget {
  const AnoopAstroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EphemerisProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AnoopAstro Light',
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    initializeAstro();
  }

  Future<void> initializeAstro() async {
    final provider = Provider.of<EphemerisProvider>(context, listen: false);
    await provider.initialize();
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<EphemerisProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("AnoopAstro Light")),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ChartWidget(planets: provider.planets, houses: provider.houses),
                  const SizedBox(height: 20),
                  ElevatedButton(
                      onPressed: () async {
                        final pdf = await PdfGenerator.generateKundaliPdf(
                            planets: provider.planets,
                            houses: provider.houses,
                            birthDate: provider.birthDate,
                            city: provider.city);
                        await PdfGenerator.saveAndShare(pdf);
                      },
                      child: const Text("Generate PDF"))
                ],
              ),
            ),
    );
  }
}
