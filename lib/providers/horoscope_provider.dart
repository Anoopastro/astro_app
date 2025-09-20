import 'package:flutter/foundation.dart';

class HoroscopeProvider with ChangeNotifier {
  Map<String, String> _planetPositions = {};
  List<String> _houses = [];

  Map<String, String> get planetPositions => _planetPositions;
  List<String> get houses => _houses;

  /// Generate a mock horoscope based on user input.
  /// In the future, replace this with real astrology logic.
  void generateHoroscope({
    required DateTime birthDate,
    required double latitude,
    required double longitude,
  }) {
    // For now, just return placeholder data
    _planetPositions = {
      "Sun": "Leo 15°",
      "Moon": "Virgo 5°",
      "Mars": "Libra 23°",
      "Mercury": "Cancer 12°",
      "Jupiter": "Sagittarius 8°",
      "Venus": "Gemini 19°",
      "Saturn": "Capricorn 3°",
      "Rahu": "Pisces 10°",
      "Ketu": "Virgo 10°",
    };

    _houses = List.generate(12, (i) => "House ${i + 1}: Example Sign");

    notifyListeners();
  }
}
