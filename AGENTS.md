# AGENTS.md — Development Guidelines for Private Media Downloader

## Project Overview
This repository contains a private, self-hosted cross-platform mobile media downloader (MP3/MP4) and offline music player inspired by top Google Play apps (*MP3 Downloader+ / Music Downloader & MP3 Player*).

- **Client**: Flutter 3.x (Dart 3.x) targeting Android
- **Backend**: FastAPI + yt-dlp + FFmpeg (Hosted on Hugging Face Spaces Docker, 2 vCPU / 16GB RAM)
- **Secret Key**: `Haphuocvinhdz25082009@` (Configurable via `API_KEY` env var)
- **Output Storage**: `/storage/emulated/0/Music` (via Scoped Storage `media_store_plus`)
- **Version**: 4.1.0 (Production Resilient - Code-Level Disciplines)

---

## Directory Organization Blueprint
```text
project-root/
├── .cursorrules                   # Cursor IDE rules & Coding discipline
├── AGENTS.md                      # Universal Agent blueprint & guidelines
├── GEMINI.md                      # Antigravity primary rule configuration
├── .rulesrc.yaml                  # Skill generator profile configuration
├── backend/                       # Hugging Face Spaces Docker Root
│   ├── Dockerfile                 # Debian + FFmpeg + Python 3.11 + Expose 7860
│   ├── requirements.txt           # fastapi, uvicorn, yt-dlp, aiofiles, pydantic
│   └── app/
│       ├── main.py                # Entrypoint, CORS, Auth Guard
│       ├── config.py              # Environment variables (API_KEY, Cookies, Temp paths)
│       ├── api/
│       │   ├── routes.py          # /extract, /download-job, /job-status, /job (DELETE), /stream, /admin/cookies, /health
│       │   └── deps.py            # X-API-Key validator
│       └── services/
│           ├── ytdlp_service.py   # Search & extraction async worker (asyncio.to_thread)
│           ├── download_runner.py # Long downloads & transcode runner (asyncio.create_subprocess_exec)
│           ├── ffmpeg_service.py  # 1:1 Center crop & MP4 stream copy
│           ├── process_registry.py# active_processes dict for safe process termination
│           └── cleaner.py         # Ephemeral /tmp storage cleaner daemon
└── mobile/                        # Flutter Android Application Root
    ├── pubspec.yaml
    ├── android/app/
    │   ├── build.gradle           # Configured with explicit namespace for AGP 8+
    │   └── src/main/AndroidManifest.xml # Scoped storage & Wakelock permissions
    └── lib/
        ├── main.dart
        ├── core/                  # Theme (AMOLED Neon), ApiClient, Constants, Utils
        ├── data/
        │   ├── models/            # ExtractEnvelope, VideoItem, FormatItem, JobStatus
        │   ├── local/             # Isar Database (Track, Playlist, DownloadTask schemas)
        │   └── repositories/      # MediaRepository, DownloadRepository
        └── features/
            ├── search/            # In-app search, URL parser, Clipboard BottomSheet
            ├── download_queue/    # 3-task concurrency, Priority Queue, Notifications, Wakelock
            ├── library/           # 2-tab view (Downloaded vs Device), Fuzzy Search, Playlist Manager
            ├── player/            # MiniPlayer, FullPlayer (Vinyl Rotation), Equalizer, SleepTimer
            ├── tag_editor/        # ID3 metadata & Album art editing screen
            ├── settings/          # Server URL, API Key, Paste Cookies screen
            └── debug_logger/      # Secret in-app error log viewer (5 taps on logo)
```

---

## Agent Behavioral Expectations & Directives

### 1. Subprocess vs Thread Execution Distinction
- **Fast Metadata Extraction (`/api/extract`)**:
  - Execution time is 1–2 seconds. Use Python library API `yt_dlp.YoutubeDL` dispatched via `asyncio.to_thread(...)` to avoid blocking the event loop.
- **Long-Running Download & Transcode (`/api/download-job`)**:
  - BẮT BUỘC dùng `asyncio.create_subprocess_exec(...)` để gọi CLI `yt-dlp` và `ffmpeg` dưới dạng tiến trình con độc lập.
  - Lưu thực thể `asyncio.subprocess.Process` vào dictionary `active_processes[job_id]`.
  - Khi nhận `DELETE /api/job/{job_id}`, backend lập tức gọi `process.terminate()` / `process.kill()` để dừng tiến trình ngay lập tức và dọn dẹp file rác `/tmp/{video_id}_{job_id}/`.

### 2. Mobile Scoped Storage & Battery Safety
- Android 11+ blocks raw `File('/storage/emulated/0/Music/...')` path writing. BẮT BUỘC dùng `media_store_plus` để chèn file vào `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` an toàn 100%.
- Bật `WakelockPlus.enable()` khi hàng đợi có bài đang tải; gọi `WakelockPlus.disable()` ngay khi hàng đợi rỗng.
- Lắng nghe `player.androidAudioSessionIdStream` từ `just_audio` và chỉ khởi tạo `Equalizer.init(sessionId)` khi `sessionId != null && sessionId > 0` để tránh văng app khi khởi động.

---

## 4. CODING DISCIPLINE (Anti-Laziness & Strict Constraints)
Every AI agent writing code for this repository MUST adhere to these non-negotiable rules:

1. **No Placeholders**: Never output `// TODO`, `// Implement later`, `/* logic goes here */`, or `pass` in Python. Every generated method must have full, functioning logic.
2. **Schema & Naming Lock**:
   - Backend APIs must output JSON keys in `snake_case`.
   - Flutter models must explicitly map with `@JsonKey(name: 'snake_case_key')` to Dart `camelCase` fields. Never alter field names.
3. **Async & State Safety**:
   - After every `await` statement in Flutter, ALWAYS check:
     `if (!mounted) return;` (for State classes) or `if (!ref.mounted) return;` (for Riverpod Notifiers) before calling `setState`, `ref.read`, `showDialog`, or `ScaffoldMessenger`.
4. **Android Gradle Plugin 8+ Compatibility**:
   - `android/app/build.gradle` must declare an explicit `namespace` and `minSdkVersion 21`.
   - If generator conflicts arise with `isar` on Flutter 3.x, use `isar_community` or `hive_ce` to guarantee error-free builds.
