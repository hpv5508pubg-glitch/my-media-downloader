import asyncio
import logging
import os
import shutil
from pathlib import Path
from typing import Optional

from app.services.process_registry import register_process, unregister_process

logger = logging.getLogger("backend.ffmpeg_service")


def get_ffmpeg_executable() -> str:
    """Resolve FFmpeg binary path."""
    direct = shutil.which("ffmpeg")
    if direct:
        return direct
    env_path = os.getenv("FFMPEG_PATH")
    if env_path and Path(env_path).exists():
        return env_path
    return "ffmpeg"


async def crop_cover_square(input_img: Path, output_img: Path, job_id: Optional[str] = None) -> bool:
    """
    Center crop an image to a 1:1 aspect ratio using FFmpeg:
    ffmpeg -y -i thumb_raw.jpg -vf "crop='min(iw,ih)':'min(iw,ih)'" thumb_square.jpg
    """
    if not input_img.exists():
        logger.warning("Input image %s does not exist for cropping", input_img)
        return False

    cmd = [
        get_ffmpeg_executable(),
        "-y",
        "-i", str(input_img),
        "-vf", "crop='min(iw,ih)':'min(iw,ih)'",
        str(output_img),
    ]

    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, process)

        _, stderr = await process.communicate()

        if job_id:
            unregister_process(job_id)

        if process.returncode == 0 and output_img.exists():
            logger.info("Successfully cropped thumbnail 1:1 square: %s", output_img)
            return True

        logger.error("FFmpeg square crop failed (code %s): %s", process.returncode, stderr.decode("utf-8", errors="ignore"))
        return False
    except Exception as exc:
        if job_id:
            unregister_process(job_id)
        logger.error("Exception during thumbnail square crop: %s", exc)
        return False


async def embed_mp3_metadata(
    audio_input: Path,
    cover_input: Optional[Path],
    output_mp3: Path,
    title: str,
    artist: str,
    bitrate: str = "320k",
    job_id: Optional[str] = None,
) -> bool:
    """
    Transcode audio to MP3 with specified bitrate, embed 1:1 square album art,
    and attach ID3v2 metadata tags.
    """
    if not audio_input.exists():
        logger.error("Audio input file %s does not exist", audio_input)
        return False

    cmd = [get_ffmpeg_executable(), "-y", "-i", str(audio_input)]

    has_cover = cover_input is not None and cover_input.exists()
    if has_cover:
        cmd.extend(["-i", str(cover_input), "-map", "0:a", "-map", "1:v"])
    else:
        cmd.extend(["-map", "0:a"])

    cmd.extend([
        "-c:a", "libmp3lame",
        "-b:a", bitrate,
        "-id3v2_version", "3",
    ])

    if has_cover:
        cmd.extend([
            "-metadata:s:v", 'title="Album cover"',
            "-metadata:s:v", 'comment="Cover (front)"',
        ])

    cmd.extend([
        "-metadata", f"title={title}",
        "-metadata", f"artist={artist}",
        str(output_mp3),
    ])

    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, process)

        _, stderr = await process.communicate()

        if job_id:
            unregister_process(job_id)

        if process.returncode == 0 and output_mp3.exists():
            logger.info("Successfully encoded MP3 with metadata: %s", output_mp3)
            return True

        logger.error("FFmpeg MP3 transcode failed (code %s): %s", process.returncode, stderr.decode("utf-8", errors="ignore"))
        return False
    except Exception as exc:
        if job_id:
            unregister_process(job_id)
        logger.error("Exception during MP3 encoding: %s", exc)
        return False


async def merge_mp4_stream_copy(
    video_input: Path,
    audio_input: Path,
    output_mp4: Path,
    job_id: Optional[str] = None,
) -> bool:
    """
    Merge separate video and audio streams using 2-second Stream Copy:
    ffmpeg -y -i video.mp4 -i audio.m4a -c:v copy -c:a copy -movflags +faststart output.mp4
    Falls back to ultrafast re-encoding if stream copy fails.
    """
    if not video_input.exists() or not audio_input.exists():
        logger.error("Missing input streams: video=%s, audio=%s", video_input.exists(), audio_input.exists())
        return False

    # Attempt 1: Ultra-fast stream copy (CPU < 5%, 2s)
    copy_cmd = [
        get_ffmpeg_executable(),
        "-y",
        "-i", str(video_input),
        "-i", str(audio_input),
        "-c:v", "copy",
        "-c:a", "copy",
        "-movflags", "+faststart",
        str(output_mp4),
    ]

    try:
        process = await asyncio.create_subprocess_exec(
            *copy_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, process)

        _, stderr = await process.communicate()

        if job_id:
            unregister_process(job_id)

        if process.returncode == 0 and output_mp4.exists():
            logger.info("Stream copy merge succeeded: %s", output_mp4)
            return True

        logger.warning(
            "Stream copy failed (code %s). Falling back to ultrafast re-encoding: %s",
            process.returncode,
            stderr.decode("utf-8", errors="ignore"),
        )
    except Exception as exc:
        if job_id:
            unregister_process(job_id)
        logger.warning("Stream copy exception: %s. Proceeding to fallback.", exc)

    # Attempt 2: Fallback ultrafast transcode
    fallback_cmd = [
        get_ffmpeg_executable(),
        "-y",
        "-i", str(video_input),
        "-i", str(audio_input),
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-c:a", "aac",
        "-movflags", "+faststart",
        str(output_mp4),
    ]

    try:
        process = await asyncio.create_subprocess_exec(
            *fallback_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, process)

        _, stderr = await process.communicate()

        if job_id:
            unregister_process(job_id)

        if process.returncode == 0 and output_mp4.exists():
            logger.info("Fallback MP4 transcode succeeded: %s", output_mp4)
            return True

        logger.error("Fallback MP4 transcode failed (code %s): %s", process.returncode, stderr.decode("utf-8", errors="ignore"))
        return False
    except Exception as exc:
        if job_id:
            unregister_process(job_id)
        logger.error("Exception during fallback MP4 transcode: %s", exc)
        return False


async def create_mp4_mute(
    video_input: Path,
    output_mp4: Path,
    job_id: Optional[str] = None,
) -> bool:
    """
    Strip audio from video using Stream Copy (-an -c:v copy -movflags +faststart).
    """
    if not video_input.exists():
        logger.error("Video input %s does not exist", video_input)
        return False

    cmd = [
        get_ffmpeg_executable(),
        "-y",
        "-i", str(video_input),
        "-an",
        "-c:v", "copy",
        "-movflags", "+faststart",
        str(output_mp4),
    ]

    try:
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, process)

        _, stderr = await process.communicate()

        if job_id:
            unregister_process(job_id)

        if process.returncode == 0 and output_mp4.exists():
            logger.info("Created muted MP4 via stream copy: %s", output_mp4)
            return True

        # Fallback if container stream copy is rejected
        fallback_cmd = [
            get_ffmpeg_executable(),
            "-y",
            "-i", str(video_input),
            "-an",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-movflags", "+faststart",
            str(output_mp4),
        ]
        fb_process = await asyncio.create_subprocess_exec(
            *fallback_cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        if job_id:
            register_process(job_id, fb_process)

        _, fb_stderr = await fb_process.communicate()

        if job_id:
            unregister_process(job_id)

        if fb_process.returncode == 0 and output_mp4.exists():
            logger.info("Created muted MP4 via fallback transcode: %s", output_mp4)
            return True

        logger.error("Muted MP4 failed (code %s): %s", fb_process.returncode, fb_stderr.decode("utf-8", errors="ignore"))
        return False
    except Exception as exc:
        if job_id:
            unregister_process(job_id)
        logger.error("Exception creating muted MP4: %s", exc)
        return False
