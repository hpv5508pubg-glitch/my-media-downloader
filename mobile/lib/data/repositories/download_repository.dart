import '../../core/api/api_client.dart';
import '../local/isar_database.dart';
import '../local/schemas/download_task_schema.dart';
import '../models/job_status.dart';

class DownloadRepository {
  final ApiClient _apiClient;
  final IsarDatabase _db;

  DownloadRepository({
    ApiClient? apiClient,
    IsarDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? IsarDatabase.instance;

  /// Start a download job on backend, persist to Isar queue
  Future<DownloadTask> enqueueDownload({
    required String videoId,
    required String url,
    required String title,
    required String artist,
    required String formatId,
    required String ext,
    int priority = 0,
  }) async {
    // 1. Call backend POST /api/download-job
    final jobId = await _apiClient.createDownloadJob(
      url: url,
      formatId: formatId,
      customTitle: title,
      customArtist: artist,
    );

    // 2. Persist to local database
    final task = DownloadTask()
      ..jobId = jobId
      ..videoId = videoId
      ..url = url
      ..title = title
      ..artist = artist
      ..formatId = formatId
      ..ext = ext
      ..progress = 0.0
      ..status = 'queued'
      ..step = 'downloading'
      ..priority = priority
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();

    await _db.saveDownloadTask(task);
    return task;
  }

  /// Poll progress of a specific job from server
  Future<JobStatus> pollJobStatus(String jobId) async {
    return await _apiClient.getJobStatus(jobId);
  }

  /// Cancel a job both on the server (DELETE /api/job) and in the local DB
  Future<bool> cancelDownload(String jobId) async {
    final serverCancelled = await _apiClient.cancelJob(jobId);
    await _db.updateDownloadTaskProgress(jobId, 0.0, 'cancelled');

    final task = await _db.getDownloadTaskByJobId(jobId);
    if (task != null) {
      task.status = 'cancelled';
      await _db.saveDownloadTask(task);
    }

    return serverCancelled;
  }

  /// Boost task priority ('Ưu tiên tải ngay')
  Future<void> elevatePriority(String jobId) async {
    await _db.elevateTaskPriority(jobId);
  }

  /// Get pending download tasks ordered by priority
  Future<List<DownloadTask>> getPendingTasks() async {
    return await _db.getPendingDownloadTasks();
  }

  /// Get all download tasks in history
  Future<List<DownloadTask>> getAllTasks() async {
    return await _db.getAllDownloadTasks();
  }

  /// Update local progress
  Future<void> updateProgress(String jobId, double progress, String step) async {
    await _db.updateDownloadTaskProgress(jobId, progress, step);
  }

  /// Mark completed
  Future<void> markCompleted(String jobId, String path) async {
    await _db.markDownloadTaskCompleted(jobId, path);
  }

  /// Mark failed
  Future<void> markFailed(String jobId, String error) async {
    await _db.markDownloadTaskFailed(jobId, error);
  }
}
