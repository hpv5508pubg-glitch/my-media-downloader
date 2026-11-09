import 'package:json_annotation/json_annotation.dart';

part 'job_status.g.dart';

@JsonSerializable()
class JobStatus {
  @JsonKey(name: 'job_id')
  final String jobId;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'progress')
  final double progress;

  @JsonKey(name: 'step')
  final String step;

  @JsonKey(name: 'filename')
  final String? filename;

  @JsonKey(name: 'filesize_bytes')
  final int filesizeBytes;

  @JsonKey(name: 'error')
  final String? error;

  const JobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.step,
    this.filename,
    required this.filesizeBytes,
    this.error,
  });

  factory JobStatus.fromJson(Map<String, dynamic> json) {
    return JobStatus(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      step: json['step'] as String? ?? 'downloading',
      filename: json['filename'] as String?,
      filesizeBytes: (json['filesize_bytes'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => _$JobStatusToJson(this);

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isProcessing =>
      status == 'processing' || status == 'downloading' || status == 'converting';

  String get progressPercentageFormatted => '${progress.toStringAsFixed(1)}%';

  JobStatus copyWith({
    String? jobId,
    String? status,
    double? progress,
    String? step,
    String? filename,
    int? filesizeBytes,
    String? error,
  }) {
    return JobStatus(
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      step: step ?? this.step,
      filename: filename ?? this.filename,
      filesizeBytes: filesizeBytes ?? this.filesizeBytes,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'JobStatus(jobId: $jobId, status: $status, progress: $progress%, step: $step, filename: $filename, error: $error)';
}
