"""Firebase Cloud Messaging — real push for "need help" alerts.

Closed-app push is the one thing the WebSocket can't do (the socket dies when
the app is killed). FCM delivers to the device's OS notification tray even when
the app isn't running.

Activates only when FIREBASE_CREDENTIALS points at a service-account JSON key
*and* firebase-admin is installed. Otherwise every call no-ops gracefully, so
the rest of the app is unaffected. Token registry is in-memory (ephemeral) —
back it with a DB for production.
"""
from __future__ import annotations

import asyncio
from typing import Dict

from . import config

# device FCM token -> platform label
_tokens: Dict[str, str] = {}
_app = None
_init_attempted = False


def register_token(token: str, platform: str = "") -> None:
    if token:
        _tokens[token] = platform


def token_count() -> int:
    return len(_tokens)


def status() -> dict:
    return {
        "configured": bool(config.FIREBASE_CREDENTIALS),
        "tokens": len(_tokens),
    }


def _ensure_app():
    """Lazy, one-shot firebase-admin init."""
    global _app, _init_attempted
    if _init_attempted:
        return _app
    _init_attempted = True
    if not config.FIREBASE_CREDENTIALS:
        return None
    try:
        import firebase_admin
        from firebase_admin import credentials
        cred = credentials.Certificate(config.FIREBASE_CREDENTIALS)
        _app = firebase_admin.initialize_app(cred)
        print("[fcm] Firebase initialized — push enabled", flush=True)
    except Exception as exc:  # missing lib, bad key, etc.
        print(f"[fcm] disabled ({type(exc).__name__}: {exc})", flush=True)
        _app = None
    return _app


def _send_sync(name: str) -> int:
    app = _ensure_app()
    if app is None or not _tokens:
        return 0
    from firebase_admin import messaging
    message = messaging.MulticastMessage(
        tokens=list(_tokens.keys()),
        notification=messaging.Notification(
            title=f"🆘 {name} needs help",
            body=f'{name} flagged "Need help" in your network',
        ),
        data={"type": "help_alert", "name": name},
        android=messaging.AndroidConfig(priority="high"),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", content_available=True))),
    )
    resp = messaging.send_each_for_multicast(message)
    # Prune tokens the server says are dead so the registry self-heals.
    if resp.failure_count:
        all_tokens = list(_tokens.keys())
        for i, r in enumerate(resp.responses):
            if not r.success:
                _tokens.pop(all_tokens[i], None)
    return resp.success_count


async def send_help(name: str) -> int:
    """Send a help push to every registered device. Returns # delivered."""
    try:
        return await asyncio.to_thread(_send_sync, name)
    except Exception as exc:
        print(f"[fcm] send failed ({type(exc).__name__}: {exc})", flush=True)
        return 0
