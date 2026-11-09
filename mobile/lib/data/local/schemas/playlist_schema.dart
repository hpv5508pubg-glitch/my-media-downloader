import 'package:isar_community/isar.dart';

part 'playlist_schema.g.dart';

@collection
class Playlist {
  Id id = Isar.autoIncrement;

  /// Unique playlist name
  @Index(unique: true)
  late String name;

  late DateTime createdAt;

  /// Ordered list of Track videoIds contained in this playlist
  late List<String> trackVideoIds;
}
