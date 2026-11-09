# CẨM NANG THỰC CHIẾN: LỘ TRÌNH 4 CHẶNG CUỐN CHIẾU (PHASED EXECUTION)
> **Chiến lược:** Chia để trị, xong chặng nào khóa sổ chặng đó, kiểm thử với Verification Loop và lưu mốc an toàn bằng Git Checkpoint.  
> **Quy tắc vàng CODING DISCIPLINE:** Không viết `// TODO`, không dùng `pass`, bắt buộc khớp 100% Schema JSON và kiểm tra `if (!mounted) return;` sau mỗi lệnh `await`.

---

## 📌 QUY TRÌNH CHUẨN KHI GIAO VIỆC CHO AI:
1. Mở folder `Testt` làm Workspace trong **Antigravity** (hoặc Cursor / Claude Code).
2. Gõ lệnh khởi tạo Git trong Terminal nếu chưa có:
   ```bash
   git init
   git add .
   git commit -m "chore: initial project blueprint and rules"
   ```
3. Copy lần lượt từng Chặng dưới đây dán vào khung chat AI.
4. **Quy tắc Verification Loop**: Khi gặp bất kỳ lỗi đỏ nào ở Terminal, copy nguyên văn dòng lỗi ném ngược lại cho AI để nó tự vá lỗi. Khi test thành công, chạy lệnh Git commit tương ứng trước khi sang chặng tiếp theo!

---

### 🚀 CHẶNG 1: BACKEND FASTAPI & HUGGING FACE DOCKER
**👉 Copy đoạn prompt này gửi cho AI:**
```text
Thực hiện CHẶNG 1 theo đúng quy chuẩn trong GEMINI.md, .cursorrules và MASTER_PROMPT.md:
Hãy lập trình toàn bộ thư mục backend/ bao gồm:
1. Dockerfile (Base python:3.11-slim + ffmpeg qua apt-get + expose port 7860).
2. requirements.txt (fastapi, uvicorn, yt-dlp, aiofiles, pydantic).
3. backend/app/config.py (đọc API_KEY từ env, mặc định 'Haphuocvinhdz25082009@', cấu hình cookies /tmp/cookies.txt, dọn dẹp file tạm /tmp).
4. backend/app/services/:
   - ytdlp_service.py: Bóc tách thông tin dùng asyncio.to_thread(yt_dlp.YoutubeDL(...)).
   - download_runner.py: Chạy tải và transcode dài hạn BẮT BUỘC dùng asyncio.create_subprocess_exec gọi CLI yt-dlp và ffmpeg, parse dòng % tiến độ.
   - ffmpeg_service.py: Ghép luồng MP4 1080p bằng Stream Copy 2s (-c:v copy -c:a copy -movflags +faststart) và Center Crop 1:1 ảnh bìa trước khi nhúng MP3.
   - process_registry.py: Quản lý active_processes: dict[str, asyncio.subprocess.Process] để phục vụ lệnh kill tiến trình.
5. backend/app/api/:
   - GET /health (wake-up ping).
   - POST /api/extract (Envelope chuẩn {result_type, playlist_title, items}).
   - POST /api/download-job (bất đồng bộ, lưu process vào registry, trả về {job_id, status: 'processing'} trong 0.1s).
   - GET /api/job-status/{job_id} (polling tiến độ).
   - DELETE /api/job/{job_id} (gọi process.terminate()/kill(), dọn /tmp và giải phóng CPU/RAM server).
   - GET /api/stream/{job_id} (truyền file thành phẩm với Accept-Ranges).
   - POST /api/admin/cookies (lưu chuỗi Netscape cookies vào /tmp/cookies.txt).

KỶ LUẬT VIẾT CODE: Không viết mã giả, không dùng // TODO hay pass. Viết code đầy đủ, sẵn sàng chạy uvicorn app.main:app.
```
**✅ Kiểm thử & Git Checkpoint Chặng 1:**
```bash
# Chạy thử backend:
cd backend
python -m venv venv
.\venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --port 7860 --reload

# Khi các endpoint test bằng curl/Swagger (/docs) hoạt động trơn tru:
git add backend/
git commit -m "feat(backend): complete FastAPI media transcoding engine with async jobs"
```

---

### 🚀 CHẶNG 2: FLUTTER SETUP, ISAR DB & DATA CONTRACT
**👉 Copy đoạn prompt này gửi cho AI:**
```text
Thực hiện CHẶNG 2 theo đúng quy chuẩn trong GEMINI.md, .cursorrules và MASTER_PROMPT.md:
Hãy thiết lập nền tảng dự án mobile/ bằng Flutter:
1. pubspec.yaml: flutter_riverpod, isar (hoặc isar_community / hive_ce tương thích AGP 8+), isar_flutter_libs, path_provider, dio, media_store_plus, audiotags, just_audio, audio_service, equalizer_flutter, wakelock_plus, cached_network_image, flutter_local_notifications.
2. android/app/build.gradle: Khai báo namespace "com.example.app", compileSdkVersion 34, minSdkVersion 21 đảm bảo tương thích 100% Android Gradle Plugin (AGP) 8+.
3. android/app/src/main/AndroidManifest.xml: Khai báo đầy đủ Scoped Storage (READ_MEDIA_AUDIO, READ_MEDIA_VIDEO, POST_NOTIFICATIONS, WAKE_LOCK, INTERNET).
4. mobile/lib/data/models/: Viết các data models khớp 100% với JSON Backend (bắt buộc dùng @JsonKey cho video_id, uploader, filesize_mb, needs_ffmpeg).
5. mobile/lib/data/local/: Thiết lập Isar Database với Schema cho Track (có @Index(unique: true) String videoId), Playlist, và DownloadTask.
6. mobile/lib/core/api/: Thiết lập DioClient có Interceptor tự động gắn X-API-Key, cấu hình Timeout 60s và Retry Policy 5 lần.

KỶ LUẬT VIẾT CODE: Không viết code giữ chỗ. Đảm bảo chạy build_runner sinh code Isar không lỗi type mismatch.
```
**✅ Kiểm thử & Git Checkpoint Chặng 2:**
```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Khi build runner xong và test kết nối API thành công:
git add mobile/
git commit -m "feat(mobile): setup models, isar storage and network client"
```

---

### 🚀 CHẶNG 3: DOWNLOAD ENGINE & AUDIO PLAYER CORE
**👉 Copy đoạn prompt này gửi cho AI:**
```text
Thực hiện CHẶNG 3 theo đúng quy chuẩn trong GEMINI.md, .cursorrules và MASTER_PROMPT.md:
Hãy lập trình toàn bộ phần lõi xử lý trên Flutter:
1. DownloadQueueManager:
   - Giới hạn 3 tác vụ tải đồng thời, các tác vụ còn lại vào hàng chờ Queued. Nút "Ưu tiên tải ngay" (Priority Queue) đẩy bài lên đầu.
   - Bật WakelockPlus.enable() khi có bài đang tải, tự tắt khi hàng đợi rỗng.
   - Cơ chế Resume với HTTP Range, tải file tạm .download, đủ 100% byte mới đổi tên sang .mp3 qua media_store_plus.
   - Hủy tác vụ 2 chiều: Khi người dùng bấm Cancel, vừa hủy Dio token vừa gọi DELETE /api/job/{job_id} lên server.
   - Tính tốc độ MB/s và ETA bằng thuật toán Moving Average 5 giây, hiển thị Foreground Notification.
2. AudioEngine & Service:
   - Cài đặt BaseAudioHandler từ audio_service kết hợp just_audio.
   - Lắng nghe player.androidAudioSessionIdStream và chỉ khởi tạo Equalizer khi sessionId != null && sessionId > 0 (chống văng app).
   - Xử lý Audio Focus tự động Pause khi có cuộc gọi / app khác phát âm thanh, tự Resume khi kết thúc.

KỶ LUẬT VIẾT CODE: Mọi hàm bất đồng bộ sau khi await bắt buộc phải kiểm tra if (!mounted) return; hoặc if (!ref.mounted) return;.
```
**✅ Kiểm thử & Git Checkpoint Chặng 3:**
```bash
# Chạy app trên máy ảo hoặc điện thoại Android thật:
flutter run

# Khi test tải file thành công vào /Music và phát nhạc nền mượt mà:
git add mobile/
git commit -m "feat(mobile): implement core download manager and audio engine"
```

---

### 🚀 CHẶNG 4: UI DARK MODE AMOLED, VINYL PLAYER & SETTINGS
**👉 Copy đoạn prompt này gửi cho AI:**
```text
Thực hiện CHẶNG 4 (Giao diện & Hoàn thiện) theo GEMINI.md, .cursorrules và MASTER_PROMPT.md:
1. Theme: Dark Mode AMOLED đen tuyền (#121212 / #000000) với màu nhấn Xanh Neon (#1DB954 Spotify style). Dùng CachedNetworkImage với memCacheWidth/Height: 150 chống tràn RAM.
2. Màn hình Tìm kiếm & Bóc tách:
   - Thanh search từ khóa / dán link, Smart Clipboard BottomSheet tự động hiện khi resume app.
   - Danh sách kết quả: Tự động đối chiếu video_id với Isar DB, gắn nhãn xanh [Đã có trong máy] và uncheck mặc định khi tải Playlist.
3. Màn hình Thư viện 2 Tab:
   - Tab 1 (Tải về) vs Tab 2 (Thiết bị) gom bài tạo Playlist/Favorites.
   - Thuật toán Fuzzy Search tìm kiếm không dấu tiếng Việt.
4. Trình phát nhạc:
   - Mini Player cố định ở đáy màn hình.
   - Full Player đĩa than xoay tròn (Vinyl animation), Seekbar sóng nhạc, Sleep Timer (fade-out 5s hạ âm lượng), Tag Editor.
5. Màn hình Cài đặt (Settings):
   - Đổi URL Hugging Face Spaces và API Key.
   - Ô dán chuỗi YouTube Cookies (Netscape) có nút "Đồng bộ lên Server" gọi POST /api/admin/cookies.
   - Debug Logger bí mật: Chạm 5 lần Logo app mở màn hình xem toàn bộ nhật ký lỗi.

KỶ LUẬT VIẾT CODE: Không dùng // TODO, viết code giao diện hoàn chỉnh, sẵn sàng build release.
```
**✅ Kiểm thử & Git Checkpoint Chặng 4:**
```bash
# Chạy kiểm thử toàn bộ giao diện và build file APK hoàn thiện:
flutter build apk --release

# Khóa sổ dự án:
git add .
git commit -m "feat(mobile): complete UI, vinyl player, equalizer and settings"
```
