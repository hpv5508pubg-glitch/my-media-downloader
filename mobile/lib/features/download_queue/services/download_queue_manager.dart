import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/local/isar_database.dart';
import '../../../data/local/schemas/download_task_schema.dart';
import '../../../data/local/schemas/track_schema.dart';
import '../models/active_download_state.dart';
import 'notification_service.dart';

class DownloadQueueManager {
  static final DownloadQueueManager instance = DownloadQueueManager._();
  DownloadQueueManager._();

  final ApiClient _apiClient = ApiClient();
  final IsarDatabase _db = IsarDatabase.instance;
  final NotificationService _notifications = NotificationService.instance;
  final MediaStore _mediaStore = MediaStore();

  /// Map of actively running tasks by jobId
  final Map<String, CancelToken> _cancelTokens = {};

  /// Real-time download progress tracking states
  final Map<String, ActiveDownloadState> _activeStates = {};

  /// Controller for queue state updates broadcast to Riverpod listeners
  final StreamController<Map<String, ActiveDownloadState>> _progressController =
      StreamController<Map<String, ActiveDownloadState>>.broadcast();

  Stream<Map<String, ActiveDownloadState>> get progressStream =>
      _progressController.stream;

  Map<String, ActiveDownloadState> get activeStates =>
      Map.unmodifiable(_activeStates);

  bool _isProcessing = false;
  bool _wakelockEnabled = false;

  /// Initialize dependencies
  Future<void> init() async {
    await _notifications.init();
    try {
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'Music';
    } catch (_) {}

    // Resume any pending tasks that were interrupted
    await _processQueue();
  }

  /// Add a new download task into the persistent Isar queue
  Future<String> enqueue({
    required String videoId,
    required String url,
    required String title,
    required String artist,
    required String formatId,
    required String ext,
    int priority = 0,
  }) async {
    // 1. Submit download job to server
    final jobId = await _apiClient.createDownloadJob(
      url: url,
      formatId: formatId,
      customTitle: title,
      customArtist: artist,
    );

    // 2. Persist task to local DB
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

    // 3. Process queue
    _processQueue();

    return jobId;
  }

  /// 'Ưu tiên tải ngay': Boost task priority to head of queue
  Future<void> elevatePriority(String jobId) async {
    await _db.elevateTaskPriority(jobId);
    _processQueue();
  }

  /// Two-way cancel: Cancel local Dio stream, call DELETE on server, update DB and cleanup
  Future<void> cancelDownload(String jobId) async {
    // 1. Cancel local HTTP download if active
    if (_cancelTokens.containsKey(jobId)) {
      _cancelTokens[jobId]?.cancel('Cancelled by user');
      _cancelTokens.remove(jobId);
    }

    // 2. Call backend DELETE /api/job/{job_id} to terminate remote yt-dlp & FFmpeg process
    await _apiClient.cancelJob(jobId);

    // 3. Update Isar status to cancelled
    final task = await _db.getDownloadTaskByJobId(jobId);
    if (task != null) {
      task.status = 'cancelled';
      task.step = 'cancelled';
      task.updatedAt = DateTime.now();
      await _db.saveDownloadTask(task);
    }

    // 4. Delete incomplete .download file
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$jobId.download');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    // 5. Cancel notification & clean up memory state
    final notifId = jobId.hashCode.abs() % 100000;
    await _notifications.cancel(notifId);

    _activeStates.remove(jobId);
    _progressController.add(Map.from(_activeStates));

    await _updateWakelock();

    // 6. Trigger next queued task
    _processQueue();
  }

  /// Manage Wakelock based on active running task count
  Future<void> _updateWakelock() async {
    final activeCount = _cancelTokens.length;
    if (activeCount > 0 && !_wakelockEnabled) {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    } else if (activeCount == 0 && _wakelockEnabled) {
      await WakelockPlus.disable();
      _wakelockEnabled = false;
    }
  }

  /// Core queue dispatcher: enforces 3-task concurrency and priority ordering
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      while (_cancelTokens.length < AppConstants.maxConcurrentDownloads) {
        final pendingTasks = await _db.getPendingDownloadTasks();
        final queuedTasks = pendingTasks
            .where((t) => t.status == 'queued' && !_cancelTokens.containsKey(t.jobId))
            .toList();

        if (queuedTasks.isEmpty) break;

        // Take highest priority task
        final taskToRun = queuedTasks.first;
        _startTask(taskToRun);
      }
    } finally {
      _isProcessing = false;
      await _updateWakelock();
    }
  }

  /// Start an individual download worker
  void _startTask(DownloadTask task) {
    final jobId = task.jobId;
    final cancelToken = CancelToken();
    _cancelTokens[jobId] = cancelToken;

    final state = ActiveDownloadState(
      jobId: jobId,
      title: task.title,
      progress: task.progress,
      step: 'processing',
    );
    _activeStates[jobId] = state;
    _progressController.add(Map.from(_activeStates));

    // Run task execution asynchronously
    _executeDownloadPipeline(task, cancelToken).then((_) {
      _cancelTokens.remove(jobId);
      _activeStates.remove(jobId);
      _progressController.add(Map.from(_activeStates));
      _updateWakelock();
      _processQueue();
    }).catchError((err) {
      _cancelTokens.remove(jobId);
      _activeStates.remove(jobId);
      _progressController.add(Map.from(_activeStates));
      _updateWakelock();
      _processQueue();
    });
  }

  /// Executes the 3 phases of media retrieval:
  /// Phase 1: Wait for backend conversion (polling)
  /// Phase 2: Stream media with HTTP Range resume to local .download file
  /// Phase 3: Move to Scoped Storage (/Music) and save Track to Isar
  Future<void> _executeDownloadPipeline(
    DownloadTask task,
    CancelToken cancelToken,
  ) async {
    final jobId = task.jobId;
    final notifId = jobId.hashCode.abs() % 100000;

    // Mark status running in DB
    task.status = 'running';
    task.step = 'downloading';
    task.updatedAt = DateTime.now();
    await _db.saveDownloadTask(task);

    final state = _activeStates[jobId]!;

    try {
      // -----------------------------------------------------------------------
      // PHASE 1: Server Polling until completed
      // -----------------------------------------------------------------------
      String? serverFilename;
      int serverFilesize = 0;

      while (!cancelToken.isCancelled) {
        final statusRes = await _apiClient.getJobStatus(jobId, cancelToken: cancelToken);

        if (statusRes.isFailed) {
          throw Exception(statusRes.error ?? 'Server transcode failed');
        }

        if (statusRes.isCancelled) {
          return;
        }

        if (statusRes.isCompleted) {
          serverFilename = statusRes.filename ?? '${task.title}.${task.ext}';
          serverFilesize = statusRes.filesizeBytes;
          break;
        }

        // Server is processing / downloading
        state.step = statusRes.step;
        state.progress = (statusRes.progress * 0.4); // Server step is 0-40% of total
        _progressController.add(Map.from(_activeStates));

        await _notifications.showDownloadProgress(
          notificationId: notifId,
          title: task.title,
          progress: state.progress,
          speedMbPerSec: 0.0,
          etaFormatted: 'Đang xử lý...',
        );

        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (cancelToken.isCancelled) return;

      // -----------------------------------------------------------------------
      // PHASE 2: Stream file to .download with HTTP Range Resume
      // -----------------------------------------------------------------------
      state.step = 'streaming';
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$jobId.download');

      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      String? rangeHeader;
      if (existingBytes > 0 && serverFilesize > existingBytes) {
        rangeHeader = 'bytes=$existingBytes-';
      } else if (existingBytes >= serverFilesize && serverFilesize > 0) {
        // Already fully downloaded in temp
        existingBytes = serverFilesize;
      }

      if (existingBytes < serverFilesize || serverFilesize == 0) {
        final streamResponse = await _apiClient.getStreamResponse(
          jobId,
          rangeHeader: rangeHeader,
          cancelToken: cancelToken,
        );

        final sink = tempFile.openWrite(
          mode: rangeHeader != null ? FileMode.append : FileMode.write,
        );

        int bytesReceivedSoFar = existingBytes;
        final totalExpectedBytes = serverFilesize > 0 ? serverFilesize : 10000000;

        await for (final chunk in streamResponse.data!.stream) {
          if (cancelToken.isCancelled) {
            await sink.close();
            return;
          }

          sink.add(chunk);
          bytesReceivedSoFar += chunk.length;

          // Record moving average speed and ETA
          state.recordByteProgress(bytesReceivedSoFar, totalExpectedBytes);
          _progressController.add(Map.from(_activeStates));

          // Throttle notification updates
          if (bytesReceivedSoFar % (128 * 1024) < chunk.length) {
            await _notifications.showDownloadProgress(
              notificationId: notifId,
              title: task.title,
              progress: state.progress,
              speedMbPerSec: state.speedMbPerSec,
              etaFormatted: state.etaFormatted,
            );
          }
        }

        await sink.flush();
        await sink.close();
      }

      if (cancelToken.isCancelled) return;

      // -----------------------------------------------------------------------
      // PHASE 3: Persist to Scoped Storage (/Music) via media_store_plus
      // -----------------------------------------------------------------------
      state.step = 'saving';
      state.progress = 100.0;
      _progressController.add(Map.from(_activeStates));

      final finalExt = task.ext.isNotEmpty ? task.ext : 'mp3';
      final isAudio = finalExt == 'mp3' || finalExt == 'm4a';
      final cleanTitle = task.title.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
      final finalFileName = '$cleanTitle.$finalExt';

      String finalSavedPath = '';

      try {
        final saveResult = await _mediaStore.saveFile(
          tempFilePath: tempFile.path,
          dirType: isAudio ? DirType.audio : DirType.video,
          dirName: isAudio ? DirType.audio.defaults : DirType.video.defaults,
          relativePath: 'Music',
        );

        if (saveResult?.isSuccessful == true && saveResult?.uri != null) {
          finalSavedPath = saveResult!.uri.toString();
        } else {
          finalSavedPath = '/storage/emulated/0/Music/$finalFileName';
        }
      } catch (_) {
        // Fallback for non-Android environments / test emulators
        final appDir = await getApplicationDocumentsDirectory();
        final musicFallbackDir = Directory('${appDir.path}/Music');
        await musicFallbackDir.create(parents: true);
        final destinationFile = File('${musicFallbackDir.path}/$finalFileName');
        await tempFile.copy(destinationFile.path);
        finalSavedPath = destinationFile.path;
      }

      // Record completed Track in Isar Database
      final track = Track()
        ..videoId = task.videoId
        ..title = task.title
        ..artist = task.artist
        ..album = 'Downloads'
        ..filePath = finalSavedPath
        ..coverPath = null
        ..duration = 0
        ..filesizeBytes = await tempFile.length()
        ..ext = finalExt
        ..isFavorite = false
        ..addedAt = DateTime.now();

      await _db.saveTrack(track);

      // Clean up temporary .download file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // Mark DownloadTask completed in Isar DB
      await _db.markDownloadTaskCompleted(jobId, finalSavedPath);

      // Show completion notification
      await _notifications.showDownloadComplete(
        notificationId: notifId,
        title: task.title,
        filename: finalFileName,
      );
    } catch (exc) {
      if (cancelToken.isCancelled) return;

      final errorMsg = exc.toString();
      await _db.markDownloadTaskFailed(jobId, errorMsg);
      await _notifications.showDownloadError(
        notificationId: notifId,
        title: task.title,
        error: errorMsg,
      );
    }
  }

  void dispose() {
    _progressController.close();
  }
}
