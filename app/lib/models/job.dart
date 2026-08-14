/// Mirrors the three possible shapes get_job_status can return:
/// VisitJobPending, VisitJobDone, VisitJobFailed.
enum JobStatus { pending, done, failed, unknown }

class VisitJob {
  final int jobId;
  final JobStatus status;
  final double? distance; // only present when status == done
  final String? error; // only present when status == failed

  VisitJob({
    required this.jobId,
    required this.status,
    this.distance,
    this.error,
  });

  factory VisitJob.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? '').toString();
    JobStatus status;
    switch (rawStatus) {
      case 'pending':
        status = JobStatus.pending;
        break;
      case 'done':
        status = JobStatus.done;
        break;
      case 'failed':
        status = JobStatus.failed;
        break;
      default:
        status = JobStatus.unknown;
    }
    return VisitJob(
      jobId: json['job_id'] is int
          ? json['job_id']
          : int.tryParse('${json['job_id']}') ?? -1,
      status: status,
      distance: json['distance'] == null
          ? null
          : double.tryParse('${json['distance']}'),
      error: json['error']?.toString(),
    );
  }
}
