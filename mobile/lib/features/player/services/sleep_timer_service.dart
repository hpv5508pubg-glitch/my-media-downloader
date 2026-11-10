import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_player_handler.dart';

enum SleepTimerMode { none, duration, endOfTrack }

class SleepTimerService {
  static final SleepTimerService instance = SleepTimerService._();
  SleepTimerService._();

  Timer? _countdownTimer;
  StreamSubscription<PlayerState>? _trackCompletionSub;
  int? _remainingSeconds;
  SleepTimerMode _mode = SleepTimerMode.none;

  final StreamController<int?> _remainingSecondsController =
      StreamController<int?>.broadcast();

  Stream<int?> get remainingSecondsStream => _remainingSecondsController.stream;
  int? get remainingSeconds => _remainingSeconds;
  bool get isActive => _mode != SleepTimerMode.none;
  SleepTimerMode get mode => _mode;

  /// Start sleep timer for a specific duration with 5-second fade-out
  void startTimer({
    required Duration duration,
    required AudioPlayerHandler handler,
  }) {
    cancelTimer(restoreVolume: true, handler: handler);

    _mode = SleepTimerMode.duration;
    _remainingSeconds = duration.inSeconds;
    _remainingSecondsController.add(_remainingSeconds);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds == null || _remainingSeconds! <= 0) {
        timer.cancel();
        await _executeShutdown(handler);
        return;
      }

      _remainingSeconds = _remainingSeconds! - 1;
      _remainingSecondsController.add(_remainingSeconds);

      // 5-second fade-out: smoothly reduce volume to zero
      if (_remainingSeconds! <= 5) {
        final fadeVolume = (_remainingSeconds! / 5.0).clamp(0.0, 1.0);
        await handler.setVolume(fadeVolume);
      }
    });
  }

  /// Sleep timer: stop after current track finishes playing
  void setEndOfTrack({required AudioPlayerHandler handler}) {
    cancelTimer(restoreVolume: true, handler: handler);

    _mode = SleepTimerMode.endOfTrack;
    _remainingSeconds = null;
    _remainingSecondsController.add(null);

    _trackCompletionSub = handler.player.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await _executeShutdown(handler);
      }
    });
  }

  /// Cancels any active sleep timer and restores volume
  void cancelTimer({bool restoreVolume = true, AudioPlayerHandler? handler}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;

    _trackCompletionSub?.cancel();
    _trackCompletionSub = null;

    _remainingSeconds = null;
    _mode = SleepTimerMode.none;
    _remainingSecondsController.add(null);

    if (restoreVolume && handler != null) {
      handler.setVolume(1.0);
    }
  }

  Future<void> _executeShutdown(AudioPlayerHandler handler) async {
    debugPrint('Sleep timer triggered: pausing playback and resetting volume.');
    await handler.pause();
    await handler.setVolume(1.0);
    cancelTimer();
  }

  void dispose() {
    cancelTimer();
    _remainingSecondsController.close();
  }
}
