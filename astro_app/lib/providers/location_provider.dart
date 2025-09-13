import 'dart:convert';
import 'package:flutter/services.dart';

class LocationProvider {
  late Map<String, Map<String,double>> _cities;

  Future<void> loadCities(String path) async {
    final data = await rootBundle.loadString(path);
    final jsonMap = json.decode(data) as Map<String,dynamic>;
    _cities = jsonMap.map((k,v) => MapEntry(k, {
      "lat": (v["lat"] as num).toDouble(),
      "lon": (v["lon"] as num).toDouble()
    }));
  }

  Map<String,double>? getCoordinates(String city) {
    return _cities[city];
  }
}