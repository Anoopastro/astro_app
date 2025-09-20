import 'dart:convert';
import 'package:flutter/foundation.dart'; // Add this
import 'package:sweph/sweph.dart' as sweph;

class HoroscopeProvider extends ChangeNotifier { // Must extend ChangeNotifier
  final List<dynamic> cities;
  final String ephemPath;
  late sweph.Sweph swephInstance;

  Map<String, dynamic> horoscopeData = {};
  String selectedCity = '';
  double latitude = 0.0;
  double longitude = 0.0;

  HoroscopeProvider(this.cities, this.ephemPath) {
    swephInstance = sweph.Sweph();
    swephInstance.swe_set_ephe_path(ephemPath);
  }

  void setCity(String cityName, double lat, double lon) {
    selectedCity = cityName;
    latitude = lat;
    longitude = lon;
    notifyListeners();
  }

  Future<void> calculateHoroscope(DateTime birthDate) async {
    final jd = swephInstance.swe_julday(
      birthDate.year,
      birthDate.month,
      birthDate.day,
      birthDate.hour + birthDate.minute / 60.0,
      sweph.SE_GREG_CAL,
    );

    final planetIds = {
      'Sun': sweph.SE_SUN,
      'Moon': sweph.SE_MOON,
      'Mercury': sweph.SE_MERCURY,
      'Venus': sweph.SE_VENUS,
      'Mars': sweph.SE_MARS,
      'Jupiter': sweph.SE_JUPITER,
      'Saturn': sweph.SE_SATURN,
      'Rahu': sweph.SE_NODE,
      'Ketu': sweph.SE_TRUE_NODE,
    };

    Map<String, List<double>> planets = {};
    for (var entry in planetIds.entries) {
      planets[entry.key] = swephInstance.swe_calc_ut(jd, entry.value, sweph.SEFLG_SWIEPH);
    }

    final houses = swephInstance.swe_houses(jd, latitude, longitude);
    final ascendant = houses[0][0];

    // Dummy VimshottariDasha calculation if you don't have separate class
    final dasha = {
      'currentMahadasha': {'planet': 'Moon'},
      'antardashas': [{'planet': 'Sun'}],
    };

    horoscopeData = {
      'planets': planets,
      'lagna': ascendant,
      'houses': houses[0],
      'nakshatra': 'Ashwini',
      'tithi': 'Shukla Paksha 5',
      'dasha': dasha,
    };
    notifyListeners();
  }
}
