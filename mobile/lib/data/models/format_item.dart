import 'package:json_annotation/json_annotation.dart';

part 'format_item.g.dart';

@JsonSerializable()
class FormatItem {
  @JsonKey(name: 'format_id')
  final String formatId;

  @JsonKey(name: 'type')
  final String type;

  @JsonKey(name: 'quality')
  final String quality;

  @JsonKey(name: 'ext')
  final String ext;

  @JsonKey(name: 'filesize_mb')
  final double filesizeMb;

  @JsonKey(name: 'needs_ffmpeg')
  final bool needsFfmpeg;

  const FormatItem({
    required this.formatId,
    required this.type,
    required this.quality,
    required this.ext,
    required this.filesizeMb,
    required this.needsFfmpeg,
  });

  factory FormatItem.fromJson(Map<String, dynamic> json) {
    return FormatItem(
      formatId: json['format_id'] as String? ?? '',
      type: json['type'] as String? ?? 'audio',
      quality: json['quality'] as String? ?? '',
      ext: json['ext'] as String? ?? 'mp3',
      filesizeMb: (json['filesize_mb'] as num?)?.toDouble() ?? 0.0,
      needs_ffmpeg: json['needs_ffmpeg'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => _$FormatItemToJson(this);

  FormatItem copyWith({
    String? formatId,
    String? type,
    String? quality,
    String? ext,
    double? filesizeMb,
    bool? needsFfmpeg,
  }) {
    return FormatItem(
      formatId: formatId ?? this.formatId,
      type: type ?? this.type,
      quality: quality ?? this.quality,
      ext: ext ?? this.ext,
      filesizeMb: filesizeMb ?? this.filesizeMb,
      needsFfmpeg: needsFfmpeg ?? this.needsFfmpeg,
    );
  }

  @override
  String toString() =>
      'FormatItem(formatId: $formatId, type: $type, quality: $quality, ext: $ext, filesizeMb: $filesizeMb, needsFfmpeg: $needsFfmpeg)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormatItem &&
          runtimeType == other.runtimeType &&
          formatId == other.formatId &&
          type == other.type &&
          quality == other.quality &&
          ext == other.ext &&
          filesizeMb == other.filesizeMb &&
          needsFfmpeg == other.needsFfmpeg;

  @override
  int get hashCode =>
      formatId.hashCode ^
      type.hashCode ^
      quality.hashCode ^
      ext.hashCode ^
      filesizeMb.hashCode ^
      needsFfmpeg.hashCode;
}
