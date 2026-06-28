"""Unified REST API + WebSocket consumed by the Flutter client."""
from __future__ import annotations

import asyncio
from typing import List, Optional

from fastapi import (APIRouter, Depends, HTTPException, Query, WebSocket,
                     WebSocketDisconnect)
from pydantic import BaseModel

from .. import fcm, live_store, presence
from ..adapters import registry
from ..models import (Conversation, Message, Peer, Platform, PlatformInfo,
                      PresenceReport)
from ..realtime import manager
from ..security import require_api_key, ws_key_ok

# Header auth applies to every HTTP route on this router. The WebSocket lives on
# a separate router and authenticates via query param (browsers can't set
# headers on the WS handshake).
router = APIRouter(prefix="/api", dependencies=[Depends(require_api_key)])
ws_router = APIRouter(prefix="/api")


class SendBody(BaseModel):
    text: str


class FcmToken(BaseModel):
    token: str
    platform: str = ""


@router.get("/platforms", response_model=List[PlatformInfo])
async def list_platforms():
    """Status of every platform (connected / demo / needs_setup / unavailable)."""
    return [a.info() for a in registry.all_adapters()]


@router.get("/conversations", response_model=List[Conversation])
async def list_conversations(platform: Optional[str] = None):
    """Unified inbox: conversations merged across all platforms, newest first.

    Optional ?platform=telegram filters to one platform.
    """
    adapters = registry.all_adapters()
    if platform:
        try:
            adapters = [registry.get(Platform(platform))]
        except (ValueError, KeyError):
            raise HTTPException(404, f"Unknown platform '{platform}'")

    results = await asyncio.gather(
        *[a.get_conversations() for a in adapters], return_exceptions=True)
    merged: List[Conversation] = []
    for res in results:
        if isinstance(res, Exception):
            continue
        merged.extend(res)
    merged = [_apply_overlay(c) for c in merged]
    merged.sort(key=lambda c: c.timestamp or "", reverse=True)
    return merged


@router.get("/conversations/{platform}/{conversation_id}/messages",
            response_model=List[Message])
async def get_messages(platform: str, conversation_id: str, limit: int = 50):
    adapter = _adapter_or_404(platform)
    base = await adapter.get_messages(conversation_id, limit=limit)
    return base + live_store.extra_messages(platform, conversation_id)


@router.post("/conversations/{platform}/{conversation_id}/send",
             response_model=Message)
async def send_message(platform: str, conversation_id: str, body: SendBody):
    adapter = _adapter_or_404(platform)
    if not body.text.strip():
        raise HTTPException(400, "Empty message")
    try:
        return await adapter.send_message(conversation_id, body.text)
    except (NotImplementedError, RuntimeError) as exc:
        raise HTTPException(409, str(exc))


@router.get("/network", response_model=List[Peer])
async def get_network():
    """Everyone in your network who has shared status — with online state and a
    Google Maps link per peer who shared a location."""
    return presence.roster()


@router.post("/presence", response_model=Peer)
async def report_presence(report: PresenceReport):
    """A client shares its own signal/location. Marked as self."""
    peer = presence.report(report, is_self=True)
    await manager.broadcast({"type": "network_changed"})
    if report.status == "help":
        await manager.broadcast({
            "type": "help_alert",
            "id": peer.id,
            "name": peer.name,
        })
        await fcm.send_help(peer.name)  # closed-app push
    return peer


@router.get("/fcm/status")
async def fcm_status():
    """Whether push is configured and how many devices are registered."""
    return fcm.status()


@router.post("/fcm/register")
async def fcm_register(body: FcmToken):
    """A device registers its FCM token to receive help-alert push."""
    fcm.register_token(body.token, body.platform)
    return {"ok": True, "tokens": fcm.token_count()}


@ws_router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket, key: Optional[str] = Query(default=None)):
    """Live channel. The client only listens; we never expect inbound frames,
    but we drain them so the socket stays healthy."""
    if not ws_key_ok(key):
        await ws.close(code=1008)  # policy violation
        return
    await manager.connect(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        await manager.disconnect(ws)
    except Exception:
        await manager.disconnect(ws)


def _apply_overlay(c: Conversation) -> Conversation:
    """Fold any live (pushed/simulated) messages into the conversation summary."""
    latest = live_store.latest(c.platform.value, c.id)
    if latest is None:
        return c
    if not c.timestamp or latest.timestamp >= c.timestamp:
        c.last_message = latest.text
        c.last_sender = latest.sender_name
        c.timestamp = latest.timestamp
    c.unread_count += live_store.incoming_count(c.platform.value, c.id)
    return c


def _adapter_or_404(platform: str):
    try:
        return registry.get(Platform(platform))
    except (ValueError, KeyError):
        raise HTTPException(404, f"Unknown platform '{platform}'")
