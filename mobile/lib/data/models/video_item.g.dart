// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VideoItem _$VideoItemFromJson(Map<String, dynamic> json) => VideoItem(
      videoId: json['video_id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      uploader: json['uploader'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      thumbnail: json['thumbnail'] as String? ?? '',
      formats: (json['formats'] as List<dynamic>?)
              ?.map((e) => FormatItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$VideoItemToJson(VideoItem instance) => <String, dynamic>{
      'video_id': instance.videoId,
      'url': instance.url,
      'title': instance.title,
      'uploader': instance.uploader,
      'duration': instance.duration,
      'thumbnail': instance.thumbnail,
      'formats': instance.formats.map((e) => e.toJson()).toList(),
    };
