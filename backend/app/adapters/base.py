"""Adapter contract every platform integration implements.

An adapter is the only thing that knows about a specific platform's API. The
rest of the backend talks to adapters purely through this interface, so adding
a new platform is "write one adapter, register it" and nothing else changes.
"""
from __future__ import annotations

from typing import List

from ..models import (
    Conversation,
    IntegrationStatus,
    Message,
    Platform,
    PLATFORM_META,
    PlatformInfo,
)


class BaseAdapter:
    platform: Platform
    can_send: bool = False

    # ---- lifecycle ----------------------------------------------------
    async def start(self) -> None:
        """Open any long-lived client/connection. Safe to no-op."""

    async def stop(self) -> None:
        """Tear down connections. Safe to no-op."""

    # ---- status -------------------------------------------------------
    def status(self) -> IntegrationStatus:
        """Override to report real connection state."""
        return IntegrationStatus.unavailable

    def detail(self) -> str:
        """Short human explanation of the current status / setup hint."""
        return ""

    def info(self) -> PlatformInfo:
        meta = PLATFORM_META[self.platform]
        return PlatformInfo(
            platform=self.platform,
            label=meta["label"],
            color=meta["color"],
            status=self.status(),
            detail=self.detail(),
            can_send=self.can_send and self.status() == IntegrationStatus.connected,
        )

    # ---- data ---------------------------------------------------------
    async def get_conversations(self) -> List[Conversation]:
        return []

    async def get_messages(self, conversation_id: str, limit: int = 50) -> List[Message]:
        return []

    async def send_message(self, conversation_id: str, text: str) -> Message:
        raise NotImplementedError(f"{self.platform.value} does not support sending")
