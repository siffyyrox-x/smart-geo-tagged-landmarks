import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/landmark.dart';
import '../providers/landmarks_provider.dart';
import '../services/location_service.dart';
import '../utils/score_color.dart';
import '../utils/visit_helper.dart';
import '../widgets/landmark_image.dart';
import '../widgets/offline_banner.dart';
import '../widgets/score_badge.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LandmarksProvider>();
    // Requirement 2 says the map shows ALL landmarks - intentionally not
    // provider.visibleLandmarks, which is filtered/sorted by the separate
    // Landmarks List controls (Requirement 4) and shares this same
    // provider instance.
    final landmarks = provider.allActiveLandmarks;
    final (minScore, maxScore) = provider.scoreRange;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmarks Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'My location',
            onPressed: () => _centerOnMyLocation(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<LandmarksProvider>().refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          if (provider.errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade50,
              padding: const EdgeInsets.all(8),
              child: Text(
                provider.errorMessage!,
                style: TextStyle(color: Colors.red.shade800, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(kBangladeshCenterLat, kBangladeshCenterLon),
                    initialZoom: kDefaultMapZoom,
                    minZoom: 4,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cse489.smart_landmarks',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: landmarks.map((landmark) {
                        return Marker(
                          width: 42,
                          height: 42,
                          point: LatLng(landmark.lat, landmark.lon),
                          child: GestureDetector(
                            onTap: () => _showLandmarkDetail(context, landmark, minScore, maxScore),
                            child: _MarkerPin(
                              color: scoreToColor(landmark.score, minScore, maxScore),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (provider.isLoading)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnMyLocation(BuildContext context) async {
    try {
      final position = await LocationService.getCurrentLocation();
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _showLandmarkDetail(
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
                        Text(
                          landmark.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
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
              Text(
                'Lat: ${landmark.lat.toStringAsFixed(5)}, Lon: ${landmark.lon.toStringAsFixed(5)}',
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

/// A simple teardrop-style pin, colored by score, so we don't need any
/// extra icon assets bundled with the app.
class _MarkerPin extends StatelessWidget {
  final Color color;
  const _MarkerPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.location_on, color: color, size: 42, shadows: const [
      Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(0, 1)),
    ]);
  }
}
