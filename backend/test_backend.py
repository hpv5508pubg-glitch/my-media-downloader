import asyncio
import os
import sys
import unittest
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
if str(backend_dir) not in sys.path:
    sys.path.insert(0, str(backend_dir))

from fastapi.testclient import TestClient
from app.main import app
from app.config import API_KEY, COOKIES_PATH, TEMP_DIR
from app.services.process_registry import job_states, init_job_state, terminate_and_cleanup_job


class BackendChặng1TestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)
        cls.valid_headers = {"X-API-Key": API_KEY}
        cls.invalid_headers = {"X-API-Key": "wrong-key"}

    def test_01_health_check_open(self):
        """GET /health and GET /api/health must be reachable without auth."""
        res1 = self.client.get("/health")
        self.assertEqual(res1.status_code, 200)
        data1 = res1.json()
        self.assertEqual(data1.get("status"), "healthy")
        self.assertEqual(data1.get("version"), "4.1.0")

        res2 = self.client.get("/api/health")
        self.assertEqual(res2.status_code, 200)
        data2 = res2.json()
        self.assertEqual(data2.get("status"), "healthy")

    def test_02_auth_guard(self):
        """Protected endpoints must reject missing or invalid X-API-Key."""
        # 1. Missing header
        res_no_auth = self.client.post("/api/extract", json={"query": "test"})
        self.assertEqual(res_no_auth.status_code, 401)

        # 2. Invalid key
        res_bad_auth = self.client.post("/api/extract", json={"query": "test"}, headers=self.invalid_headers)
        self.assertEqual(res_bad_auth.status_code, 401)

    def test_03_admin_cookies(self):
        """POST /api/admin/cookies saves Netscape cookies string."""
        sample_cookies = "# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t2147483647\tSID\tsample_cookie_value"
        res = self.client.post(
            "/api/admin/cookies",
            headers=self.valid_headers,
            json={"cookies": sample_cookies},
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "success")
        self.assertTrue(COOKIES_PATH.exists())

        # Check content on disk
        with open(COOKIES_PATH, "r", encoding="utf-8") as f:
            saved_content = f.read()
        self.assertEqual(saved_content, sample_cookies)

    def test_04_download_job_creation_and_polling(self):
        """POST /api/download-job returns job_id in <0.1s and GET /api/job-status returns status."""
        payload = {
            "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "format_id": "mp3_320",
            "custom_title": "Rick Roll",
            "custom_artist": "Rick Astley",
        }
        res = self.client.post("/api/download-job", json=payload, headers=self.valid_headers)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn("job_id", data)
        self.assertEqual(data["status"], "processing")

        job_id = data["job_id"]

        # Poll status
        status_res = self.client.get(f"/api/job-status/{job_id}", headers=self.valid_headers)
        self.assertEqual(status_res.status_code, 200)
        status_data = status_res.json()
        self.assertEqual(status_data["job_id"], job_id)
        self.assertIn(status_data["status"], ["processing", "downloading", "failed", "cancelled", "completed"])

    def test_05_job_cancellation(self):
        """DELETE /api/job/{job_id} cancels the job and releases resources."""
        job_id = "test-cancel-uuid-12345"
        dummy_job_dir = TEMP_DIR / f"job_{job_id}"
        dummy_job_dir.mkdir(parents=True, exist_ok=True)
        dummy_file = dummy_job_dir / "temp.download"
        dummy_file.write_text("dummy data")

        init_job_state(job_id=job_id, job_dir=dummy_job_dir)

        # Call DELETE
        res = self.client.delete(f"/api/job/{job_id}", headers=self.valid_headers)
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data["status"], "cancelled")
        self.assertEqual(data["job_id"], job_id)

        # Confirm directory was cleaned up
        self.assertFalse(dummy_job_dir.exists())

        # Check status shows cancelled
        status_res = self.client.get(f"/api/job-status/{job_id}", headers=self.valid_headers)
        self.assertEqual(status_res.status_code, 200)
        self.assertEqual(status_res.json()["status"], "cancelled")

    def test_06_stream_completed_file_with_range(self):
        """GET /api/stream/{job_id} supports 200 OK and 206 Partial Content (HTTP Range)."""
        job_id = "test-stream-uuid-67890"
        dummy_job_dir = TEMP_DIR / f"job_{job_id}"
        dummy_job_dir.mkdir(parents=True, exist_ok=True)
        test_content = b"0123456789" * 100  # 1000 bytes
        test_file = dummy_job_dir / "test_song.mp3"
        test_file.write_bytes(test_content)

        state = init_job_state(job_id=job_id, job_dir=dummy_job_dir)
        state["status"] = "completed"
        state["file_path"] = str(test_file)
        state["filename"] = "test_song.mp3"
        state["filesize_bytes"] = len(test_content)

        # 1. Full stream (200 OK)
        res_full = self.client.get(f"/api/stream/{job_id}", headers=self.valid_headers)
        self.assertEqual(res_full.status_code, 200)
        self.assertEqual(res_full.headers["Accept-Ranges"], "bytes")
        self.assertEqual(int(res_full.headers["Content-Length"]), 1000)
        self.assertEqual(res_full.content, test_content)

        # 2. Range request (206 Partial Content)
        range_headers = dict(self.valid_headers)
        range_headers["Range"] = "bytes=0-99"
        res_part = self.client.get(f"/api/stream/{job_id}", headers=range_headers)
        self.assertEqual(res_part.status_code, 206)
        self.assertEqual(res_part.headers["Accept-Ranges"], "bytes")
        self.assertEqual(res_part.headers["Content-Range"], "bytes 0-99/1000")
        self.assertEqual(int(res_part.headers["Content-Length"]), 100)
        self.assertEqual(res_part.content, test_content[0:100])

        # Cleanup
        asyncio.run(terminate_and_cleanup_job(job_id))


if __name__ == "__main__":
    unittest.main()
