// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'extract_envelope.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExtractEnvelope _$ExtractEnvelopeFromJson(Map<String, dynamic> json) =>
    ExtractEnvelope(
      resultType: json['result_type'] as String? ?? 'single',
      playlistTitle: json['playlist_title'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$ExtractEnvelopeToJson(ExtractEnvelope instance) =>
    <String, dynamic>{
      'result_type': instance.resultType,
      'playlist_title': instance.playlistTitle,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };
