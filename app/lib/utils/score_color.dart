import 'package:flutter/material.dart';

/// Requirement 2 (Map View) says marker color must reflect score
/// (low -> high). Since the scoring formula/weights vary per student key,
/// we can't hard-code absolute thresholds like "score > 80 = green" - so
/// this interpolates red -> amber -> green based on where the score falls
/// between the min and max score CURRENTLY loaded (see
/// LandmarksProvider.scoreRange).
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
