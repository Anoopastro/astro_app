import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() => runApp(AnoopAstroApp());

class AnoopAstroApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnoopAstro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.amber),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: HomeScreen(),
    );
  }
}

// ---------------- Home Screen ----------------
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TextEditingController birthDateController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  final List<Map<String, dynamic>> features = [
    {'title': 'Panchang', 'icon': Icons.calendar_today},
    {'title': 'Mahadasha', 'icon': Icons.schedule},
    {'title': 'Antardasha', 'icon': Icons.timelapse},
    {'title': 'Chakras', 'icon': Icons.brightness_low},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AnoopAstro'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              controller: birthDateController,
              decoration: InputDecoration(
                  labelText: 'Enter Birth Date (YYYY-MM-DD)',
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                  labelText: 'Enter Location',
                  border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: features.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemBuilder: (context, index) {
                  final feature = features[index];
                  return FeatureCard(
                    title: feature['title'] as String,
                    icon: feature['icon'] as IconData,
                    onTap: () {
                      if (birthDateController.text.isEmpty ||
                          locationController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Enter birth date & location')));
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => FeatureScreen(
                                  feature['title'] as String,
                                  birthDate: birthDateController.text,
                                  location: locationController.text)));
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  FeatureCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        elevation: 5,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade300, Colors.purple.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              SizedBox(height: 10),
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Feature Screen ----------------
class FeatureScreen extends StatefulWidget {
  final String feature;
  final String birthDate;
  final String location;

  FeatureScreen(this.feature,
      {required this.birthDate, required this.location});

  @override
  _FeatureScreenState createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? data;
  bool loading = true;
  late TabController _tabController;

  // <-- Replace with your actual Prokerala credentials
  final String clientId = '26eb97c3-7cbb-4df1-90e0-a84edf49043d';
  final String clientSecret = 'E0ytDZ3fBCRx3Gi0q3PeMbI5gpevfY6v986FQWmx';
  String? accessToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    authenticateAndLoad();
  }

  Future<void> authenticateAndLoad() async {
    try {
      accessToken = await getProkeralaAccessToken(clientId, clientSecret);
      await loadData();
    } catch (e) {
      setState(() {
        loading = false;
        data = {'error': e.toString()};
      });
    }
  }

  Future<void> loadData() async {
    try {
      if (accessToken == null) return;

      if (widget.feature == 'Panchang') {
        data = await fetchPanchang(
            widget.birthDate, widget.location, accessToken!);
      } else if (widget.feature == 'Mahadasha') {
        data = await fetchMahadasha(widget.birthDate, accessToken!);
      } else if (widget.feature == 'Antardasha') {
        data = await fetchAntardasha(widget.birthDate, accessToken!);
      } else if (widget.feature == 'Chakras') {
        data = await fetchChakras(accessToken!);
      } else {
        data = {'info': 'No data yet'};
      }
    } catch (e) {
      data = {'error': e.toString()};
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.feature),
        bottom: (widget.feature == 'Mahadasha' || widget.feature == 'Antardasha')
            ? TabBar(
                controller: _tabController,
                tabs: [Tab(text: 'Main'), Tab(text: 'Details')],
              )
            : null,
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : (widget.feature == 'Mahadasha' || widget.feature == 'Antardasha')
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    DataTab(data: data ?? {}),
                    DataTab(data: data ?? {}),
                  ],
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.feature == 'Panchang')
                        PanchangCards(data: data ?? {}),
                      if (widget.feature == 'Chakras')
                        ChakraGrid(data: data ?? {}),
                      DataTab(data: data ?? {}),
                      SizedBox(height: 20),
                      Center(
                        child: ElevatedButton(
                          child: Text('Generate PDF'),
                          onPressed: () async =>
                              await generatePdf(widget.feature, data ?? {}),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> generatePdf(String feature, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Stack(
          children: [
            pw.Positioned(
              child: pw.Opacity(
                opacity: 0.1,
                child: pw.Center(
                    child: pw.Text('AnoopAstro',
                        style: pw.TextStyle(fontSize: 50))),
              ),
            ),
            pw.Center(
              child: pw.Text('$feature Report\n\n${jsonEncode(data)}',
                  style: pw.TextStyle(fontSize: 20)),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}

// ---------------- Data Tab ----------------
class DataTab extends StatelessWidget {
  final Map<String, dynamic> data;
  DataTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text('${e.key}: ${e.value}', style: TextStyle(fontSize: 16)),
        );
      }).toList(),
    );
  }
}

// ---------------- Panchang Cards ----------------
class PanchangCards extends StatelessWidget {
  final Map<String, dynamic> data;
  PanchangCards({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 6,
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade300, Colors.purple.shade100],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: data.entries.map((e) {
                return Text('${e.key}: ${e.value}',
                    style: TextStyle(color: Colors.white, fontSize: 16));
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- Chakra Grid ----------------
class ChakraGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  ChakraGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final List chakras = data['chakras'] ?? [];
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: chakras.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10),
      itemBuilder: (context, index) {
        final chakra = chakras[index] as Map<String, dynamic>;
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(chakra['icon'] as IconData,
                  size: 50, color: chakra['color'] as Color),
              SizedBox(height: 10),
              Text(chakra['name'] as String,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      },
    );
  }
}

// ---------------- Prokerala API ----------------
Future<String> getProkeralaAccessToken(String clientId, String clientSecret) async {
  final response = await http.post(
    Uri.parse('https://api.prokerala.com/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: 'grant_type=client_credentials&client_id=$clientId&client_secret=$clientSecret',
  );
  final data = jsonDecode(response.body);
  if (data['access_token'] != null) return data['access_token'];
  throw Exception('Failed to get access token: $data');
}

Future<Map<String, dynamic>> fetchPanchang(
    String birthDate, String location, String token) async {
  // Dummy API call structure; replace with actual Prokerala Panchang API endpoint
  return {
    'tithi': 'Shukla Paksha',
    'nakshatra': 'Ashwini',
    'yoga': 'Vishkumbha'
  };
}

Future<Map<String, dynamic>> fetchMahadasha(String birthDate, String token) async {
  return {'mahadasha': 'Ketu', 'start': '2025-01-01', 'end': '2032-03-15'};
}

Future<Map<String, dynamic>> fetchAntardasha(String birthDate, String token) async {
  return {'antardasha': 'Venus', 'start': '2025-01-01', 'end': '2027-06-10'};
}

Future<Map<String, dynamic>> fetchChakras(String token) async {
  return {
    'chakras': [
      {'name': 'Muladhara', 'icon': Icons.adjust, 'color': Colors.red},
      {'name': 'Swadhisthana', 'icon': Icons.adjust, 'color': Colors.orange},
      {'name': 'Manipura', 'icon': Icons.adjust, 'color': Colors.yellow},
      {'name': 'Anahata', 'icon': Icons.adjust, 'color': Colors.green},
    ]
  };
}
