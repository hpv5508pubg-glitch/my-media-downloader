import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/isar_database.dart';
import '../../../data/models/extract_envelope.dart';
import '../../../data/models/video_item.dart';
import '../../download_queue/providers/download_queue_provider.dart';
import '../widgets/format_selection_dialog.dart';
import '../widgets/smart_clipboard_sheet.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with WidgetsBindingObserver {
  final TextEditingController _queryController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final IsarDatabase _db = IsarDatabase.instance;

  bool _isLoading = false;
  String? _errorMessage;
  ExtractEnvelope? _resultEnvelope;
  Set<String> _downloadedVideoIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check clipboard on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final detectedUrl = await SmartClipboardManager.checkClipboardForMediaUrl();
    if (!mounted || detectedUrl == null) return;

    SmartClipboardManager.showDetectedLinkSheet(
      context: context,
      url: detectedUrl,
      onConfirmExtract: (url) {
        _queryController.text = url;
        _performExtraction(url);
      },
    );
  }

  Future<void> _performExtraction(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final envelope = await _apiClient.extractMedia(cleanQuery);
      final videoIds = envelope.items.map((i) => i.videoId).toList();
      final downloaded = await _db.getDownloadedVideoIds(videoIds);

      if (!mounted) return;
      setState(() {
        _resultEnvelope = envelope;
        _downloadedVideoIds = downloaded;
        _isLoading = false;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _errorMessage = exc.toString();
        _isLoading = false;
      });
    }
  }

  void _onDownloadItem(VideoItem video) async {
    final result = await showDialog<FormatSelectionResult>(
      context: context,
      builder: (ctx) => FormatSelectionDialog(video: video),
    );

    if (result == null || !mounted) return;

    await ref.read(downloadQueueProvider.notifier).enqueue(
          videoId: video.videoId,
          url: video.url,
          title: video.title,
          artist: video.uploader,
          formatId: result.format.formatId,
          ext: result.format.ext,
          priority: result.isPriority ? 100 : 0,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm "${video.title}" vào hàng đợi tải.'),
        backgroundColor: AppTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onDownloadPlaylist(ExtractEnvelope envelope) {
    final selectedVideoIds = <String>{};

    // Default unchecked for already downloaded videos, checked for new tracks
    for (final item in envelope.items) {
      if (!_downloadedVideoIds.contains(item.videoId)) {
        selectedVideoIds.add(item.videoId);
      }
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          envelope.playlistTitle ?? 'Tải Playlist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(
                    'Đã chọn ${selectedVideoIds.length}/${envelope.items.length} bài hát',
                    style: const TextStyle(color: AppTheme.neonGreen, fontSize: 13),
                  ),
                  const Divider(color: AppTheme.surfaceLight, height: 24),
                  Expanded(
                    child: ListView.builder(
                      itemCount: envelope.items.length,
                      itemBuilder: (context, index) {
                        final item = envelope.items[index];
                        final isAlreadyDownloaded =
                            _downloadedVideoIds.contains(item.videoId);
                        final isChecked = selectedVideoIds.contains(item.videoId);

                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: AppTheme.neonGreen,
                          checkColor: AppTheme.pureBlack,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                item.durationFormatted,
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              if (isAlreadyDownloaded) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.neonGreen.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Đã có',
                                    style: TextStyle(
                                      color: AppTheme.neonGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                selectedVideoIds.add(item.videoId);
                              } else {
                                selectedVideoIds.remove(item.videoId);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedVideoIds.isEmpty
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              _enqueueBatch(
                                envelope.items
                                    .where((i) => selectedVideoIds.contains(i.videoId))
                                    .toList(),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.neonGreen,
                        foregroundColor: AppTheme.pureBlack,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Tải ${selectedVideoIds.length} bài hát đã chọn',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _enqueueBatch(List<VideoItem> items) async {
    for (final item in items) {
      final defaultFormat = item.defaultAudioFormat;
      await ref.read(downloadQueueProvider.notifier).enqueue(
            videoId: item.videoId,
            url: item.url,
            title: item.title,
            artist: item.uploader,
            formatId: defaultFormat?.formatId ?? 'mp3_320',
            ext: defaultFormat?.ext ?? 'mp3',
          );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${items.length} bài vào hàng đợi tải.'),
        backgroundColor: AppTheme.neonGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm & Bóc tách'),
      ),
      body: Column(
        children: [
          // Search & Paste Header Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performExtraction,
                    decoration: InputDecoration(
                      hintText: 'Nhập từ khóa hoặc dán link media...',
                      prefixIcon: const Icon(Icons.search, color: AppTheme.neonGreen),
                      suffixIcon: _queryController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppTheme.textMuted),
                              onPressed: () {
                                _queryController.clear();
                                setState(() {});
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.paste, color: AppTheme.neonGreen),
                              onPressed: () async {
                                final clip =
                                    await Clipboard.getData(Clipboard.kTextPlain);
                                if (clip?.text != null) {
                                  _queryController.text = clip!.text!.trim();
                                  setState(() {});
                                }
                              },
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _performExtraction(_queryController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    foregroundColor: AppTheme.pureBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.pureBlack,
                          ),
                        )
                      : const Text('Tìm', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // Content body
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.neonGreen),
            SizedBox(height: 16),
            Text(
              'Đang bóc tách thông tin media qua server...',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 12),
              Text(
                'Lỗi bóc tách:\n$_errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _performExtraction(_queryController.text),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final envelope = _resultEnvelope;
    if (envelope == null || envelope.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppTheme.surfaceLight),
            const SizedBox(height: 16),
            const Text(
              'Hỗ trợ link YouTube, TikTok, Facebook, SoundCloud\nhoặc tìm kiếm từ khóa bất kỳ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (envelope.isPlaylist)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.playlist_play, color: AppTheme.neonGreen, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        envelope.playlistTitle ?? 'Playlist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${envelope.count} bài hát',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _onDownloadPlaylist(envelope),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Tải cả List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen,
                    foregroundColor: AppTheme.pureBlack,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: envelope.items.length,
            itemBuilder: (context, index) {
              final video = envelope.items[index];
              final isDownloaded = _downloadedVideoIds.contains(video.videoId);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      // Thumbnail with memCacheWidth & memCacheHeight: 150 (chống tràn RAM)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            CachedNetworkImage(
                              imageUrl: video.thumbnail,
                              width: 100,
                              height: 60,
                              fit: BoxFit.cover,
                              memCacheWidth: 150,
                              memCacheHeight: 150,
                              placeholder: (ctx, url) => Container(
                                width: 100,
                                height: 60,
                                color: AppTheme.surfaceLight,
                              ),
                              errorWidget: (ctx, url, err) => Container(
                                width: 100,
                                height: 60,
                                color: AppTheme.surfaceLight,
                                child: const Icon(Icons.music_note, color: AppTheme.textMuted),
                              ),
                            ),
                            Positioned(
                              bottom: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  video.durationFormatted,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              video.uploader,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            if (isDownloaded) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.neonGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.neonGreen.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: const Text(
                                  'Đã có trong máy',
                                  style: TextStyle(
                                    color: AppTheme.neonGreen,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download, color: AppTheme.neonGreen),
                        onPressed: () => _onDownloadItem(video),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
