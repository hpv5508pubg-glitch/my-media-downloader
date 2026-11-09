import 'package:isar_community/isar.dart';

part 'download_task_schema.g.dart';

@collection
class DownloadTask {
  Id id = Isar.autoIncrement;

  /// Unique UUID job_id from Backend /api/download-job
  @Index(unique: true)
  late String jobId;

  late String videoId;
  late String url;
  late String title;
  late String artist;
  late String formatId;
  late String ext;

  /// Progress percentage: 0.0 to 100.0
  late double progress;

  /// Status: 'queued', 'running', 'completed', 'failed', 'cancelled'
  late String status;

  /// Step: 'downloading', 'converting', 'completed', 'cancelled'
  late String step;

  /// Concurrency Priority: Higher integer value gets processed first
  /// 'Ưu tiên tải ngay' increments this priority to bump to the head of the queue.
  late int priority;

  /// Error message if status == 'failed'
  String? error;

  /// Final saved path in Scoped Storage (/Music)
  String? destinationPath;

  late DateTime createdAt;
  late DateTime updatedAt;
}
