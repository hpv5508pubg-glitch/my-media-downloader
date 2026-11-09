import asyncio
import logging
import shutil
import time
from pathlib import Path

from app.config import CLEANUP_INTERVAL_SECONDS, JOB_RETENTION_SECONDS, TEMP_DIR
from app.services.process_registry import job_states, remove_job_state

logger = logging.getLogger("backend.cleaner")


def clean_job_directory(job_dir: Path) -> None:
    """Remove a specific job directory safely."""
    try:
        if job_dir.exists():
            shutil.rmtree(job_dir, ignore_errors=True)
            logger.info("Cleaned up directory: %s", job_dir)
    except Exception as exc:
        logger.error("Error cleaning directory %s: %s", job_dir, exc)


async def run_cleanup_sweep() -> int:
    """
    Scan TEMP_DIR and job_states for jobs that have exceeded JOB_RETENTION_SECONDS.
    Returns the count of deleted directories.
    """
    now = time.time()
    deleted_count = 0

    # 1. Clean from in-memory state tracking
    expired_job_ids = []
    for job_id, state in list(job_states.items()):
        created_at = state.get("created_at", now)
        if (now - created_at) > JOB_RETENTION_SECONDS:
            expired_job_ids.append(job_id)

    for job_id in expired_job_ids:
        state = job_states.get(job_id)
        if state and state.get("job_dir"):
            job_dir = Path(state["job_dir"])
            clean_job_directory(job_dir)
            deleted_count += 1
        remove_job_state(job_id)
        logger.info("Purged expired job record %s from memory", job_id)

    # 2. Check disk for any orphaned directories in TEMP_DIR older than JOB_RETENTION_SECONDS
    if TEMP_DIR.exists():
        for item in TEMP_DIR.iterdir():
            if item.is_dir():
                try:
                    dir_mtime = item.stat().st_mtime
                    if (now - dir_mtime) > JOB_RETENTION_SECONDS:
                        shutil.rmtree(item, ignore_errors=True)
                        deleted_count += 1
                        logger.info("Purged orphaned temporary folder: %s", item)
                except Exception as exc:
                    logger.warning("Could not inspect/remove temporary directory %s: %s", item, exc)

    return deleted_count


async def start_cleaner_daemon() -> None:
    """Background daemon loop that periodically purges old media files and job records."""
    logger.info("Cleaner daemon started (interval=%ss, retention=%ss)", CLEANUP_INTERVAL_SECONDS, JOB_RETENTION_SECONDS)
    while True:
        try:
            await asyncio.sleep(CLEANUP_INTERVAL_SECONDS)
            deleted = await run_cleanup_sweep()
            if deleted > 0:
                logger.info("Cleaner sweep completed: removed %d expired jobs/directories", deleted)
        except asyncio.CancelledError:
            logger.info("Cleaner daemon received cancellation signal. Stopping.")
            break
        except Exception as exc:
            logger.error("Unexpected error during cleaner sweep: %s", exc)
