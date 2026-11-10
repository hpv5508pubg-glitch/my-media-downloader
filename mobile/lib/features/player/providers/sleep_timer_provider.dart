import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/sleep_timer_service.dart';
import 'audio_player_provider.dart';

class SleepTimerState {
  final bool isActive;
  final int? remainingSeconds;
  final SleepTimerMode mode;

  const SleepTimerState({
    this.isActive = false,
    this.remainingSeconds,
    this.mode = SleepTimerMode.none,
  });

  String get formattedRemaining {
    if (remainingSeconds == null) return '--:--';
    final m = remainingSeconds! ~/ 60;
    final s = remainingSeconds! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  SleepTimerState copyWith({
    bool? isActive,
    int? remainingSeconds,
    SleepTimerMode? mode,
  }) {
    return SleepTimerState(
      isActive: isActive ?? this.isActive,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      mode: mode ?? this.mode,
    );
  }
}

class SleepTimerNotifier extends StateNotifier<SleepTimerState> {
  final Ref _ref;
  final SleepTimerService _service = SleepTimerService.instance;
  StreamSubscription<int?>? _sub;

  SleepTimerNotifier(this._ref) : super(const SleepTimerState()) {
    _sub = _service.remainingSecondsStream.listen((sec) {
      if (!mounted) return;
      state = state.copyWith(
        isActive: _service.isActive,
        remainingSeconds: sec,
        mode: _service.mode,
      );
    });
  }

  void startTimer(Duration duration) {
    final handler = _ref.read(audioPlayerHandlerProvider);
    _service.startTimer(duration: duration, handler: handler);
    state = state.copyWith(
      isActive: true,
      remainingSeconds: duration.inSeconds,
      mode: SleepTimerMode.duration,
    );
  }

  void setEndOfTrack() {
    final handler = _ref.read(audioPlayerHandlerProvider);
    _service.setEndOfTrack(handler: handler);
    state = state.copyWith(
      isActive: true,
      remainingSeconds: null,
      mode: SleepTimerMode.endOfTrack,
    );
  }

  void cancel() {
    final handler = _ref.read(audioPlayerHandlerProvider);
    _service.cancelTimer(handler: handler);
    state = const SleepTimerState();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sleepTimerProvider =
    StateNotifierProvider<SleepTimerNotifier, SleepTimerState>((ref) {
  return SleepTimerNotifier(ref);
});
