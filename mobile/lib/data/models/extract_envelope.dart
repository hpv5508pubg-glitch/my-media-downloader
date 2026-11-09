import 'package:json_annotation/json_annotation.dart';
import 'video_item.dart';

part 'extract_envelope.g.dart';

@JsonSerializable(explicitToJson: true)
class ExtractEnvelope {
  @JsonKey(name: 'result_type')
  final String resultType;

  @JsonKey(name: 'playlist_title')
  final String? playlistTitle;

  @JsonKey(name: 'items')
  final List<VideoItem> items;

  const ExtractEnvelope({
    required this.resultType,
    this.playlistTitle,
    required this.items,
  });

  factory ExtractEnvelope.fromJson(Map<String, dynamic> json) {
    return ExtractEnvelope(
      resultType: json['result_type'] as String? ?? 'single',
      playlistTitle: json['playlist_title'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => _$ExtractEnvelopeToJson(this);

  bool get isSingle => resultType == 'single';
  bool get isPlaylist => resultType == 'playlist';
  bool get isSearch => resultType == 'search';
  bool get isEmpty => items.isEmpty;
  int get count => items.length;

  ExtractEnvelope copyWith({
    String? resultType,
    String? playlistTitle,
    List<VideoItem>? items,
  }) {
    return ExtractEnvelope(
      resultType: resultType ?? this.resultType,
      playlistTitle: playlistTitle ?? this.playlistTitle,
      items: items ?? this.items,
    );
  }

  @override
  String toString() =>
      'ExtractEnvelope(resultType: $resultType, playlistTitle: $playlistTitle, itemsCount: ${items.length})';
}
