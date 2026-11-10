import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/isar_database.dart';
import '../../../data/local/schemas/playlist_schema.dart';
import '../../../data/local/schemas/track_schema.dart';
import '../../player/providers/audio_player_provider.dart';
import '../../tag_editor/screens/tag_editor_screen.dart';
import '../utils/vietnamese_fuzzy_search.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final IsarDatabase _db = IsarDatabase.instance;

  List<Track> _downloadedTracks = [];
  List<Track> _deviceTracks = [];
  List<Playlist> _playlists = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadDownloadedTracks(),
      _loadDeviceTracks(),
      _loadPlaylists(),
    ]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadDownloadedTracks() async {
    final tracks = await _db.getAllTracks();
    if (!mounted) return;
    setState(() => _downloadedTracks = tracks);
  }

  Future<void> _loadDeviceTracks() async {
    final List<Track> localTracks = [];
    try {
      final musicDir = Directory(AppConstants.scopedMusicDirectory);
      if (await musicDir.exists()) {
        final files = await musicDir.list().toList();
        for (final entity in files) {
          if (entity is File) {
            final ext = entity.path.split('.').last.toLowerCase();
            if (ext == 'mp3' || ext == 'm4a' || ext == 'mp4') {
              final filename = entity.uri.pathSegments.last;
              final nameWithoutExt = filename.substring(0, filename.lastIndexOf('.'));
              localTracks.add(
                Track()
                  ..videoId = 'device_${entity.path.hashCode}'
                  ..title = nameWithoutExt
                  ..artist = 'Thiết bị'
                  ..album = 'Nhạc thiết bị'
                  ..filePath = entity.path
                  ..duration = 0
                  ..filesizeBytes = await entity.length()
                  ..ext = ext
                  ..isFavorite = false
                  ..addedAt = DateTime.now(),
              );
            }
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() => _deviceTracks = localTracks);
  }

  Future<void> _loadPlaylists() async {
    final playlists = await _db.getAllPlaylists();
    if (!mounted) return;
    setState(() => _playlists = playlists);
  }

  void _createPlaylistDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Tạo Playlist mới', style: TextStyle(color: AppTheme.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(hintText: 'Tên Playlist...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await _db.createPlaylist(name);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  await _loadPlaylists();
                }
              },
              child: const Text('Tạo'),
            ),
          ],
        );
      },
    );
  }

  void _showTrackOptions(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add, color: AppTheme.neonGreen),
                title: const Text('Thêm vào Playlist', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _addToPlaylistSheet(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note, color: AppTheme.neonGreen),
                title: const Text('Sửa ID3 Tags & Ảnh bìa', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TagEditorScreen(track: track),
                    ),
                  ).then((_) => _loadDownloadedTracks());
                },
              ),
              ListTile(
                leading: Icon(
                  track.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: AppTheme.neonGreen,
                ),
                title: Text(
                  track.isFavorite ? 'Bỏ yêu thích' : 'Thêm vào Yêu thích',
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _db.toggleFavorite(track.id);
                  if (!mounted) return;
                  await _loadDownloadedTracks();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                title: const Text('Xóa khỏi thư viện', style: TextStyle(color: AppTheme.errorRed)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _db.deleteTrack(track.id);
                  if (!mounted) return;
                  await _loadDownloadedTracks();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _addToPlaylistSheet(Track track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn Playlist',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (_playlists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Chưa có playlist nào. Hãy tạo mới!'),
                  ),
                )
              else
                ..._playlists.map((playlist) {
                  return ListTile(
                    leading: const Icon(Icons.queue_music, color: AppTheme.neonGreen),
                    title: Text(playlist.name, style: const TextStyle(color: AppTheme.textPrimary)),
                    subtitle: Text('${playlist.trackVideoIds.length} bài', style: const TextStyle(color: AppTheme.textMuted)),
                    onTap: () async {
                      await _db.addTrackToPlaylist(playlist.id, track.videoId);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã thêm vào "${playlist.name}"'), backgroundColor: AppTheme.neonGreen),
                      );
                      await _loadPlaylists();
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thư viện'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Tạo Playlist',
            onPressed: _createPlaylistDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadAll,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(98),
          child: Column(
            children: [
              // Vietnamese Fuzzy Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm không dấu (VD: "noi nay co anh")...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.neonGreen),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.neonGreen,
                labelColor: AppTheme.neonGreen,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: [
                  Tab(text: 'Tải về (${_downloadedTracks.length})'),
                  Tab(text: 'Thiết bị (${_deviceTracks.length})'),
                  Tab(text: 'Playlists (${_playlists.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrackList(_downloadedTracks),
                _buildTrackList(_deviceTracks),
                _buildPlaylistTab(),
              ],
            ),
    );
  }

  Widget _buildTrackList(List<Track> sourceTracks) {
    final filtered = sourceTracks.where((t) {
      final combined = '${t.title} ${t.artist} ${t.album}';
      return VietnameseFuzzySearch.matches(combined, _searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off, size: 56, color: AppTheme.surfaceLight),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isEmpty ? 'Chưa có bài hát nào' : 'Không tìm thấy kết quả phù hợp',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final track = filtered[index];
        final isAudio = track.ext == 'mp3' || track.ext == 'm4a';

        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isAudio ? Icons.music_note : Icons.videocam,
              color: AppTheme.neonGreen,
            ),
          ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${track.artist} • ${track.ext.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  track.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: track.isFavorite ? AppTheme.neonGreen : AppTheme.textMuted,
                  size: 20,
                ),
                onPressed: () async {
                  await _db.toggleFavorite(track.id);
                  if (!mounted) return;
                  await _loadDownloadedTracks();
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary, size: 20),
                onPressed: () => _showTrackOptions(track),
              ),
            ],
          ),
          onTap: () {
            ref.read(audioPlayerProvider.notifier).loadPlaylist(filtered, initialIndex: index);
          },
        );
      },
    );
  }

  Widget _buildPlaylistTab() {
    if (_playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.queue_music, size: 56, color: AppTheme.surfaceLight),
            const SizedBox(height: 12),
            const Text('Chưa có Playlist nào', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createPlaylistDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tạo Playlist'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _playlists.length,
      itemBuilder: (context, index) {
        final playlist = _playlists[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.queue_music, color: AppTheme.neonGreen),
          ),
          title: Text(playlist.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          subtitle: Text('${playlist.trackVideoIds.length} bài hát', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted),
            onPressed: () async {
              await _db.deletePlaylist(playlist.id);
              if (!mounted) return;
              await _loadPlaylists();
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlaylistDetailScreen(playlist: playlist),
              ),
            ).then((_) => _loadAll());
          },
        );
      },
    );
  }
}
