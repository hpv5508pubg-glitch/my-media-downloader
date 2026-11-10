import os
import asyncio
import spaces
from gradio import Server
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import router
from app.config import init_storage_and_cookies
from app.services.cleaner import start_cleaner_daemon

# 1. Initialize Gradio Server (native FastAPI subclass)
app = Server(
    title="Private Media Downloader API",
    version="4.1.0",
)

# 2. Add CORS Middleware for Flutter & external requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 3. ZeroGPU keeper function to satisfy Hugging Face ZeroGPU supervisor
@spaces.GPU
def gpu_health_check():
    """ZeroGPU keeper function required by Hugging Face ZeroGPU runtime."""
    return "ZeroGPU Hardware Online"

# 4. Include all project API routes (/health, /api/extract, /api/download-job, etc.)
app.include_router(router)

# 5. Root endpoint for quick browser inspection
@app.get("/")
def root():
    return {
        "status": "online",
        "service": "Private Media Downloader Backend",
        "version": "4.1.0",
        "hardware": "ZeroGPU Free",
        "endpoints": {
            "health": "/health",
            "extract": "/api/extract",
            "download_job": "/api/download-job",
            "docs": "/docs"
        }
    }

# 6. Startup event for storage & background cleanup daemon
@app.on_event("startup")
async def startup_event():
    init_storage_and_cookies()
    asyncio.create_task(start_cleaner_daemon())

# 7. Launch using Gradio native launcher (handles port 7860 & proxy)
if __name__ == "__main__":
    app.launch(ssr_mode=False)
