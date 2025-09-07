import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tzdb;
import 'package:timezone/timezone.dart' as tz;

// PDF
import 'package:pdf/pdf.dart' as pwf;
import 'package:pdf/widgets.dart' as pw;

// App constants
const appBrand = "AnoopAstro";
const brandPrimary = Color(0xFF6A1B9A); // Purple
const brandGold = Color(0xFFFFC107); // Gold

// Hindi labels
const grahHindi = [
  'सूर्य', 'चंद्र', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'राहु', 'केतु'
];

const rashiHindi = [
  'मेष','वृषभ','मिथुन','कर्क','सिंह','कन्या','तुला','वृश्चिक','धनु','मकर','कुंभ','मीन'
];

const nakshatraHindi = [
  'अश्विनी','भरणी','कृत्तिका','रोहिणी','मृगशीर्ष','आर्द्रा','पुनर्वसु','पुष्य','आश्लेषा',
  'मघा','पूर्वा फाल्गुनी','उत्तरा फाल्गुनी','हस्त','चित्रा','स्वाती','विशाखा','अनूराधा',
  'ज्येष्ठा','मूला','पूर्वाषाढ़ा','उत्तराषाढ़ा','श्रवण','धनिष्ठा','शतभिषा','पूर्वाभाद्रपदा',
  'उत्तराभाद्रपदा','रेवती'
];

// Providers
final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final tzReadyProvider = FutureProvider<bool>((ref) async {
  tzdb.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  return true;
});

// Database handling (India-only cities with FTS + tiny fallback)
class City {
  final int id;
  final String name;
  final String admin1;
  final double lat;
  final double lon;
  final String tzId;
  final int population;

  City({
    required this.id,
    required this.name,
    required this.admin1,
    required this.lat,
    required this.lon,
    required this.tzId,
    required this.population,
  });

  @override
  String toString() => '$name, $admin1 ($tzId)';
}

class CityDatabase {
  CityDatabase._(this.db);
  final Database db;

  static Future<CityDatabase> open() async {
    final dbPath = await getDatabasesPath();
    final target = p.join(dbPath, 'cities_india.db');

    // Try copy from asset; if missing, create a tiny sample DB
    if (!await File(target).exists()) {
      try {
        await _copyDbFromAssets(target);
      } catch (_) {
        await _createSampleDb(target);
      }
    }
    final db = await openDatabase(target, readOnly: true);
    return CityDatabase._(db);
  }

  static Future<void> _copyDbFromAssets(String dest) async {
    final data = await rootBundle.load('assets/db/cities_india.db'); // throws if missing
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await Directory(p.dirname(dest)).create(recursive: true);
    final file = File(dest);
    await file.writeAsBytes(bytes, flush: true);
  }

  // Tiny sample India DB so app works without asset
  static Future<void> _createSampleDb(String dest) async {
    await Directory(p.dirname(dest)).create(recursive: true);
    final db = await openDatabase(dest, version: 1,
        onCreate: (Database db, int version) async {
      await db.execute('''
        CREATE TABLE cities(
          id INTEGER PRIMARY KEY,
          name TEXT,
          alt_names TEXT,
          admin1 TEXT,
          admin2 TEXT,
          lat REAL,
          lon REAL,
          tz TEXT,
          population INT
        );
      ''');
      // Try FTS5 (ignore if not available)
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE fts_cities USING fts5(
            name, alt_names, content=cities, content_rowid=id
          );
        ''');
      } catch (_) {}
    });

    final rows = <Map<String, Object?>>[
      {'id': 1, 'name': 'Delhi', 'alt_names': 'दिल्ली, New Delhi', 'admin1': 'Delhi', 'admin2': '', 'lat': 28.6139, 'lon': 77.2090, 'tz': 'Asia/Kolkata', 'population': 16787941},
      {'id': 2, 'name': 'Mumbai', 'alt_names': 'मुंबई, Bombay', 'admin1': 'Maharashtra', 'admin2': '', 'lat': 19.0760, 'lon': 72.8777, 'tz': 'Asia/Kolkata', 'population': 12442373},
      {'id': 3, 'name': 'Kolkata', 'alt_names': 'कोलकाता, Calcutta', 'admin1': 'West Bengal', 'admin2': '', 'lat': 22.5726, 'lon': 88.3639, 'tz': 'Asia/Kolkata', 'population': 4486679},
      {'id': 4, 'name': 'Chennai', 'alt_names': 'चेन्नई, Madras', 'admin1': 'Tamil Nadu', 'admin2': '', 'lat': 13.0827, 'lon': 80.2707, 'tz': 'Asia/Kolkata', 'population': 4646732},
      {'id': 5, 'name': 'Bengaluru', 'alt_names': 'बेंगलुरु, Bangalore', 'admin1': 'Karnataka', 'admin2': '', 'lat': 12.9716, 'lon': 77.5946, 'tz': 'Asia/Kolkata', 'population': 8443675},
      {'id': 6, 'name': 'Hyderabad', 'alt_names': 'हैदराबाद', 'admin1': 'Telangana', 'admin2': '', 'lat': 17.3850, 'lon': 78.4867, 'tz': 'Asia/Kolkata', 'population': 6809970},
      {'id': 7, 'name': 'Pune', 'alt_names': 'पुणे, Poona', 'admin1': 'Maharashtra', 'admin2': '', 'lat': 18.5204, 'lon': 73.8567, 'tz': 'Asia/Kolkata', 'population': 3124458},
      {'id': 8, 'name': 'Ahmedabad', 'alt_names': 'अहमदाबाद', 'admin1': 'Gujarat', 'admin2': '', 'lat': 23.0225, 'lon': 72.5714, 'tz': 'Asia/Kolkata', 'population': 5570585},
      {'id': 9, 'name': 'Jaipur', 'alt_names': 'जयपुर', 'admin1': 'Rajasthan', 'admin2': '', 'lat': 26.9124, 'lon': 75.7873, 'tz': 'Asia/Kolkata', 'population': 3073350},
      {'id': 10, 'name': 'Lucknow', 'alt_names': 'लखनऊ', 'admin1': 'Uttar Pradesh', 'admin2': '', 'lat': 26.8467, 'lon': 80.9462, 'tz': 'Asia/Kolkata', 'population': 2815601},
      {'id': 11, 'name': 'Kanpur', 'alt_names': 'कानपुर', 'admin1': 'Uttar Pradesh', 'admin2': '', 'lat': 26.4499, 'lon': 80.3319, 'tz': 'Asia/Kolkata', 'population': 2765348},
      {'id': 12, 'name': 'Surat', 'alt_names': 'सूरत', 'admin1': 'Gujarat', 'admin2': '', 'lat': 21.1702, 'lon': 72.8311, 'tz': 'Asia/Kolkata', 'population': 4467797},
      {'id': 13, 'name': 'Nagpur', 'alt_names': 'नागपुर', 'admin1': 'Maharashtra', 'admin2': '', 'lat': 21.1458, 'lon': 79.0882, 'tz': 'Asia/Kolkata', 'population': 2405665},
      {'id': 14, 'name': 'Patna', 'alt_names': 'पटना', 'admin1': 'Bihar', 'admin2': '', 'lat': 25.5941, 'lon': 85.1376, 'tz': 'Asia/Kolkata', 'population': 1684222},
      {'id': 15, 'name': 'Bhopal', 'alt_names': 'भोपाल', 'admin1': 'Madhya Pradesh', 'admin2': '', 'lat': 23.2599, 'lon': 77.4126, 'tz': 'Asia/Kolkata', 'population': 1798218},
      {'id': 16, 'name': 'Chandigarh', 'alt_names': 'चंडीगढ़', 'admin1': 'Chandigarh', 'admin2': '', 'lat': 30.7333, 'lon': 76.7794, 'tz': 'Asia/Kolkata', 'population': 1026459},
      {'id': 17, 'name': 'Noida', 'alt_names': 'नोएडा', 'admin1': 'Uttar Pradesh', 'admin2': '', 'lat': 28.5355, 'lon': 77.3910, 'tz': 'Asia/Kolkata', 'population': 642381},
      {'id': 18, 'name': 'Gurgaon', 'alt_names': 'गुरुग्राम', 'admin1': 'Haryana', 'admin2': '', 'lat': 28.4595, 'lon': 77.0266, 'tz': 'Asia/Kolkata', 'population': 876824},
      {'id': 19, 'name': 'Kochi', 'alt_names': 'कोच्चि, Cochin', 'admin1': 'Kerala', 'admin2': '', 'lat': 9.9312, 'lon': 76.2673, 'tz': 'Asia/Kolkata', 'population': 677381},
      {'id': 20, 'name': 'Guwahati', 'alt_names': 'गुवाहाटी', 'admin1': 'Assam', 'admin2': '', 'lat': 26.1445, 'lon': 91.7362, 'tz': 'Asia/Kolkata', 'population': 963429},
    ];

    final batch = db.batch();
    for (final r in rows) {
      batch.insert('cities', r);
    }
    await batch.commit(noResult: true);

    try {
      await db.execute(
          'INSERT INTO fts_cities(rowid, name, alt_names) SELECT id, name, alt_names FROM cities;');
    } catch (_) {}
    await db.close();
  }

  Future<List<City>> search(String q, {int limit = 20}) async {
    final query = q.trim();
    if (query.isEmpty) return [];
    try {
      final rows = await db.rawQuery('''
      SELECT c.id, c.name, c.admin1, c.lat, c.lon, c.tz, c.population
      FROM fts_cities f
      JOIN cities c ON c.id = f.rowid
      WHERE f MATCH ?
      ORDER BY c.population DESC
      LIMIT ?;
      ''', [query, limit]);

      return rows
          .map((r) => City(
                id: r['id'] as int,
                name: r['name'] as String,
                admin1: r['admin1'] as String? ?? '',
                lat: (r['lat'] as num).toDouble(),
                lon: (r['lon'] as num).toDouble(),
                tzId: r['tz'] as String,
                population: (r['population'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    } catch (_) {
      final rows = await db.rawQuery('''
      SELECT id, name, admin1, lat, lon, tz, population
      FROM cities
      WHERE lower(name) LIKE ?
      ORDER BY population DESC
      LIMIT ?;
      ''', ['%${query.toLowerCase()}%', limit]);
      return rows
          .map((r) => City(
                id: r['id'] as int,
                name: r['name'] as String,
                admin1: r['admin1'] as String? ?? '',
                lat: (r['lat'] as num).toDouble(),
                lon: (r['lon'] as num).toDouble(),
                tzId: r['tz'] as String,
                population: (r['population'] as num?)?.toInt() ?? 0,
              ))
          .toList();
    }
  }

  Future<void> close() => db.close();
}

final cityDbProvider = FutureProvider<CityDatabase>((ref) async {
  return CityDatabase.open();
});

// ---------- Astro math (minimal accurate Sun/Moon + Lahiri ayanamsa) ----------
class AstroMath {
  static const double pi = math.pi;
  static const double deg2rad = math.pi / 180.0;
  static const double rad2deg = 180.0 / math.pi;

  static double normalizeDegrees(double x) {
    var y = x % 360.0;
    if (y < 0) y += 360.0;
    return y;
  }

  static double jdFromTZ(tz.TZDateTime t) {
    final utc = t.toUtc();
    final year = utc.year;
    final month = utc.month;
    final day = utc.day;
    final hour = utc.hour +
        utc.minute / 60.0 +
        utc.second / 3600.0 +
        utc.millisecond / 3_600_000.0 +
        utc.microsecond / 3_600_000_000.0;

    var y = year;
    var m = month;
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final A = (y / 100).floor();
    final B = 2 - A + (A / 4).floor();
    final jd0 = (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        B -
        1524.5;
    return jd0 + hour / 24.0;
  }

  static double Tcenturies(double jd) => (jd - 2451545.0) / 36525.0;

  // Mean obliquity (arcsec) IAU 2006-ish, good enough
  static double meanObliquityDeg(double T) {
    // 23°26′21.448″ - 46.8150″T - 0.00059″T^2 + 0.001813″T^3
    final seconds =
        21.448 - 46.8150 * T - 0.00059 * T * T + 0.001813 * T * T * T;
    return 23.0 + 26.0 / 60.0 + seconds / 3600.0;
  }

  // GMST in degrees (Meeus)
  static double gmstDeg(double jd) {
    final T = (jd - 2451545.0) / 36525.0;
    final theta = 280.46061837 +
        360.98564736629 * (jd - 2451545.0) +
        0.000387933 * T * T -
        (T * T * T) / 38710000.0;
    return normalizeDegrees(theta);
  }

  static double lstDeg(double jd, double eastLongitudeDeg) {
    return normalizeDegrees(gmstDeg(jd) + eastLongitudeDeg);
  }

  // Lahiri (Chitra-Paksha) ayanamsa: simple linearized model around J2000
  // ay(2000-01-01 12:00 TT) ≈ 23.8531°
  // rate ≈ 50.290966″/yr = 0.013969157°/yr
  static double lahiriAyanamsaDeg(double jd) {
    final years = (jd - 2451545.0) / 365.2422;
    const ay2000 = 23.8531;
    const rateDegPerYear = 50.290966 / 3600.0;
    return ay2000 + rateDegPerYear * years;
  }

  // Sun apparent ecliptic longitude (tropical) in degrees
  static double sunLongitudeTropical(double jd) {
    final T = Tcenturies(jd);
    final L0 = normalizeDegrees(
        280.46646 + 36000.76983 * T + 0.0003032 * T * T); // mean lon
    final M = normalizeDegrees(357.52911 + 35999.05029 * T - 0.0001537 * T * T);
    final Mr = M * deg2rad;
    final C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * math.sin(Mr) +
        (0.019993 - 0.000101 * T) * math.sin(2 * Mr) +
        0.000289 * math.sin(3 * Mr);
    final trueLon = L0 + C;
    final Omega = normalizeDegrees(125.04 - 1934.136 * T);
    final lambdaApp =
        trueLon - 0.00569 - 0.00478 * math.sin(Omega * deg2rad);
    return normalizeDegrees(lambdaApp);
  }

  // Moon ecliptic longitude (tropical, degrees), compact approximation
  // Good to ~0.5–1.0° typically.
  static double moonLongitudeTropical(double jd) {
    final T = Tcenturies(jd);

    final Lp = normalizeDegrees(218.3164477 +
        481267.88123421 * T -
        0.0015786 * T * T +
        T * T * T / 538841.0 -
        T * T * T * T / 65194000.0);

    final D = normalizeDegrees(297.8501921 +
        445267.1114034 * T -
        0.0018819 * T * T +
        T * T * T / 545868.0 -
        T * T * T * T / 113065000.0);

    final M = normalizeDegrees(357.5291092 +
        35999.0502909 * T -
        0.0001536 * T * T +
        T * T * T / 24490000.0);

    final Mp = normalizeDegrees(134.9633964 +
        477198.8675055 * T +
        0.0087414 * T * T +
        T * T * T / 69699.0 -
        T * T * T * T / 14712000.0);

    final F = normalizeDegrees(93.2720950 +
        483202.0175233 * T -
        0.0036539 * T * T -
        T * T * T / 3526000.0 +
        T * T * T * T / 863310000.0);

    final Dr = D * deg2rad;
    final Mr = M * deg2rad;
    final Mpr = Mp * deg2rad;
    final Fr = F * deg2rad;

    // Compact series (dominant terms)
    final lambda = Lp +
        6.289 * math.sin(Mpr) + // Evection
        1.274 * math.sin(2 * Dr - Mpr) +
        0.658 * math.sin(2 * Dr) +
        0.214 * math.sin(2 * Mpr) +
        -0.186 * math.sin(Mr) +
        -0.114 * math.sin(2 * Fr) +
        0.059 * math.sin(2 * Dr - 2 * Mpr) +
        0.057 * math.sin(2 * Dr - Mpr - Mr) +
        0.053 * math.sin(2 * Dr + Mpr) +
        0.046 * math.sin(2 * Dr - Mr) +
        0.041 * math.sin(Mpr - Mr) +
        -0.035 * math.sin(Dr) +
        -0.031 * math.sin(Mpr + Mr);

    return normalizeDegrees(lambda);
  }

  static int signIndex(double longitude) => ((longitude / 30.0).floor()) % 12;
  static double degInSign(double longitude) => longitude % 30.0;

  static int nakshatraIndex(double siderealLon) =>
      (siderealLon / (13.333333333333334)).floor().clamp(0, 26);

  static int padaFromSidereal(double siderealLon) =>
      ((siderealLon / (13.333333333333334) - (siderealLon / (13.333333333333334)).floor()) * 4)
          .floor() + 1;

  static int tithiNumber(double moonSid, double sunSid) {
    final delta = normalizeDegrees(moonSid - sunSid);
    return (delta / 12.0).floor() + 1; // 1..30
  }

  static int yogaIndex(double moonSid, double sunSid) {
    final sum = normalizeDegrees(moonSid + sunSid);
    return (sum / 13.333333333333334).floor() + 1; // 1..27
  }

  // Approx lagna (house 1 sign) using Local Sidereal Time (rough)
  // This is not exact ascendant, but ok for demo.
  static (int sign, double degInSign) approxLagnaSign(double jd, double eastLonDeg) {
    final lst = lstDeg(jd, eastLonDeg); // 0..360
    final sign = signIndex(lst);
    final deg = degInSign(lst);
    return (sign, deg);
  }
}

// ---------- Varga helpers (D1/D9/D10) ----------
enum SignQuality { chara, sthira, dwiswabhava }

SignQuality qualityForSign(int signIndex) {
  switch (signIndex % 12) {
    case 0:
    case 3:
    case 6:
    case 9:
      return SignQuality.chara;
    case 1:
    case 4:
    case 7:
    case 10:
      return SignQuality.sthira;
    default:
      return SignQuality.dwiswabhava;
  }
}

// Generic varga mapping: divisor = 9 (D9), 10 (D10), etc.
// Start offsets: chara=0, sthira=+8, dwiswabhava=+4 (mod 12).
int vargaSignIndex(int signIndex, double degInSign, int divisor) {
  final partWidth = 30.0 / divisor;
  final partIndex = (degInSign / partWidth).floor().clamp(0, divisor - 1);
  final q = qualityForSign(signIndex);
  final startOffset = switch (q) {
    SignQuality.chara => 0,
    SignQuality.sthira => 8,
    SignQuality.dwiswabhava => 4,
  };
  return (signIndex + startOffset + partIndex) % 12;
}

// ---------- Domain models ----------
class KundaliInput {
  final String name;
  final DateTime dob; // local date/time chosen by user (naive)
  final City city;
  KundaliInput({required this.name, required this.dob, required this.city});
}

class PlanetPos {
  final String grah; // Hindi name
  final double longitudeSidereal; // deg 0..360
  final int rashiIndex; // 0..11
  final String nakshatra; // for UI
  final int pada; // 1..4
  PlanetPos({
    required this.grah,
    required this.longitudeSidereal,
    required this.rashiIndex,
    required this.nakshatra,
    required this.pada,
  });
}

class KundaliResult {
  final tz.TZDateTime zonedBirth;
  final String weekday;
  final String lagnaLabel;
  final int lagnaSignIndex; // 0..11
  final double lagnaDegreeInSign; // 0..30
  final List<PlanetPos> planets;
  final Map<String, String> panchang;
  final double sunSid; // for reference
  final double moonSid; // for reference
  KundaliResult({
    required this.zonedBirth,
    required this.weekday,
    required this.lagnaLabel,
    required this.lagnaSignIndex,
    required this.lagnaDegreeInSign,
    required this.planets,
    required this.panchang,
    required this.sunSid,
    required this.moonSid,
  });
}

// ---------- Astro engine (Sun/Moon accurate, rest placeholders) ----------
class AstroEngine {
  Future<KundaliResult> compute(KundaliInput input) async {
    final loc = tz.getLocation(input.city.tzId);
    final birth = tz.TZDateTime.from(input.dob, loc);
    final weekday = DateFormat.EEEE('en').format(birth);

    final jd = AstroMath.jdFromTZ(birth);
    final sunTrop = AstroMath.sunLongitudeTropical(jd);
    final moonTrop = AstroMath.moonLongitudeTropical(jd);
    final ay = AstroMath.lahiriAyanamsaDeg(jd);

    final sunSid = AstroMath.normalizeDegrees(sunTrop - ay);
    final moonSid = AstroMath.normalizeDegrees(moonTrop - ay);

    // Approx lagna from LST (demo)
    final (lagSign, lagDeg) =
        AstroMath.approxLagnaSign(jd, input.city.lon);

    // Build planets (Sun/Moon accurate; others placeholders based on time)
    final seed = (birth.millisecondsSinceEpoch % 360).toDouble();
    final placeholders = <double>[
      (seed + 70) % 360, // मंगल
      (seed + 110) % 360, // बुध
      (seed + 150) % 360, // गुरु
      (seed + 190) % 360, // शुक्र
      (seed + 230) % 360, // शनि
      (seed + 270) % 360, // राहु
      (seed + 90) % 360, // केतु
    ];

    List<PlanetPos> planets = [
      _pp('सूर्य', sunSid),
      _pp('चंद्र', moonSid),
      _pp('मंगल', placeholders[0]),
      _pp('बुध', placeholders[1]),
      _pp('गुरु', placeholders[2]),
      _pp('शुक्र', placeholders[3]),
      _pp('शनि', placeholders[4]),
      _pp('राहु', placeholders[5]),
      _pp('केतु', placeholders[6]),
    ];

    final tithiNum = AstroMath.tithiNumber(moonSid, sunSid);
    final paksha = tithiNum <= 15 ? 'शुक्ल' : 'कृष्ण';
    final yogaIdx = AstroMath.yogaIndex(moonSid, sunSid); // 1..27

    final panchang = <String, String>{
      'tithi': '$paksha $tithiNum',
      'nakshatra':
          '${nakshatraHindi[AstroMath.nakshatraIndex(moonSid)]} (पाद ${AstroMath.padaFromSidereal(moonSid)})',
      'yoga': 'योग $yogaIdx',
      'karana': '—', // TODO
      'sunrise': '—', // TODO: compute
      'sunset': '—',  // TODO: compute
    };

    return KundaliResult(
      zonedBirth: birth,
      weekday: weekday,
      lagnaLabel:
          'लग्न ${rashiHindi[lagSign]} ${lagDeg.toStringAsFixed(1)}°',
      lagnaSignIndex: lagSign,
      lagnaDegreeInSign: lagDeg,
      planets: planets,
      panchang: panchang,
      sunSid: sunSid,
      moonSid: moonSid,
    );
  }

  PlanetPos _pp(String grah, double sidLon) {
    final rIndex = AstroMath.signIndex(sidLon);
    final nakIdx = AstroMath.nakshatraIndex(sidLon);
    final pada = AstroMath.padaFromSidereal(sidLon);
    return PlanetPos(
      grah: grah,
      longitudeSidereal: sidLon,
      rashiIndex: rIndex,
      nakshatra: nakshatraHindi[nakIdx],
      pada: pada,
    );
  }
}

// ---------- Vimshottari Dasha (starter, unchanged logic) ----------
class DashaPeriod {
  final String maha; // Hindi
  final tz.TZDateTime start;
  final tz.TZDateTime end;
  final List<DashaPeriod> antars; // nested
  DashaPeriod({
    required this.maha,
    required this.start,
    required this.end,
    this.antars = const [],
  });
}

class DashaService {
  static const daysPerYear = 365.2425;
  static const lordsHi = ['केतु','शुक्र','सूर्य','चंद्र','मंगल','राहु','गुरु','शनि','बुध'];
  static const lordYears = [7,20,6,10,7,18,16,19,17];

  int nakshatraIndexFromMoon(double moonSidereal) {
    final idx =
        (moonSidereal / (13.333333333333334)).floor().clamp(0, 26);
    return idx;
  }

  List<DashaPeriod> buildTimeline(KundaliInput input, KundaliResult result,
      {int levels = 2, int maxYears = 120}) {
    final moonLon = result.moonSid;
    final nakIdx = nakshatraIndexFromMoon(moonLon);
    final lordIndex = nakIdx % 9;
    final loc = tz.getLocation(input.city.tzId);
    final birth = result.zonedBirth;

    final nakSpan = 13.333333333333334;
    final passedInNak = moonLon - (nakIdx * nakSpan);
    final passedFrac = (passedInNak / nakSpan).clamp(0.0, 1.0);
    final totalYears = lordYears[lordIndex].toDouble();
    final elapsedYears = totalYears * passedFrac;
    final elapsedDays = elapsedYears * daysPerYear;

    final mahaStart = _addDays(loc, birth, -elapsedDays);
    final timeline = <DashaPeriod>[];

    final maxSpanDays = maxYears * daysPerYear;
    var cursor = mahaStart;
    var accumulated = 0.0;

    for (int m = 0; accumulated < maxSpanDays; m++) {
      final mLordIndex = (lordIndex + m) % 9;
      final mYears = lordYears[mLordIndex].toDouble();
      final mDays = mYears * daysPerYear;

      final mStart = cursor;
      final mEnd = _addDays(loc, mStart, mDays);

      final antars = <DashaPeriod>[];
      if (levels >= 2) {
        var aCursor = mStart;
        for (int a = 0; a < 9; a++) {
          final aLordIndex = (mLordIndex + a) % 9;
          final aDays = mDays * (lordYears[aLordIndex] / 120.0);
          final aStart = aCursor;
          final aEnd = _addDays(loc, aStart, aDays);

          final praty = <DashaPeriod>[];
          if (levels >= 3) {
            var pCursor = aStart;
            for (int pIdx = 0; pIdx < 9; pIdx++) {
              final pLordIndex = (aLordIndex + pIdx) % 9;
              final pDays = aDays * (lordYears[pLordIndex] / 120.0);
              final pStart = pCursor;
              final pEnd = _addDays(loc, pStart, pDays);
              praty.add(DashaPeriod(
                maha: lordsHi[pLordIndex],
                start: pStart,
                end: pEnd,
              ));
              pCursor = pEnd;
            }
          }

          antars.add(DashaPeriod(
            maha: lordsHi[aLordIndex],
            start: aStart,
            end: aEnd,
            antars: praty,
          ));
          aCursor = aEnd;
        }
      }

      timeline.add(DashaPeriod(
        maha: lordsHi[mLordIndex],
        start: mStart,
        end: mEnd,
        antars: antars,
      ));

      cursor = mEnd;
      accumulated += mDays;
      if (timeline.length > 60) break;
    }

    return timeline.where((d) => d.end.isAfter(birth)).toList();
  }

  tz.TZDateTime _addDays(tz.Location loc, tz.TZDateTime start, double days) {
    final micros = (days * Duration.microsecondsPerDay).round();
    final utc = start.toUtc().add(Duration(microseconds: micros));
    return tz.TZDateTime.from(utc, loc);
  }
}

// ---------- PDF Service (with D1 + D9/D10) ----------
class PdfService {
  Future<Uint8List> buildKundaliPdf({
    required KundaliInput input,
    required KundaliResult result,
    required ByteData devanagariFontData,
    Uint8List? chartD1,
    Uint8List? chartD9,
    Uint8List? chartD10,
    List<Map<String, String>>? dashaRows,
  }) async {
    final ttf = pw.Font.ttf(devanagariFontData);
    final doc = pw.Document();

    final headerStyle =
        pw.TextStyle(font: ttf, fontSize: 18, color: pw.PdfColors.purple);
    final normal = pw.TextStyle(font: ttf, fontSize: 12);
    final small =
        pw.TextStyle(font: ttf, fontSize: 10, color: pw.PdfColors.grey700);

    // Page 1: Birth details
    doc.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4,
        build: (ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(appBrand,
                        style: headerStyle.copyWith(
                            color: pw.PdfColors.deepPurple)),
                    pw.Text('© $appBrand', style: small),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Kundali', style: headerStyle),
                pw.SizedBox(height: 8),
                pw.Text('Name: ${input.name}', style: normal),
                pw.Text(
                    'DOB: ${DateFormat('yyyy-MM-dd HH:mm').format(result.zonedBirth)}',
                    style: normal),
                pw.Text('Place: ${input.city.name}, ${input.city.admin1}',
                    style: normal),
                pw.Text(
                    'Coordinates: ${input.city.lat.toStringAsFixed(4)}, ${input.city.lon.toStringAsFixed(4)}',
                    style: normal),
                pw.Text(
                    'Timezone: ${input.city.tzId} (UTC ${_formatOffset(result.zonedBirth)})',
                    style: normal),
                pw.SizedBox(height: 8),
                pw.Text('Weekday: ${result.weekday}', style: normal),
                pw.SizedBox(height: 8),
                pw.Text(
                    'Tithi: ${result.panchang['tithi']}  •  Nakshatra: ${result.panchang['nakshatra']}',
                    style: normal),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: pw.Text('$appBrand — Offline Vedic Astrology',
                      style: small),
                )
              ],
            ),
          );
        },
      ),
    );

    // Page 2: D1 chart + planets
    doc.addPage(
      pw.Page(
        pageFormat: pw.PdfPageFormat.a4,
        build: (ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('राशि चक्र (D1) — Planetary Positions',
                    style: headerStyle),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (chartD1 != null)
                      pw.Container(
                        width: 240,
                        height: 240,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: pw.PdfColors.grey600),
                        ),
                        child:
                            pw.Image(pw.MemoryImage(chartD1), fit: pw.BoxFit.cover),
                      ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Table.fromTextArray(
                        cellStyle: normal,
                        headerStyle:
                            normal.copyWith(fontWeight: pw.FontWeight.bold),
                        headers: ['ग्रह', 'दीर्घांश°', 'राशि', 'नक्षत्र/पाद'],
                        data: result.planets
                            .map((p) => [
                                  p.grah,
                                  p.longitudeSidereal.toStringAsFixed(2),
                                  rashiHindi[p.rashiIndex],
                                  '${p.nakshatra} / ${p.pada}',
                                ])
                            .toList(),
                      ),
                    )
                  ],
                ),
                pw.Spacer(),
                pw.Align(
                  alignment: pw.Alignment.bottomRight,
                  child: pw.Text('© $appBrand', style: small),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Page 3: D9 + D10 charts
    if (chartD9 != null || chartD10 != null) {
      doc.addPage(
        pw.Page(
          pageFormat: pw.PdfPageFormat.a4,
          build: (ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('वर्ग — D9 (नवांश) और D10 (दशांश)', style: headerStyle),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    children: [
                      if (chartD9 != null)
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              pw.Text('D9 (Navamsa)', style: normal),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                height: 240,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: pw.PdfColors.grey600),
                                ),
                                child: pw.Image(pw.MemoryImage(chartD9), fit: pw.BoxFit.contain),
                              ),
                            ],
                          ),
                        ),
                      pw.SizedBox(width: 12),
                      if (chartD10 != null)
                        pw.Expanded(
                          child: pw.Column(
                            children: [
                              pw.Text('D10 (Dasamsa)', style: normal),
                              pw.SizedBox(height: 8),
                              pw.Container(
                                height: 240,
                                decoration: pw.BoxDecoration(
                                  border: pw.Border.all(color: pw.PdfColors.grey600),
                                ),
                                child: pw.Image(pw.MemoryImage(chartD10), fit: pw.BoxFit.contain),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Page 4: Vimshottari Dasha table
    if (dashaRows != null && dashaRows.isNotEmpty) {
      doc.addPage(
        pw.Page(
          pageFormat: pw.PdfPageFormat.a4,
          build: (ctx) {
            return pw.Container(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('विंशोत्तरी दशा (महादशा → अंतरदशा)', style: headerStyle),
                  pw.SizedBox(height: 12),
                  pw.Table.fromTextArray(
                    headerStyle:
                        normal.copyWith(fontWeight: pw.FontWeight.bold),
                    cellStyle: normal,
                    headers: ['महादशा', 'अंतरदशा', 'From', 'To'],
                    data: dashaRows
                        .map((r) =>
                            [r['maha']!, r['antar']!, r['from']!, r['to']!])
                        .toList(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  String _formatOffset(tz.TZDateTime dt) {
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs().toString().padLeft(2, '0');
    final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    return '$sign$h:$m';
  }
}

// ---------- North-Indian chart painter ----------
class NorthIndianChart extends StatelessWidget {
  const NorthIndianChart({
    super.key,
    required this.size,
    required this.planetsByHouse, // 1..12
    required this.lagnaSignIndex,
  });

  final double size;
  final Map<int, List<String>> planetsByHouse;
  final int lagnaSignIndex;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: NorthIndianChartPainter(
        planetsByHouse: planetsByHouse,
        lagnaSignIndex: lagnaSignIndex,
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansDevanagari',
          fontSize: 10,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class NorthIndianChartPainter extends CustomPainter {
  NorthIndianChartPainter({
    required this.planetsByHouse,
    required this.lagnaSignIndex,
    required this.labelStyle,
  });

  final Map<int, List<String>> planetsByHouse; // house 1..12 -> labels
  final int lagnaSignIndex;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final paintBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = brandPrimary;

    final paintGrid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = brandGold;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;

    // Outer square
    canvas.drawRect(rect, paintBorder);

    // Diamond (connect midpoints)
    final midTop = Offset(size.width / 2, 0);
    final midRight = Offset(size.width, size.height / 2);
    final midBottom = Offset(size.width / 2, size.height);
    final midLeft = Offset(0, size.height / 2);

    final diamond = Path()
      ..moveTo(midTop.dx, midTop.dy)
      ..lineTo(midRight.dx, midRight.dy)
      ..lineTo(midBottom.dx, midBottom.dy)
      ..lineTo(midLeft.dx, midLeft.dy)
      ..close();
    canvas.drawPath(diamond, paintGrid);

    // Diagonals
    canvas.drawLine(Offset(0, 0), Offset(size.width, size.height), paintGrid);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paintGrid);

    // Quarter lines (from corners to opposite midpoints)
    canvas.drawLine(Offset(0, 0), midLeft, paintGrid);
    canvas.drawLine(Offset(0, 0), midTop, paintGrid);
    canvas.drawLine(Offset(size.width, 0), midTop, paintGrid);
    canvas.drawLine(Offset(size.width, 0), midRight, paintGrid);
    canvas.drawLine(Offset(0, size.height), midLeft, paintGrid);
    canvas.drawLine(Offset(0, size.height), midBottom, paintGrid);
    canvas.drawLine(Offset(size.width, size.height), midRight, paintGrid);
    canvas.drawLine(Offset(size.width, size.height), midBottom, paintGrid);

    // Draw house labels and planets
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final anchors = _houseAnchors(size); // indices 1..12
    for (int house = 1; house <= 12; house++) {
      final pos = anchors[house]!;
      // House number
      _paintText(
        canvas,
        textPainter,
        labelStyle.copyWith(fontWeight: FontWeight.bold, color: brandPrimary),
        '$house',
        pos + const Offset(-8, -10),
      );
      // Sign label for that house (rotates with lagna)
      final signIndex = (lagnaSignIndex + (house - 1)) % 12;
      _paintText(
        canvas,
        textPainter,
        labelStyle.copyWith(color: Colors.black54),
        rashiHindi[signIndex],
        pos + const Offset(-14, 2),
      );

      // Lagna mark in house 1
      if (house == 1) {
        _paintText(
          canvas,
          textPainter,
          labelStyle.copyWith(color: brandPrimary, fontWeight: FontWeight.bold),
          'लग्न',
          pos + const Offset(20, -10),
        );
      }

      final items = planetsByHouse[house] ?? [];
      for (int i = 0; i < items.length; i++) {
        _paintText(canvas, textPainter, labelStyle,
            items[i], pos + Offset(-14, 16 + i * 12));
      }
    }

    // Center watermark brand
    _paintText(
      canvas,
      textPainter,
      labelStyle.copyWith(color: brandPrimary.withOpacity(0.3), fontSize: 12),
      appBrand,
      center + const Offset(-30, -6),
    );
  }

  Map<int, Offset> _houseAnchors(Size s) {
    final w = s.width, h = s.height;
    // Approx anchors for houses (North-Indian layout)
    return {
      1: Offset(w * 0.50, h * 0.07),
      2: Offset(w * 0.80, h * 0.20),
      3: Offset(w * 0.93, h * 0.50),
      4: Offset(w * 0.80, h * 0.80),
      5: Offset(w * 0.50, h * 0.93),
      6: Offset(w * 0.20, h * 0.80),
      7: Offset(w * 0.07, h * 0.50),
      8: Offset(w * 0.20, h * 0.20),
      9: Offset(w * 0.34, h * 0.34),
      10: Offset(w * 0.66, h * 0.34),
      11: Offset(w * 0.66, h * 0.66),
      12: Offset(w * 0.34, h * 0.66),
    };
  }

  void _paintText(Canvas c, TextPainter tp, TextStyle st, String text, Offset pos) {
    tp.text = TextSpan(text: text, style: st);
    tp.layout();
    tp.paint(c, pos);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Chart renderer for PDF (paint CustomPainter to PNG)
class ChartRenderer {
  static Future<Uint8List> renderNorthIndianChartPng({
    required double size,
    required Map<int, List<String>> planetsByHouse,
    required int lagnaSignIndex,
    TextStyle? labelStyle,
    double pixelRatio = 3.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final painter = NorthIndianChartPainter(
      planetsByHouse: planetsByHouse,
      lagnaSignIndex: lagnaSignIndex,
      labelStyle: labelStyle ??
          const TextStyle(
            fontFamily: 'NotoSansDevanagari',
            fontSize: 12,
            color: Colors.black87,
          ),
    );
    painter.paint(canvas, Size(size, size));
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (size * pixelRatio).toInt(),
      (size * pixelRatio).toInt(),
    );
    final bytes =
        await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }
}

// ---------- App entry ----------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AnoopAstroApp()));
}

class AnoopAstroApp extends ConsumerWidget {
  const AnoopAstroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.read(tzReadyProvider.future),
      builder: (context, snap) {
        final ready =
            snap.connectionState == ConnectionState.done && snap.data == true;
        final locale = ref.watch(localeProvider);
        final themeMode = ref.watch(themeModeProvider);

        return MaterialApp(
          title: appBrand,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: brandPrimary)
                .copyWith(secondary: brandGold),
            fontFamily: 'NotoSansDevanagari',
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: brandPrimary, brightness: Brightness.dark),
            fontFamily: 'NotoSansDevanagari',
          ),
          locale: locale,
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ready ? const RootScaffold() : const SplashScreen(),
        );
      },
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brandPrimary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/splash.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain, errorBuilder: (_, __, ___) {
              return const Icon(Icons.auto_awesome, color: Colors.white, size: 96);
            }),
            const SizedBox(height: 16),
            const Text(appBrand,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});
  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomePage(),
      const CreateKundaliPage(),
      const SavedChartsPage(),
      const PanchangPage(),
      const SettingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text(appBrand),
        backgroundColor: brandPrimary,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: brandPrimary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.auto_fix_normal_outlined),
              selectedIcon: Icon(Icons.auto_fix_normal),
              label: 'Create'),
          NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Saved'),
          NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny),
              label: 'Panchang'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png',
                    width: 96, height: 96, errorBuilder: (_, __, ___) =>
                        const Icon(Icons.auto_awesome,
                            size: 96, color: brandPrimary)),
                const SizedBox(height: 12),
                const Text('Welcome to AnoopAstro',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Fully offline Vedic astrology. Create kundali, view charts, dashas, and export PDF.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateKundaliPage extends ConsumerStatefulWidget {
  const CreateKundaliPage({super.key});
  @override
  ConsumerState<CreateKundaliPage> createState() => _CreateKundaliPageState();
}

class _CreateKundaliPageState extends ConsumerState<CreateKundaliPage> {
  final _nameCtrl = TextEditingController();
  DateTime? _date;
  TimeOfDay? _time;
  City? _selectedCity;
  final _cityCtrl = TextEditingController();
  List<City> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _onCityChanged(String text) async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () async {
      final dbAsync = ref.read(cityDbProvider);
      final db = await dbAsync.future;
      final results = await db.search(text, limit: 20);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
      });
    });
  }

  Future<void> _pickDate(BuildContext ctx) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: ctx,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
      initialDate: _date ?? now,
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime(BuildContext ctx) async {
    final t =
        await showTimePicker(context: ctx, initialTime: _time ?? TimeOfDay.now());
    if (t != null) setState(() => _time = t);
  }

  bool get _ready =>
      _nameCtrl.text.trim().isNotEmpty &&
      _date != null &&
      _time != null &&
      _selectedCity != null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration:
              const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(_date == null
                    ? 'Select Date'
                    : DateFormat('yyyy-MM-dd').format(_date!)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickTime(context),
                icon: const Icon(Icons.schedule),
                label: Text(_time == null ? 'Select Time' : _time!.format(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityCtrl,
          decoration: const InputDecoration(
            labelText: 'Place (City, State)',
            prefixIcon: Icon(Icons.location_city),
          ),
          onChanged: _onCityChanged,
        ),
        const SizedBox(height: 6),
        if (_suggestions.isNotEmpty)
          Card(
            child: ListView.separated(
              itemCount: _suggestions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final c = _suggestions[i];
                return ListTile(
                  dense: true,
                  title: Text('${c.name}, ${c.admin1}'),
                  subtitle: Text(
                      '${c.lat.toStringAsFixed(4)}, ${c.lon.toStringAsFixed(4)} — ${c.tzId}'),
                  onTap: () {
                    setState(() {
                      _selectedCity = c;
                      _cityCtrl.text = '${c.name}, ${c.admin1}';
                      _suggestions = [];
                    });
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ready ? _computeAndShow : null,
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('Compute Kundali'),
        ),
      ],
    );
  }

  Future<void> _computeAndShow() async {
    if (!_ready) return;
    final dt = DateTime(
      _date!.year,
      _date!.month,
      _date!.day,
      _time!.hour,
      _time!.minute,
    );
    final input = KundaliInput(
      name: _nameCtrl.text.trim(),
      dob: dt,
      city: _selectedCity!,
    );

    final result = await AstroEngine().compute(input);

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => KundaliResultScreen(input: input, result: result),
    ));
  }
}

class KundaliResultScreen extends StatelessWidget {
  const KundaliResultScreen(
      {super.key, required this.input, required this.result});
  final KundaliInput input;
  final KundaliResult result;

  Map<int, List<String>> _planetsToHouses({
    required List<PlanetPos> planets,
    required int lagnaSignIndex,
    required List<int> signIndicesForPlanets,
  }) {
    // Convert sign placements to houses relative to lagna
    final byHouse = <int, List<String>>{};
    for (int i = 0; i < planets.length; i++) {
      final sign = signIndicesForPlanets[i];
      final house = ((sign - lagnaSignIndex + 12) % 12) + 1;
      byHouse.putIfAbsent(house, () => []).add(planets[i].grah);
    }
    return byHouse;
  }

  // Build varga sign indices for each planet
  List<int> _vargaSigns(List<PlanetPos> planets, int divisor) {
    return planets.map((p) {
      final s = AstroMath.signIndex(p.longitudeSidereal);
      final d = AstroMath.degInSign(p.longitudeSidereal);
      return vargaSignIndex(s, d, divisor);
    }).toList();
  }

  List<Map<String, String>> _buildDashaRows(List<DashaPeriod> timeline) {
    final rows = <Map<String, String>>[];
    final fmt = DateFormat('yyyy-MM-dd');
    int count = 0;
    for (final maha in timeline) {
      for (final antar in maha.antars) {
        if (antar.end.isBefore(result.zonedBirth)) continue;
        rows.add({
          'maha': maha.maha,
          'antar': antar.maha,
          'from': fmt.format(antar.start),
          'to': fmt.format(antar.end),
        });
        count++;
        if (count >= 18) break;
      }
      if (count >= 18) break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    // D1 signs are just planet.rashiIndex
    final d1Signs = result.planets.map((p) => p.rashiIndex).toList();
    final d1ByHouse = _planetsToHouses(
      planets: result.planets,
      lagnaSignIndex: result.lagnaSignIndex,
      signIndicesForPlanets: d1Signs,
    );

    // D9 and D10
    final d9Signs = _vargaSigns(result.planets, 9);
    final d10Signs = _vargaSigns(result.planets, 10);

    // Varga lagna signs: apply varga mapping to ascendant too (approx)
    final ascLonApprox =
        (result.lagnaSignIndex * 30.0 + result.lagnaDegreeInSign);
    final ascNavSign = vargaSignIndex(AstroMath.signIndex(ascLonApprox),
        AstroMath.degInSign(ascLonApprox), 9);
    final ascDasSign = vargaSignIndex(AstroMath.signIndex(ascLonApprox),
        AstroMath.degInSign(ascLonApprox), 10);

    final d9ByHouse = _planetsToHouses(
      planets: result.planets,
      lagnaSignIndex: ascNavSign,
      signIndicesForPlanets: d9Signs,
    );
    final d10ByHouse = _planetsToHouses(
      planets: result.planets,
      lagnaSignIndex: ascDasSign,
      signIndicesForPlanets: d10Signs,
    );

    final dashaTimeline =
        DashaService().buildTimeline(input, result, levels: 2, maxYears: 120);
    final dashaRows = _buildDashaRows(dashaTimeline);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kundali Result'),
          backgroundColor: brandPrimary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'D1'),
              Tab(text: 'D9'),
              Tab(text: 'D10'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: () async {
                // Render three charts
                final chartD1 = await ChartRenderer.renderNorthIndianChartPng(
                  size: 320,
                  planetsByHouse: d1ByHouse,
                  lagnaSignIndex: result.lagnaSignIndex,
                );
                final chartD9 = await ChartRenderer.renderNorthIndianChartPng(
                  size: 320,
                  planetsByHouse: d9ByHouse,
                  lagnaSignIndex: ascNavSign,
                );
                final chartD10 = await ChartRenderer.renderNorthIndianChartPng(
                  size: 320,
                  planetsByHouse: d10ByHouse,
                  lagnaSignIndex: ascDasSign,
                );

                final pdfSvc = PdfService();
                final fontData = await rootBundle
                    .load('assets/fonts/NotoSansDevanagari-Regular.ttf');
                final bytes = await pdfSvc.buildKundaliPdf(
                  input: input,
                  result: result,
                  devanagariFontData: fontData,
                  chartD1: chartD1,
                  chartD9: chartD9,
                  chartD10: chartD10,
                  dashaRows: dashaRows,
                );
                final dir = await getApplicationDocumentsDirectory();
                final file = File(p.join(
                    dir.path,
                    'AnoopAstro_Kundali_${input.name}_${DateFormat('yyyyMMdd').format(result.zonedBirth)}.pdf'));
                await file.writeAsBytes(bytes, flush: true);
                await Printing.sharePdf(
                    bytes: bytes, filename: p.basename(file.path));
              },
            )
          ],
        ),
        body: TabBarView(
          children: [
            _ChartTab(
              title: 'D1 North-Indian Chart',
              planetsByHouse: d1ByHouse,
              lagnaSignIndex: result.lagnaSignIndex,
              result: result,
              dashaRows: dashaRows,
            ),
            _ChartTab(
              title: 'D9 (Navamsa)',
              planetsByHouse: d9ByHouse,
              lagnaSignIndex: ascNavSign,
              result: result,
              dashaRows: dashaRows,
            ),
            _ChartTab(
              title: 'D10 (Dasamsa)',
              planetsByHouse: d10ByHouse,
              lagnaSignIndex: ascDasSign,
              result: result,
              dashaRows: dashaRows,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartTab extends StatelessWidget {
  const _ChartTab({
    required this.title,
    required this.planetsByHouse,
    required this.lagnaSignIndex,
    required this.result,
    required this.dashaRows,
  });

  final String title;
  final Map<int, List<String>> planetsByHouse;
  final int lagnaSignIndex;
  final KundaliResult result;
  final List<Map<String, String>> dashaRows;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.zonedBirth.timeZoneName}: ${DateFormat('yyyy-MM-dd HH:mm').format(result.zonedBirth)}'),
                Text('Place: ${result.zonedBirth.timeZoneOffset.isNegative ? '-' : '+'}${result.zonedBirth.timeZoneOffset.inHours.abs().toString().padLeft(2, '0')}:${(result.zonedBirth.timeZoneOffset.inMinutes.abs()%60).toString().padLeft(2, '0')}  •  Weekday: ${result.weekday}'),
                const SizedBox(height: 8),
                Text('Lagna: ${result.lagnaLabel}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: result.panchang.entries
                      .map((e) => Chip(label: Text('${e.key}: ${e.value}')))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Center(
                  child: NorthIndianChart(
                    size: 280,
                    planetsByHouse: planetsByHouse,
                    lagnaSignIndex: lagnaSignIndex,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (title.contains('D1')) ...[
          const SizedBox(height: 12),
          Card(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ग्रह')),
                DataColumn(label: Text('दीर्घांश°')),
                DataColumn(label: Text('राशि')),
                DataColumn(label: Text('नक्षत्र/पाद')),
              ],
              rows: result.planets
                  .map((p) => DataRow(cells: [
                        DataCell(Text(p.grah)),
                        DataCell(Text(p.longitudeSidereal.toStringAsFixed(2))),
                        DataCell(Text(rashiHindi[p.rashiIndex])),
                        DataCell(Text('${p.nakshatra} / ${p.pada}')),
                      ]))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Vimshottari Dasha (Mahadasha → Antardasha)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _DashaTable(rows: dashaRows),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Note: Sun/Moon are computed with compact Meeus formulas and Lahiri ayanamsa; lagna is approximated from LST for demo. Swap in a precise ascendant algorithm and full planetary engine for production.',
          style: TextStyle(color: Colors.orange),
        ),
      ],
    );
  }
}

class _DashaTable extends StatelessWidget {
  const _DashaTable({required this.rows});
  final List<Map<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final styleHeader =
        Theme.of(context).textTheme.labelLarge!.copyWith(fontWeight: FontWeight.bold);
    final styleCell = Theme.of(context).textTheme.bodyMedium;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 36,
        columns: [
          DataColumn(label: Text('महादशा', style: styleHeader)),
          DataColumn(label: Text('अंतरदशा', style: styleHeader)),
          DataColumn(label: Text('From', style: styleHeader)),
          DataColumn(label: Text('To', style: styleHeader)),
        ],
        rows: rows
            .map((r) => DataRow(cells: [
                  DataCell(Text(r['maha']!, style: styleCell)),
                  DataCell(Text(r['antar']!, style: styleCell)),
                  DataCell(Text(r['from']!, style: styleCell)),
                  DataCell(Text(r['to']!, style: styleCell)),
                ]))
            .toList(),
      ),
    );
  }
}

class SavedChartsPage extends StatelessWidget {
  const SavedChartsPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('Saved charts — TODO: Persist locally with sqflite'));
  }
}

class PanchangPage extends StatelessWidget {
  const PanchangPage({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('Panchang — TODO: Compute sunrise/sunset, karana offline'));
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          title: Text('Brand'),
          subtitle: Text('AnoopAstro — Offline Vedic Astrology'),
          leading: Icon(Icons.auto_awesome, color: brandPrimary),
        ),
        const Divider(),
        SwitchListTile(
          title: const Text('Dark mode'),
          value: themeMode == ThemeMode.dark,
          onChanged: (v) => ref.read(themeModeProvider.notifier).state =
              v ? ThemeMode.dark : ThemeMode.light,
        ),
        const SizedBox(height: 4),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('Language'),
          subtitle:
              Text(locale.languageCode == 'hi' ? 'Hindi (हिंदी)' : 'English'),
          onTap: () async {
            final sel = await showModalBottomSheet<Locale>(
              context: context,
              builder: (_) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('English'),
                    onTap: () => Navigator.pop(context, const Locale('en')),
                  ),
                  ListTile(
                    title: const Text('हिंदी'),
                    onTap: () => Navigator.pop(context, const Locale('hi')),
                  ),
                ],
              ),
            );
            if (sel != null) ref.read(localeProvider.notifier).state = sel;
          },
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.shield),
          title: Text('Offline'),
          subtitle:
              Text('No internet permission. All computations & data are on-device.'),
        ),
        const SizedBox(height: 24),
        const Text('Attributions', style: TextStyle(fontWeight: FontWeight.bold)),
        const Text(
            '• Timezone data: package:timezone (offline)\n• Fonts: Noto Sans Devanagari\n• City data: GeoNames (India subset)'),
      ],
    );
  }
}
