// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'format_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FormatItem _$FormatItemFromJson(Map<String, dynamic> json) => FormatItem(
      formatId: json['format_id'] as String? ?? '',
      type: json['type'] as String? ?? 'audio',
      quality: json['quality'] as String? ?? '',
      ext: json['ext'] as String? ?? 'mp3',
      filesizeMb: (json['filesize_mb'] as num?)?.toDouble() ?? 0.0,
      needsFfmpeg: json['needs_ffmpeg'] as bool? ?? false,
    );

Map<String, dynamic> _$FormatItemToJson(FormatItem instance) =>
    <String, dynamic>{
      'format_id': instance.formatId,
      'type': instance.type,
      'quality': instance.quality,
      'ext': instance.ext,
      'filesize_mb': instance.filesizeMb,
      'needs_ffmpeg': instance.needsFfmpeg,
    };
