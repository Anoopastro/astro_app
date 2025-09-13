import 'package:flutter/material.dart';

class ChartDrawer {
  final Map<String,double> planets;
  ChartDrawer({required this.planets});

  Widget buildChart() {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: GridView.count(
        crossAxisCount: 4,
        children: List.generate(16, (i) {
          return Center(
            child: Text(
              planets.keys.elementAt(i % planets.length),
              style: const TextStyle(fontSize: 10),
            ),
          );
        }),
      ),
    );
  }
}