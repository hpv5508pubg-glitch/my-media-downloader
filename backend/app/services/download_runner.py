import asyncio
import logging
import os
import re
import shutil
import sys
from pathlib import Path
from typing import List, Optional

from app.config import COOKIES_PATH, TEMP_DIR
from app.services.ffmpeg_service import (
    crop_cover_square,
    embed_mp3_metadata,
    merge_mp4_stream_copy,
    create_mp4_mute,
)
from app.services.process_registry import (
    get_job_state,
    register_process,
    unregister_process,
    update_job_state,
)

logger = logging.getLogger("backend.download_runner")

PROGRESS_REGEX = re.compile(r"\[download\]\s+([\d\.]+)%")


def get_ytdlp_command() -> List[str]:
    """Resolve the yt-dlp executable across Linux (Docker), Windows, and virtual environments."""
    direct = shutil.which("yt-dlp")
    if direct:
        return [direct]

    # Check Python's Scripts folder
    scripts_dir = Path(sys.executable).parent / "Scripts"
    candidate = scripts_dir / ("yt-dlp.exe" if os.name == "nt" else "yt-dlp")
    if candidate.exists():
        return [str(candidate)]

    # Fallback to direct python module execution
    return [sys.executable, "-m", "yt_dlp"]


def sanitize_filename(name: str) -> str:
    """Sanitize strings to ensure valid filenames across all operating systems."""
    clean = re.sub(r'[\\/*?:"<>|]', "_", name).strip()
    return clean if clean else "media_file"


async def run_download_job(
    job_id: str,
    url: str,
    format_id: str,
    custom_title: Optional[str] = None,
    custom_artist: Optional[str] = None,
) -> None:
    """
    Executes a long-running download and transcode job asynchronously using
    CLI yt-dlp and FFmpeg through asyncio.create_subprocess_exec.
    Stores process in active_processes for real-time cancellation capability.
    """
    job_dir = TEMP_DIR / f"job_{job_id}"
    job_dir.mkdir(parents=True, exist_ok=True)

    update_job_state(
        job_id,
        status="processing",
        progress=0.0,
        step="downloading",
        job_dir=str(job_dir),
    )

    try:
        # Check if already cancelled
        curr_state = get_job_state(job_id)
        if curr_state and curr_state.get("status") == "cancelled":
            logger.info("Job %s was cancelled before execution started", job_id)
            return

        is_audio = format_id.startswith("mp3")
        is_mute = format_id == "mp4_mute"

        base_filename = "downloaded"
        raw_download_template = str(job_dir / f"{base_filename}.%(ext)s")

        ytdlp_cmd = list(get_ytdlp_command()) + [
            "--newline",
            "--no-colors",
            "--no-playlist",
            "-o", raw_download_template,
        ]

        if COOKIES_PATH.exists() and COOKIES_PATH.stat().st_size > 0:
            ytdlp_cmd.extend(["--cookies", str(COOKIES_PATH)])

        if is_audio:
            # Download best audio and raw thumbnail
            ytdlp_cmd.extend([
                "-f", "bestaudio[ext=m4a]/bestaudio/best",
                "--write-thumbnail",
                "--convert-thumbnails", "jpg",
            ])
        elif is_mute:
            # Download video only
            ytdlp_cmd.extend([
                "-f", "bestvideo[height<=1080]/bestvideo/best",
            ])
        else:
            # Video with audio: prefer AVC1 + M4A for 2-second stream copy
            if "1080" in format_id:
                ytdlp_cmd.extend([
                    "-f", "bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]/best",
                ])
            else:
                ytdlp_cmd.extend([
                    "-f", "bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=720]+bestaudio/best[height<=720]/best",
                ])

        ytdlp_cmd.append(url)

        logger.info("Starting yt-dlp CLI subprocess for job_id=%s", job_id)
        process = await asyncio.create_subprocess_exec(
            *ytdlp_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
        )
        register_process(job_id, process)

        # Parse stdout in real-time for progress percentages
        while True:
            line_bytes = await process.stdout.readline()
            if not line_bytes:
                break
            line = line_bytes.decode("utf-8", errors="ignore").strip()

            # Check for progress pattern
            match = PROGRESS_REGEX.search(line)
            if match:
                try:
                    pct = float(match.group(1))
                    # Scale download progress to 0-85% to reserve 85-100% for converting/finishing
                    scaled_progress = round(pct * 0.85, 1)
                    update_job_state(job_id, progress=scaled_progress, step="downloading")
                except ValueError as err:
                    logger.debug("Failed parsing progress float '%s': %s", match.group(1), err)

        await process.wait()
        unregister_process(job_id)

        # Check if cancelled during download
        curr_state = get_job_state(job_id)
        if curr_state and curr_state.get("status") == "cancelled":
            logger.info("Job %s was cancelled during yt-dlp download", job_id)
            return

        if process.returncode != 0:
            error_msg = f"yt-dlp download exited with error code {process.returncode}"
            logger.error("Job %s failed: %s", job_id, error_msg)
            update_job_state(job_id, status="failed", error=error_msg)
            return

        # Step 2: Post-processing / Transcoding with FFmpeg
        update_job_state(job_id, step="converting", progress=88.0)

        # Determine downloaded media file
        downloaded_files = list(job_dir.glob(f"{base_filename}.*"))
        # Filter out images (.jpg, .png, .webp)
        media_files = [f for f in downloaded_files if f.suffix.lower() not in [".jpg", ".jpeg", ".png", ".webp", ""]]

        if not media_files:
            error_msg = "No media files were found after yt-dlp completed"
            logger.error("Job %s failed: %s", job_id, error_msg)
            update_job_state(job_id, status="failed", error=error_msg)
            return

        raw_media = media_files[0]
        final_title = sanitize_filename(custom_title if custom_title else "downloaded_track")
        final_artist = sanitize_filename(custom_artist if custom_artist else "Unknown Artist")

        if is_audio:
            # 1. Prepare 1:1 center-cropped square thumbnail
            raw_thumb = job_dir / f"{base_filename}.jpg"
            square_thumb = job_dir / "thumb_square.jpg"

            if raw_thumb.exists():
                await crop_cover_square(raw_thumb, square_thumb, job_id=job_id)

            bitrate = "320k" if "320" in format_id else "128k"
            output_filename = f"{final_title}.mp3"
            final_output_path = job_dir / output_filename

            # 2. Embed square thumbnail & ID3v2 tags
            success = await embed_mp3_metadata(
                audio_input=raw_media,
                cover_input=square_thumb if square_thumb.exists() else None,
                output_mp3=final_output_path,
                title=custom_title or final_title,
                artist=custom_artist or final_artist,
                bitrate=bitrate,
                job_id=job_id,
            )

            if not success or not final_output_path.exists():
                error_msg = "FFmpeg audio transcoding/tagging failed"
                logger.error("Job %s failed: %s", job_id, error_msg)
                update_job_state(job_id, status="failed", error=error_msg)
                return

        elif is_mute:
            output_filename = f"{final_title}_mute.mp4"
            final_output_path = job_dir / output_filename

            success = await create_mp4_mute(
                video_input=raw_media,
                output_mp4=final_output_path,
                job_id=job_id,
            )

            if not success or not final_output_path.exists():
                error_msg = "FFmpeg mute video creation failed"
                logger.error("Job %s failed: %s", job_id, error_msg)
                update_job_state(job_id, status="failed", error=error_msg)
                return

        else:
            # Standard video: check if video + audio merged or needs stream copy
            output_filename = f"{final_title}.mp4"
            final_output_path = job_dir / output_filename

            # If yt-dlp already produced an mp4 directly
            if raw_media.suffix.lower() == ".mp4":
                # Rename or optimize with faststart
                if raw_media != final_output_path:
                    raw_media.rename(final_output_path)
            else:
                # Need merge/conversion to MP4
                success = await merge_mp4_stream_copy(
                    video_input=raw_media,
                    audio_input=raw_media,
                    output_mp4=final_output_path,
                    job_id=job_id,
                )
                if not success or not final_output_path.exists():
                    # Fallback rename
                    raw_media.rename(final_output_path)

        # Check cancellation before marking completed
        curr_state = get_job_state(job_id)
        if curr_state and curr_state.get("status") == "cancelled":
            logger.info("Job %s was cancelled during FFmpeg transcode", job_id)
            return

        filesize = final_output_path.stat().st_size
        logger.info("Job %s successfully completed: %s (%d bytes)", job_id, output_filename, filesize)

        update_job_state(
            job_id,
            status="completed",
            progress=100.0,
            step="completed",
            filename=output_filename,
            filesize_bytes=filesize,
            file_path=str(final_output_path),
            error=None,
        )

    except asyncio.CancelledError:
        logger.info("Job task cancelled for job_id=%s", job_id)
        unregister_process(job_id)
        update_job_state(job_id, status="cancelled", step="cancelled", error="Job task cancelled")
    except Exception as exc:
        logger.exception("Unexpected exception in download runner for job_id=%s: %s", job_id, exc)
        unregister_process(job_id)
        curr_state = get_job_state(job_id)
        if not curr_state or curr_state.get("status") != "cancelled":
            update_job_state(job_id, status="failed", error=str(exc))
