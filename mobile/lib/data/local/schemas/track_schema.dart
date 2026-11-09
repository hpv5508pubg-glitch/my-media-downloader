import 'package:isar_community/isar.dart';

part 'track_schema.g.dart';

@collection
class Track {
  Id id = Isar.autoIncrement;

  /// Unique Video ID from YouTube, TikTok, Facebook, etc.
  /// Used to check if track is already downloaded.
  @Index(unique: true)
  late String videoId;

  late String title;
  late String artist;
  late String album;

  /// Absolute file path or Scoped Storage URI in /storage/emulated/0/Music
  late String filePath;

  /// Local path to cached 1:1 square cover art
  String? coverPath;

  /// Duration in seconds
  late int duration;

  /// Total file size in bytes
  late int filesizeBytes;

  /// File extension: 'mp3', 'mp4', 'm4a'
  late String ext;

  /// Favorite flag
  late bool isFavorite;

  /// Timestamp when added to local library
  late DateTime addedAt;
}
