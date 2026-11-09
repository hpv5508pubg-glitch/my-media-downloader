import 'package:json_annotation/json_annotation.dart';
import 'format_item.dart';

part 'video_item.g.dart';

@JsonSerializable(explicitToJson: true)
class VideoItem {
  @JsonKey(name: 'video_id')
  final String videoId;

  @JsonKey(name: 'url')
  final String url;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'uploader')
  final String uploader;

  @JsonKey(name: 'duration')
  final int duration;

  @JsonKey(name: 'thumbnail')
  final String thumbnail;

  @JsonKey(name: 'formats')
  final List<FormatItem> formats;

  const VideoItem({
    required this.videoId,
    required this.url,
    required this.title,
    required this.uploader,
    required this.duration,
    required this.thumbnail,
    required this.formats,
  });

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
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
  }

  Map<String, dynamic> toJson() => _$VideoItemToJson(this);

  /// Helper: Formats duration in seconds into 'mm:ss' or 'hh:mm:ss'
  String get durationFormatted {
    if (duration <= 0) return '00:00';
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Convenience: Find default 320kbps MP3 format or fallback to first audio format
  FormatItem? get defaultAudioFormat {
    for (final f in formats) {
      if (f.formatId == 'mp3_320') return f;
    }
    for (final f in formats) {
      if (f.type == 'audio') return f;
    }
    return formats.isNotEmpty ? formats.first : null;
  }

  /// Convenience: Find default 1080p MP4 format or fallback to first video format
  FormatItem? get defaultVideoFormat {
    for (final f in formats) {
      if (f.formatId == 'mp4_1080') return f;
    }
    for (final f in formats) {
      if (f.type == 'video') return f;
    }
    return null;
  }

  VideoItem copyWith({
    String? videoId,
    String? url,
    String? title,
    String? uploader,
    int? duration,
    String? thumbnail,
    List<FormatItem>? formats,
  }) {
    return VideoItem(
      videoId: videoId ?? this.videoId,
      url: url ?? this.url,
      title: title ?? this.title,
      uploader: uploader ?? this.uploader,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      formats: formats ?? this.formats,
    );
  }

  @override
  String toString() =>
      'VideoItem(videoId: $videoId, title: $title, uploader: $uploader, duration: $duration)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoItem &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId;

  @override
  int get hashCode => videoId.hashCode;
}
