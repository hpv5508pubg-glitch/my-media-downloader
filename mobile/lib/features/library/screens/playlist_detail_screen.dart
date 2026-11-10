import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/isar_database.dart';
import '../../../data/local/schemas/playlist_schema.dart';
import '../../../data/local/schemas/track_schema.dart';
import '../../player/providers/audio_player_provider.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final IsarDatabase _db = IsarDatabase.instance;
  List<Track> _tracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaylistTracks();
  }

  Future<void> _loadPlaylistTracks() async {
    setState(() => _isLoading = true);
    final allTracks = await _db.getAllTracks();
    final matchedTracks = <Track>[];

    for (final videoId in widget.playlist.trackVideoIds) {
      for (final t in allTracks) {
        if (t.videoId == videoId) {
          matchedTracks.add(t);
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _tracks = matchedTracks;
      _isLoading = false;
    });
  }

  void _removeTrack(String videoId) async {
    await _db.removeTrackFromPlaylist(widget.playlist.id, videoId);
    if (!mounted) return;
    await _loadPlaylistTracks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.name),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : _tracks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.music_off, size: 56, color: AppTheme.surfaceLight),
                      const SizedBox(height: 12),
                      const Text(
                        'Playlist này chưa có bài hát nào.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Thêm bài từ Thư viện > [3 chấm] > Thêm vào Playlist',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: AppTheme.surfaceDark,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_tracks.length} bài hát',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              ref.read(audioPlayerProvider.notifier).loadPlaylist(_tracks);
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Phát tất cả'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonGreen,
                              foregroundColor: AppTheme.pureBlack,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final track = _tracks[index];
                          return ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.music_note, color: AppTheme.neonGreen),
                            ),
                            title: Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              track.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed),
                              onPressed: () => _removeTrack(track.videoId),
                            ),
                            onTap: () {
                              ref.read(audioPlayerProvider.notifier).loadPlaylist(_tracks, initialIndex: index);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
