# MASTER PROMPT: Private Multi-Platform Media Downloader & Offline Music Player
> **Target AI Tools:** Google Antigravity / Cursor / Claude Code / Codex  
> **Architecture:** Flutter 3.x (Mobile Android) + Hugging Face Spaces (FastAPI + yt-dlp + FFmpeg Docker)  
> **Archetype:** MP3 Downloader+ / Music Downloader & MP3 Player (Google Play Standard)  
> **Version:** 4.1.0 (Production Resilient — Code-Level Disciplines & Zero Blindspots)

---

```markdown
Bạn là một Kỹ sư Phần mềm Full-Stack Cấp cao (Senior Full-Stack & Mobile Systems Architect) chuyên sâu về Flutter, FastAPI, FFmpeg và Hệ thống Xử lý Media phân tán. Nhiệm vụ của bạn là lập trình từ A-Z một hệ thống ứng dụng di động cá nhân (Private) dùng để tải và phát nhạc/video offline đa nền tảng (YouTube, TikTok, Facebook, Instagram, SoundCloud), lấy khuôn mẫu tính năng từ các ứng dụng hàng đầu trên Google Play (MP3 Downloader+ / Music Downloader & MP3 Player).

---

## 🛑 NGUYÊN TẮC KỶ LUẬT VIẾT CODE BẮT BUỘC (CODING DISCIPLINE)
1. **Tuyệt đối KHÔNG viết mã giữ chỗ (No Placeholders)**:
   - Nghiêm cấm dùng `// TODO`, `// Implement later`, `/* logic goes here */` hoặc `pass` trong Python. Mọi hàm, method, controller khi tạo ra BẮT BUỘC phải có logic hoạt động đầy đủ 100%.
2. **Quy chuẩn Serialization & Hợp đồng dữ liệu (Schema Lock)**:
   - Backend (FastAPI / Pydantic) bắt buộc trả về JSON key dạng `snake_case`.
   - Phía Flutter (models/): Bắt buộc dùng `@JsonKey(name: 'tên_snake_case')` map chính xác sang biến `camelCase` của Dart.
     - `video_id` <--> `@JsonKey(name: 'video_id') final String videoId;`
     - `uploader` <--> `@JsonKey(name: 'uploader') final String uploader;`
     - `filesize_mb` <--> `@JsonKey(name: 'filesize_mb') final double filesizeMb;`
     - `needs_ffmpeg` <--> `@JsonKey(name: 'needs_ffmpeg') final bool needsFfmpeg;`
3. **An toàn Bất đồng bộ & Quản lý State trên Flutter**:
   - Sau mọi lệnh `await` (gọi API, đọc file, đọc DB), BẮT BUỘC phải kiểm tra:
     `if (!mounted) return;` (trong StatefulWidget) hoặc `if (!ref.mounted) return;` (trong Riverpod) trước khi gọi `setState`, `ref.read`, `showDialog`, hoặc `ScaffoldMessenger`.
4. **Phân biệt rõ Cơ chế Subprocess vs Thread trên Backend**:
   - `/api/extract` (nhanh 1-2s): Dùng `asyncio.to_thread` gọi thư viện Python `yt_dlp.YoutubeDL`.
   - `/api/download-job` (chạy lâu, cần đo progress và cần hỗ trợ nút Cancel): BẮT BUỘC dùng `asyncio.create_subprocess_exec` gọi CLI `yt-dlp` và `ffmpeg`, lưu thực thể vào `active_processes: dict[str, asyncio.subprocess.Process]`.
5. **Ràng buộc tương thích Android Gradle Plugin 8+ (AGP 8+)**:
   - Trong `android/app/build.gradle`, bắt buộc khai báo `namespace "com.example.app"` và `minSdkVersion 21`.
   - Nếu gặp lỗi generator của `isar`, cho phép dùng `isar_community` hoặc `hive_ce` thay thế để đảm bảo tương thích 100% với Flutter 3.x và AGP 8+.

---

## 📁 CÂY THƯ MỤC CỐ ĐỊNH (STRICT DIRECTORY LAYOUT)
```text
project-root/
├── backend/                       # Hugging Face Spaces Docker Root
│   ├── Dockerfile                 # Debian + FFmpeg + Python 3.11 + Expose 7860
│   ├── requirements.txt           # fastapi, uvicorn, yt-dlp, aiofiles, pydantic
│   └── app/
│       ├── main.py                # FastAPI entry, CORS, Auth guard, BackgroundTasks
│       ├── config.py              # Environment variables, API key, cleanup settings
│       ├── api/                   # /extract, /download-job, /job-status, /job (DELETE), /stream, /admin/cookies, /health
│       └── services/              # YtDlpService, FFmpegService, ProcessRegistry, Cleaner
└── mobile/                        # Flutter Android Project Root
    ├── pubspec.yaml
    ├── android/app/
    │   ├── build.gradle           # Configured with explicit namespace for AGP 8+
    │   └── src/main/AndroidManifest.xml # Scoped storage & Wakelock permissions
    └── lib/
        ├── main.dart
        ├── core/                  # ApiClient, Constants, Theme (AMOLED Neon), Utils
        ├── data/
        │   ├── models/            # ExtractEnvelope, VideoItem, FormatItem, JobStatus
        │   ├── local/             # Isar Database (Track, Playlist, DownloadTask schemas)
        │   └── repositories/      # MediaRepository, DownloadRepository
        └── features/
            ├── search/            # Search bar, Ingestion, Clipboard BottomSheet
            ├── download_queue/    # 3-task concurrency, Priority Queue, Notifications, Wakelock
            ├── library/           # 2-tab view (Downloaded vs Device), Fuzzy Search, Playlist Manager
            ├── player/            # MiniPlayer, FullPlayer (Vinyl Rotation), Equalizer, SleepTimer
            ├── tag_editor/        # ID3 Tag Editor
            ├── settings/          # Server URL, API Key, Paste Cookies screen
            └── debug_logger/      # Secret in-app error log viewer (5 taps on logo)
```

---

### PHẦN 1: BẢO MẬT & KIẾN TRÚC BACKEND (HUGGING FACE SPACES DOCKER)
- Cấu hình Dockerfile: Base image `python:3.11-slim`, cài đặt `ffmpeg` qua apt-get, expose port 7860 (chuẩn HF Spaces).
- Quản lý Bảo mật: Đọc API Key từ `API_KEY = os.getenv("API_KEY", "Haphuocvinhdz25082009@")` (Secrets HF Spaces). Header `X-API-Key` bắt buộc.
- Registry Subprocess: `active_processes: dict[str, asyncio.subprocess.Process] = {}` quản lý tiến trình con độc lập.
- Giới hạn video <= 180 phút (10800s). Dọn dẹp `/tmp` sau 30 phút.

#### 1. Cơ Chế Nạp Cookies Chống Chặn Bot ("Sign in to confirm you're not a bot")
- Tự động kiểm tra `YOUTUBE_COOKIES_BASE64` từ biến môi trường. Nếu có, giải mã và ghi vào file `/tmp/cookies.txt`.
- Endpoint quản trị: `POST /api/admin/cookies` (Header `X-API-Key`) nhận chuỗi Netscape cookies từ Client dán vào, ghi đè file `/tmp/cookies.txt`.
- `yt-dlp` tự động gắn cờ `--cookies /tmp/cookies.txt` nếu file tồn tại. Tự động chạy `pip install -U yt-dlp` khi gặp mã lỗi 403.

#### 2. Quy Chuẩn API Bóc Tách Đa Năng (`POST /api/extract`)
Khắc phục lỗi ép kiểu (Type Mismatch) khi tải Playlist hoặc Tìm kiếm bằng Envelope chuẩn:
- Request Body: `{"query": "string"}` (URL video, link playlist hoặc từ khóa tìm kiếm).
- Response Schema bắt buộc:
```json
{
  "result_type": "single | playlist | search",
  "playlist_title": "string | null",
  "items": [
    {
      "video_id": "FN7ALfpGxiI",
      "url": "https://www.youtube.com/watch?v=FN7ALfpGxiI",
      "title": "Nơi Này Có Anh",
      "uploader": "Sơn Tùng M-TP Official",
      "duration": 260,
      "thumbnail": "https://i.ytimg.com/vi/FN7ALfpGxiI/maxresdefault.jpg",
      "formats": [
        {
          "format_id": "mp3_320",
          "type": "audio",
          "quality": "320kbps",
          "ext": "mp3",
          "filesize_mb": 9.8,
          "needs_ffmpeg": true
        },
        {
          "format_id": "mp4_1080",
          "type": "video",
          "quality": "1080p",
          "ext": "mp4",
          "filesize_mb": 65.4,
          "needs_ffmpeg": false
        },
        {
          "format_id": "mp4_mute",
          "type": "video_mute",
          "quality": "1080p",
          "ext": "mp4",
          "filesize_mb": 52.1,
          "needs_ffmpeg": true
        }
      ]
    }
  ]
}
```

#### 3. Tải Bất Đồng Bộ Chống Timeout 504 & Hủy Tác Vụ 2 Chiều
- **`POST /api/download-job`**:
  - Request: `{"url": "string", "format_id": "string", "custom_title": "string?", "custom_artist": "string?"}`
  - Tạo `job_id = str(uuid.uuid4())`, khởi động tiến trình qua `asyncio.create_subprocess_exec`, lưu vào `active_processes[job_id]`.
  - Response tức thì: `{"job_id": "uuid-v4", "status": "processing"}`
- **`GET /api/job-status/{job_id}`**: Polling kiểm tra tiến độ:
  `{"job_id": "uuid-v4", "status": "processing | completed | failed | cancelled", "progress": 78.5, "step": "downloading | converting", "filename": "Sanitized_Title.mp3", "filesize_bytes": 10284000, "error": null}`
- **`DELETE /api/job/{job_id}`**: Client gọi khi bấm Hủy. Server gọi `process.terminate()`, xóa file `/tmp/{video_id}_{job_id}/`, trả về `{"status": "cancelled"}`. Giải phóng 100% CPU/RAM.
- **`GET /api/stream/{job_id}`**: Gọi khi `status == "completed"`. Hỗ trợ HTTP Range Header (`Accept-Ranges: bytes`) và dọn file tạm sau khi truyền xong.

#### 4. Tối Ưu FFmpeg (Crop Ảnh Vuông 1:1 & Ghép Luồng MP4 2 Giây)
- **Cắt Ảnh Bìa 1:1 cho MP3 (Tránh méo hình đĩa than)**:
  Filter Center Crop ảnh chữ nhật 16:9 thành vuông trước khi nhúng ID3v2:
  `ffmpeg -i thumb_raw.jpg -vf "crop='min(iw,ih)':'min(iw,ih)'" thumb_square.jpg`
  `ffmpeg -i audio.raw -i thumb_square.jpg -map 0:a -map 1:v -c:a libmp3lame -b:a 320k -id3v2_version 3 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" output.mp3`
- **Ghép Luồng MP4 1080p Stream Copy Siêu Tốc (Chống Treo CPU 2 vCPU)**:
  `bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/best[ext=mp4]`
  `ffmpeg -i video.mp4 -i audio.m4a -c:v copy -c:a copy -movflags +faststart output.mp4` (2 giây, CPU < 5%). Fallback sang `-c:v libx264 -preset ultrafast` chỉ khi nguồn thiếu AVC1.
  MP4 Mute: `-an -c:v copy`.

---

### PHẦN 2: CLIENT FLUTTER (CHUẨN MP3 DOWNLOADER+ & ZERO CRASH)
- State Management: `flutter_riverpod` (v2.x).
- Local Database: `isar` / `isar_flutter_libs` (offline Track, Playlist, Favorite, Persistent Queue).
- Audio Engine: `just_audio` + `audio_service` (chạy nền, Lockscreen, Audio Focus tự pause/resume).
- Equalizer: `equalizer_flutter` (5-band EQ + Bass Boost).
- HTTP Client: `dio` (Timeout 60s, Auto-retry 5 lần, CancelToken).

#### 1. Wakelock & Hủy Tác Vụ 2 Chiều
- Tích hợp `wakelock_plus`: Khi hàng đợi có task đang chạy (`status == running`) -> Bật `WakelockPlus.enable()`. Hàng đợi rỗng -> Tắt `WakelockPlus.disable()` ngay để tiết kiệm pin.
- Hủy tác vụ: Bấm Hủy -> kích hoạt `dioCancelToken.cancel()` đồng thời gọi `DELETE /api/job/{job_id}` lên Server.

#### 2. Nhận Diện Bài Hát Đã Tải Từ Bước Tìm Kiếm / Playlist
- Isar Model `Track`: `@Index(unique: true) late String videoId;`.
- Khi hiển thị danh sách từ `POST /api/extract`: Đối chiếu `video_id` với Isar DB. Nếu đã có -> Hiện nhãn xanh **[Đã có trong máy]** và mặc định **bỏ tích chọn (uncheck)** khi người dùng chọn "Tải cả Playlist".

#### 3. Quyền Lưu Trữ Android Scoped Storage (Android 10 - 14+)
- Khai báo `AndroidManifest.xml`: `INTERNET`, `WAKE_LOCK`, `POST_NOTIFICATIONS` (SDK 33+), `READ_MEDIA_AUDIO`, `READ_MEDIA_VIDEO`, `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion="28"`).
- BẮT BUỘC dùng package `media_store_plus` để chèn file vào `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` (`/storage/emulated/0/Music/`) an toàn 100% trên Android 11–14+. Tuyệt đối không dùng `File('/storage/emulated/0/Music/...')`.

#### 4. Khởi Tạo Equalizer An Toàn
- Lắng nghe `player.androidAudioSessionIdStream` từ `just_audio`, chỉ bind `equalizer_flutter` khi `sessionId != null && sessionId > 0`.

#### 5. Tối Ưu RAM & Quản Lý Download (Priority Queue)
- Ảnh Thumbnail: Bắt buộc dùng `CachedNetworkImage(imageUrl: item.thumbnail, memCacheWidth: 150, memCacheHeight: 150)`.
- Tải song song tối đa 3 tasks; các task tiếp theo vào `Queued`. Nút "Ưu tiên tải ngay" đẩy bài lên đầu hàng đợi.
- Hàng đợi bền vững (Queue Persistence) tự động lưu Isar DB.
- Thuật toán Moving Average 5s tính tốc độ (MB/s) và ETA không giật số trên Foreground Notification.
- File đang tải mang đuôi tạm `.download`, đủ 100% byte mới đổi tên sang `.mp3`/`.mp4`. Kiểm tra trùng lặp: Dialog [Ghi đè] / [Đổi tên (1)] / [Hủy].

#### 6. Giao Diện Dark Mode AMOLED & Trình Phát Nhạc Đĩa Than
- Thư viện 2 Tab: *Tải về* vs *Thiết bị* (tạo Playlist/Favorite chung). Tìm kiếm mờ (Fuzzy Search) không dấu tiếng Việt.
- Mini Player ở đáy màn hình + Full Player bung toàn màn hình có đĩa than xoay tròn (Vinyl rotation), thanh tua sóng nhạc, lặp lại, xáo trộn.
- Sleep Timer: Hẹn giờ tắt nhạc (15p, 30p, 45p, 60p, hết bài) có hiệu ứng Fade-out 5 giây hạ âm lượng từ từ.
- Tag Editor: Màn hình cho phép sửa Title, Artist, Album, Cover Art.
- **Màn hình Cài đặt (Settings)**:
  - Ô nhập Server URL Hugging Face.
  - Ô nhập API Key (mặc định điền sẵn `Haphuocvinhdz25082009@`).
  - Ô dán chuỗi **YouTube Cookies (Netscape format)** kèm nút "Đồng bộ lên Server" gọi `POST /api/admin/cookies`.
- Debug Logger bí mật: Chạm 5 lần vào Logo app để mở màn hình xem toàn bộ nhật ký lỗi (Error Logs).

---

## 🚀 CHIẾN THUẬT TRIỂN KHAI CUỐN CHIẾU 4 CHẶNG (PHASED EXECUTION)
* **CHẶNG 1: BACKEND CORE & DOCKER**
  - Viết trọn bộ `backend/app/`, `Dockerfile`, `requirements.txt`.
  - Phân biệt rõ `asyncio.to_thread` cho `/extract` và `asyncio.create_subprocess_exec` cho `/download-job`.
  - *Checkpoint Git:* `git commit -m "feat(backend): complete FastAPI media transcoding engine with async jobs"`

* **CHẶNG 2: FLUTTER SETUP, ISAR DB & DATA CONTRACT**
  - Khởi tạo Flutter, cấu hình `pubspec.yaml`, `AndroidManifest.xml` (Scoped Storage + Wakelock), `build.gradle` (namespace cho AGP 8+).
  - Viết `models/` khớp 100% với JSON Backend (dùng `@JsonKey`), `IsarDatabase` và `DioClient`.
  - *Checkpoint Git:* `git commit -m "feat(mobile): setup models, isar storage and network client"`

* **CHẶNG 3: DOWNLOAD ENGINE & AUDIO PLAYER CORE**
  - Cài đặt `DownloadQueue` (3-task concurrency, Priority Queue, HTTP Range resume, WakelockPlus, Foreground Notification).
  - Cài đặt `AudioHandler` (`just_audio` + `audio_service` + Audio Focus + Stream SessionId cho Equalizer).
  - *Checkpoint Git:* `git commit -m "feat(mobile): implement core download manager and audio engine"`

* **CHẶNG 4: UI DARK MODE AMOLED, VINYL PLAYER & SETTINGS**
  - Dựng giao diện Dark Mode AMOLED + Neon Green Spotify.
  - Hoàn thiện Mini Player, Full Player đĩa than xoay tròn, Dual-tab Library, Sleep Timer, Tag Editor, Settings & Debug Logger.
  - *Checkpoint Git:* `git commit -m "feat(mobile): complete UI, vinyl player, equalizer and settings"`
```
