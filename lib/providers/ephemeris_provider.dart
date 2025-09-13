import 'package:sweph/sweph.dart';

class EphemerisProvider {
  // Planet constants (sweph 2.x)
  static const Map<int, String> planets = {
    SE_SUN: "Sun",
    SE_MOON: "Moon",
    SE_MERCURY: "Mercury",
    SE_VENUS: "Venus",
    SE_MARS: "Mars",
    SE_JUPITER: "Jupiter",
    SE_SATURN: "Saturn",
    SE_URANUS: "Uranus",
    SE_NEPTUNE: "Neptune",
    SE_PLUTO: "Pluto",
    SE_TRUE_NODE: "Rahu",
    SE_MEAN_NODE: "Ketu",
  };

  // Calculate planetary longitudes
  Future<Map<String, double>> allPlanetsAt(double jd) async {
    final Map<String, double> results = {};
    for (var entry in planets.entries) {
      final pos = await calc(jd, entry.key, SEFLG_SWIEPH); // [lon, lat, distance, speedLon, speedLat, speedDist]
      results[entry.value] = pos[0]; // longitude
    }
    return results;
  }

  // Calculate houses (Placidus)
  Future<List<double>> calculateHouses(double jd, double lat, double lon) async {
    final housesCusps = await houses(jd, lat, lon, 'P'); // Placidus
    return housesCusps;
  }
}
