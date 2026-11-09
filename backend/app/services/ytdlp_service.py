import asyncio
import logging
import subprocess
import sys
from typing import Any, Dict, List, Optional
import yt_dlp

from app.config import COOKIES_PATH, MAX_VIDEO_DURATION_SECONDS

logger = logging.getLogger("backend.ytdlp_service")


def _run_ytdlp_update() -> None:
    """Run pip install -U yt-dlp when 403 or bot blocks are encountered."""
    try:
        logger.info("Attempting automatic yt-dlp package upgrade...")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-U", "yt-dlp"],
            check=True,
            capture_output=True,
            timeout=60,
        )
        logger.info("yt-dlp package successfully upgraded.")
    except Exception as exc:
        logger.error("Failed to auto-upgrade yt-dlp: %s", exc)


def _get_ytdlp_options(extract_flat: bool = False) -> Dict[str, Any]:
    """Build YoutubeDL configuration dictionary."""
    opts: Dict[str, Any] = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "ignoreerrors": True,
        "no_color": True,
        "extract_flat": "in_playlist" if extract_flat else False,
    }
    if COOKIES_PATH.exists() and COOKIES_PATH.stat().st_size > 0:
        opts["cookiefile"] = str(COOKIES_PATH)
        logger.debug("Using cookies file: %s", COOKIES_PATH)
    return opts


def _estimate_filesize_mb(duration_sec: int, bitrate_kbps: int) -> float:
    """Calculate approximate file size in MB given duration and bitrate."""
    if not duration_sec or duration_sec <= 0:
        return 5.0
    bytes_est = (bitrate_kbps * 1000 / 8) * duration_sec
    return round(bytes_est / (1024 * 1024), 1)


def _build_standard_formats(duration_sec: int) -> List[Dict[str, Any]]:
    """Build standardized, high-quality audio & video format options."""
    dur = duration_sec if duration_sec and duration_sec > 0 else 240
    return [
        {
            "format_id": "mp3_320",
            "type": "audio",
            "quality": "320kbps",
            "ext": "mp3",
            "filesize_mb": _estimate_filesize_mb(dur, 320),
            "needs_ffmpeg": True,
        },
        {
            "format_id": "mp3_128",
            "type": "audio",
            "quality": "128kbps",
            "ext": "mp3",
            "filesize_mb": _estimate_filesize_mb(dur, 128),
            "needs_ffmpeg": True,
        },
        {
            "format_id": "mp4_1080",
            "type": "video",
            "quality": "1080p",
            "ext": "mp4",
            "filesize_mb": _estimate_filesize_mb(dur, 2600),
            "needs_ffmpeg": False,
        },
        {
            "format_id": "mp4_720",
            "type": "video",
            "quality": "720p",
            "ext": "mp4",
            "filesize_mb": _estimate_filesize_mb(dur, 1500),
            "needs_ffmpeg": False,
        },
        {
            "format_id": "mp4_mute",
            "type": "video_mute",
            "quality": "1080p",
            "ext": "mp4",
            "filesize_mb": _estimate_filesize_mb(dur, 2300),
            "needs_ffmpeg": True,
        },
    ]


def _format_video_item(entry: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Format a single extracted entry into the standard VideoItem dictionary."""
    if not entry:
        return None

    video_id = entry.get("id") or entry.get("video_id") or ""
    url = entry.get("webpage_url") or entry.get("url")
    if not url:
        if video_id:
            url = f"https://www.youtube.com/watch?v={video_id}"
        else:
            return None

    title = entry.get("title") or "Untitled Media"
    uploader = entry.get("uploader") or entry.get("channel") or entry.get("artist") or "Unknown Artist"
    duration = int(entry.get("duration") or 0)

    # Pick highest resolution thumbnail
    thumbnail = entry.get("thumbnail") or ""
    if not thumbnail and entry.get("thumbnails"):
        thumbs = entry.get("thumbnails", [])
        if thumbs:
            thumbnail = thumbs[-1].get("url", "")
    if not thumbnail and video_id:
        thumbnail = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"

    return {
        "video_id": str(video_id),
        "url": str(url),
        "title": str(title),
        "uploader": str(uploader),
        "duration": duration,
        "thumbnail": str(thumbnail),
        "formats": _build_standard_formats(duration),
    }


def _extract_sync(query: str) -> Dict[str, Any]:
    """Synchronous worker function to be dispatched via asyncio.to_thread."""
    query_str = query.strip()
    is_url = query_str.startswith("http://") or query_str.startswith("https://")

    target_query = query_str if is_url else f"ytsearch10:{query_str}"
    is_flat_search = not is_url or ("list=" in query_str or "playlist" in query_str.lower())

    opts = _get_ytdlp_options(extract_flat=is_flat_search)

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            data = ydl.extract_info(target_query, download=False)
    except Exception as exc:
        err_msg = str(exc)
        if "403" in err_msg or "Sign in to confirm you're not a bot" in err_msg:
            logger.warning("Bot block / 403 detected: %s. Upgrading yt-dlp and re-trying...", err_msg)
            _run_ytdlp_update()
            # Retry once after update
            with yt_dlp.YoutubeDL(opts) as ydl:
                data = ydl.extract_info(target_query, download=False)
        else:
            raise exc

    if not data:
        return {
            "result_type": "search" if not is_url else "single",
            "playlist_title": None,
            "items": [],
        }

    # Case 1: Search results
    if not is_url or target_query.startswith("ytsearch"):
        entries = data.get("entries") or []
        items = []
        for e in entries:
            item = _format_video_item(e)
            if item:
                items.append(item)
        return {
            "result_type": "search",
            "playlist_title": None,
            "items": items,
        }

    # Case 2: Playlist
    if data.get("_type") == "playlist" or "entries" in data:
        playlist_title = data.get("title") or "Playlist"
        entries = data.get("entries") or []
        items = []
        for e in entries:
            item = _format_video_item(e)
            if item:
                # Check duration limit
                if item["duration"] <= MAX_VIDEO_DURATION_SECONDS:
                    items.append(item)
        return {
            "result_type": "playlist",
            "playlist_title": playlist_title,
            "items": items,
        }

    # Case 3: Single video
    duration = int(data.get("duration") or 0)
    if duration > MAX_VIDEO_DURATION_SECONDS:
        raise ValueError(f"Video duration ({duration}s) exceeds the maximum limit of {MAX_VIDEO_DURATION_SECONDS}s (180 mins).")

    single_item = _format_video_item(data)
    return {
        "result_type": "single",
        "playlist_title": None,
        "items": [single_item] if single_item else [],
    }


async def extract_info(query: str) -> Dict[str, Any]:
    """
    Asynchronously extracts media metadata without blocking the event loop
    using asyncio.to_thread.
    """
    logger.info("Extracting metadata for query: %s", query[:80])
    return await asyncio.to_thread(_extract_sync, query)
