# ==============================================================================
# ANTIGRAVITY RULES: Private Multi-Platform Media Downloader & Offline Music Player
# Archetype: MP3 Downloader+ & Music Player (Google Play Standard)
# Architecture: Flutter 3.x (Mobile Client) + Hugging Face Spaces (FastAPI + yt-dlp + FFmpeg)
# Severity: BALANCED (Clean, Resilient, Production-Ready, Zero-Blindspots)
# Version: 4.1.0
# ==============================================================================

## 1. TỔNG QUAN DỰ ÁN & KIẾN TRÚC HỆ THỐNG
Dự án là ứng dụng di động cá nhân (Private) dùng để tải và nghe nhạc/video offline đa nền tảng (YouTube, TikTok, Facebook, Instagram, SoundCloud), lấy khuôn mẫu tính năng từ các ứng dụng hàng đầu trên Google Play như **MP3 Downloader+ / Music Downloader & MP3 Player**.

### Kiến trúc phân tách Client - Server (Bất đồng bộ & Hủy tác vụ 2 chiều):
```text
[Điện thoại Android (Flutter Client)]
       │
       │ (1) POST /api/extract (Gửi link hoặc từ khóa tìm kiếm)
       ▼
[Backend Hugging Face Spaces (FastAPI + yt-dlp qua asyncio.to_thread)]
  - Trả về Envelope: {result_type: "single"|"playlist"|"search", items: [...]}
  - Client tự đối chiếu video_id với Isar DB để gắn nhãn [Đã tải]
       │
       │ (2) POST /api/download-job (Khởi tạo tác vụ nền)
       ▼
[Backend quản lý tiến trình con độc lập asyncio.create_subprocess_exec]
  - Lưu vào registry active_processes[job_id] để hỗ trợ lệnh kill
  - Trả về ngay: {job_id: "uuid", status: "processing"} trong 0.1s
  - Client polling: GET /api/job-status/{job_id} lấy % tiến trình
  - Tự động Center Crop 1:1 ảnh thumbnail bằng FFmpeg trước khi nhúng MP3
  - Ghép luồng MP4 1080p bằng -c:v copy -c:a copy siêu tốc 2s
  - Nhận lệnh DELETE /api/job/{job_id} để kill process nếu người dùng bấm Hủy
       │
       │ (3) GET /api/stream/{job_id} (Khi status == "completed")
       ▼
[Điện thoại lưu vào /Music thông qua MediaStore API (media_store_plus)]
  - WakelockPlus giữ CPU sống khi tắt màn hình lúc đang tải
  - An toàn 100% trên Android 10, 11, 12, 13, 14+ (Scoped Storage)
  - Phát trực tiếp qua Trình phát nhạc đĩa than (Mini Player / Full Player)
```

---

## 2. QUY CHUẨN BACKEND (FastAPI trên Hugging Face Spaces)
1. **Phân biệt rõ Cơ chế Subprocess vs Thread**:
   - **`/api/extract` (1-2s)**: Dùng `asyncio.to_thread` gọi thư viện Python `yt_dlp.YoutubeDL`.
   - **`/api/download-job` (Tải/convert dài)**: BẮT BUỘC dùng `asyncio.create_subprocess_exec` gọi CLI `yt-dlp` và `ffmpeg`. Lưu thực thể vào `active_processes: dict[str, asyncio.subprocess.Process]`.
2. **Hủy tác vụ đồng bộ (`DELETE /api/job/{job_id}`)**:
   - Khi nhận lệnh DELETE: Tìm `job_id` trong `active_processes`, gọi `process.terminate()` / `process.kill()`, xóa file `/tmp/{video_id}_{job_id}/`, và trả về `{"status": "cancelled"}`.
3. **Bảo mật & Cookies chống Chặn Bot**:
   - Backend đọc `API_KEY = os.getenv("API_KEY", "Haphuocvinhdz25082009@")`. Header `X-API-Key` bắt buộc.
   - Endpoint `POST /api/admin/cookies` cho phép Client dán chuỗi Netscape cookies ghi đè `/tmp/cookies.txt`.
   - `yt-dlp` tự động nhận cờ `--cookies /tmp/cookies.txt` nếu file tồn tại.
4. **Tối ưu FFmpeg**:
   - Cắt ảnh bìa vuông 1:1 (`-vf "crop='min(iw,ih)':'min(iw,ih)'"`) trước khi nhúng vào ID3v2 của file MP3 320kbps.
   - Ghép luồng MP4 1080p bằng Stream Copy `-c:v copy -c:a copy -movflags +faststart` (2 giây, CPU < 5%).

---

## 3. QUY CHUẨN CLIENT FLUTTER (Chuẩn khuôn mẫu MP3 Downloader+)
1. **Wakelock & Hủy tác vụ 2 chiều**:
   - Bật `WakelockPlus.enable()` khi có task đang tải; tắt ngay `WakelockPlus.disable()` khi hàng đợi rỗng.
   - Nút Hủy (Cancel) vừa cancel `DioCancelToken` vừa gọi `DELETE /api/job/{job_id}` lên Server.
2. **Nhận diện bài hát đã tải**:
   - Lưu `videoId` vào Isar DB. Khi hiển thị kết quả từ `POST /api/extract`, kiểm tra `videoId` để hiện nhãn xanh **[Đã có trong máy]** và mặc định bỏ tích chọn khi tải playlist.
3. **Quyền Lưu Trữ Android Scoped Storage**:
   - Khai báo đầy đủ trong `AndroidManifest.xml` (`WAKE_LOCK`, `POST_NOTIFICATIONS`, `READ_MEDIA_AUDIO`).
   - Dùng `media_store_plus` để chèn file vào `MediaStore.Audio.Media.EXTERNAL_CONTENT_URI` an toàn trên Android 11–14+.
4. **Khởi tạo Equalizer An Toàn**:
   - Lắng nghe `player.androidAudioSessionIdStream` từ `just_audio` và chỉ gọi `Equalizer.init(sessionId)` khi `sessionId != null && sessionId > 0`.
5. **Tối ưu RAM (Chống OOM)**:
   - Dùng `cached_network_image` với `memCacheWidth: 150, memCacheHeight: 150`.
6. **Trình phát nhạc & Tiện ích**:
   - Thư viện 2 Tab (*Tải về* vs *Thiết bị*), tạo Playlist chung, tìm kiếm mờ Fuzzy Search.
   - Mini Player đáy màn hình + Full Player đĩa than xoay tròn. Sleep Timer (Fade-out 5 giây).
   - Màn hình ID3 Tag Editor.
   - Màn hình Cài đặt (Settings): Đổi Server URL, API Key và ô dán YouTube Cookies đồng bộ lên server.
   - Debug Logger bí mật: Chạm 5 lần Logo app để xem log lỗi.

---

## 4. QUY TẮC KỶ LUẬT VIẾT CODE (CODING DISCIPLINE)
1. **Tuyệt đối KHÔNG viết mã giữ chỗ (No Placeholders)**:
   - Nghiêm cấm dùng `// TODO`, `// Implement later`, `/* logic goes here */` hoặc `pass` trong Python. Mọi hàm, method, controller khi tạo ra BẮT BUỘC phải có logic hoạt động đầy đủ 100%.
2. **Quy chuẩn Serialization & Hợp đồng dữ liệu**:
   - Backend (FastAPI / Pydantic) bắt buộc trả về JSON key dạng `snake_case`.
   - Phía Flutter (models/): Bắt buộc dùng `@JsonKey(name: 'tên_snake_case')` map chính xác sang biến `camelCase` của Dart. Tuyệt đối không tự ý đổi tên trường.
3. **An toàn Bất đồng bộ & Quản lý State trên Flutter**:
   - Sau mọi lệnh `await` (gọi API, đọc file, đọc DB), BẮT BUỘC phải kiểm tra:
     `if (!mounted) return;` (trong StatefulWidget) hoặc `if (!ref.mounted) return;` (trong Riverpod) trước khi gọi `setState`, `ref.read`, `showDialog`, hoặc `ScaffoldMessenger`.
4. **Ràng buộc tương thích Android Gradle Plugin 8+ (AGP 8+)**:
   - Trong `android/app/build.gradle`, bắt buộc khai báo `namespace "com.example.app"` và `minSdkVersion 21`.
   - Nếu gặp lỗi generator của `isar`, cho phép dùng `isar_community` hoặc `hive_ce` thay thế để đảm bảo tương thích 100% với Flutter 3.x và AGP 8+.
