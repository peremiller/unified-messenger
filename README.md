# Unified Messenger

One mobile inbox for messages and group chats across **Telegram, Discord, Slack,
Substack, Skool, SMS, WhatsApp, Messenger, Viber, and LinkedIn**.

A Flutter app (`app/`) talks to a Python FastAPI backend (`backend/`). The
backend has one *adapter* per platform behind a single unified API, so every
chat — a Telegram group, a Discord channel, a Slack DM — looks identical to the
app.

```
┌────────────┐     REST/JSON      ┌──────────────────────────────┐
│ Flutter app│ ─────────────────► │ FastAPI backend              │
│ (inbox UI) │ ◄───────────────── │  ├ telegram  (Telethon)      │
└────────────┘                    │  ├ discord   (REST)          │
                                  │  ├ slack     (slack_sdk)     │
                                  │  ├ substack  (RSS)           │
                                  │  └ placeholders (the rest)   │
                                  └──────────────────────────────┘
```

## What's real vs. what isn't

A true all-in-one inbox cannot legally or technically pull from every messaging
service. This project is honest about that — every platform shows its real
status in the app's **Accounts & Platforms** screen.

| Platform   | Live integration | How |
|------------|:---:|-----|
| Telegram   | ✅ | Telethon, your user account |
| Discord    | ✅ | Bot token, server channels |
| Slack      | ✅ | OAuth token, channels + DMs |
| Substack   | 🟡 | Public RSS feeds (read-only) |
| SMS        | 🟡 | Android companion app only (iOS blocks it) |
| Skool      | 🟡 | No public API (would need scraping) |
| WhatsApp   | ❌ | No personal-inbox API (ToS) |
| Messenger  | ❌ | Meta removed 3rd-party access |
| Viber      | ❌ | Bot API only, no personal chats |
| LinkedIn   | ❌ | No messaging API, scraping banned |

**Demo mode** (default) serves realistic sample data for *all* platforms so you
can explore the full app immediately. As you add credentials, each supported
platform switches from "Demo data" to "Connected" and serves your real messages.

## Run it

### 1. Backend
```bash
cd backend
./run.sh                      # creates venv, installs deps, starts on :8000
# or manually:
#   python3 -m venv venv && source venv/bin/activate
#   pip install -r requirements.txt
#   uvicorn app.main:app --reload --port 8000
```
Visit http://localhost:8000/api/platforms to see adapter statuses.

### 2. App
```bash
cd app
flutter pub get
flutter run                   # pick a device, or:
flutter run -d chrome         # web
```
- iOS simulator / web / desktop reach the backend at `localhost:8000`.
- Android emulator uses `10.0.2.2:8000` automatically.
- A physical phone needs your machine's LAN IP:
  `flutter run --dart-define=API_BASE=http://192.168.x.x:8000`

## Real-time updates

The inbox and open chats update live — no pull-to-refresh needed.

- The backend exposes a WebSocket at `ws://<host>/api/ws`. It pushes small
  events (`new_message`, `conversations_changed`); the app re-fetches the
  affected REST endpoint and the UI reorders itself. A green **● Live** dot in
  the app bar shows the socket is connected (it auto-reconnects with backoff).
- **Telegram** pushes instantly via Telethon's `NewMessage` events.
- **Slack / Discord / Substack** are covered by a 20s change-poller that only
  fires an event when something actually changed.
- **Demo mode** runs a simulator that injects a sample incoming message every
  ~15s (only while a client is connected), so you can watch live updates with no
  credentials at all.

## Connect Telegram (real account) — 3 steps

```bash
cd backend && source venv/bin/activate
pip install telethon                      # 1. install the client
# 2. put TELEGRAM_API_ID / TELEGRAM_API_HASH in .env (from my.telegram.org)
python login_telegram.py                  # 3. one-time phone-code login
```
After that, start the backend normally — Telegram connects automatically and
your real chats appear in the inbox, updating in real time.

## Going live with other platforms

Copy `backend/.env.example` to `backend/.env` and fill in only what you want:

- **Telegram** — `TELEGRAM_API_ID` / `TELEGRAM_API_HASH` from
  [my.telegram.org](https://my.telegram.org). First backend start prompts for
  your phone + login code in the console, then caches a session file.
- **Slack** — create an app at [api.slack.com/apps](https://api.slack.com/apps),
  add read/history/`chat:write` scopes, install it, put the token in `SLACK_TOKEN`.
- **Discord** — create a bot at
  [discord.com/developers](https://discord.com/developers/applications), enable
  the Message Content intent, invite it to your server, set `DISCORD_BOT_TOKEN`.
- **Substack** — `SUBSTACK_FEEDS=https://x.substack.com/feed,https://y.substack.com/feed`

Set `DEMO_MODE=false` once you're live to hide sample data for unconfigured
platforms.

## API

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/platforms` | Status of every platform |
| GET | `/api/conversations` | Unified inbox (add `?platform=telegram` to filter) |
| GET | `/api/conversations/{platform}/{id}/messages` | Messages in one chat |
| POST | `/api/conversations/{platform}/{id}/send` | Send a reply (`{"text": "..."}`) |

## Network, signal & location

A second purpose of the app (handy for disaster/emergency check-ins): see who in
your network is reachable and where. Three tabs at the bottom — **Chats ·
Network · Map**.

- **My signal** — your own connectivity, shown as signal bars. True cellular
  "bars" is Android-only; elsewhere this reflects the active connection type
  (cellular / Wi-Fi / offline), which is reliable on every platform.
- **Who has signal** — contacts who also run the app and opt in self-report
  their status; the Network tab shows the roster with each person's signal,
  online/offline state, and "last seen". **You can never detect someone else's
  signal or location remotely** — only what they choose to share.
- **Google Maps link** — every peer who shares a location gets a tappable pin
  that opens `https://www.google.com/maps?q=lat,lng`.
- **Heatmap** — the Map tab plots all shared locations on an OpenStreetMap and
  overlays a density heatmap (denser clusters burn hotter). Markers turn red for
  anyone flagged "need help".
- **Emergency check-in** — tap **I'm safe** or **Need help** to broadcast your
  status (with location). Anyone flagged "need help" surfaces in a red banner
  and sorts to the top of the roster, with a red map marker.
- **Contact matching** — with permission, the app reads your phone contacts and
  matches them to network members by phone number (last-10-digits, format-
  agnostic), showing "X of Y phone contacts are on the network" and labelling
  peers with your saved contact name. Falls back to sample contacts on web /
  when permission is denied.
- **Help alerts** — when any contact flags "need help", the backend pushes a
  `help_alert` over the WebSocket (in-app red banner + local notification) **and**
  sends a Firebase Cloud Messaging push so it reaches devices even when the app
  is fully closed — on **mobile and web** (PWA service worker + VAPID). FCM is
  code-complete but dormant until you add a Firebase project — see
  [app/fcm_setup/SETUP_FCM.md](app/fcm_setup/SETUP_FCM.md). Endpoints:
  `POST /api/fcm/register`, `GET /api/fcm/status`.
- **Heatmap filter** — filter the map by All / Needs help / Safe (with live
  counts) to isolate who needs help.

Endpoints: `GET /api/network` (roster), `POST /api/presence` (share your own
status). Demo mode seeds sample Philippine peers so all of this is visible
immediately. Real location sharing uses device GPS (permissions are declared for
Android/iOS); it degrades gracefully to "signal only" if location is denied.

## Security

- **Secrets stay local.** `.env` and Telegram `*.session` files are git-ignored
  (root + `backend/.gitignore`). Never commit them; the session file is a full
  login to your Telegram account.
- **API auth is opt-in.** With no `API_KEY` the backend is unauthenticated —
  fine for `localhost`, but it binds `0.0.0.0`, so anyone on your network could
  read/send your messages. Set `API_KEY` (a long random string) before exposing
  it. Then every REST call needs the `X-API-Key` header and the WebSocket needs
  `?key=`; the app supplies both from `--dart-define=API_KEY=YOUR_KEY`.
  ```bash
  # backend/.env
  API_KEY=$(openssl rand -hex 24)
  # app
  flutter run --dart-define=API_BASE=http://192.168.x.x:8000 --dart-define=API_KEY=<same value>
  ```
  The backend prints a warning at startup whenever auth is off.

## Adding a new platform

1. Create `backend/app/adapters/<name>_adapter.py` subclassing `BaseAdapter`.
2. Implement `status()`, `get_conversations()`, `get_messages()`, and optionally
   `send_message()`.
3. Register it in `backend/app/adapters/registry.py`.

Nothing in the app or API layer needs to change — the new platform appears
automatically with its own colour and badge.
