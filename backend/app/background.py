"""Background loops that drive live updates.

- demo_simulator: in DEMO_MODE, periodically injects an incoming message into a
  sample conversation and pushes it, so the real-time pipeline is visible with
  zero credentials.
- change_poller: for genuinely connected adapters (Slack, Discord, Substack),
  polls periodically and pushes a refresh when the conversation list changes.
  Telegram doesn't need polling — it pushes instantly via Telethon events.
"""
from __future__ import annotations

import asyncio
import hashlib
import json

from . import config, fcm, live_store
from .adapters import registry
from .models import IntegrationStatus, Message, Platform
from .realtime import broadcast, manager

# Canned incoming messages cycled by the demo simulator, mapped to real demo
# conversation ids (see demo_data.py).
_DEMO_SCRIPT = [
    (Platform.telegram, "demo-0", "Mama", "Anak, on the way na ba kayo?"),
    (Platform.slack, "demo-1", "Daniel Cruz", "thanks! shipping it 🚀"),
    (Platform.discord, "demo-1", "Maya", "ping me when you're free"),
    (Platform.whatsapp, "demo-0", "Migs", "booked the table for 7 🍻"),
    (Platform.telegram, "demo-1", "Ana", "did you see the 3.44 changelog?"),
]


async def demo_simulator(interval: int = 15) -> None:
    if not config.DEMO_MODE:
        return
    i = 0
    while True:
        await asyncio.sleep(interval)
        if manager.count == 0:
            continue  # nobody listening — don't accumulate noise
        platform, conv_id, sender, text = _DEMO_SCRIPT[i % len(_DEMO_SCRIPT)]
        i += 1
        msg = Message(
            id=f"{conv_id}-live-{i}",
            conversation_id=conv_id,
            platform=platform,
            sender_name=sender,
            text=text,
            timestamp=_now_iso(),
            is_from_me=False,
        )
        live_store.add_message(msg)
        await broadcast({
            "type": "new_message",
            "platform": platform.value,
            "conversation_id": conv_id,
        })


async def help_simulator(interval: int = 40) -> None:
    """Demo only: periodically flip an online peer to 'help' (and reset the
    previous one), broadcasting a help_alert so the notification pipeline is
    visible without anyone manually tapping SOS."""
    if not config.DEMO_MODE:
        return
    candidates = presence.online_demo_ids()
    if not candidates:
        return
    i = 0
    previous = None
    while True:
        await asyncio.sleep(interval)
        if manager.count == 0:
            continue
        if previous is not None:
            presence.set_status(previous, "safe")
        pid = candidates[i % len(candidates)]
        i += 1
        peer = presence.set_status(pid, "help")
        previous = pid
        if peer is not None:
            await broadcast({"type": "help_alert", "id": peer.id,
                             "name": peer.name})
            await broadcast({"type": "network_changed"})
            await fcm.send_help(peer.name)  # no-op until FCM is configured


async def change_poller(interval: int = 20) -> None:
    signatures: dict = {}
    while True:
        await asyncio.sleep(interval)
        if manager.count == 0:
            continue
        for adapter in registry.all_adapters():
            if adapter.status() != IntegrationStatus.connected:
                continue
            if adapter.platform == Platform.telegram:
                continue  # event-driven, no polling needed
            try:
                convs = await adapter.get_conversations()
            except Exception:
                continue
            sig = _signature(convs)
            prev = signatures.get(adapter.platform)
            if prev is not None and prev != sig:
                await broadcast({
                    "type": "conversations_changed",
                    "platform": adapter.platform.value,
                })
            signatures[adapter.platform] = sig


def _signature(convs) -> str:
    payload = json.dumps(
        [[c.id, c.last_message, c.timestamp, c.unread_count] for c in convs],
        sort_keys=True)
    return hashlib.sha1(payload.encode()).hexdigest()


def _now_iso() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat()
