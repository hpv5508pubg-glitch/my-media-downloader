import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'schemas/download_task_schema.dart';
import 'schemas/playlist_schema.dart';
import 'schemas/track_schema.dart';

class IsarDatabase {
  static IsarDatabase? _instance;
  static Isar? _isar;

  IsarDatabase._();

  static IsarDatabase get instance {
    _instance ??= IsarDatabase._();
    return _instance!;
  }

  Isar get isar {
    if (_isar == null || !_isar!.isOpen) {
      throw StateError('IsarDatabase has not been initialized. Call init() first.');
    }
    return _isar!;
  }

  /// Initialize the Isar database with schemas
  Future<void> init({String? customDir}) async {
    if (_isar != null && _isar!.isOpen) return;

    final dir = customDir ?? (await getApplicationDocumentsDirectory()).path;
    _isar = await Isar.open(
      [
        TrackSchema,
        PlaylistSchema,
        DownloadTaskSchema,
      ],
      directory: dir,
      inspector: false,
    );
  }

  // ---------------------------------------------------------------------------
  // TRACK QUERIES (Identification, Offline Library, Favorites)
  // ---------------------------------------------------------------------------

  /// Checks if a media item is already saved locally by videoId.
  /// Used in Search/Ingestion to display the green [Đã có trong máy] badge.
  Future<bool> isTrackDownloaded(String videoId) async {
    final count = await isar.tracks.filter().videoIdEqualTo(videoId).count();
    return count > 0;
  }

  /// Batch check multiple video IDs against Isar local tracks.
  Future<Set<String>> getDownloadedVideoIds(List<String> videoIds) async {
    if (videoIds.isEmpty) return <String>{};
    final matchingTracks = await isar.tracks
        .filter()
        .anyOf(videoIds, (q, String id) => q.videoIdEqualTo(id))
        .findAll();
    return matchingTracks.map((t) => t.videoId).toSet();
  }

  /// Save or update a track record
  Future<void> saveTrack(Track track) async {
    await isar.writeTxn(() async {
      await isar.tracks.put(track);
    });
  }

  /// Fetch all tracks ordered by addedAt descending
  Future<List<Track>> getAllTracks() async {
    return await isar.tracks.where().sortByAddedAtDesc().findAll();
  }

  /// Retrieve a specific track by unique videoId
  Future<Track?> getTrackByVideoId(String videoId) async {
    return await isar.tracks.filter().videoIdEqualTo(videoId).findFirst();
  }

  /// Delete a track record from database
  Future<void> deleteTrack(int id) async {
    await isar.writeTxn(() async {
      await isar.tracks.delete(id);
    });
  }

  /// Toggle track favorite status
  Future<void> toggleFavorite(int trackId) async {
    await isar.writeTxn(() async {
      final track = await isar.tracks.get(trackId);
      if (track != null) {
        track.isFavorite = !track.isFavorite;
        await isar.tracks.put(track);
      }
    });
  }

  /// Retrieve all favorite tracks
  Future<List<Track>> getFavoriteTracks() async {
    return await isar.tracks.filter().isFavoriteEqualTo(true).sortByAddedAtDesc().findAll();
  }

  // ---------------------------------------------------------------------------
  // PLAYLIST MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Retrieve all playlists
  Future<List<Playlist>> getAllPlaylists() async {
    return await isar.playlists.where().sortByCreatedAtDesc().findAll();
  }

  /// Create a new playlist
  Future<Playlist> createPlaylist(String name) async {
    final playlist = Playlist()
      ..name = name.trim()
      ..createdAt = DateTime.now()
      ..trackVideoIds = [];

    await isar.writeTxn(() async {
      await isar.playlists.put(playlist);
    });
    return playlist;
  }

  /// Delete a playlist
  Future<void> deletePlaylist(int id) async {
    await isar.writeTxn(() async {
      await isar.playlists.delete(id);
    });
  }

  /// Add a videoId to playlist track list
  Future<void> addTrackToPlaylist(int playlistId, String videoId) async {
    await isar.writeTxn(() async {
      final playlist = await isar.playlists.get(playlistId);
      if (playlist != null && !playlist.trackVideoIds.contains(videoId)) {
        final updatedIds = List<String>.from(playlist.trackVideoIds)..add(videoId);
        playlist.trackVideoIds = updatedIds;
        await isar.playlists.put(playlist);
      }
    });
  }

  /// Remove a videoId from playlist track list
  Future<void> removeTrackFromPlaylist(int playlistId, String videoId) async {
    await isar.writeTxn(() async {
      final playlist = await isar.playlists.get(playlistId);
      if (playlist != null && playlist.trackVideoIds.contains(videoId)) {
        final updatedIds = List<String>.from(playlist.trackVideoIds)..remove(videoId);
        playlist.trackVideoIds = updatedIds;
        await isar.playlists.put(playlist);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD QUEUE PERSISTENCE
  // ---------------------------------------------------------------------------

  /// Save or update a download task
  Future<void> saveDownloadTask(DownloadTask task) async {
    task.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.downloadTasks.put(task);
    });
  }

  /// Get download task by its backend jobId
  Future<DownloadTask?> getDownloadTaskByJobId(String jobId) async {
    return await isar.downloadTasks.filter().jobIdEqualTo(jobId).findFirst();
  }

  /// Get all download tasks sorted by priority (high to low) and createdAt
  Future<List<DownloadTask>> getAllDownloadTasks() async {
    return await isar.downloadTasks
        .where()
        .sortByPriorityDesc()
        .thenByCreatedAt()
        .findAll();
  }

  /// Retrieve pending tasks (queued or running)
  Future<List<DownloadTask>> getPendingDownloadTasks() async {
    return await isar.downloadTasks
        .filter()
        .statusEqualTo('queued')
        .or()
        .statusEqualTo('running')
        .sortByPriorityDesc()
        .thenByCreatedAt()
        .findAll();
  }

  /// Update progress and step for an active task
  Future<void> updateDownloadTaskProgress(
    String jobId,
    double progress,
    String step,
  ) async {
    await isar.writeTxn(() async {
      final task = await isar.downloadTasks.filter().jobIdEqualTo(jobId).findFirst();
      if (task != null) {
        task.progress = progress;
        task.step = step;
        task.updatedAt = DateTime.now();
        await isar.downloadTasks.put(task);
      }
    });
  }

  /// Mark download task as successfully completed
  Future<void> markDownloadTaskCompleted(
    String jobId,
    String destinationPath,
  ) async {
    await isar.writeTxn(() async {
      final task = await isar.downloadTasks.filter().jobIdEqualTo(jobId).findFirst();
      if (task != null) {
        task.status = 'completed';
        task.step = 'completed';
        task.progress = 100.0;
        task.destinationPath = destinationPath;
        task.updatedAt = DateTime.now();
        await isar.downloadTasks.put(task);
      }
    });
  }

  /// Mark download task as failed with error description
  Future<void> markDownloadTaskFailed(String jobId, String error) async {
    await isar.writeTxn(() async {
      final task = await isar.downloadTasks.filter().jobIdEqualTo(jobId).findFirst();
      if (task != null) {
        task.status = 'failed';
        task.error = error;
        task.updatedAt = DateTime.now();
        await isar.downloadTasks.put(task);
      }
    });
  }

  /// Elevate task priority ('Ưu tiên tải ngay') to push task to top of queue
  Future<void> elevateTaskPriority(String jobId) async {
    await isar.writeTxn(() async {
      final highestPriorityTask =
          await isar.downloadTasks.where().sortByPriorityDesc().findFirst();
      final currentMaxPriority = highestPriorityTask?.priority ?? 0;

      final targetTask =
          await isar.downloadTasks.filter().jobIdEqualTo(jobId).findFirst();
      if (targetTask != null) {
        targetTask.priority = currentMaxPriority + 1;
        targetTask.updatedAt = DateTime.now();
        await isar.downloadTasks.put(targetTask);
      }
    });
  }

  /// Delete a download task from database
  Future<void> deleteDownloadTask(String jobId) async {
    await isar.writeTxn(() async {
      await isar.downloadTasks.filter().jobIdEqualTo(jobId).deleteAll();
    });
  }

  /// Purge all completed or cancelled tasks
  Future<void> clearCompletedTasks() async {
    await isar.writeTxn(() async {
      await isar.downloadTasks
          .filter()
          .statusEqualTo('completed')
          .or()
          .statusEqualTo('cancelled')
          .deleteAll();
    });
  }
}
