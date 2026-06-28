"""Substack adapter — newsletter posts via public RSS feeds.

Substack has no chat API, but every newsletter exposes an RSS feed at
<publication>.substack.com/feed. We surface each newsletter as a "conversation"
and its recent posts as messages. Read-only by nature.

Setup: SUBSTACK_FEEDS=https://lenny.substack.com/feed,https://...
"""
from __future__ import annotations

from typing import List

from .. import config, demo_data
from ..models import Conversation, IntegrationStatus, Message, Platform
from .base import BaseAdapter

try:
    import feedparser
    _HAS_FEED = True
except ImportError:
    _HAS_FEED = False


class SubstackAdapter(BaseAdapter):
    platform = Platform.substack
    can_send = False

    def __init__(self) -> None:
        self._configured = bool(config.SUBSTACK_FEEDS)
        # map a stable conversation id -> feed url
        self._feeds = {f"feed-{i}": url for i, url in enumerate(config.SUBSTACK_FEEDS)}

    def status(self) -> IntegrationStatus:
        if self._configured and _HAS_FEED:
            return IntegrationStatus.connected
        if not _HAS_FEED:
            return IntegrationStatus.needs_setup
        return IntegrationStatus.demo if config.DEMO_MODE else IntegrationStatus.needs_setup

    def detail(self) -> str:
        if self.status() == IntegrationStatus.connected:
            return "Live — latest posts from your Substack feeds"
        if not _HAS_FEED:
            return "Run: pip install feedparser"
        return "Add SUBSTACK_FEEDS=<feed-url>,<feed-url> in .env"

    async def get_conversations(self) -> List[Conversation]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.conversations_for(self.platform) if config.DEMO_MODE else []
        out: List[Conversation] = []
        for cid, url in self._feeds.items():
            parsed = feedparser.parse(url)
            title = parsed.feed.get("title", "Substack")
            entries = parsed.entries or []
            last = entries[0] if entries else None
            out.append(Conversation(
                id=cid,
                platform=self.platform,
                name=title,
                is_group=False,
                last_message=last.get("title", "") if last else "",
                timestamp=last.get("published", "") if last else "",
            ))
        return out

    async def get_messages(self, conversation_id: str, limit: int = 20) -> List[Message]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.messages_for(self.platform, conversation_id) if config.DEMO_MODE else []
        url = self._feeds.get(conversation_id)
        if not url:
            return []
        parsed = feedparser.parse(url)
        title = parsed.feed.get("title", "Substack")
        out: List[Message] = []
        for i, entry in enumerate(parsed.entries[:limit]):
            out.append(Message(
                id=f"{conversation_id}-{i}",
                conversation_id=conversation_id,
                platform=self.platform,
                sender_name=title,
                text=entry.get("title", ""),
                timestamp=entry.get("published", ""),
                is_from_me=False,
                attachments=[entry.get("link", "")] if entry.get("link") else [],
            ))
        return list(reversed(out))
