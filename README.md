# Private Multi-Platform Media Downloader & Offline Music Player
> **Archetype:** MP3 Downloader+ / Music Downloader & MP3 Player (Google Play Standard)  
> **Version:** 4.1.0 (Production Resilient — Zero Blindspots)  
> **Architecture:** Flutter 3.x (Android) + Hugging Face Spaces (FastAPI + yt-dlp + FFmpeg Docker)

---

## 🌟 Tổng Quan Hệ Thống

Dự án là ứng dụng di động cá nhân (Private) dùng để tìm kiếm, tải và phát nhạc/video offline chất lượng cao đa nền tảng (YouTube, TikTok, Facebook, Instagram, SoundCloud). Hệ thống được phân tách thành hai tầng kiến trúc độc lập:

1. **Backend Service (`backend/`)**:
   - Triển khai bằng Docker trên Hugging Face Spaces (2 vCPU / 16GB RAM).
   - FastAPI + Python 3.11 + FFmpeg + yt-dlp.
   - Bóc tách siêu tốc (1–2s) qua `asyncio.to_thread`.
   - Quản lý tải và transcode dài hạn qua tiến trình con độc lập `asyncio.create_subprocess_exec` kết hợp Registry hỗ trợ lệnh Hủy 2 chiều (`DELETE /api/job/{job_id}`).
   - Stream Copy 2s cho MP4 1080p (`-c:v copy -c:a copy`) và Center Crop 1:1 ảnh bìa đĩa than trước khi nhúng MP3 ID3v2 320kbps.
   - Cơ chế nạp Netscape Cookies (`/tmp/cookies.txt`) vượt qua cơ chế chống bot YouTube.

2. **Mobile Client (`mobile/`)**:
   - Viết bằng Flutter 3.x (Dart 3.x) hỗ trợ Android 10, 11, 12, 13, 14+ (AGP 8+).
   - Quản lý State: `flutter_riverpod`.
   - Cơ sở dữ liệu: `isar_community` (AGP 8+ compatible).
   - Lưu trữ an toàn Scoped Storage: Lưu trực tiếp vào `/storage/emulated/0/Music` bằng `media_store_plus`.
   - Quản lý hàng đợi: Tải tối đa 3 tác vụ đồng thời, ưu tiên tải ngay (Priority Queue), Wakelock giữ CPU sống khi tắt màn hình, tính toán tốc độ MB/s & ETA không giật số bằng Moving Average 5s.
   - Audio Engine: `just_audio` + `audio_service` (chạy nền, Lockscreen controls, Audio Focus xử lý cuộc gọi).
   - Equalizer 5 dải tần + Bass Boost khởi tạo an toàn sau khi nhận `sessionId > 0`.
   - Giao diện Dark Mode AMOLED (`#121212`) + Xanh Neon Spotify (`#1DB954`), Mini Player đáy màn hình + Full Player đĩa than xoay tròn (Vinyl animation), Sleep Timer (Fade-out 5s).
   - Nhận diện bài đã tải (hiện nhãn xanh `[Đã có trong máy]` và tự động bỏ tích khi tải playlist).
   - Màn hình Debug Logger bí mật: Chạm 5 lần vào Logo app để mở nhật ký lỗi.

---

## 📁 Cấu Trúc Thư Mục Dự Án

```text
Testt/
├── .cursorrules                   # Cursor IDE rules & Coding discipline
├── .gitignore                     # Git ignore rules
├── AGENTS.md                      # Universal Agent blueprint & guidelines
├── GEMINI.md                      # Antigravity primary rule configuration
├── MASTER_PROMPT.md               # Master system specification
├── PHASED_EXECUTION_ROADMAP.md    # Phased rollout roadmap
├── README.md                      # Project documentation
├── backend/                       # Hugging Face Spaces Docker Root
│   ├── Dockerfile                 # Debian + FFmpeg + Python 3.11 + Expose 7860
│   ├── requirements.txt           # fastapi, uvicorn, yt-dlp, aiofiles, pydantic
│   ├── test_backend.py            # Unit test suite verifying all endpoints
│   └── app/
│       ├── main.py                # FastAPI entry, CORS, Lifespan, Cleanup daemon
│       ├── config.py              # Environment variables, API key, cleanup settings
│       ├── api/
│       │   ├── deps.py            # X-API-Key validator
│       │   └── routes.py          # /extract, /download-job, /job-status, /job (DELETE), /stream, /admin/cookies, /health
│       └── services/
│           ├── ytdlp_service.py   # Search & extraction async worker (asyncio.to_thread)
│           ├── download_runner.py # Long downloads & transcode runner (asyncio.create_subprocess_exec)
│           ├── ffmpeg_service.py  # 1:1 Center crop & MP4 stream copy
│           ├── process_registry.py# active_processes dict for safe process termination
│           └── cleaner.py         # Ephemeral /tmp storage cleaner daemon
└── mobile/                        # Flutter Android Application Root
    ├── pubspec.yaml
    ├── android/
    │   ├── build.gradle
    │   ├── settings.gradle
    │   └── app/
    │       ├── build.gradle       # Configured with explicit namespace for AGP 8+
    │       └── src/main/AndroidManifest.xml # Scoped storage & Wakelock permissions
    └── lib/
        ├── main.dart              # Main shell with BottomNavigationBar & MiniPlayer
        ├── core/
        │   ├── api/               # ApiClient, ApiInterceptors (Retry, ApiKey, DebugLog)
        │   ├── constants/         # AppConstants
        │   └── theme/             # AppTheme (Dark AMOLED + Spotify Neon Green)
        ├── data/
        │   ├── models/            # ExtractEnvelope, VideoItem, FormatItem, JobStatus
        │   ├── local/             # IsarDatabase, Track, Playlist, DownloadTask schemas
        │   └── repositories/      # MediaRepository, DownloadRepository
        └── features/
            ├── search/            # Search & Ingestion, Smart Clipboard BottomSheet
            ├── download_queue/    # 3-task concurrency, Moving Average speed & ETA, Notifications
            ├── library/           # Dual-Tab (Tải về vs Thiết bị), Vietnamese Fuzzy Search, Playlists
            ├── player/            # MiniPlayer, FullPlayer (Vinyl animation), Equalizer, SleepTimer
            ├── tag_editor/        # ID3 Tag & Album Art Editor
            ├── settings/          # Server URL, API Key, Netscape Cookies Sync
            └── debug_logger/      # Secret in-app error log viewer (5 taps on logo)
```

---

## 🚀 Hướng Dẫn Chạy & Kiểm Thử

### 1. Khởi Chạy Backend (FastAPI + Docker)

```bash
cd backend

# Cách 1: Chạy trực tiếp qua Python
pip install -r requirements.txt
uvicorn app.main:app --port 7860 --reload

# Cách 2: Chạy qua Docker (Chuẩn Hugging Face Spaces)
docker build -t private-media-backend .
docker run -p 7860:7860 private-media-backend

# Chạy bài test tự động (Verification Loop):
python test_backend.py
```

### 2. Khởi Chạy Mobile App (Flutter Android)

```bash
cd mobile

# Cài đặt dependencies
flutter pub get

# Sinh mã nguồn Isar và JSON Serializer (nếu cần):
dart run build_runner build --delete-conflicting-outputs

# Chạy trên máy ảo Android hoặc điện thoại thật:
flutter run

# Build APK Release:
flutter build apk --release
```

---

## 🔒 Bản Quyền & Bảo Mật
- Dự án phục vụ mục đích sử dụng cá nhân (Private Self-Hosted).
- Mọi yêu cầu API đều được bảo vệ bằng header `X-API-Key` bí mật.
