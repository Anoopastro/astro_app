import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sweph/sweph.dart';

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
    // Julian day
    final jd = sweph.swe_julday(
      birthDate.year,
      birthDate.month,
      birthDate.day,
      birthDate.hour + birthDate.minute / 60.0,
      Sweph.SE_GREG_CAL,
    );

    // Planet positions
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

    // Houses & Ascendant
    final houses = sweph.swe_houses(jd, latitude, longitude);
    final ascendant = houses[0][0];

    // Moon position for Nakshatra and Dasha
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

// ---------------------- VIMSHOTTARI DASHA ----------------------
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
