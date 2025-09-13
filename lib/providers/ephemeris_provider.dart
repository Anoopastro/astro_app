import 'package:sweph/sweph.dart';

class EphemerisProvider {
  late Sweph _swe;
  bool _initialized = false;

  /// Initialize Swiss Ephemeris
  Future<void> init() async {
    if (!_initialized) {
      _swe = Sweph();
      await _swe.init();
      _initialized = true;
    }
  }

  /// Close Swiss Ephemeris (cleanup)
  Future<void> close() async {
    if (_initialized) {
      await _swe.close();
      _initialized = false;
    }
  }

  /// Calculate planetary longitudes for given Julian Day (UT)
  Future<Map<String, double>> calculatePlanets(double jd) async {
    if (!_initialized) {
      await init();
    }

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
      SweConst.SE_TRUE_NODE: "Rahu",
      SweConst.SE_MEAN_NODE: "Ketu" // Ketu को Rahu से 180° shift करके भी निकाल सकते हैं
    };

    Map<String, double> result = {};
    for (var entry in planetNames.entries) {
      final pos = await _swe.calcUt(jd, entry.key, SweConst.SEFLG_SWIEPH);
      result[entry.value] = pos.longitude;
    }

    // Correct Ketu as 180° opposite Rahu
    if (result.containsKey("Rahu")) {
      result["Ketu"] = (result["Rahu"]! + 180.0) % 360;
    }

    return result;
  }

  /// Calculate Ascendant (Lagna) and 12 Houses
  Future<Map<String, double>> calculateHouses(
      double jd, double lat, double lon) async {
    if (!_initialized) {
      await init();
    }

    final houses = await _swe.houses(jd, lat, lon, 'P'); // Placidus system
    Map<String, double> result = {
      "Ascendant": houses.ascendant,
    };

    for (int i = 0; i < houses.cusps.length; i++) {
      result["House_${i + 1}"] = houses.cusps[i];
    }

    return result;
  }
}
