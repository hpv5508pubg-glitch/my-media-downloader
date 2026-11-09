// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_status.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JobStatus _$JobStatusFromJson(Map<String, dynamic> json) => JobStatus(
      jobId: json['job_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      step: json['step'] as String? ?? 'downloading',
      filename: json['filename'] as String?,
      filesizeBytes: (json['filesize_bytes'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );

Map<String, dynamic> _$JobStatusToJson(JobStatus instance) => <String, dynamic>{
      'job_id': instance.jobId,
      'status': instance.status,
      'progress': instance.progress,
      'step': instance.step,
      'filename': instance.filename,
      'filesize_bytes': instance.filesizeBytes,
      'error': instance.error,
    };
