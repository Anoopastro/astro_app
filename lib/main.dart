import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(AnoopAstroApp());
}

class AnoopAstroApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AnoopAstro Light',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: HoroscopeHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class City {
  final String name;
  final double lat;
  final double lon;
  City({required this.name, required this.lat, required this.lon});
  factory City.fromJson(Map<String, dynamic> j) {
    // Accept common key names
    final name = j['name'] ?? j['city'] ?? 'Unknown';
    final latVal = j['lat'] ?? j['latitude'] ?? j['Latitude'];
    final lonVal = j['lon'] ?? j['lng'] ?? j['longitude'] ?? j['Longitude'];
    double lat = (latVal is num) ? latVal.toDouble() : double.tryParse('$latVal') ?? 0.0;
    double lon = (lonVal is num) ? lonVal.toDouble() : double.tryParse('$lonVal') ?? 0.0;
    return City(name: name, lat: lat, lon: lon);
  }
}

/// Simple EphemerisProvider placeholder: later you can plug a binary ephem reader here.
class EphemerisProvider {
  // Example stub for future ephemeris integration
  // double planetLongitude(String planet, double jd) => ...;
  EphemerisProvider();
}

class HoroscopeHomePage extends StatefulWidget {
  @override
  _HoroscopeHomePageState createState() => _HoroscopeHomePageState();
}

class _HoroscopeHomePageState extends State<HoroscopeHomePage> {
  List<City> cities = [];
  City? selectedCity;
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  // results
  double? jd;
  double? ascendant;
  double? sunLon;
  double? moonLon;

  bool locating = false;

  final EphemerisProvider ephemeris = EphemerisProvider();

  @override
  void initState() {
    super.initState();
    loadCities();
  }

  Future<void> loadCities() async {
    final s = await rootBundle.loadString('assets/cities.json');
    final list = json.decode(s) as List<dynamic>;
    final loaded = list.map((e) => City.fromJson(e)).toList();
    setState(() {
      cities = loaded;
      if (cities.isNotEmpty) selectedCity = cities[0];
    });
  }

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => selectedDate = d);
  }

  Future<void> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: selectedTime);
    if (t != null) setState(() => selectedTime = t);
  }

  /// Try to get device location and autofill nearest city from assets.
  Future<void> autofillNearestCity() async {
    if (kIsWeb) {
      // geolocator on web needs additional config; skip autofill on web
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Autofill not available on Web.')));
      return;
    }

    setState(() => locating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location permission denied')));
        setState(() => locating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final nearest = findNearestCity(pos.latitude, pos.longitude);
      if (nearest != null) {
        setState(() {
          selectedCity = nearest;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected nearest city: ${nearest.name}')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No cities loaded to select from.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    } finally {
      setState(() => locating = false);
    }
  }

  City? findNearestCity(double lat, double lon) {
    if (cities.isEmpty) return null;
    City? nearest;
    double bestKm = double.infinity;
    for (final c in cities) {
      final d = haversineKm(lat, lon, c.lat, c.lon);
      if (d < bestKm) {
        bestKm = d;
        nearest = c;
      }
    }
    return nearest;
  }

  double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    final R = 6371.0;
    final dLat = toRadians(lat2 - lat1);
    final dLon = toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRadians(lat1)) * cos(toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  void computeAll() {
    if (selectedCity == null) return;
    final localDt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final utc = localDt.toUtc();
    final jdUtc = julianDayUtc(utc);
    final asc = ascendantDegrees(jdUtc, selectedCity!.lat, selectedCity!.lon);
    final sun = sunEclipticLongitude(jdUtc);
    final moon = moonEclipticLongitude(jdUtc);

    // future: you can call ephemeris.planetLongitude('Mercury', jdUtc) etc

    setState(() {
      jd = jdUtc;
      ascendant = asc;
      sunLon = sun;
      moonLon = moon;
    });
  }

  String degToString(double? d) {
    if (d == null) return '--';
    final deg = d % 360;
    final intDeg = deg.floor();
    final min = ((deg - intDeg) * 60).floor();
    final sec = (((deg - intDeg) * 60 - min) * 60).round();
    return '$intDeg° ${min}\' ${sec}\"';
  }

  String zodiacFromLongitude(double lon) {
    final sign = ((lon ~/ 30) % 12);
    final signs = [
      'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
      'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'
    ];
    final degInSign = (lon % 30).toStringAsFixed(2);
    return '${signs[sign]} ${degInSign}°';
  }

  /// Generate a PDF report (simple) with watermark "AnoopAstro Light"
  Future<Uint8List> buildPdfBytes() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final df = DateFormat.yMMMMd().add_Hm();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return [
            pw.Stack(
              children: [
                // Watermark
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: 0.08,
                    child: pw.Center(
                      child: pw.Text('AnoopAstro Light', style: pw.TextStyle(fontSize: 80, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                ),
                pw.Positioned(
                  left: 0,
                  right: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('AnoopAstro Light — Horoscope', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Generated: ${df.format(now)}'),
                      pw.SizedBox(height: 12),
                      pw.Divider(),
                      pw.Text('Input:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('City: ${selectedCity?.name ?? "--"}'),
                      pw.Text('Date: ${DateFormat.yMMMMd().format(selectedDate)}'),
                      pw.Text('Time: ${selectedTime.format(context)} (local)'),
                      pw.SizedBox(height: 12),
                      pw.Text('Results:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Julian Day: ${jd?.toStringAsFixed(6) ?? "--"}'),
                      pw.Text('Ascendant (Lagna): ${ascendant != null ? '${ascendant!.toStringAsFixed(6)}° — ${zodiacFromLongitude(ascendant!)}' : "--"}'),
                      pw.Text('Sun: ${sunLon != null ? '${sunLon!.toStringAsFixed(6)}° — ${zodiacFromLongitude(sunLon!)}' : "--"}'),
                      pw.Text('Moon: ${moonLon != null ? '${moonLon!.toStringAsFixed(6)}° — ${zodiacFromLongitude(moonLon!)}' : "--"}'),
                      pw.SizedBox(height: 18),
                      pw.Text('Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('This PDF was generated offline by AnoopAstro Light. For higher planetary accuracy (Mercury→Pluto) you can include a precomputed ephemeris binary in app assets.'),
                      pw.SizedBox(height: 30),
                      pw.Center(child: pw.Text('© AnoopAstro Light', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  Future<void> exportPdf() async {
    try {
      final bytes = await buildPdfBytes();
      // show native share/print UI
      await Printing.sharePdf(bytes: bytes, filename: 'AnoopAstro_Horoscope.pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat.yMMMEd();
    return Scaffold(
      appBar: AppBar(title: Text('AnoopAstro Light'), centerTitle: true),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: DropdownButton<City>(
                      isExpanded: true,
                      value: selectedCity,
                      hint: Text('Select city (from assets)'),
                      items: cities.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} (${c.lat.toStringAsFixed(3)}, ${c.lon.toStringAsFixed(3)})'),
                      )).toList(),
                      onChanged: (v) => setState(() => selectedCity = v),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: locating ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.my_location),
                    label: Text('Autofill'),
                    onPressed: locating ? null : autofillNearestCity,
                  ),
                ]),
                SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: pickDate,
                      child: InputDecorator(decoration: InputDecoration(labelText: "Date"), child: Text(formatter.format(selectedDate))),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: pickTime,
                      child: InputDecorator(decoration: InputDecoration(labelText: "Time"), child: Text(selectedTime.format(context))),
                    ),
                  ),
                ]),
                SizedBox(height: 12),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(icon: Icon(Icons.calculate), label: Text('Compute Horoscope'), onPressed: computeAll)),
                ]),
              ]),
            ),
          ),
          SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Card(
                elevation: 1,
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Results', style: Theme.of(context).textTheme.headline6),
                    SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text('Julian Day: ${jd?.toStringAsFixed(6) ?? '--'}')),
                      Expanded(child: Text('Ascendant: ${degToString(ascendant)}')),
                    ]),
                    SizedBox(height: 8),
                    Divider(),
                    ListTile(
                      title: Text('Sun'),
                      subtitle: Text('Longitude: ${sunLon?.toStringAsFixed(6) ?? '--'}°  — ${sunLon != null ? zodiacFromLongitude(sunLon!) : ''}'),
                      trailing: Text(degToString(sunLon)),
                    ),
                    ListTile(
                      title: Text('Moon'),
                      subtitle: Text('Longitude: ${moonLon?.toStringAsFixed(6) ?? '--'}°  — ${moonLon != null ? zodiacFromLongitude(moonLon!) : ''}'),
                      trailing: Text(degToString(moonLon)),
                    ),
                    Divider(),
                    SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(icon: Icon(Icons.picture_as_pdf), label: Text('Export PDF'), onPressed: exportPdf)),
                    ]),
                    SizedBox(height: 16),
                    Text('© AnoopAstro Light', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/* -------------------------------
   Astronomical utility functions
   ------------------------------- */

double toRadians(double deg) => deg * pi / 180.0;
double toDegrees(double rad) => rad * 180.0 / pi;

/// Convert UTC DateTime to Julian Day (including fraction)
double julianDayUtc(DateTime utc) {
  int Y = utc.year;
  int M = utc.month;
  double D = utc.day.toDouble() + (utc.hour / 24.0) + (utc.minute / 1440.0) + (utc.second / 86400.0) + (utc.millisecond / 86400000.0);

  if (M <= 2) {
    Y -= 1;
    M += 12;
  }
  int A = (Y / 100).floor();
  int B = 2 - A + (A / 4).floor();
  double jd = (365.25 * (Y + 4716)).floorToDouble() + (30.6001 * (M + 1)).floorToDouble() + D + B - 1524.5;
  return jd;
}

/// Greenwich Mean Sidereal Time in degrees
double gmstDegrees(double jd) {
  double T = (jd - 2451545.0) / 36525.0;
  double gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0) + 0.000387933 * T * T - (T * T * T) / 38710000.0;
  gmst = (gmst % 360 + 360) % 360;
  return gmst;
}

/// Local Sidereal Time (degrees) for longitude (east positive)
double localSiderealTimeDegrees(double jd, double longitudeDegEast) {
  double g = gmstDegrees(jd);
  double lst = g + longitudeDegEast;
  return (lst % 360 + 360) % 360;
}

/// Mean obliquity of the ecliptic (degrees) — Meeus approx
double obliquityDegrees(double jd) {
  double T = (jd - 2451545.0) / 36525.0;
  double eps = 23.4392911111111 - 0.0130041666667 * T - 1.6666666667e-7 * T * T + 5.0277777778e-7 * T * T * T;
  return eps;
}

/// Compute Ascendant (Lagna) in ecliptic longitude degrees
double ascendantDegrees(double jd, double latitudeDeg, double longitudeDegEast) {
  double eps = toRadians(obliquityDegrees(jd));
  double lat = toRadians(latitudeDeg);
  double lst = toRadians(localSiderealTimeDegrees(jd, longitudeDegEast));

  // Using formula: tan(asc) = (sin(LST)*cos(eps) - tan(lat)*sin(eps)) / cos(LST)
  double num = sin(lst) * cos(eps) - tan(lat) * sin(eps);
  double den = cos(lst);
  double asc = atan2(num, den);
  double ascDeg = (toDegrees(asc) % 360 + 360) % 360;
  return ascDeg;
}

/// Simple Sun ecliptic longitude (approx)
double sunEclipticLongitude(double jd) {
  double T = (jd - 2451545.0) / 36525.0;
  double M = (357.52911 + 35999.05029 * T - 0.0001537 * T * T) % 360;
  double L0 = (280.46646 + 36000.76983 * T + 0.0003032 * T * T) % 360;
  double Mrad = toRadians(M);
  double C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(Mrad)
      + (0.019993 - 0.000101 * T) * sin(2 * Mrad)
      + 0.000289 * sin(3 * Mrad);
  double trueLong = L0 + C;
  return (trueLong % 360 + 360) % 360;
}

/// Simplified Moon ecliptic longitude (approx)
double moonEclipticLongitude(double jd) {
  double T = (jd - 2451545.0) / 36525.0;
  double L0 = (218.3164477 + 481267.88123421 * T - 0.0015786 * T * T + T * T * T / 538841.0 - T * T * T * T / 65194000.0) % 360;
  double D = (297.8501921 + 445267.1114034 * T - 0.0018819 * T * T + T * T * T / 545868.0 - T * T * T * T / 113065000.0) % 360;
  double M = (357.5291092 + 35999.0502909 * T - 0.0001536 * T * T + T * T * T / 24490000.0) % 360;
  double Mprime = (134.9633964 + 477198.8675055 * T + 0.0087414 * T * T + T * T * T / 69699.0 - T * T * T * T / 14712000.0) % 360;
  double F = (93.2720950 + 483202.0175233 * T - 0.0036539 * T * T - T * T * T / 3526000.0 + T * T * T * T / 863310000.0) % 360;

  double Dm = toRadians(D);
  double Mm = toRadians(M);
  double Mpm = toRadians(Mprime);
  double Fm = toRadians(F);

  double lon = L0
      + 6.289 * sin(Mpm)
      + 1.274 * sin(2 * Dm - Mpm)
      + 0.658 * sin(2 * Dm)
      + 0.214 * sin(2 * Mpm)
      - 0.186 * sin(Mm)
      - 0.059 * sin(2 * Dm - 2 * Mpm)
      - 0.057 * sin(2 * Dm - Mm - Mpm)
      + 0.053 * sin(2 * Dm + Mpm)
      + 0.046 * sin(2 * Dm - Mm)
      + 0.041 * sin(Mm - Mpm)
      - 0.035 * sin(Dm)
      - 0.031 * sin(Mm + Mpm)
      - 0.015 * sin(2 * Fm)
      + 0.011 * sin(2 * Dm - 2 * Fm);

  return (lon % 360 + 360) % 360;
}
