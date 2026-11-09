import asyncio
import logging
import shutil
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger("backend.process_registry")

# Active subprocess instances mapped by job_id
active_processes: Dict[str, asyncio.subprocess.Process] = {}

# In-memory status store for polling and streaming
job_states: Dict[str, Dict[str, Any]] = {}


def register_process(job_id: str, process: asyncio.subprocess.Process) -> None:
    """Register an active subprocess for a given job_id."""
    active_processes[job_id] = process
    logger.info("Subprocess registered for job_id=%s (PID=%s)", job_id, process.pid)


def unregister_process(job_id: str) -> None:
    """Remove a subprocess from the active registry."""
    if job_id in active_processes:
        process = active_processes.pop(job_id, None)
        pid = process.pid if process else "unknown"
        logger.info("Subprocess unregistered for job_id=%s (PID=%s)", job_id, pid)


def get_process(job_id: str) -> Optional[asyncio.subprocess.Process]:
    """Retrieve the active subprocess for a job_id."""
    return active_processes.get(job_id)


def init_job_state(
    job_id: str,
    job_dir: Optional[Path] = None,
    url: str = "",
    format_id: str = "",
    custom_title: Optional[str] = None,
    custom_artist: Optional[str] = None,
) -> Dict[str, Any]:
    """Initialize state dictionary for a new download job."""
    state = {
        "job_id": job_id,
        "status": "processing",
        "progress": 0.0,
        "step": "downloading",
        "filename": None,
        "filesize_bytes": 0,
        "error": None,
        "file_path": None,
        "job_dir": str(job_dir) if job_dir else None,
        "url": url,
        "format_id": format_id,
        "custom_title": custom_title,
        "custom_artist": custom_artist,
        "created_at": time.time(),
        "updated_at": time.time(),
    }
    job_states[job_id] = state
    return state


def update_job_state(job_id: str, **kwargs: Any) -> Optional[Dict[str, Any]]:
    """Update attributes in a job state record."""
    if job_id in job_states:
        job_states[job_id].update(kwargs)
        job_states[job_id]["updated_at"] = time.time()
        return job_states[job_id]
    return None


def get_job_state(job_id: str) -> Optional[Dict[str, Any]]:
    """Get the current job state dictionary."""
    return job_states.get(job_id)


def remove_job_state(job_id: str) -> None:
    """Remove a job state record from memory."""
    job_states.pop(job_id, None)


async def terminate_and_cleanup_job(job_id: str) -> bool:
    """
    Synchronously terminate active subprocess, wipe temporary files, and mark status as cancelled.
    Releases 100% of CPU and RAM associated with the task immediately.
    """
    job = job_states.get(job_id)
    process = active_processes.get(job_id)

    # 1. Terminate or Kill running subprocess
    if process is not None:
        try:
            logger.info("Terminating process PID=%s for job_id=%s", process.pid, job_id)
            process.terminate()
            try:
                await asyncio.wait_for(process.wait(), timeout=1.5)
            except asyncio.TimeoutError:
                logger.warning("Process PID=%s did not exit after terminate(); killing...", process.pid)
                process.kill()
                await process.wait()
        except ProcessLookupError:
            logger.info("Process already terminated for job_id=%s", job_id)
        except Exception as exc:
            logger.error("Error terminating process for job_id=%s: %s", job_id, exc)
        finally:
            unregister_process(job_id)

    # 2. Wipe temporary folder associated with this job
    if job and job.get("job_dir"):
        target_dir = Path(job["job_dir"])
        if target_dir.exists():
            try:
                shutil.rmtree(target_dir, ignore_errors=True)
                logger.info("Deleted job temporary directory: %s", target_dir)
            except Exception as exc:
                logger.error("Failed to delete directory %s: %s", target_dir, exc)

    # 3. Update status to cancelled
    if job:
        job["status"] = "cancelled"
        job["step"] = "cancelled"
        job["error"] = "Job cancelled by user"
        job["updated_at"] = time.time()
        return True

    return False
