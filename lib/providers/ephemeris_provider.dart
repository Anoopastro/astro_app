import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class EphemerisProvider {
  static final EphemerisProvider _instance = EphemerisProvider._internal();
  factory EphemerisProvider() => _instance;
  EphemerisProvider._internal();

  late Float64List _data;
  bool _isLoaded = false;

  Future<void> load() async {
    if (_isLoaded) return;

    // load compressed binary file from assets
    final byteData = await rootBundle.load('assets/ephem/ephem_1950_2050.gz');
    final List<int> compressed = byteData.buffer.asUint8List();

    // decompress (example using gzip decoder)
    final List<int> decompressed = gzip.decode(compressed);

    // ✅ convert to Uint8List (TypedData)
    final Uint8List decompressedBytes = Uint8List.fromList(decompressed);

    // ✅ safe: sublistView works on Uint8List
    final bd = ByteData.sublistView(decompressedBytes);

    // Example offset / length (adjust according to your binary format)
    const int offset = 0;
    final int expected = bd.lengthInBytes;

    // ✅ safe: buffer exists on Uint8List
    _data = decompressedBytes.buffer.asFloat64List(offset, expected ~/ 8);

    _isLoaded = true;
  }

  double getValue(int index) {
    if (!_isLoaded) {
      throw StateError("Ephemeris data not loaded yet. Call load() first.");
    }
    if (index < 0 || index >= _data.length) {
      throw RangeError("Index $index out of range (0..${_data.length - 1})");
    }
    return _data[index];
  }
}
