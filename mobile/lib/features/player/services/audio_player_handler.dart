import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/local/schemas/track_schema.dart';

/// AudioHandler implementation using audio_service and just_audio
class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  List<Track> _playlist = [];
  int _currentIndex = -1;

  AudioPlayer get player => _player;

  /// Expose native Android audio session ID stream for safe Equalizer binding
  Stream<int?> get androidAudioSessionIdStream =>
      _player.androidAudioSessionIdStream;

  AudioPlayerHandler() {
    _initAudioSessionAndInterruptionHandling();
  }

  /// Configure Audio Focus, Interruption handling (calls, alarms, headphones unplugged)
  void _initAudioSessionAndInterruptionHandling() {
    // Listen for player state changes
    _player.playbackEventStream.listen(_broadcastPlaybackEvent);

    // Handle track completion
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        skipToNext();
      }
    });

    // Listen to current sequence index changes in player
    _player.currentIndexStream.listen((index) {
      if (index != null && index >= 0 && index < _playlist.length) {
        _currentIndex = index;
        _broadcastMediaItem(_playlist[index]);
      }
    });
  }

  void _broadcastPlaybackEvent(PlaybackEvent event) {
    final playing = _player.playing;
    final controls = [
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  void _broadcastMediaItem(Track track) {
    final item = MediaItem(
      id: track.videoId,
      title: track.title,
      artist: track.artist,
      album: track.album,
      duration: track.duration > 0 ? Duration(seconds: track.duration) : null,
      artUri: track.coverPath != null && File(track.coverPath!).existsSync()
          ? Uri.file(track.coverPath!)
          : null,
    );
    mediaItem.add(item);
  }

  /// Play a single Track directly
  Future<void> playTrack(Track track) async {
    _playlist = [track];
    _currentIndex = 0;

    queue.add([
      MediaItem(
        id: track.videoId,
        title: track.title,
        artist: track.artist,
        album: track.album,
      ),
    ]);

    try {
      if (track.filePath.startsWith('content://')) {
        await _player.setAudioSource(AudioSource.uri(Uri.parse(track.filePath)));
      } else {
        await _player.setFilePath(track.filePath);
      }
      _broadcastMediaItem(track);
      await _player.play();
    } catch (exc) {
      debugPrint('Error playing track: $exc');
    }
  }

  /// Load a full playlist and start playback at initialIndex
  Future<void> loadPlaylist(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;

    _playlist = List.from(tracks);
    _currentIndex = initialIndex.clamp(0, tracks.length - 1);

    final mediaItems = tracks.map((t) {
      return MediaItem(
        id: t.videoId,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration > 0 ? Duration(seconds: t.duration) : null,
        artUri: t.coverPath != null && File(t.coverPath!).existsSync()
            ? Uri.file(t.coverPath!)
            : null,
      );
    }).toList();

    queue.add(mediaItems);

    final audioSources = tracks.map((t) {
      if (t.filePath.startsWith('content://')) {
        return AudioSource.uri(Uri.parse(t.filePath));
      }
      return AudioSource.file(t.filePath);
    }).toList();

    try {
      await _player.setAudioSource(
        ConcatenatingAudioSource(children: audioSources),
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );

      _broadcastMediaItem(_playlist[_currentIndex]);
      await _player.play();
    } catch (exc) {
      debugPrint('Error loading playlist: $exc');
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_playlist.isEmpty) return;
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      _broadcastMediaItem(_playlist[_currentIndex]);
      await _player.seekToNext();
      await _player.play();
    } else {
      // Loop around to first track
      _currentIndex = 0;
      _broadcastMediaItem(_playlist[_currentIndex]);
      await _player.seek(Duration.zero, index: 0);
      await _player.play();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playlist.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      // If played more than 3s, seek to start of current track
      await _player.seek(Duration.zero);
      return;
    }

    if (_currentIndex > 0) {
      _currentIndex--;
      _broadcastMediaItem(_playlist[_currentIndex]);
      await _player.seekToPrevious();
      await _player.play();
    } else {
      // Seek to last track
      _currentIndex = _playlist.length - 1;
      _broadcastMediaItem(_playlist[_currentIndex]);
      await _player.seek(Duration.zero, index: _currentIndex);
      await _player.play();
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(enabled);
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Track? get currentTrack {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      return _playlist[_currentIndex];
    }
    return null;
  }

  List<Track> get currentPlaylist => List.unmodifiable(_playlist);

  Future<void> dispose() async {
    await _player.dispose();
  }
}
