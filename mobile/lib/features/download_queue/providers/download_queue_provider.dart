import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/isar_database.dart';
import '../../../data/local/schemas/download_task_schema.dart';
import '../models/active_download_state.dart';
import '../services/download_queue_manager.dart';

class DownloadQueueState {
  final List<DownloadTask> pendingTasks;
  final List<DownloadTask> completedTasks;
  final Map<String, ActiveDownloadState> activeStates;
  final bool isLoading;

  const DownloadQueueState({
    this.pendingTasks = const [],
    this.completedTasks = const [],
    this.activeStates = const {},
    this.isLoading = false,
  });

  DownloadQueueState copyWith({
    List<DownloadTask>? pendingTasks,
    List<DownloadTask>? completedTasks,
    Map<String, ActiveDownloadState>? activeStates,
    bool? isLoading,
  }) {
    return DownloadQueueState(
      pendingTasks: pendingTasks ?? this.pendingTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      activeStates: activeStates ?? this.activeStates,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class DownloadQueueNotifier extends StateNotifier<DownloadQueueState> {
  final DownloadQueueManager _manager = DownloadQueueManager.instance;
  final IsarDatabase _db = IsarDatabase.instance;
  StreamSubscription? _progressSubscription;

  DownloadQueueNotifier() : super(const DownloadQueueState()) {
    _init();
  }

  void _init() {
    _loadTasks();

    _progressSubscription = _manager.progressStream.listen((activeMap) {
      if (!mounted) return;
      state = state.copyWith(activeStates: activeMap);
      _loadTasks();
    });
  }

  Future<void> _loadTasks() async {
    try {
      final allTasks = await _db.getAllDownloadTasks();
      if (!mounted) return;

      final pending = allTasks
          .where((t) => t.status == 'queued' || t.status == 'running')
          .toList();
      final completed = allTasks
          .where((t) => t.status == 'completed' || t.status == 'failed' || t.status == 'cancelled')
          .toList();

      state = state.copyWith(
        pendingTasks: pending,
        completedTasks: completed,
      );
    } catch (_) {}
  }

  /// Enqueue a new download request
  Future<String> enqueue({
    required String videoId,
    required String url,
    required String title,
    required String artist,
    required String formatId,
    required String ext,
    int priority = 0,
  }) async {
    final jobId = await _manager.enqueue(
      videoId: videoId,
      url: url,
      title: title,
      artist: artist,
      formatId: formatId,
      ext: ext,
      priority: priority,
    );
    if (!mounted) return jobId;
    await _loadTasks();
    return jobId;
  }

  /// 'Ưu tiên tải ngay' pushes task ahead in the queue
  Future<void> elevatePriority(String jobId) async {
    await _manager.elevatePriority(jobId);
    if (!mounted) return;
    await _loadTasks();
  }

  /// Two-way cancel task
  Future<void> cancel(String jobId) async {
    await _manager.cancelDownload(jobId);
    if (!mounted) return;
    await _loadTasks();
  }

  /// Clear finished/cancelled tasks history
  Future<void> clearCompleted() async {
    await _db.clearCompletedTasks();
    if (!mounted) return;
    await _loadTasks();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}

final downloadQueueProvider =
    StateNotifierProvider<DownloadQueueNotifier, DownloadQueueState>((ref) {
  return DownloadQueueNotifier();
});
