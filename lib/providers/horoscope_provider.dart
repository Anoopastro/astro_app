import 'package:flutter/foundation.dart';
import 'package:vedic_astrology/vedic_astrology.dart';

class HoroscopeProvider extends ChangeNotifier {
  Map<String, dynamic> horoscopeData = {};

  Future<void> generateHoroscope(
      DateTime birthDate, double latitude, double longitude) async {
    try {
      // Create Horoscope using vedic_astrology
      final horoscope = Horoscope(
        dateTime: birthDate,
        latitude: latitude,
        longitude: longitude,
      );

      // Planets
      final planets = <String, double>{};
      for (final planet in Planet.values) {
        final position = horoscope.getPlanetPosition(planet);
        planets[planet.name] = position.longitude;
      }

      // Houses
      final houses = <int, double>{};
      for (var i = 1; i <= 12; i++) {
        houses[i] = horoscope.getHouseCusp(i);
      }

      // Save
      horoscopeData = {
        'planets': planets,
        'houses': houses,
        'ascendant': horoscope.ascendant,
      };

      notifyListeners();
    } catch (e) {
      debugPrint("Error generating horoscope: $e");
    }
  }
}
