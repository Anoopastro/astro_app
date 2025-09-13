import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sweph/sweph.dart';
import 'package:intl/intl.dart';

class EphemerisProvider extends ChangeNotifier {
  final Sweph _swe = Sweph();
  Map<String, double> planets = {};
  List<double> houses = [];
  late String city;
  late DateTime birthDate;

  Future<void> initialize() async {
    // Load local ephemeris file
    final ephemData = await rootBundle.load('assets/ephem/ephem_1950_2050.dat');
    _swe.loadBinaryEphemeris(ephemData.buffer.asUint8List());

    // Get current location
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    city = await _getNearestCity(pos.latitude, pos.longitude);

    birthDate = DateTime.now(); // Default now, can be user input

    await _calculatePlanets(pos.latitude, pos.longitude);
    await _calculateHouses(pos.latitude, pos.longitude);
  }

  Future<String> _getNearestCity(double lat, double lon) async {
    final data = await rootBundle.loadString('assets/cities/cities.json');
    final List cities = jsonDecode(data);
    // Simple nearest city calculation (can enhance)
    cities.sort((a, b) {
      final distA = (a['lat'] - lat).abs() + (a['lon'] - lon).abs();
      final distB = (b['lat'] - lat).abs() + (b['lon'] - lon).abs();
      return distA.compareTo(distB);
    });
    return cities.first['name'];
  }

  Future<void> _calculatePlanets(double lat, double lon) async {
    final jd = _swe.swe_julday(
        birthDate.year, birthDate.month, birthDate.day, birthDate.hour + birthDate.minute / 60, Sweph.SE_GREG_CAL);
    final Map<int, String> planetNames = {
      SweConst.SE_SUN: 'Sun',
      SweConst.SE_MOON: 'Moon',
      SweConst.SE_MERCURY: 'Mercury',
      SweConst.SE_VENUS: 'Venus',
      SweConst.SE_MARS: 'Mars',
      SweConst.SE_JUPITER: 'Jupiter',
      SweConst.SE_SATURN: 'Saturn',
      SweConst.SE_URANUS: 'Uranus',
      SweConst.SE_NEPTUNE: 'Neptune',
      SweConst.SE_PLUTO: 'Pluto',
      SweConst.SE_TRUE_NODE: 'Rahu',
      SweConst.SE_MEAN_NODE: 'Ketu',
    };

    planets.clear();
    for (var key in planetNames.keys) {
      final pos = _swe.calc(jd, key, SweConst.SEFLG_SWIEPH);
      planets[planetNames[key]!] = pos[0]; // Longitude
    }
    notifyListeners();
  }

  Future<void> _calculateHouses(double lat, double lon) async {
    final jd = _swe.swe_julday(
        birthDate.year, birthDate.month, birthDate.day, birthDate.hour + birthDate.minute / 60, Sweph.SE_GREG_CAL);
    houses = _swe.houses(jd, lat, lon, 'P'); // Placidus
    notifyListeners();
  }
}
