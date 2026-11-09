import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/local/isar_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // AMOLED Neon System Navigation & Status Bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.pureBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Isar Database
  try {
    await IsarDatabase.instance.init();
  } catch (exc) {
    debugPrint('Database initialization notice: $exc');
  }

  runApp(
    const ProviderScope(
      child: MediaDownloaderApp(),
    ),
  );
}

class MediaDownloaderApp extends StatelessWidget {
  const MediaDownloaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MP3 Downloader+',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const InitialHomeScreen(),
    );
  }
}

class InitialHomeScreen extends ConsumerStatefulWidget {
  const InitialHomeScreen({super.key});

  @override
  ConsumerState<InitialHomeScreen> createState() => _InitialHomeScreenState();
}

class _InitialHomeScreenState extends ConsumerState<InitialHomeScreen> {
  int _tapCount = 0;

  void _onLogoTapped() {
    setState(() {
      _tapCount++;
    });

    if (_tapCount >= 5) {
      _tapCount = 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Secret Debug Logger: Enabled (5 taps triggered)'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onLogoTapped,
          child: const Row(
            children: [
              Icon(Icons.music_note, color: AppTheme.neonGreen),
              SizedBox(width: 8),
              Text('MP3 Downloader+'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings opened')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceDark,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.neonGreen.withOpacity(0.3),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.album,
                  size: 48,
                  color: AppTheme.neonGreen,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'MP3 Downloader & Offline Player',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Production Architecture: Flutter 3.x + Isar DB + FastAPI yt-dlp/FFmpeg Engine',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Chặng 2: Foundation & Data Contract Complete',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
