import base64
import logging
import os
import tempfile
from pathlib import Path

logger = logging.getLogger("backend.config")

# Authentication Secret Key (Default or Hugging Face Space Secret)
API_KEY: str = os.getenv("API_KEY", "Haphuocvinhdz25082009@")

# Storage directory for ephemeral job files
_default_temp_dir = "/tmp/media_downloader" if os.name != "nt" else os.path.join(tempfile.gettempdir(), "media_downloader")
TEMP_DIR: Path = Path(os.getenv("TEMP_DIR", _default_temp_dir))

# Netscape Cookies file path for bot verification bypass
_default_cookies_path = "/tmp/cookies.txt" if os.name != "nt" else os.path.join(tempfile.gettempdir(), "cookies.txt")
COOKIES_PATH: Path = Path(os.getenv("COOKIES_PATH", _default_cookies_path))

# Video length limits (<= 180 minutes / 10800s)
MAX_VIDEO_DURATION_SECONDS: int = int(os.getenv("MAX_VIDEO_DURATION_SECONDS", "10800"))

# Lifecycle of completed/failed job files in seconds (30 minutes)
JOB_RETENTION_SECONDS: int = int(os.getenv("JOB_RETENTION_SECONDS", "1800"))

# Ephemeral storage cleaner cycle interval (10 minutes)
CLEANUP_INTERVAL_SECONDS: int = int(os.getenv("CLEANUP_INTERVAL_SECONDS", "600"))

# Base64-encoded Netscape cookies string from environment variables
YOUTUBE_COOKIES_BASE64: str = os.getenv("YOUTUBE_COOKIES_BASE64", "").strip()


def init_storage_and_cookies() -> None:
    """Initialize temporary storage folders and load YouTube cookies if provided."""
    try:
        TEMP_DIR.mkdir(parents=True, exist_ok=True)
        COOKIES_PATH.parent.mkdir(parents=True, exist_ok=True)

        if YOUTUBE_COOKIES_BASE64:
            decoded_cookies = base64.b64decode(YOUTUBE_COOKIES_BASE64).decode("utf-8", errors="ignore")
            with open(COOKIES_PATH, "w", encoding="utf-8") as f:
                f.write(decoded_cookies)
            logger.info("Successfully decoded and loaded cookies from YOUTUBE_COOKIES_BASE64 into %s", COOKIES_PATH)
        elif COOKIES_PATH.exists() and COOKIES_PATH.stat().st_size > 0:
            logger.info("Existing cookies file detected at %s", COOKIES_PATH)
        else:
            logger.info("No initial cookies file detected. Admin endpoint POST /api/admin/cookies is available.")
    except Exception as exc:
        logger.error("Error initializing storage and cookies: %s", exc)
