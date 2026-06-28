"""Slack adapter — real conversations via the Slack Web API.

Setup:
  1. Create an app at https://api.slack.com/apps
  2. Add scopes: channels:read, groups:read, im:read, channels:history,
     groups:history, im:history, users:read, chat:write
  3. Install to your workspace and copy the token (xoxp-/xoxb-) into SLACK_TOKEN
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Dict, List

from .. import config, demo_data
from ..models import Conversation, IntegrationStatus, Message, Platform
from .base import BaseAdapter

try:
    from slack_sdk.web.async_client import AsyncWebClient
    _HAS_SLACK = True
except ImportError:
    _HAS_SLACK = False


def _ts_to_iso(ts: str) -> str:
    try:
        return datetime.fromtimestamp(float(ts), tz=timezone.utc).isoformat()
    except (ValueError, TypeError):
        return ""


class SlackAdapter(BaseAdapter):
    platform = Platform.slack
    can_send = True

    def __init__(self) -> None:
        self._client = None
        self._users: Dict[str, str] = {}
        self._self_id = ""
        self._configured = bool(config.SLACK_TOKEN)

    async def start(self) -> None:
        if not (self._configured and _HAS_SLACK):
            return
        self._client = AsyncWebClient(token=config.SLACK_TOKEN)
        try:
            auth = await self._client.auth_test()
            self._self_id = auth.get("user_id", "")
        except Exception:
            self._client = None

    def status(self) -> IntegrationStatus:
        if self._client is not None:
            return IntegrationStatus.connected
        if not self._configured:
            return IntegrationStatus.demo if config.DEMO_MODE else IntegrationStatus.needs_setup
        return IntegrationStatus.needs_setup

    def detail(self) -> str:
        if self.status() == IntegrationStatus.connected:
            return "Live — synced from your Slack workspace"
        if not _HAS_SLACK:
            return "Run: pip install slack_sdk"
        return "Add SLACK_TOKEN (xoxp-/xoxb-) from api.slack.com/apps"

    async def _user_name(self, uid: str) -> str:
        if not uid:
            return "Unknown"
        if uid not in self._users:
            try:
                resp = await self._client.users_info(user=uid)
                prof = resp["user"]
                self._users[uid] = prof.get("real_name") or prof.get("name") or uid
            except Exception:
                self._users[uid] = uid
        return self._users[uid]

    async def get_conversations(self) -> List[Conversation]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.conversations_for(self.platform) if config.DEMO_MODE else []
        out: List[Conversation] = []
        resp = await self._client.conversations_list(
            types="public_channel,private_channel,im,mpim", limit=50)
        for ch in resp.get("channels", []):
            is_im = ch.get("is_im", False)
            if is_im:
                name = await self._user_name(ch.get("user", ""))
            else:
                name = "#" + ch.get("name", "channel")
            out.append(Conversation(
                id=ch["id"],
                platform=self.platform,
                name=name,
                is_group=not is_im,
                unread_count=ch.get("unread_count", 0) or 0,
            ))
        return out

    async def get_messages(self, conversation_id: str, limit: int = 50) -> List[Message]:
        if self.status() != IntegrationStatus.connected:
            return demo_data.messages_for(self.platform, conversation_id) if config.DEMO_MODE else []
        resp = await self._client.conversations_history(channel=conversation_id, limit=limit)
        out: List[Message] = []
        for m in reversed(resp.get("messages", [])):
            uid = m.get("user", "")
            out.append(Message(
                id=m.get("ts", ""),
                conversation_id=conversation_id,
                platform=self.platform,
                sender_name="Me" if uid == self._self_id else await self._user_name(uid),
                text=m.get("text", ""),
                timestamp=_ts_to_iso(m.get("ts", "")),
                is_from_me=uid == self._self_id,
            ))
        return out

    async def send_message(self, conversation_id: str, text: str) -> Message:
        if self.status() != IntegrationStatus.connected:
            raise RuntimeError("Slack not connected")
        resp = await self._client.chat_postMessage(channel=conversation_id, text=text)
        return Message(
            id=resp.get("ts", ""),
            conversation_id=conversation_id,
            platform=self.platform,
            sender_name="Me",
            text=text,
            timestamp=_ts_to_iso(resp.get("ts", "")),
            is_from_me=True,
        )
