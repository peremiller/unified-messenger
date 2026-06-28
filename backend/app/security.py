"""Opt-in API-key auth.

Disabled when API_KEY is empty (local dev). When set, REST routes require the
`X-API-Key` header and the WebSocket requires a `?key=` query parameter
(browsers can't set custom headers on a WebSocket handshake, hence the query
param). Comparison is constant-time to avoid timing leaks.
"""
from __future__ import annotations

import hmac
from typing import Optional

from fastapi import Header, HTTPException, status

from . import config


def _matches(candidate: Optional[str]) -> bool:
    if not config.API_KEY:
        return True  # auth disabled
    if not candidate:
        return False
    return hmac.compare_digest(candidate, config.API_KEY)


async def require_api_key(x_api_key: Optional[str] = Header(default=None)) -> None:
    """FastAPI dependency for HTTP routes."""
    if not _matches(x_api_key):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "Invalid or missing API key")


def ws_key_ok(key: Optional[str]) -> bool:
    """Plain check for the WebSocket handshake."""
    return _matches(key)
