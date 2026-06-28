"""In-memory overlay of messages that arrived (or were sent) at runtime.

Adapters fetch a snapshot from their platform; anything that streams in live
(a Telegram event, a simulated demo message, an optimistic send) is appended
here and merged into the REST responses. This keeps a pushed "new message"
event consistent with what the client sees when it re-fetches.

It is intentionally ephemeral — restart clears it; the source of truth remains
each platform.
"""
from __future__ import annotations

from collections import defaultdict
from typing import Dict, List, Tuple

from .models import Message

_overlay: Dict[Tuple[str, str], List[Message]] = defaultdict(list)


def add_message(msg: Message) -> None:
    _overlay[(msg.platform.value, msg.conversation_id)].append(msg)


def extra_messages(platform: str, conversation_id: str) -> List[Message]:
    return list(_overlay.get((platform, conversation_id), []))


def latest(platform: str, conversation_id: str) -> Message | None:
    msgs = _overlay.get((platform, conversation_id))
    return msgs[-1] if msgs else None


def incoming_count(platform: str, conversation_id: str) -> int:
    """Live messages not sent by me — counted toward unread."""
    return sum(1 for m in _overlay.get((platform, conversation_id), [])
               if not m.is_from_me)
