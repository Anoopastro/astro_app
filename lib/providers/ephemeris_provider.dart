import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:archive/archive.dart';

class EphemerisProvider {
  late Float64List _data;
  bool _isLoaded = false;

  late double _jdStart;
  late double _jdEnd;
  late double _step; // step in days (0.125 = 3h)
  static const int _planetCount = 9; // Sun..Ketu

  Future<void> load() async {
    if (_isLoaded) return;

    try {
      final compressed = await rootBundle.load('assets/ephem/ephem_1950_2050_3h.bin.gz');
      final bytes = compressed.buffer.asUint8List();

      // decompress gzip
      final raw = GZipDecoder().decodeBytes(bytes);

      // convert to doubles
      final bd = ByteData.sublistView(Uint8List.fromList(raw));
      _data = bd.buffer.asFloat64List();

      // first 3 doubles = metadata
      _jdStart = _data[0];
      _jdEnd = _data[1];
      _step = _data[2]; // in days

      _isLoaded = true;
      print("✅ Ephemeris loaded: $_jdStart → $_jdEnd step=$_step");

    } catch (e) {
      print("❌ Failed to load ephemeris: $e");
      rethrow;
    }
  }

  /// return {planetName: longitude}
  Map<String, double> allPlanetsAt(double jd) {
    if (!_isLoaded) throw StateError("Ephemeris not loaded!");

    final planets = <String, double>{};
    final names = ["Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn", "Rahu", "Ketu"];

    for (int i = 0; i < _planetCount; i++) {
      planets[names[i]] = getPlanetAt(i, jd);
    }
    return planets;
  }

  double getPlanetAt(int planetIndex, double jd) {
    if (!_isLoaded) throw StateError("Ephemeris not loaded!");
    if (jd < _jdStart || jd > _jdEnd) {
      throw RangeError("JD $jd outside ephemeris range ($_jdStart - $_jdEnd)");
    }

    final recordSize = _planetCount;
    final header = 3; // metadata count
    final stepDays = _step;

    // nearest index
    final index = ((jd - _jdStart) / stepDays).floor();
    final idx1 = header + index * recordSize + planetIndex;
    final idx2 = idx1 + recordSize;

    if (idx2 >= _data.length) return _normalize360(_data[idx1]);

    final t1 = _jdStart + index * stepDays;
    final t2 = t1 + stepDays;

    final v1 = _data[idx1];
    final v2 = _data[idx2];

    final frac = (jd - t1) / (t2 - t1);

    // linear interpolation + normalize
    return _normalize360(v1 + (v2 - v1) * frac);
  }

  double _normalize360(double v) {
    var res = v % 360.0;
    if (res < 0) res += 360.0;
    return res;
  }
}
