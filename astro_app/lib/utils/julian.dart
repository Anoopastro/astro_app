double julianDayUtc(DateTime dt) {
  int year = dt.year;
  int month = dt.month;
  double day = dt.day +
      dt.hour / 24.0 +
      dt.minute / 1440.0 +
      dt.second / 86400.0;

  if (month <= 2) {
    year -= 1;
    month += 12;
  }
  final A = (year / 100).floor();
  final B = 2 - A + (A / 4).floor();
  return (365.25 * (year + 4716)).floor() +
      (30.6001 * (month + 1)).floor() +
      day + B - 1524.5;
}