import 'dart:typed_data';
import 'dart:io' show gzip;
import 'package:flutter/services.dart';

class EphemerisProvider {
  late double startJd;
  late double stepSeconds;
  late int count;
  late int planetCount;
  late Float64List _data;
  bool _loaded = false;

  final planetNames = [
    'Sun','Moon','Mercury','Venus','Mars',
    'Jupiter','Saturn','Uranus','Neptune','Pluto','TrueNode'
  ];

  Future<void> loadFromAsset(String assetPath) async {
    final gzBytes = await rootBundle.load(assetPath);
    final bytes = gzBytes.buffer.asUint8List();
    final decompressed = gzip.decode(bytes);
    final bd = ByteData.sublistView(decompressed);

    int offset = 0;
    startJd = bd.getFloat64(offset, Endian.little); offset += 8;
    stepSeconds = bd.getFloat64(offset, Endian.little); offset += 8;
    count = bd.getInt32(offset, Endian.little); offset += 4;
    planetCount = bd.getInt32(offset, Endian.little); offset += 4;

    final expected = count * planetCount * 8;
    _data = decompressed.buffer.asFloat64List(offset, expected ~/ 8);
    _loaded = true;
  }

  double? planetLongitudeAt(String planetName, double jd) {
    if (!_loaded) throw Exception("Ephemeris not loaded");
    final idx = planetNames.indexOf(planetName);
    if (idx < 0) return null;

    final stepDays = stepSeconds / 86400.0;
    final t = (jd - startJd) / stepDays;
    if (t < 0 || t >= count - 1) return null;

    final i0 = t.floor();
    final i1 = i0 + 1;
    final frac = t - i0;

    final v0 = _data[i0 * planetCount + idx];
    final v1 = _data[i1 * planetCount + idx];
    return _interp(v0, v1, frac);
  }

  Map<String, double> allPlanetsAt(double jd) {
    final m = <String, double>{};
    for (var p in planetNames) {
      final v = planetLongitudeAt(p, jd);
      if (v != null) m[p] = v;
    }
    return m;
  }

  double _interp(double a, double b, double f) {
    double d = ((b - a + 540) % 360) - 180;
    return (a + d * f + 360) % 360;
  }
}