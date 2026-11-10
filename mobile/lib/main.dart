import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'data/local/isar_database.dart';
import 'features/debug_logger/screens/debug_logger_screen.dart';
import 'features/download_queue/providers/download_queue_provider.dart';
import 'features/download_queue/screens/queue_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'features/player/widgets/mini_player.dart';
import 'features/search/screens/search_screen.dart';
import 'features/settings/screens/settings_screen.dart';

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

  // Initialize local Isar database
  try {
    await IsarDatabase.instance.init();
  } catch (exc) {
    debugPrint('Database initialization warning: $exc');
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
      home: const MainShellScreen(),
    );
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;
  int _logoTapCount = 0;

  final List<Widget> _screens = const [
    SearchScreen(),
    QueueScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  void _onLogoTapped() {
    setState(() {
      _logoTapCount++;
    });

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugLoggerScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueState = ref.watch(downloadQueueProvider);
    final pendingCount = queueState.pendingTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _onLogoTapped,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.music_note,
                  color: AppTheme.neonGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'MP3 Downloader+',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Nhật ký lỗi (5 lần chạm)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DebugLoggerScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Persistent Mini Player fixed right above bottom navigation bar
          const MiniPlayer(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                label: 'Tìm kiếm',
              ),
              BottomNavigationBarItem(
                icon: Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  backgroundColor: AppTheme.neonGreen,
                  textColor: AppTheme.pureBlack,
                  child: const Icon(Icons.download),
                ),
                label: 'Hàng đợi',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.library_music),
                label: 'Thư viện',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Cài đặt',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
