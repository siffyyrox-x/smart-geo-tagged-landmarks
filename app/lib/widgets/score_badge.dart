import 'package:flutter/material.dart';
import '../utils/score_color.dart';

/// Small colored chip showing a landmark's score, used on the list, the
/// map popup, and the Add/View management list - one widget so the color
/// scale always looks consistent everywhere it appears.
class ScoreBadge extends StatelessWidget {
  final double score;
  final double minScore;
  final double maxScore;

  const ScoreBadge({
    super.key,
    required this.score,
    required this.minScore,
    required this.maxScore,
  });

  @override
  Widget build(BuildContext context) {
    final color = scoreToColor(score, minScore, maxScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            score.toStringAsFixed(1),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
