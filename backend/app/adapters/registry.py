"""Central registry of every adapter, keyed by platform.

The API layer only talks to this module — it never imports a concrete adapter.
"""
from __future__ import annotations

from typing import Dict, List

from ..models import Platform
from .base import BaseAdapter
from .discord_adapter import DiscordAdapter
from .placeholder import build_placeholders
from .slack_adapter import SlackAdapter
from .substack_adapter import SubstackAdapter
from .telegram_adapter import TelegramAdapter

_adapters: Dict[Platform, BaseAdapter] = {}


def _register(adapter: BaseAdapter) -> None:
    _adapters[adapter.platform] = adapter


def build_registry() -> None:
    """Instantiate all adapters once at startup."""
    if _adapters:
        return
    _register(TelegramAdapter())
    _register(DiscordAdapter())
    _register(SlackAdapter())
    _register(SubstackAdapter())
    for ph in build_placeholders():
        _register(ph)


async def start_all() -> None:
    build_registry()
    for adapter in _adapters.values():
        try:
            await adapter.start()
        except Exception as exc:  # never let one bad adapter kill startup
            # Log only the exception type, not the message — adapter errors can
            # echo back request payloads or tokens.
            print(f"[registry] {adapter.platform.value} failed to start "
                  f"({type(exc).__name__})")


async def stop_all() -> None:
    for adapter in _adapters.values():
        try:
            await adapter.stop()
        except Exception:
            pass


def all_adapters() -> List[BaseAdapter]:
    return list(_adapters.values())


def get(platform: Platform) -> BaseAdapter:
    return _adapters[platform]
