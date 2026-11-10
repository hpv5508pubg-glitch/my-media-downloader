import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/local/isar_database.dart';
import '../../tag_editor/screens/tag_editor_screen.dart';
import '../providers/audio_player_provider.dart';
import 'equalizer_dialog.dart';
import 'sleep_timer_dialog.dart';

class FullPlayerSheet extends ConsumerStatefulWidget {
  const FullPlayerSheet({super.key});

  @override
  ConsumerState<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends ConsumerState<FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _vinylAnimController;
  final IsarDatabase _db = IsarDatabase.instance;

  @override
  void initState() {
    super.initState();
    _vinylAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    final isPlaying = ref.read(audioPlayerProvider).isPlaying;
    if (isPlaying) {
      _vinylAnimController.repeat();
    }
  }

  @override
  void dispose() {
    _vinylAnimController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final track = playerState.currentTrack;

    // Synchronize vinyl rotation with playback state
    if (playerState.isPlaying) {
      if (!_vinylAnimController.isAnimating) {
        _vinylAnimController.repeat();
      }
    } else {
      if (_vinylAnimController.isAnimating) {
        _vinylAnimController.stop();
      }
    }

    final totalDuration = playerState.duration;
    final currentPosition = playerState.position;
    final maxPos = totalDuration.inMilliseconds > 0
        ? totalDuration.inMilliseconds.toDouble()
        : 1.0;
    final curPos = currentPosition.inMilliseconds.toDouble().clamp(0.0, maxPos);

    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text(
              'ĐANG PHÁT TỪ THƯ VIỆN',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              track?.album ?? 'MP3 Downloader+',
              style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              if (track != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TagEditorScreen(track: track),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // ---------------------------------------------------------------
              // Rotating Vinyl Disk
              // ---------------------------------------------------------------
              Center(
                child: RotationTransition(
                  turns: _vinylAnimController,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141414),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.neonGreen.withOpacity(0.18),
                          blurRadius: 28,
                          spreadRadius: 6,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.9),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFF2A2A2A), width: 3),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vinyl Grooves
                        Container(
                          width: 210,
                          height: 210,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF222222),
                              width: 1.5,
                            ),
                          ),
                        ),
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E1E1E),
                              width: 1.5,
                            ),
                          ),
                        ),
                        // Center Label / Album Cover
                        ClipOval(
                          child: Container(
                            width: 100,
                            height: 100,
                            color: AppTheme.surfaceDark,
                            child: (track?.coverPath != null &&
                                    File(track!.coverPath!).existsSync())
                                ? Image.file(
                                    File(track.coverPath!),
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppTheme.neonGreen.withOpacity(0.2),
                                    child: const Icon(
                                      Icons.album,
                                      size: 56,
                                      color: AppTheme.neonGreen,
                                    ),
                                  ),
                          ),
                        ),
                        // Center Spindle Hole
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.pureBlack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ---------------------------------------------------------------
              // Track Details & Favorite
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track?.title ?? 'Chưa chọn bài hát',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track?.artist ?? 'MP3 Downloader+',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (track != null)
                    IconButton(
                      icon: Icon(
                        track.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: track.isFavorite
                            ? AppTheme.neonGreen
                            : AppTheme.textMuted,
                        size: 28,
                      ),
                      onPressed: () async {
                        await _db.toggleFavorite(track.id);
                        if (!mounted) return;
                        setState(() {
                          track.isFavorite = !track.isFavorite;
                        });
                      },
                    ),
                ],
              ),

              // ---------------------------------------------------------------
              // Seekbar Timeline
              // ---------------------------------------------------------------
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: AppTheme.neonGreen,
                      inactiveTrackColor: AppTheme.surfaceLight,
                      thumbColor: AppTheme.neonGreen,
                    ),
                    child: Slider(
                      value: curPos,
                      min: 0.0,
                      max: maxPos,
                      onChanged: (val) {
                        notifier.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(currentPosition),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(totalDuration),
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ---------------------------------------------------------------
              // Main Playback Controls
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: playerState.isShuffleEnabled
                          ? AppTheme.neonGreen
                          : AppTheme.textMuted,
                    ),
                    onPressed: () => notifier.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, size: 36, color: AppTheme.textPrimary),
                    onPressed: () => notifier.skipToPrevious(),
                  ),
                  GestureDetector(
                    onTap: () => notifier.togglePlayPause(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.neonGreen,
                      ),
                      child: playerState.isBuffering
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.pureBlack,
                                ),
                              ),
                            )
                          : Icon(
                              playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 38,
                              color: AppTheme.pureBlack,
                            ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, size: 36, color: AppTheme.textPrimary),
                    onPressed: () => notifier.skipToNext(),
                  ),
                  IconButton(
                    icon: Icon(
                      playerState.loopMode == LoopMode.one
                          ? Icons.repeat_one
                          : (playerState.loopMode == LoopMode.all
                              ? Icons.repeat
                              : Icons.repeat),
                      color: playerState.loopMode != LoopMode.off
                          ? AppTheme.neonGreen
                          : AppTheme.textMuted,
                    ),
                    onPressed: () => notifier.cycleLoopMode(),
                  ),
                ],
              ),

              // ---------------------------------------------------------------
              // Utility Tools: Equalizer & Sleep Timer
              // ---------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.equalizer, color: AppTheme.neonGreen),
                    label: const Text(
                      'Equalizer',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const EqualizerDialog(),
                      );
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.bedtime, color: AppTheme.neonGreen),
                    label: const Text(
                      'Hẹn giờ tắt',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const SleepTimerDialog(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
