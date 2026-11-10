import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/equalizer_service.dart';

class EqualizerState {
  final bool isInitialized;
  final bool isEnabled;
  final List<int> bandFrequencies;
  final List<int> bandLevels;
  final List<int> bandRange;
  final List<String> presets;
  final String? currentPreset;
  final int bassBoost;

  const EqualizerState({
    this.isInitialized = false,
    this.isEnabled = false,
    this.bandFrequencies = const [60000, 230000, 910000, 3600000, 14000000],
    this.bandLevels = const [0, 0, 0, 0, 0],
    this.bandRange = const [-1500, 1500],
    this.presets = const [],
    this.currentPreset,
    this.bassBoost = 0,
  });

  EqualizerState copyWith({
    bool? isInitialized,
    bool? isEnabled,
    List<int>? bandFrequencies,
    List<int>? bandLevels,
    List<int>? bandRange,
    List<String>? presets,
    String? currentPreset,
    int? bassBoost,
  }) {
    return EqualizerState(
      isInitialized: isInitialized ?? this.isInitialized,
      isEnabled: isEnabled ?? this.isEnabled,
      bandFrequencies: bandFrequencies ?? this.bandFrequencies,
      bandLevels: bandLevels ?? this.bandLevels,
      bandRange: bandRange ?? this.bandRange,
      presets: presets ?? this.presets,
      currentPreset: currentPreset ?? this.currentPreset,
      bassBoost: bassBoost ?? this.bassBoost,
    );
  }
}

class EqualizerNotifier extends StateNotifier<EqualizerState> {
  final EqualizerService _service = EqualizerService.instance;

  EqualizerNotifier() : super(const EqualizerState()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_service.isInitialized) {
      if (!mounted) return;
      state = state.copyWith(isInitialized: false, isEnabled: false);
      return;
    }

    final freqs = await _service.getCenterBandFreqs();
    final range = await _service.getBandLevelRange();
    final presets = await _service.getPresetNames();

    final levels = <int>[];
    for (int i = 0; i < freqs.length; i++) {
      final lvl = await _service.getBandLevel(i);
      levels.add(lvl);
    }

    if (!mounted) return;
    state = state.copyWith(
      isInitialized: true,
      isEnabled: _service.isEnabled,
      bandFrequencies: freqs,
      bandLevels: levels,
      bandRange: range,
      presets: presets,
    );
  }

  Future<void> toggleEnabled(bool enabled) async {
    await _service.setEnabled(enabled);
    if (!mounted) return;
    state = state.copyWith(isEnabled: enabled);
  }

  Future<void> setBandLevel(int band, int level) async {
    await _service.setBandLevel(band, level);
    if (!mounted) return;
    final updatedLevels = List<int>.from(state.bandLevels);
    if (band >= 0 && band < updatedLevels.length) {
      updatedLevels[band] = level;
      state = state.copyWith(bandLevels: updatedLevels);
    }
  }

  Future<void> setPreset(String preset) async {
    await _service.setPreset(preset);
    if (!mounted) return;
    await refresh();
    if (!mounted) return;
    state = state.copyWith(currentPreset: preset);
  }

  Future<void> setBassBoost(int level) async {
    await _service.setBassBoost(level);
    if (!mounted) return;
    state = state.copyWith(bassBoost: level);
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>((ref) {
  return EqualizerNotifier();
});
