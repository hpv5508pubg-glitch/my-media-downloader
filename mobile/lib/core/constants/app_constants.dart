class AppConstants {
  // Network defaults
  static const String defaultBaseUrl = 'https://iamsaygoodbye-my-media-server.hf.space';
  static const String defaultApiKey = 'Haphuocvinhdz25082009@';
  static const Duration requestTimeout = Duration(seconds: 60);
  static const int maxRetryAttempts = 5;

  // SharedPreferences Keys
  static const String prefServerUrl = 'pref_server_url';
  static const String prefApiKey = 'pref_api_key';

  // Storage Paths
  static const String scopedMusicDirectory = '/storage/emulated/0/Music';

  // Concurrency & App Limits
  static const int maxConcurrentDownloads = 3;
  static const int movingAverageWindowSeconds = 5;

  // AMOLED Neon Theme Colors
  static const int colorAmoledBackground = 0xFF121212;
  static const int colorAmoledSurface = 0xFF1E1E1E;
  static const int colorAmoledSurfaceLight = 0xFF282828;
  static const int colorSpotifyNeonGreen = 0xFF1DB954;
  static const int colorSpotifyNeonGreenAccent = 0xFF1ED760;
}
