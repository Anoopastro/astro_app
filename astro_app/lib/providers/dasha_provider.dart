class DashaProvider {
  final List<Map<String,dynamic>> _sequence = [
    {"planet": "Ketu", "years": 7},
    {"planet": "Venus", "years": 20},
    {"planet": "Sun", "years": 6},
    {"planet": "Moon", "years": 10},
    {"planet": "Mars", "years": 7},
    {"planet": "Rahu", "years": 18},
    {"planet": "Jupiter", "years": 16},
    {"planet": "Saturn", "years": 19},
    {"planet": "Mercury", "years": 17},
  ];

  List<String> computeVimshottari(double jd, double moonLongitude) {
    final nakshatra = (moonLongitude / (360/27)).floor();
    final balance = ((moonLongitude % (360/27)) / (360/27));
    final startIndex = nakshatra % _sequence.length;

    List<String> dashas = [];
    double jdPointer = jd;

    for (int i=0;i<_sequence.length;i++) {
      final seq = _sequence[(startIndex + i) % _sequence.length];
      double years = seq["years"].toDouble();
      if (i == 0) years *= (1 - balance);

      dashas.add("${seq['planet']} → ${years.toStringAsFixed(1)} years");
      jdPointer += years * 365.25;
    }
    return dashas;
  }
}