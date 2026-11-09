import '../../core/api/api_client.dart';
import '../local/isar_database.dart';
import '../local/schemas/track_schema.dart';
import '../models/extract_envelope.dart';
import '../models/video_item.dart';

class MediaRepository {
  final ApiClient _apiClient;
  final IsarDatabase _db;

  MediaRepository({
    ApiClient? apiClient,
    IsarDatabase? db,
  })  : _apiClient = apiClient ?? ApiClient(),
        _db = db ?? IsarDatabase.instance;

  /// Extract media from remote server via API
  Future<ExtractEnvelope> extractMedia(String query) async {
    return await _apiClient.extractMedia(query);
  }

  /// Check if a single videoId is already downloaded locally in Isar
  Future<bool> isTrackDownloaded(String videoId) async {
    return await _db.isTrackDownloaded(videoId);
  }

  /// Batch check which videoIds from a list are already present in Isar DB
  Future<Set<String>> getDownloadedVideoIds(List<String> videoIds) async {
    return await _db.getDownloadedVideoIds(videoIds);
  }

  /// Retrieve all tracks in the local library
  Future<List<Track>> getAllTracks() async {
    return await _db.getAllTracks();
  }

  /// Retrieve all favorite tracks
  Future<List<Track>> getFavoriteTracks() async {
    return await _db.getFavoriteTracks();
  }

  /// Toggle favorite status of a local track
  Future<void> toggleFavorite(int trackId) async {
    await _db.toggleFavorite(trackId);
  }

  /// Delete track from local library
  Future<void> deleteTrack(int trackId) async {
    await _db.deleteTrack(trackId);
  }
}
