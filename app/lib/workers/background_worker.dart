import 'package:workmanager/workmanager.dart';
import '../config.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_engine.dart';

class BackgroundWorker {

  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  
  static Future<void> registerPeriodicSync() async {
    await Workmanager().registerPeriodicTask(
      kPeriodicSyncTaskName,
      kPeriodicSyncTaskName,
      tag: kPeriodicSyncTaskTag,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

 
  static Future<void> schedulePollForJob({
    required String localVisitId,
    required int jobId,
  }) async {
    final uniqueName = '$kJobPollTaskPrefix$jobId';
    await Workmanager().registerOneOffTask(
      uniqueName,
      uniqueName,
      tag: 'job_poll',
      inputData: {
        'job_id': jobId,
        'local_visit_id': localVisitId,
      },
      initialDelay: const Duration(seconds: 4),
      constraints: Constraints(networkType: NetworkType.connected),
      
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(seconds: 10),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }
}


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final api = ApiService();
    final db = DatabaseService.instance;
    try {
      if (task == kPeriodicSyncTaskName) {
        await SyncEngine.runFullSyncPass();
        return true;
      }

      if (task.startsWith(kJobPollTaskPrefix)) {
        final rawJobId = inputData?['job_id'];
        final rawLocalVisitId = inputData?['local_visit_id'];
        final jobId = int.tryParse(rawJobId?.toString() ?? '') ?? -1;
        final localVisitId = rawLocalVisitId?.toString() ?? '';
        if (jobId <= 0 || localVisitId.isEmpty) return true; // malformed, drop it

        final isTerminal = await SyncEngine.pollJobOnce(
          localVisitId,
          jobId,
          api: api,
          db: db,
        );
     
        return isTerminal;
      }

      return true;
    } catch (_) {
      
      return false;
    } finally {
      api.dispose();
    }
  });
}
