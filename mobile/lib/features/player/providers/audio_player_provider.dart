import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/local/schemas/track_schema.dart';
import '../services/audio_player_handler.dart';
import '../services/equalizer_service.dart';

class PlayerStateModel {
  final Track? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double speed;
  final bool isShuffleEnabled;
  final LoopMode loopMode;
  final List<Track> playlist;

  const PlayerStateModel({
    this.currentTrack,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.speed = 1.0,
    this.isShuffleEnabled = false,
    this.loopMode = LoopMode.off,
    this.playlist = const [],
  });

  PlayerStateModel copyWith({
    Track? currentTrack,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    Duration? bufferedPosition,
    double? speed,
    bool? isShuffleEnabled,
    LoopMode? loopMode,
    List<Track>? playlist,
  }) {
    return PlayerStateModel(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      speed: speed ?? this.speed,
      isShuffleEnabled: isShuffleEnabled ?? this.isShuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      playlist: playlist ?? this.playlist,
    );
  }
}

class AudioPlayerNotifier extends StateNotifier<PlayerStateModel> {
  final AudioPlayerHandler _handler;
  final List<StreamSubscription> _subscriptions = [];

  AudioPlayerNotifier(this._handler) : super(const PlayerStateModel()) {
    _init();
  }

  void _init() {
    // Bind session stream to Equalizer safely
    EqualizerService.instance.bindAudioSessionStream(
      _handler.androidAudioSessionIdStream,
    );

    _subscriptions.add(
      _handler.player.playerStateStream.listen((playerState) {
        if (!mounted) return;
        state = state.copyWith(
          isPlaying: playerState.playing,
          isBuffering: playerState.processingState == ProcessingState.buffering ||
              playerState.processingState == ProcessingState.loading,
        );
      }),
    );

    _subscriptions.add(
      _handler.player.positionStream.listen((pos) {
        if (!mounted) return;
        state = state.copyWith(position: pos);
      }),
    );

    _subscriptions.add(
      _handler.player.durationStream.listen((dur) {
        if (!mounted) return;
        state = state.copyWith(duration: dur ?? Duration.zero);
      }),
    );

    _subscriptions.add(
      _handler.player.bufferedPositionStream.listen((buf) {
        if (!mounted) return;
        state = state.copyWith(bufferedPosition: buf);
      }),
    );

    _subscriptions.add(
      _handler.player.speedStream.listen((spd) {
        if (!mounted) return;
        state = state.copyWith(speed: spd);
      }),
    );
  }

  Future<void> playTrack(Track track) async {
    await _handler.playTrack(track);
    if (!mounted) return;
    state = state.copyWith(
      currentTrack: track,
      playlist: [track],
    );
  }

  Future<void> loadPlaylist(List<Track> tracks, {int initialIndex = 0}) async {
    await _handler.loadPlaylist(tracks, initialIndex: initialIndex);
    if (!mounted) return;
    state = state.copyWith(
      currentTrack: tracks.isNotEmpty ? tracks[initialIndex] : null,
      playlist: tracks,
    );
  }

  Future<void> play() async => await _handler.play();
  Future<void> pause() async => await _handler.pause();

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> seek(Duration pos) async => await _handler.seek(pos);
  Future<void> skipToNext() async => await _handler.skipToNext();
  Future<void> skipToPrevious() async => await _handler.skipToPrevious();

  Future<void> toggleShuffle() async {
    final nextState = !state.isShuffleEnabled;
    await _handler.player.setShuffleModeEnabled(nextState);
    if (!mounted) return;
    state = state.copyWith(isShuffleEnabled: nextState);
  }

  Future<void> cycleLoopMode() async {
    final LoopMode nextMode;
    switch (state.loopMode) {
      case LoopMode.off:
        nextMode = LoopMode.all;
        break;
      case LoopMode.all:
        nextMode = LoopMode.one;
        break;
      case LoopMode.one:
        nextMode = LoopMode.off;
        break;
    }
    await _handler.player.setLoopMode(nextMode);
    if (!mounted) return;
    state = state.copyWith(loopMode: nextMode);
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

final audioPlayerHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  final handler = AudioPlayerHandler();
  ref.onDispose(() => handler.dispose());
  return handler;
});

final audioPlayerProvider =
    StateNotifierProvider<AudioPlayerNotifier, PlayerStateModel>((ref) {
  final handler = ref.watch(audioPlayerHandlerProvider);
  return AudioPlayerNotifier(handler);
});
