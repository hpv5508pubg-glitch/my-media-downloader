import logging
import mimetypes
import os
import time
import uuid
from pathlib import Path
from typing import Any, AsyncGenerator, Dict, List, Optional

import aiofiles
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.config import COOKIES_PATH
from app.api.deps import verify_api_key
from app.services.download_runner import run_download_job
from app.services.process_registry import (
    get_job_state,
    init_job_state,
    terminate_and_cleanup_job,
)
from app.services.ytdlp_service import extract_info

logger = logging.getLogger("backend.api")

router = APIRouter()


# -----------------------------------------------------------------------------
# PYDANTIC SCHEMAS (Strict snake_case Contract Lock)
# -----------------------------------------------------------------------------

class ExtractRequest(BaseModel):
    query: str = Field(..., description="Video/playlist URL or search keywords")


class FormatItem(BaseModel):
    format_id: str
    type: str
    quality: str
    ext: str
    filesize_mb: float
    needs_ffmpeg: bool


class VideoItem(BaseModel):
    video_id: str
    url: str
    title: str
    uploader: str
    duration: int
    thumbnail: str
    formats: List[FormatItem]


class ExtractEnvelope(BaseModel):
    result_type: str
    playlist_title: Optional[str] = None
    items: List[VideoItem]


class DownloadJobRequest(BaseModel):
    url: str = Field(..., description="Target media URL")
    format_id: str = Field(..., description="Target format ID, e.g. mp3_320, mp4_1080")
    custom_title: Optional[str] = Field(None, description="Custom title for metadata and filename")
    custom_artist: Optional[str] = Field(None, description="Custom artist for metadata")


class DownloadJobResponse(BaseModel):
    job_id: str
    status: str


class JobStatusResponse(BaseModel):
    job_id: str
    status: str
    progress: float
    step: str
    filename: Optional[str] = None
    filesize_bytes: int = 0
    error: Optional[str] = None


class CookiesRequest(BaseModel):
    cookies: str = Field(..., description="Raw Netscape cookies string")


class CookiesResponse(BaseModel):
    status: str
    message: str
    file_path: str
    bytes_written: int


# -----------------------------------------------------------------------------
# 1. HEALTH CHECKS (Open for HF Spaces Keep-Alive)
# -----------------------------------------------------------------------------

@router.get("/health", tags=["Health"])
@router.get("/api/health", tags=["Health"])
async def health_check() -> Dict[str, Any]:
    """Health check endpoint to wake up Hugging Face Spaces and monitor uptime."""
    return {
        "status": "healthy",
        "app": "private-media-downloader",
        "version": "4.1.0",
        "timestamp": int(time.time()),
    }


# -----------------------------------------------------------------------------
# 2. METADATA EXTRACTION (POST /api/extract)
# -----------------------------------------------------------------------------

@router.post(
    "/api/extract",
    response_model=ExtractEnvelope,
    tags=["Extraction"],
    dependencies=[Depends(verify_api_key)],
)
async def extract_media(request: ExtractRequest) -> ExtractEnvelope:
    """
    Extract media information (single, playlist, or search results)
    using asynchronous yt-dlp library execution in a worker thread.
    """
    if not request.query.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Query parameter cannot be empty",
        )

    try:
        data = await extract_info(request.query)
        return ExtractEnvelope(**data)
    except ValueError as val_err:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(val_err),
        )
    except Exception as exc:
        logger.error("Extraction error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to extract media information: {str(exc)}",
        )


# -----------------------------------------------------------------------------
# 3. ASYNC DOWNLOAD JOB CREATION (POST /api/download-job)
# -----------------------------------------------------------------------------

@router.post(
    "/api/download-job",
    response_model=DownloadJobResponse,
    tags=["Download"],
    dependencies=[Depends(verify_api_key)],
)
async def create_download_job(request: DownloadJobRequest) -> DownloadJobResponse:
    """
    Spawn an asynchronous media download and transcode job.
    Returns immediately in 0.1s with job_id and status: processing.
    """
    job_id = str(uuid.uuid4())

    # Initialize tracking state
    init_job_state(
        job_id=job_id,
        url=request.url,
        format_id=request.format_id,
        custom_title=request.custom_title,
        custom_artist=request.custom_artist,
    )

    # Launch CLI yt-dlp & FFmpeg subprocess runner as independent task
    import asyncio
    asyncio.create_task(
        run_download_job(
            job_id=job_id,
            url=request.url,
            format_id=request.format_id,
            custom_title=request.custom_title,
            custom_artist=request.custom_artist,
        )
    )

    return DownloadJobResponse(job_id=job_id, status="processing")


# -----------------------------------------------------------------------------
# 4. JOB STATUS POLLING (GET /api/job-status/{job_id})
# -----------------------------------------------------------------------------

@router.get(
    "/api/job-status/{job_id}",
    response_model=JobStatusResponse,
    tags=["Download"],
    dependencies=[Depends(verify_api_key)],
)
async def check_job_status(job_id: str) -> JobStatusResponse:
    """Poll the real-time progress and step of a running download job."""
    state = get_job_state(job_id)
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )

    return JobStatusResponse(
        job_id=job_id,
        status=state.get("status", "unknown"),
        progress=float(state.get("progress", 0.0)),
        step=state.get("step", "downloading"),
        filename=state.get("filename"),
        filesize_bytes=int(state.get("filesize_bytes", 0)),
        error=state.get("error"),
    )


# -----------------------------------------------------------------------------
# 5. CANCEL & TERMINATE JOB (DELETE /api/job/{job_id})
# -----------------------------------------------------------------------------

@router.delete(
    "/api/job/{job_id}",
    tags=["Download"],
    dependencies=[Depends(verify_api_key)],
)
async def cancel_job(job_id: str) -> Dict[str, Any]:
    """
    Immediately terminate the active subprocess, remove temporary files,
    and release 100% server CPU and RAM.
    """
    state = get_job_state(job_id)
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )

    await terminate_and_cleanup_job(job_id)

    return {
        "status": "cancelled",
        "job_id": job_id,
        "message": "Job successfully cancelled and resources released",
    }


# -----------------------------------------------------------------------------
# 6. STREAM COMPLETED MEDIA (GET /api/stream/{job_id})
# -----------------------------------------------------------------------------

async def _file_chunk_generator(
    file_path: Path,
    start: int,
    length: int,
    chunk_size: int = 65536,
) -> AsyncGenerator[bytes, None]:
    """Stream file byte chunks asynchronously."""
    async with aiofiles.open(file_path, mode="rb") as f:
        await f.seek(start)
        bytes_remaining = length
        while bytes_remaining > 0:
            read_size = min(chunk_size, bytes_remaining)
            chunk = await f.read(read_size)
            if not chunk:
                break
            bytes_remaining -= len(chunk)
            yield chunk


@router.get(
    "/api/stream/{job_id}",
    tags=["Streaming"],
    dependencies=[Depends(verify_api_key)],
)
async def stream_media_file(
    job_id: str,
    request: Request,
) -> Response:
    """
    Stream completed media file with full HTTP 206 Partial Content (Accept-Ranges) support.
    """
    state = get_job_state(job_id)
    if not state:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job {job_id} not found",
        )

    if state.get("status") != "completed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Job status is '{state.get('status')}'. File is not ready for streaming.",
        )

    raw_path = state.get("file_path")
    if not raw_path or not Path(raw_path).exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Media file not found on disk",
        )

    file_path = Path(raw_path)
    total_size = file_path.stat().st_size
    filename = state.get("filename") or file_path.name

    mime_type, _ = mimetypes.guess_type(str(file_path))
    if not mime_type:
        mime_type = "audio/mpeg" if file_path.suffix.lower() == ".mp3" else "video/mp4"

    range_header = request.headers.get("range")
    if range_header:
        # Parse Range: bytes=start-end
        try:
            range_value = range_header.strip().lower().replace("bytes=", "")
            parts = range_value.split("-")
            start = int(parts[0]) if parts[0] else 0
            end = int(parts[1]) if len(parts) > 1 and parts[1] else total_size - 1

            if start >= total_size or end >= total_size or start > end:
                raise HTTPException(
                    status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
                    headers={"Content-Range": f"bytes */{total_size}"},
                    detail="Requested Range Not Satisfiable",
                )

            chunk_len = (end - start) + 1
            headers = {
                "Content-Range": f"bytes {start}-{end}/{total_size}",
                "Accept-Ranges": "bytes",
                "Content-Length": str(chunk_len),
                "Content-Disposition": f'attachment; filename="{filename}"',
            }

            return StreamingResponse(
                _file_chunk_generator(file_path, start, chunk_len),
                status_code=status.HTTP_206_PARTIAL_CONTENT,
                headers=headers,
                media_type=mime_type,
            )
        except HTTPException:
            raise
        except Exception as exc:
            logger.warning("Error parsing Range header '%s': %s", range_header, exc)

    # Standard full response
    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(total_size),
        "Content-Disposition": f'attachment; filename="{filename}"',
    }

    return StreamingResponse(
        _file_chunk_generator(file_path, 0, total_size),
        status_code=status.HTTP_200_OK,
        headers=headers,
        media_type=mime_type,
    )


# -----------------------------------------------------------------------------
# 7. ADMIN COOKIES UPDATE (POST /api/admin/cookies)
# -----------------------------------------------------------------------------

@router.post(
    "/api/admin/cookies",
    response_model=CookiesResponse,
    tags=["Admin"],
    dependencies=[Depends(verify_api_key)],
)
async def update_cookies(
    request: Request,
) -> CookiesResponse:
    """
    Accepts raw Netscape cookies string (or JSON payload) and updates /tmp/cookies.txt
    to bypass bot verification and anti-scraping blocks.
    """
    content_type = request.headers.get("content-type", "")
    cookies_text = ""

    if "application/json" in content_type:
        body = await request.json()
        cookies_text = body.get("cookies", "")
    else:
        raw_body = await request.body()
        cookies_text = raw_body.decode("utf-8", errors="ignore")

    cookies_text = cookies_text.strip()
    if not cookies_text:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cookies content cannot be empty",
        )

    try:
        COOKIES_PATH.parent.mkdir(parents=True, exist_ok=True)
        async with aiofiles.open(COOKIES_PATH, mode="w", encoding="utf-8") as f:
            await f.write(cookies_text)

        bytes_written = len(cookies_text.encode("utf-8"))
        logger.info("Admin cookies updated at %s (%d bytes)", COOKIES_PATH, bytes_written)

        return CookiesResponse(
            status="success",
            message="Netscape cookies successfully saved",
            file_path=str(COOKIES_PATH),
            bytes_written=bytes_written,
        )
    except Exception as exc:
        logger.error("Failed to write cookies to %s: %s", COOKIES_PATH, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save cookies: {str(exc)}",
        )
