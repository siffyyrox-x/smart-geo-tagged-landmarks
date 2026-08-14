import 'package:flutter/material.dart';
import '../models/landmark.dart';
import 'landmark_image.dart';
import 'score_badge.dart';

/// One row in the Landmarks List screen (Requirement 4: each item must
/// show Title, Score, Image).
class LandmarkCard extends StatelessWidget {
  final Landmark landmark;
  final double minScore;
  final double maxScore;
  final VoidCallback? onTap;
  final Widget? trailing;

  const LandmarkCard({
    super.key,
    required this.landmark,
    required this.minScore,
    required this.maxScore,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(10),
        leading: LandmarkImage(imagePath: landmark.image, size: 56),
        title: Text(
          landmark.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              ScoreBadge(score: landmark.score, minScore: minScore, maxScore: maxScore),
              const SizedBox(width: 10),
              Icon(Icons.directions_walk, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 2),
              Text('${landmark.visitCount}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
