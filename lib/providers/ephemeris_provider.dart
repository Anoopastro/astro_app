import 'package:sweph/sweph.dart';

class EphemerisProvider {
  final Sweph _swe = Sweph();

  final Map<int, String> planets = {
    Sweph.SE_SUN: "Sun",
    Sweph.SE_MOON: "Moon",
    Sweph.SE_MERCURY: "Mercury",
    Sweph.SE_VENUS: "Venus",
    Sweph.SE_MARS: "Mars",
    Sweph.SE_JUPITER: "Jupiter",
    Sweph.SE_SATURN: "Saturn",
    Sweph.SE_URANUS: "Uranus",
    Sweph.SE_NEPTUNE: "Neptune",
    Sweph.SE_PLUTO: "Pluto",
    Sweph.SE_TRUE_NODE: "Rahu",
    Sweph.SE_MEAN_NODE: "Ketu",
  };

  Future<void> init() async {
    await _swe.setEphePath('assets/ephem/');
  }

  Future<Map<String, double>> allPlanetsAt(double jd) async {
    final Map<String, double> positions = {};
    for (var entry in planets.entries) {
      final pos = await _swe.calc(jd, entry.key, Sweph.SEFLG_SWIEPH);
      positions[entry.value] = pos[0]; // longitude
    }
    return positions;
  }

  Future<Map<String, double>> calculateHouses(
      double jd, double lat, double lon) async {
    final cusps = await _swe.houses(jd, lat, lon, 'P'); // Placidus
    final Map<String, double> houseMap = {};
    for (int i = 0; i < cusps.length; i++) {
      houseMap['House${i + 1}'] = cusps[i];
    }
    return houseMap;
  }
}
