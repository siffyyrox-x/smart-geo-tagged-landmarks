import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/landmarks_provider.dart';
import '../utils/visit_helper.dart';
import '../widgets/landmark_card.dart';
import '../widgets/landmark_image.dart';
import '../widgets/offline_banner.dart';
import '../widgets/score_badge.dart';



class LandmarksListScreen extends StatelessWidget {
  const LandmarksListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LandmarksProvider>();
    final landmarks = provider.visibleLandmarks;
    final (minScore, maxScore) = provider.scoreRange;

    return Scaffold(
      appBar: AppBar(title: const Text('Landmarks')),
      body: RefreshIndicator(
        onRefresh: () => context.read<LandmarksProvider>().refresh(),
        child: Column(
          children: [
            const OfflineBanner(),
            _FilterSortBar(provider: provider),
            if (provider.isLoading && landmarks.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (landmarks.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    provider.errorMessage ?? 'No landmarks match the current filter.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: landmarks.length,
                  itemBuilder: (context, index) {
                    final landmark = landmarks[index];
                    return LandmarkCard(
                      landmark: landmark,
                      minScore: minScore,
                      maxScore: maxScore,
                      onTap: () => _showDetail(context, landmark, minScore, maxScore),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDetail(
    BuildContext context,
    Landmark landmark,
    double minScore,
    double maxScore,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LandmarkImage(imagePath: landmark.image, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(landmark.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        ScoreBadge(score: landmark.score, minScore: minScore, maxScore: maxScore),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Visits so far: ${landmark.visitCount}  •  Avg distance: '
                '${landmark.avgDistance.toStringAsFixed(1)} m',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Visit this landmark'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    performVisit(context, landmark);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterSortBar extends StatelessWidget {
  final LandmarksProvider provider;
  const _FilterSortBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final (minPossible, maxPossible) = provider.scoreRange;
    final safeMax = maxPossible <= minPossible ? minPossible + 1 : maxPossible;
    // .clamp() on a double returns num, not double - Slider.value needs a
    // real double, so convert explicitly to avoid a type error.
    final double clampedValue = provider.minScoreFilter.clamp(minPossible, safeMax).toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Sort:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              DropdownButton<SortMode>(
                value: provider.sortMode,
                items: const [
                  DropdownMenuItem(value: SortMode.none, child: Text('Default')),
                  DropdownMenuItem(value: SortMode.scoreHighToLow, child: Text('Score: High to Low')),
                  DropdownMenuItem(value: SortMode.scoreLowToHigh, child: Text('Score: Low to High')),
                ],
                onChanged: (mode) {
                  if (mode == null) return;
                  provider.sortMode = mode;
                  provider.notifyListeners();
                },
              ),
            ],
          ),
          Row(
            children: [
              const Text('Min score:', style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: Slider(
                  value: clampedValue,
                  min: minPossible,
                  max: safeMax,
                  divisions: 20,
                  label: clampedValue.toStringAsFixed(1),
                  onChanged: (value) {
                    provider.minScoreFilter = value;
                    provider.notifyListeners();
                  },
                ),
              ),
              Text(clampedValue.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }
}
