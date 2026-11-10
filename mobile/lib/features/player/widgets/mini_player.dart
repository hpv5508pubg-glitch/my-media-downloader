import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/audio_player_provider.dart';
import 'full_player_sheet.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(audioPlayerProvider);
    final notifier = ref.read(audioPlayerProvider.notifier);
    final track = playerState.currentTrack;

    if (track == null) return const SizedBox.shrink();

    // Rotate when playing
    if (playerState.isPlaying) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }

    final totalDur = playerState.duration.inMilliseconds.toDouble();
    final curPos = playerState.position.inMilliseconds.toDouble();
    final progress = (totalDur > 0) ? (curPos / totalDur).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const FullPlayerSheet(),
        );
      },
      // Horizontal swipe gesture to switch tracks
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -200) {
            // Swipe Left -> Next Track
            notifier.skipToNext();
          } else if (details.primaryVelocity! > 200) {
            // Swipe Right -> Previous Track
            notifier.skipToPrevious();
          }
        }
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: AppTheme.neonGreen.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Mini Progress Line
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.neonGreen),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    // Rotating Vinyl Thumbnail
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF161616),
                          border: Border.all(color: const Color(0xFF2C2C2C), width: 1.5),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipOval(
                              child: (track.coverPath != null &&
                                      File(track.coverPath!).existsSync())
                                  ? Image.file(
                                      File(track.coverPath!),
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 22,
                                      height: 22,
                                      color: AppTheme.neonGreen,
                                      child: const Icon(
                                        Icons.music_note,
                                        size: 14,
                                        color: AppTheme.pureBlack,
                                      ),
                                    ),
                            ),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.pureBlack,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Track Title & Artist
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Action: Skip Previous
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 22),
                      color: AppTheme.textPrimary,
                      onPressed: () => notifier.skipToPrevious(),
                    ),
                    // Quick Action: Play / Pause
                    IconButton(
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        size: 32,
                        color: AppTheme.neonGreen,
                      ),
                      onPressed: () => notifier.togglePlayPause(),
                    ),
                    // Quick Action: Skip Next
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 22),
                      color: AppTheme.textPrimary,
                      onPressed: () => notifier.skipToNext(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
