import 'package:flutter/material.dart';


Color scoreToColor(double score, double min, double max) {
  final range = (max - min).abs();
  // .clamp() on a double returns num, not double - convert explicitly so
  // `t` is a real double (Color.lerp requires a double t).
  final double t = range == 0 ? 0.5 : ((score - min) / range).clamp(0.0, 1.0).toDouble();

  // 0.0 -> red, 0.5 -> amber, 1.0 -> green
  if (t < 0.5) {
    return Color.lerp(Colors.red, Colors.amber, t * 2)!;
  }
  return Color.lerp(Colors.amber, Colors.green, (t - 0.5) * 2)!;
}
