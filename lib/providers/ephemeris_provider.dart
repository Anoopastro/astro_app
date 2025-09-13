import 'package:flutter/services.dart';
import 'package:sweph/sweph.dart';

class EphemerisProvider {
  final Sweph _swe = Sweph();

  EphemerisProvider();

  Future<void> loadFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    _swe.loadBinaryEphemeris(data.buffer.asUint8List());
  }

  Map<String, double> calculatePlanets(double jd) {
    final Map<String, double> planets = {};
    final Map<int, String> planetMap = {
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
      SweConst.SE_MEAN_NODE: "Ketu",
    };

    planetMap.forEach((key, name) {
      final pos = _swe.calc(jd, key, SweConst.SEFLG_SWIEPH);
      planets[name] = pos[0]; // longitude
    });

    return planets;
  }

  Map<String, double> calculateHouses(double jd, double lat, double lon) {
    final cusps = _swe.houses(jd, lat, lon, 'P'); // Placidus
    final Map<String, double> houses = {};
    for (int i = 1; i <= 12; i++) {
      houses['House $i'] = cusps[i - 1];
    }
    return houses;
  }
}
