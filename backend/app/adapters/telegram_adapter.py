"""Telegram adapter — real personal inbox via Telethon (user account).

Setup:
  1. Get api_id / api_hash from https://my.telegram.org -> API development tools
  2. Put them in .env as TELEGRAM_API_ID / TELEGRAM_API_HASH
  3. First run will prompt for phone + login code in the backend console; that
     creates a reusable session file so subsequent runs are non-interactive.
"""
from __future__ import annotations

from typing import List

from .. import config, demo_data
from ..models import Conversation, IntegrationStatus, Message, Platform
from .base import BaseAdapter

try:
    from telethon import TelegramClient, events
    from telethon.tl.types import User
    _HAS_TELETHON = True
except ImportError:  # library optional until you actually use Telegram
    _HAS_TELETHON = False


class TelegramAdapter(BaseAdapter):
    platform = Platform.telegram
    can_send = True

    def __init__(self) -> None:
        self._client = None
        self._configured = bool(config.TELEGRAM_API_ID and config.TELEGRAM_API_HASH)

    async def start(self) -> None:
        if not (self._configured and _HAS_TELETHON):
            return
        self._client = TelegramClient(
            config.TELEGRAM_SESSION,
            int(config.TELEGRAM_API_ID),
            config.TELEGRAM_API_HASH,
        )
        await self._client.start()  # interactive on first login only
        self._register_live_push()

    def _register_live_push(self) -> None:
        """Push a live event on every incoming Telegram message. The client
        re-fetches real history/conversations — Telegram is the source of truth,
        so we don't write to the overlay (that would duplicate the message)."""
        from ..realtime import broadcast

        @self._client.on(events.NewMessage(incoming=True))
        async def _on_new(event):  # noqa: ANN001
            try:
                await broadcast({
                    "type": "new_message",
                    "platform": self.platform.value,
                    "conversation_id": str(event.chat_id),
                })
            except Exception:
                pass

    async def stop(self) -> None:
        if self._client:
            await self._client.disconnect()

    def status(self) -> IntegrationStatus:
        if self._client is not None and self._client.is_connected():
            return IntegrationStatus.connected
        if not self._configured:
            return IntegrationStatus.demo if config.DEMO_MODE else IntegrationStatus.needs_setup
        # configured but not connected (missing library or login pending)
        return IntegrationStatus.needs_setup

    def detail(self) -> str:
        if self.status() == IntegrationStatus.connected:
            return "Live — synced from your Telegram account"
        if not _HAS_TELETHON:
            return "Run: pip install telethon"
        return "Add TELEGRAM_API_ID / TELEGRAM_API_HASH from my.telegram.org"

    async def get_conversations(self) -> List[Conversation]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.conversations_for(self.platform) if config.DEMO_MODE else []
        out: List[Conversation] = []
        async for dialog in self._client.iter_dialogs(limit=40):
            ent = dialog.entity
            out.append(Conversation(
                id=str(dialog.id),
                platform=self.platform,
                name=dialog.name or "Telegram chat",
                is_group=not isinstance(ent, User),
                last_message=(dialog.message.message or "") if dialog.message else "",
                timestamp=dialog.date.isoformat() if dialog.date else "",
                unread_count=dialog.unread_count,
            ))
        return out

    async def get_messages(self, conversation_id: str, limit: int = 50) -> List[Message]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.messages_for(self.platform, conversation_id) if config.DEMO_MODE else []
        out: List[Message] = []
        async for msg in self._client.iter_messages(int(conversation_id), limit=limit):
            sender = await msg.get_sender()
            name = getattr(sender, "first_name", None) or getattr(sender, "title", None) or "Unknown"
            out.append(Message(
                id=str(msg.id),
                conversation_id=conversation_id,
                platform=self.platform,
                sender_name="Me" if msg.out else name,
                text=msg.message or "",
                timestamp=msg.date.isoformat() if msg.date else "",
                is_from_me=bool(msg.out),
            ))
        return list(reversed(out))

    async def send_message(self, conversation_id: str, text: str) -> Message:
        if self.status() != IntegrationStatus.connected:
            raise RuntimeError("Telegram not connected")
        sent = await self._client.send_message(int(conversation_id), text)
        return Message(
            id=str(sent.id),
            conversation_id=conversation_id,
            platform=self.platform,
            sender_name="Me",
            text=text,
            timestamp=sent.date.isoformat() if sent.date else "",
            is_from_me=True,
        )
