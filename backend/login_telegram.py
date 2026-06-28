#!/usr/bin/env python3
"""One-time Telegram login.

Run this once after putting TELEGRAM_API_ID / TELEGRAM_API_HASH in .env:

    cd backend
    source venv/bin/activate
    pip install telethon
    python login_telegram.py

It will ask for your phone number and the login code Telegram sends you (and
your 2FA password if you have one), then save a reusable session file. After
that the backend connects automatically with no prompts.
"""
import asyncio

from app import config

try:
    from telethon import TelegramClient
except ImportError:
    raise SystemExit("Telethon not installed. Run: pip install telethon")


async def main() -> None:
    if not (config.TELEGRAM_API_ID and config.TELEGRAM_API_HASH):
        raise SystemExit(
            "Missing credentials. Set TELEGRAM_API_ID and TELEGRAM_API_HASH "
            "in backend/.env (get them from https://my.telegram.org).")
    client = TelegramClient(
        config.TELEGRAM_SESSION,
        int(config.TELEGRAM_API_ID),
        config.TELEGRAM_API_HASH,
    )
    await client.start()
    me = await client.get_me()
    name = getattr(me, "first_name", "") or getattr(me, "username", "you")
    print(f"\n✅ Logged in as {name}. Session saved to "
          f"'{config.TELEGRAM_SESSION}.session'.")
    print("You can now start the backend — Telegram will connect automatically.")
    await client.disconnect()


if __name__ == "__main__":
    asyncio.run(main())
