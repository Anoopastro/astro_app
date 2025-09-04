import 'dart:convert';
import 'dart:io';
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController birthTimeController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AnoopAstro'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                    labelText: 'Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Enter Name' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: birthDateController,
                decoration: InputDecoration(
                    labelText: 'Birth Date (YYYY-MM-DD)',
                    border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Enter Date' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: birthTimeController,
                decoration: InputDecoration(
                    labelText: 'Birth Time (HH:MM)',
                    border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Enter Time' : null,
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: locationController,
                decoration: InputDecoration(
                    labelText: 'Birth Location',
                    border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Enter Location' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Generate Kundali'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => KundaliScreen(
                                  name: nameController.text,
                                  birthDate: birthDateController.text,
                                  birthTime: birthTimeController.text,
                                  location: locationController.text,
                                )));
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Kundali Screen ----------------
class KundaliScreen extends StatefulWidget {
  final String name;
  final String birthDate;
  final String birthTime;
  final String location;

  KundaliScreen(
      {required this.name,
      required this.birthDate,
      required this.birthTime,
      required this.location});

  @override
  _KundaliScreenState createState() => _KundaliScreenState();
}

class _KundaliScreenState extends State<KundaliScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, dynamic>? data;
  late TabController _tabController;

  final String clientId = 'YOUR_CLIENT_ID';
  final String clientSecret = 'YOUR_CLIENT_SECRET';
  String? accessToken;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    fetchData();
  }

  Future<void> fetchData() async {
    try {
      accessToken = await getProkeralaAccessToken(clientId, clientSecret);
      data = await fetchKundaliData(widget.birthDate, widget.birthTime,
          widget.location, accessToken!);
      setState(() => loading = false);
    } on SocketException {
      setState(() {
        loading = false;
        data = {'error': 'No internet connection. Please check network.'};
      });
    } catch (e) {
      setState(() {
        loading = false;
        data = {'error': e.toString()};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(body: Center(child: CircularProgressIndicator()));

    if (data?['error'] != null)
      return Scaffold(
          appBar: AppBar(title: Text('Kundali')),
          body: Center(child: Text(data!['error'], style: TextStyle(fontSize: 16))));

    return Scaffold(
      appBar: AppBar(
        title: Text('Kundali'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Panchang'),
            Tab(text: 'Kundali'),
            Tab(text: 'Dasha'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          PanchangTab(data: data!),
          KundaliTab(data: data!),
          DashaTab(data: data!),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.picture_as_pdf),
        onPressed: () => generatePdf(data!, widget.name),
      ),
    );
  }

  Future<void> generatePdf(Map<String, dynamic> data, String name) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (context) => pw.Stack(children: [
        pw.Positioned(
          child: pw.Opacity(
            opacity: 0.1,
            child: pw.Center(
                child: pw.Text('AnoopAstro',
                    style: pw.TextStyle(fontSize: 50))),
          ),
        ),
        pw.Column(children: [
          pw.Text('Kundali of $name', style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 10),
          pw.Text(jsonEncode(data), style: pw.TextStyle(fontSize: 14)),
        ])
      ]),
    ));
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}

// ---------------- Tabs ----------------
class PanchangTab extends StatelessWidget {
  final Map<String, dynamic> data;
  PanchangTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        Card(child: ListTile(title: Text('Tithi'), subtitle: Text(data['tithi'] ?? ''))),
        Card(child: ListTile(title: Text('Nakshatra'), subtitle: Text(data['nakshatra'] ?? ''))),
        Card(child: ListTile(title: Text('Yoga'), subtitle: Text(data['yoga'] ?? ''))),
        Card(child: ListTile(title: Text('Day'), subtitle: Text(data['day'] ?? ''))),
      ],
    );
  }
}

class KundaliTab extends StatelessWidget {
  final Map<String, dynamic> data;
  KundaliTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final lagna = data['lagna'] ?? [];
    final navmansh = data['navmansh'] ?? [];
    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        Text('Lagna Kundali', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: lagna.length,
          itemBuilder: (_, i) => Card(child: Center(child: Text(lagna[i].toString()))),
        ),
        SizedBox(height: 10),
        Text('Navmansh Kundali', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
          itemCount: navmansh.length,
          itemBuilder: (_, i) => Card(child: Center(child: Text(navmansh[i].toString()))),
        ),
      ],
    );
  }
}

class DashaTab extends StatelessWidget {
  final Map<String, dynamic> data;
  DashaTab({required this.data});

  @override
  Widget build(BuildContext
