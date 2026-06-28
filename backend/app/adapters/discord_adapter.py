"""Discord adapter — server channels via the Discord REST API (bot token).

Setup:
  1. Create a bot at https://discord.com/developers/applications
  2. Enable the MESSAGE CONTENT intent, copy the bot token into DISCORD_BOT_TOKEN
  3. Invite the bot to your server(s) with Read Messages / Send Messages perms

Note: bots see the channels of servers they're in. Personal 1:1 DMs between
two human users are not accessible to bots (Discord restriction).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import List

from .. import config, demo_data
from ..models import Conversation, IntegrationStatus, Message, Platform
from .base import BaseAdapter

try:
    import aiohttp
    _HAS_AIOHTTP = True
except ImportError:
    _HAS_AIOHTTP = False

_API = "https://discord.com/api/v10"


def _snowflake_to_iso(sid: str) -> str:
    try:
        ms = (int(sid) >> 22) + 1420070400000
        return datetime.fromtimestamp(ms / 1000, tz=timezone.utc).isoformat()
    except (ValueError, TypeError):
        return ""


class DiscordAdapter(BaseAdapter):
    platform = Platform.discord
    can_send = True

    def __init__(self) -> None:
        self._session = None
        self._self_id = ""
        self._configured = bool(config.DISCORD_BOT_TOKEN)

    @property
    def _headers(self):
        return {"Authorization": f"Bot {config.DISCORD_BOT_TOKEN}"}

    async def start(self) -> None:
        if not (self._configured and _HAS_AIOHTTP):
            return
        self._session = aiohttp.ClientSession()
        try:
            async with self._session.get(f"{_API}/users/@me", headers=self._headers) as r:
                if r.status == 200:
                    self._self_id = (await r.json()).get("id", "")
                else:
                    await self._session.close()
                    self._session = None
        except Exception:
            self._session = None

    async def stop(self) -> None:
        if self._session:
            await self._session.close()

    def status(self) -> IntegrationStatus:
        if self._session is not None:
            return IntegrationStatus.connected
        if not self._configured:
            return IntegrationStatus.demo if config.DEMO_MODE else IntegrationStatus.needs_setup
        return IntegrationStatus.needs_setup

    def detail(self) -> str:
        if self.status() == IntegrationStatus.connected:
            return "Live — synced from your Discord servers"
        if not _HAS_AIOHTTP:
            return "Run: pip install aiohttp"
        return "Add DISCORD_BOT_TOKEN from discord.com/developers"

    async def get_conversations(self) -> List[Conversation]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.conversations_for(self.platform) if config.DEMO_MODE else []
        out: List[Conversation] = []
        async with self._session.get(f"{_API}/users/@me/guilds", headers=self._headers) as r:
            guilds = await r.json() if r.status == 200 else []
        for g in guilds:
            async with self._session.get(
                    f"{_API}/guilds/{g['id']}/channels", headers=self._headers) as r:
                channels = await r.json() if r.status == 200 else []
            for ch in channels:
                if ch.get("type") != 0:  # 0 = guild text channel
                    continue
                out.append(Conversation(
                    id=ch["id"],
                    platform=self.platform,
                    name=f"{g['name']} / #{ch['name']}",
                    is_group=True,
                ))
        return out

    async def get_messages(self, conversation_id: str, limit: int = 50) -> List[Message]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.messages_for(self.platform, conversation_id) if config.DEMO_MODE else []
        url = f"{_API}/channels/{conversation_id}/messages?limit={limit}"
        async with self._session.get(url, headers=self._headers) as r:
            raw = await r.json() if r.status == 200 else []
        out: List[Message] = []
        for m in reversed(raw):
            author = m.get("author", {})
            uid = author.get("id", "")
            out.append(Message(
                id=m.get("id", ""),
                conversation_id=conversation_id,
                platform=self.platform,
                sender_name="Me" if uid == self._self_id else author.get("username", "Unknown"),
                text=m.get("content", ""),
                timestamp=m.get("timestamp") or _snowflake_to_iso(m.get("id", "")),
                is_from_me=uid == self._self_id,
            ))
        return out

    async def send_message(self, conversation_id: str, text: str) -> Message:
        if self.status() != IntegrationStatus.connected:
            raise RuntimeError("Discord not connected")
        url = f"{_API}/channels/{conversation_id}/messages"
        async with self._session.post(url, headers=self._headers, json={"content": text}) as r:
            m = await r.json()
        return Message(
            id=m.get("id", ""),
            conversation_id=conversation_id,
            platform=self.platform,
            sender_name="Me",
            text=text,
            timestamp=m.get("timestamp", ""),
            is_from_me=True,
        )
