import asyncio
import logging
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.config import init_storage_and_cookies
from app.services.cleaner import start_cleaner_daemon
from app.services.process_registry import active_processes

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] [%(name)s] %(message)s",
)
logger = logging.getLogger("backend.main")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """
    Application lifespan manager:
    1. Initialize storage and environment cookies.
    2. Start the background cleaner daemon.
    3. Gracefully clean up active processes and tasks on shutdown.
    """
    logger.info("Initializing Private Media Downloader Backend (v4.1.0)...")
    init_storage_and_cookies()

    cleaner_task = asyncio.create_task(start_cleaner_daemon())
    logger.info("Storage and background cleaner daemon ready.")

    try:
        yield
    finally:
        logger.info("Shutting down backend service...")
        # Cancel background cleaner
        cleaner_task.cancel()
        try:
            await cleaner_task
        except asyncio.CancelledError:
            logger.info("Cleaner task cancelled successfully on shutdown.")
        except Exception as exc:
            logger.warning("Error cancelling cleaner task: %s", exc)

        # Terminate any remaining active subprocesses
        for job_id, process in list(active_processes.items()):
            try:
                logger.info("Terminating process PID=%s for job_id=%s on shutdown", process.pid, job_id)
                process.terminate()
            except Exception as exc:
                logger.warning("Error terminating process on shutdown: %s", exc)

        logger.info("Backend shutdown complete.")


# Instantiate FastAPI application
app = FastAPI(
    title="Private Media Downloader API",
    description="High-performance asynchronous backend for private multi-platform media downloading and offline playback.",
    version="4.1.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# Enable CORS for Flutter Client and external access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routes
app.include_router(router)
