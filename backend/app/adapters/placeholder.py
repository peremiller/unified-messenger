"""Placeholder adapters for platforms without a usable personal-inbox API.

These exist so the UI can show every requested platform with an honest status
instead of silently dropping them. In demo mode they serve sample data; in
production they report exactly why they can't go live and what (if anything)
could change that.
"""
from __future__ import annotations

from typing import List

from .. import config, demo_data
from ..models import Conversation, IntegrationStatus, Message, Platform
from .base import BaseAdapter


class PlaceholderAdapter(BaseAdapter):
    can_send = False

    def __init__(self, platform: Platform, status: IntegrationStatus, detail: str) -> None:
        self.platform = platform
        self._real_status = status
        self._detail = detail

    def status(self) -> IntegrationStatus:
        if config.DEMO_MODE:
            return IntegrationStatus.demo
        return self._real_status

    def detail(self) -> str:
        return self._detail

    async def get_conversations(self) -> List[Conversation]:
        return demo_data.conversations_for(self.platform) if config.DEMO_MODE else []

    async def get_messages(self, conversation_id: str, limit: int = 50) -> List[Message]:
        return demo_data.messages_for(self.platform, conversation_id) if config.DEMO_MODE else []


# Why each of these can't be a live personal-inbox integration today.
PLACEHOLDER_SPECS = {
    Platform.whatsapp: (
        IntegrationStatus.unavailable,
        "No personal-inbox API. WhatsApp Business API only sends to opted-in "
        "users; mirroring your personal chats violates WhatsApp ToS.",
    ),
    Platform.messenger: (
        IntegrationStatus.unavailable,
        "Meta removed 3rd-party access to personal Messenger inboxes. Only "
        "Pages can use the Messenger Platform API.",
    ),
    Platform.viber: (
        IntegrationStatus.unavailable,
        "Viber only offers a Bot/Business API for opted-in users — no access "
        "to your personal 1:1 or group chats.",
    ),
    Platform.linkedin: (
        IntegrationStatus.unavailable,
        "LinkedIn has no messaging API and prohibits scraping. Read-only "
        "mirroring is not permitted.",
    ),
    Platform.sms: (
        IntegrationStatus.needs_setup,
        "Android-only: a companion app can read SMS via the SMS permission. "
        "iOS blocks 3rd-party SMS access entirely.",
    ),
    Platform.skool: (
        IntegrationStatus.needs_setup,
        "No public API. A live integration would require fragile scraping of "
        "your Skool session and may break or violate ToS.",
    ),
}


def build_placeholders() -> List[PlaceholderAdapter]:
    return [PlaceholderAdapter(p, status, detail)
            for p, (status, detail) in PLACEHOLDER_SPECS.items()]
