"""Configuration loaded from environment variables / .env file.

Nothing here is required to run: with no credentials the app boots in demo
mode and serves realistic sample data so you can see the product immediately.
Add credentials for a platform and that adapter switches to live data.
"""
import os

from dotenv import load_dotenv

load_dotenv()


def _flag(name: str, default: bool = False) -> bool:
    val = os.getenv(name)
    if val is None:
        return default
    return val.strip().lower() in {"1", "true", "yes", "on"}


# When True, any adapter without credentials returns curated sample data.
# When False, unconfigured adapters return nothing.
DEMO_MODE = _flag("DEMO_MODE", default=True)

# --- Telegram (user account via Telethon) ---
TELEGRAM_API_ID = os.getenv("TELEGRAM_API_ID", "")
TELEGRAM_API_HASH = os.getenv("TELEGRAM_API_HASH", "")
TELEGRAM_SESSION = os.getenv("TELEGRAM_SESSION", "unified_messenger")

# --- Discord (bot token) ---
DISCORD_BOT_TOKEN = os.getenv("DISCORD_BOT_TOKEN", "")

# --- Slack (user or bot OAuth token, starts with xoxp-/xoxb-) ---
SLACK_TOKEN = os.getenv("SLACK_TOKEN", "")

# --- Substack (public newsletter RSS feeds, comma-separated URLs) ---
SUBSTACK_FEEDS = [u.strip() for u in os.getenv("SUBSTACK_FEEDS", "").split(",") if u.strip()]

# Server
HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8000"))

# Required for live platform credentials; optional for credential-free demo.
# If set, every REST call must send it as the
# `X-API-Key` header and the WebSocket must pass it as `?key=`. Leave blank for
# local-only development; ALWAYS set it before exposing the backend on a network.
API_KEY = os.getenv("API_KEY", "")

# Path to a Firebase service-account JSON key. When set (and firebase-admin is
# installed), the backend sends real FCM push for help alerts. Leave blank to
# disable push — everything else (WebSocket alerts, in-app banners) still works.
FIREBASE_CREDENTIALS = os.getenv("FIREBASE_CREDENTIALS", "")
