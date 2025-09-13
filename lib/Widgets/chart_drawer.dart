import 'package:flutter/material.dart';
import '../utils/chart_drawer.dart';

class ChartWidget extends StatelessWidget {
  final Map<String, double> planets;
  final List<double> houses;

  const ChartWidget({super.key, required this.planets, required this.houses});

  @override
  Widget build(BuildContext context) {
    return ChartDrawer(planets: planets, houses: houses).buildChart();
  }
}
