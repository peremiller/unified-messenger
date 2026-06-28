"""Unified data models shared across every platform adapter.

The whole point of this app is that a Telegram chat, a Discord channel and a
Slack DM all look the same to the Flutter client. Adapters are responsible for
mapping their platform's native shapes onto these models.
"""
from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


class Platform(str, Enum):
    telegram = "telegram"
    discord = "discord"
    slack = "slack"
    substack = "substack"
    skool = "skool"
    sms = "sms"
    whatsapp = "whatsapp"
    messenger = "messenger"
    viber = "viber"
    linkedin = "linkedin"


# Human-facing metadata for each platform: display name + brand colour (hex).
PLATFORM_META = {
    Platform.telegram:  {"label": "Telegram",  "color": "#2AABEE"},
    Platform.discord:   {"label": "Discord",   "color": "#5865F2"},
    Platform.slack:     {"label": "Slack",     "color": "#4A154B"},
    Platform.substack:  {"label": "Substack",  "color": "#FF6719"},
    Platform.skool:     {"label": "Skool",     "color": "#F2C94C"},
    Platform.sms:       {"label": "Text / SMS", "color": "#34C759"},
    Platform.whatsapp:  {"label": "WhatsApp",  "color": "#25D366"},
    Platform.messenger: {"label": "Messenger", "color": "#0084FF"},
    Platform.viber:     {"label": "Viber",     "color": "#7360F2"},
    Platform.linkedin:  {"label": "LinkedIn",  "color": "#0A66C2"},
}


class IntegrationStatus(str, Enum):
    connected = "connected"        # adapter is configured and live
    demo = "demo"                  # serving sample data (no creds yet)
    needs_setup = "needs_setup"    # API exists but no credentials supplied
    unavailable = "unavailable"    # no public API / blocked by platform ToS


class Message(BaseModel):
    id: str
    conversation_id: str
    platform: Platform
    sender_name: str
    sender_id: str = ""
    text: str = ""
    timestamp: str                       # ISO-8601 UTC
    is_from_me: bool = False
    attachments: List[str] = Field(default_factory=list)


class Conversation(BaseModel):
    id: str                              # adapter-local id (unique within platform)
    platform: Platform
    name: str
    is_group: bool = False
    avatar_url: Optional[str] = None
    last_message: str = ""
    last_sender: str = ""
    timestamp: str = ""                  # ISO-8601 UTC of last message
    unread_count: int = 0

    @property
    def uid(self) -> str:
        """Globally unique id across platforms (used by the client)."""
        return f"{self.platform.value}:{self.id}"


class PlatformInfo(BaseModel):
    platform: Platform
    label: str
    color: str
    status: IntegrationStatus
    detail: str = ""                     # why it's in this status / setup hint
    can_send: bool = False


class Peer(BaseModel):
    """A member of your network who self-reports presence/signal/location.

    You can never detect someone else's signal remotely — these fields are only
    populated for contacts who also run this app and opt in to share.
    """
    id: str
    name: str
    phone: str = ""
    is_self: bool = False
    online: bool = False                 # computed from last_seen freshness
    signal_level: int = 0                # 0-4 bars; -1 = unknown
    connection_type: str = "unknown"     # cellular | wifi | none | unknown
    status: str = "unknown"              # emergency check-in: safe | help | unknown
    lat: Optional[float] = None
    lng: Optional[float] = None
    last_seen: str = ""                  # ISO-8601 UTC
    maps_url: str = ""                   # computed Google Maps link


class PresenceReport(BaseModel):
    """What a client POSTs to share its own status."""
    id: str
    name: str
    phone: str = ""
    signal_level: int = 0
    connection_type: str = "unknown"
    status: str = "unknown"              # safe | help | unknown
    lat: Optional[float] = None
    lng: Optional[float] = None
