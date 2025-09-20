// lib/providers/horoscope_provider.dart
import 'dart:math';
import 'package:flutter/foundation.dart';

/// HoroscopeProvider
/// - Keeps simple offline/mock planet & house data so the app builds on mobile/tablet.
/// - Replace the mock calculations with a real ephemeris (sweph/ffi) later if desired.
class HoroscopeProvider extends ChangeNotifier {
  final List<dynamic> cities;
  final String? ephemPath;

  // Data exposed to UI & PDF generator
  Map<String, double> planets = {}; // planet name -> ecliptic longitude (deg)
  List<double> houses = []; // 16-house or 12-house cusp longitudes (deg)
  double? ascendant;
  String selectedCity = '';
  double latitude = 0.0;
  double longitude = 0.0;

  // Dasha / Nakshatra mock results
  Map<String, dynamic> dasha = {};
  String nakshatra = '';
  String tithi = '';

  HoroscopeProvider(this.cities, [this.ephemPath]);

  void setCity(String cityName, double lat, double lon) {
    selectedCity = cityName;
    latitude = lat;
    longitude = lon;
    notifyListeners();
  }

  /// Mock horoscope calculation.
  /// Deterministic simple algorithm so results vary by birthDate/lat/lon.
  /// Replace with real ephemeris calls later.
  Future<void> calculateHoroscope(DateTime birthDate) async {
    final seed = birthDate.millisecondsSinceEpoch ~/ 1000 + latitude.toInt() + longitude.toInt();
    final rng = Random(seed);

    // create mock planet longitudes (0-360)
    final planetNames = ['Sun','Moon','Mercury','Venus','Mars','Jupiter','Saturn','Rahu','Ketu'];
    planets = {
      for (var p in planetNames) p : (rng.nextDouble() * 360.0)
    };

    // Produce 16 house cusps by evenly dividing circle but phase-shifted by seed
    final houseCount = 16;
    final baseOffset = (seed % 360).toDouble();
    houses = List.generate(houseCount, (i) => (baseOffset + i * (360 / houseCount)) % 360);

    // Ascendant mock = house 1 cusp
    ascendant = houses.isNotEmpty ? houses[0] : 0.0;

    // Mock Nakshatra & Tithi (deterministic from moon position)
    final moonLon = planets['Moon'] ?? 0.0;
    nakshatra = _calcNakshatraFromMoon(moonLon);
    tithi = _calcMockTithi(birthDate);

    // Mock Vimshottari dasha (basic)
    dasha = _mockVimshottari(moonLon, birthDate);

    notifyListeners();
  }

  String _calcNakshatraFromMoon(double moonLon) {
    final nak = [
      'Ashwini','Bharani','Krittika','Rohini','Mrigashirsha','Ardra','Punarvasu','Pushya','Ashlesha',
      'Magha','Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha',
      'Mula','Purva Ashadha','Uttara Ashadha','Shravana','Dhanishta','Shatabhisha','Purva Bhadrapada',
      'Uttara Bhadrapada','Revati'
    ];
    final index = ((moonLon / 13.3333333).floor()) % 27;
    return nak[index];
  }

  String _calcMockTithi(DateTime birthDate) {
    final d = birthDate.day % 30;
    return 'Shukla Paksha ${d == 0 ? 30 : d}';
  }

  Map<String, dynamic> _mockVimshottari(double moonLon, DateTime jd0) {
    // Very simple mock - returns 9 mahadasha entries and picks one based on moon
    final mahadashaOrder = ['Ketu','Venus','Sun','Moon','Mars','Rahu','Jupiter','Saturn','Mercury'];
    final yearsMap = {
      'Ketu':7,'Venus':20,'Sun':6,'Moon':10,'Mars':7,'Rahu':18,'Jupiter':16,'Saturn':19,'Mercury':17
    };

    final startIndex = ((moonLon / 13.3333333).floor()) % 9;
    double startJD = jd0.millisecondsSinceEpoch / 1000 / 86400 + 2440587.5; // rough JD
    final List<Map<String,dynamic>> mahadashas = [];
    double curJD = startJD;
    for (int i=0;i<9;i++) {
      final pl = mahadashaOrder[(startIndex + i) % 9];
      final yrs = yearsMap[pl]!.toDouble();
      final endJD = curJD + yrs * 365.25;
      mahadashas.add({'planet':pl,'startJD':curJD,'endJD':endJD,'years':yrs});
      curJD = endJD;
    }
    final current = mahadashas[0];
    // simple antardashas split equally (mock)
    final antard = mahadashas.map((m) => {'planet':m['planet'],'startJD':m['startJD'],'endJD':m['endJD'],'years':m['years']}).toList();
    return {'mahadashas':mahadashas,'currentMahadasha':current,'antardashas':antard};
  }
}
