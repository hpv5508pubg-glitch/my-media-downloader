import 'dart:async';
import 'package:equalizer_flutter/equalizer_flutter.dart';
import 'package:flutter/foundation.dart';

class EqualizerService {
  static final EqualizerService instance = EqualizerService._();
  EqualizerService._();

  StreamSubscription<int?>? _sessionIdSubscription;
  int? _currentSessionId;
  bool _isInitialized = false;
  bool _isEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get isEnabled => _isEnabled;
  int? get currentSessionId => _currentSessionId;

  /// CRITICAL: Listen to androidAudioSessionIdStream from just_audio and only
  /// initialize EqualizerFlutter when sessionId != null && sessionId > 0
  /// This prevents native crashes / SIGSEGV on app startup.
  void bindAudioSessionStream(Stream<int?> stream) {
    _sessionIdSubscription?.cancel();
    _sessionIdSubscription = stream.listen((sessionId) {
      if (sessionId != null && sessionId > 0 && sessionId != _currentSessionId) {
        _initEqualizerWithSessionId(sessionId);
      }
    });
  }

  Future<void> _initEqualizerWithSessionId(int sessionId) async {
    try {
      if (_isInitialized) {
        try {
          await EqualizerFlutter.release();
        } catch (_) {}
      }

      _currentSessionId = sessionId;
      await EqualizerFlutter.init(sessionId);
      await EqualizerFlutter.setEnabled(true);

      _isInitialized = true;
      _isEnabled = true;
      debugPrint('Equalizer successfully initialized for sessionId: $sessionId');
    } catch (exc) {
      debugPrint('Equalizer initialization safe guard caught: $exc');
      _isInitialized = false;
      _isEnabled = false;
    }
  }

  /// Toggle equalizer on/off
  Future<void> setEnabled(bool enabled) async {
    if (!_isInitialized) return;
    try {
      await EqualizerFlutter.setEnabled(enabled);
      _isEnabled = enabled;
    } catch (exc) {
      debugPrint('Error toggling equalizer enabled: $exc');
    }
  }

  /// Get dB level range [min, max] typically [-1500, 1500] mB
  Future<List<int>> getBandLevelRange() async {
    if (!_isInitialized) return const [-1500, 1500];
    try {
      return await EqualizerFlutter.getBandLevelRange();
    } catch (_) {
      return const [-1500, 1500];
    }
  }

  /// Get center frequencies of each band in mHz (e.g. 60Hz, 230Hz, 910Hz, 3600Hz, 14000Hz)
  Future<List<int>> getCenterBandFreqs() async {
    if (!_isInitialized) return const [60000, 230000, 910000, 3600000, 14000000];
    try {
      return await EqualizerFlutter.getCenterBandFreqs();
    } catch (_) {
      return const [60000, 230000, 910000, 3600000, 14000000];
    }
  }

  /// Retrieve current gain level for a specific band
  Future<int> getBandLevel(int band) async {
    if (!_isInitialized) return 0;
    try {
      return await EqualizerFlutter.getBandLevel(band);
    } catch (_) {
      return 0;
    }
  }

  /// Adjust gain level for a band
  Future<void> setBandLevel(int band, int level) async {
    if (!_isInitialized) return;
    try {
      await EqualizerFlutter.setBandLevel(band, level);
    } catch (exc) {
      debugPrint('Error setting band level: $exc');
    }
  }

  /// Available presets (e.g. Normal, Classical, Dance, Flat, Folk, Heavy Metal, Hip Hop, Jazz, Pop, Rock)
  Future<List<String>> getPresetNames() async {
    if (!_isInitialized) return const [];
    try {
      return await EqualizerFlutter.getPresetNames();
    } catch (_) {
      return const [];
    }
  }

  /// Apply an equalizer preset
  Future<void> setPreset(String presetName) async {
    if (!_isInitialized) return;
    try {
      await EqualizerFlutter.setPreset(presetName);
    } catch (exc) {
      debugPrint('Error setting preset: $exc');
    }
  }

  /// Apply bass boost (level 0 to 1000)
  Future<void> setBassBoost(int level) async {
    if (!_isInitialized) return;
    try {
      // Adjust lowest frequency band (Bass)
      await EqualizerFlutter.setBandLevel(0, ((level / 1000.0) * 10).round());
    } catch (exc) {
      debugPrint('Error setting bass boost: $exc');
    }
  }

  /// Release native resources on shutdown
  Future<void> release() async {
    _sessionIdSubscription?.cancel();
    if (_isInitialized) {
      try {
        await EqualizerFlutter.release();
      } catch (_) {}
      _isInitialized = false;
      _currentSessionId = null;
    }
  }
}
