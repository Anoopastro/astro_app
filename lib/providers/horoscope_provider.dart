class HoroscopeProvider extends ChangeNotifier {
  final List<dynamic> cities;
  final String ephemPath;
  late sweph.Sweph sweph;

  Map<String, dynamic> horoscopeData = {};
  String selectedCity = '';
  double latitude = 0.0;
  double longitude = 0.0;

  HoroscopeProvider(this.cities, this.ephemPath) {
    sweph = sweph.Sweph();
    sweph.setEphemerisPath(ephemPath);
  }

  void setCity(String cityName, double lat, double lon) {
    selectedCity = cityName;
    latitude = lat;
    longitude = lon;
    notifyListeners();
  }

  Future<void> calculateHoroscope(DateTime birthDate) async {
    // Julian Day
    final jd = sweph.julday(
        birthDate.year,
        birthDate.month,
        birthDate.day,
        birthDate.hour + birthDate.minute / 60.0,
        sweph.GREG_CAL);

    // Planets
    Map<String, List<double>> planets = {};
    final planetMap = {
      'Sun': sweph.Planet.Sun,
      'Moon': sweph.Planet.Moon,
      'Mercury': sweph.Planet.Mercury,
      'Venus': sweph.Planet.Venus,
      'Mars': sweph.Planet.Mars,
      'Jupiter': sweph.Planet.Jupiter,
      'Saturn': sweph.Planet.Saturn,
      'Rahu': sweph.Planet.Node,
      'Ketu': sweph.Planet.TrueNode,
    };

    for (var entry in planetMap.entries) {
      final result = sweph.calc_ut(jd, entry.value, sweph.SEFLG_SWIEPH);
      planets[entry.key] = [result.longitude, result.latitude, result.distance, result.speed];
    }

    // Houses
    final houseResult = sweph.houses(jd, latitude, longitude, 0);
    final houses = houseResult.houses; // 16 house longitudes
    final ascendant = houseResult.ascendant;

    // Dasha calculation
    final moonPos = planets['Moon']![0];
    final dasha = VimshottariDasha.calculate(moonPos, jd);
    final nakshatra = _getNakshatra(moonPos);
    final tithi = _getTithi(jd);

    horoscopeData = {
      'planets': planets,
      'lagna': ascendant,
      'houses': houses,
      'nakshatra': nakshatra,
      'tithi': tithi,
      'dasha': dasha,
    };
    notifyListeners();
  }

  String _getNakshatra(double moonLongitude) {
    final nakshatras = [
      'Ashwini','Bharani','Krittika','Rohini','Mrigashirsha','Ardra','Punarvasu','Pushya','Ashlesha','Magha',
      'Purva Phalguni','Uttara Phalguni','Hasta','Chitra','Swati','Vishakha','Anuradha','Jyeshtha','Mula',
      'Purva Ashadha','Uttara Ashadha','Shravana','Dhanishta','Shatabhisha','Purva Bhadrapada','Uttara Bhadrapada','Revati'
    ];
    final index = ((moonLongitude / 13.3333333).floor()) % 27;
    return nakshatras[index];
  }

  String _getTithi(double jd) => 'Shukla Paksha 5';
}
