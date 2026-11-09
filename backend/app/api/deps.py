import logging
from typing import Optional
from fastapi import Header, HTTPException, Query, status

from app.config import API_KEY

logger = logging.getLogger("backend.deps")


async def verify_api_key(
    x_api_key: Optional[str] = Header(None, alias="X-API-Key"),
    api_key: Optional[str] = Query(None, alias="api_key"),
) -> str:
    """
    Validate incoming requests against the configured API_KEY.
    Accepts X-API-Key HTTP header or api_key query parameter for media streaming.
    """
    token = x_api_key or api_key
    if not token or token != API_KEY:
        logger.warning("Unauthorized access attempt. Provided token: %s", token[:4] + "***" if token else "None")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API Key",
            headers={"WWW-Authenticate": "ApiKey"},
        )
    return token
