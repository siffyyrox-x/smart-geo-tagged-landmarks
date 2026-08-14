import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/visit.dart';
import '../providers/activity_provider.dart';
import '../widgets/offline_banner.dart';


class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityProvider>().loadVisits();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActivityProvider>();
    final visits = provider.visits;

    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: Column(
        children: [
          const OfflineBanner(),
          if (provider.isLoading && visits.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (visits.isEmpty)
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "No visits yet. Go to the Map or Landmarks tab and tap\n"
                    "\"Visit this landmark\" to log your first one.",
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<ActivityProvider>().loadVisits(),
                child: ListView.builder(
                  itemCount: visits.length,
                  itemBuilder: (context, index) => _VisitTile(visit: visits[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final VisitRecord visit;
  const _VisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d, y • h:mm a').format(visit.visitTime);

    late final IconData icon;
    late final Color color;
    late final String statusText;

    switch (visit.status) {
      case VisitStatus.queuedOffline:
        icon = Icons.cloud_upload_outlined;
        color = Colors.orange;
        statusText = 'Queued (offline) - will sync automatically';
        break;
      case VisitStatus.submitting:
        icon = Icons.hourglass_top;
        color = Colors.blueGrey;
        statusText = 'Sending...';
        break;
      case VisitStatus.pendingServer:
        icon = Icons.hourglass_bottom;
        color = Colors.blue;
        statusText = 'Server is calculating distance...';
        break;
      case VisitStatus.done:
        icon = Icons.check_circle;
        color = Colors.green;
        statusText = visit.distance != null
            ? 'Distance: ${visit.distance!.toStringAsFixed(1)} m'
            : 'Done';
        break;
      case VisitStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        statusText = visit.errorMessage ?? 'Visit failed';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(visit.landmarkTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 2),
            Text(statusText, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
