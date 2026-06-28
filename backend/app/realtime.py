"""WebSocket hub for pushing live updates to connected clients.

Events broadcast to every client are small JSON envelopes, e.g.:
  {"type": "new_message", "platform": "telegram", "conversation_id": "123"}
  {"type": "conversations_changed"}
The client reacts by re-fetching the relevant REST endpoint.
"""
from __future__ import annotations

import asyncio
from typing import Set

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._conns: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket) -> None:
        await ws.accept()
        async with self._lock:
            self._conns.add(ws)

    async def disconnect(self, ws: WebSocket) -> None:
        async with self._lock:
            self._conns.discard(ws)

    @property
    def count(self) -> int:
        return len(self._conns)

    async def broadcast(self, event: dict) -> None:
        async with self._lock:
            targets = list(self._conns)
        dead = []
        for ws in targets:
            try:
                await ws.send_json(event)
            except Exception:
                dead.append(ws)
        if dead:
            async with self._lock:
                for ws in dead:
                    self._conns.discard(ws)


manager = ConnectionManager()


async def broadcast(event: dict) -> None:
    """Module-level helper so adapters can push without importing the manager."""
    await manager.broadcast(event)
