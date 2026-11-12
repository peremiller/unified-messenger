"""Unified Messenger backend — FastAPI entrypoint.

Run:  uvicorn app.main:app --reload --port 8000
"""
import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import background, config, presence
from .adapters import registry
from .api.routes import router, ws_router
from .security import ensure_live_integrations_protected


@asynccontextmanager
async def lifespan(_app: FastAPI):
    ensure_live_integrations_protected()
    await registry.start_all()
    presence.seed_demo()
    if not config.API_KEY:
        print("[security] API_KEY not set — the API and WebSocket are "
              "UNAUTHENTICATED. Fine for localhost; set API_KEY before exposing "
              "this backend on a network or deploying it.", flush=True)
    tasks = [
        asyncio.create_task(background.demo_simulator()),
        asyncio.create_task(background.change_poller()),
        asyncio.create_task(background.help_simulator()),
    ]
    yield
    for t in tasks:
        t.cancel()
    await registry.stop_all()


app = FastAPI(title="Unified Messenger", version="0.1.0", lifespan=lifespan)

# The Flutter client may run from web/emulator/device, so allow all origins.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)
app.include_router(ws_router)


@app.get("/")
async def health():
    return {"status": "ok", "demo_mode": config.DEMO_MODE, "service": "unified-messenger"}
