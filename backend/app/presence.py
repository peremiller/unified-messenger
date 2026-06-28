"""Presence/signal/location store for the network.

Peers (contacts who also run this app) POST their own status; everyone can read
the roster. Online-ness is derived from how recently a peer reported. There is
no way to learn a peer's signal or location unless they share it — this store
only holds what peers voluntarily send (plus demo seed data).

In-memory and ephemeral; a real deployment would back this with a database.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from . import config
from .models import Peer, PresenceReport

# A peer is "online" if it reported within this window.
ONLINE_WINDOW = timedelta(minutes=5)

_peers: Dict[str, Peer] = {}
# For demo peers only: their intended "minutes since last seen", re-applied on
# every read so the online ones stay live instead of aging out after 5 min.
_demo_offset: Dict[str, int] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _maps_url(lat: Optional[float], lng: Optional[float]) -> str:
    if lat is None or lng is None:
        return ""
    return f"https://www.google.com/maps?q={lat},{lng}"


def _is_online(last_seen: str) -> bool:
    dt = datetime.fromisoformat(last_seen) if last_seen else None
    if dt is None:
        return False
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return _now() - dt <= ONLINE_WINDOW


def report(r: PresenceReport, is_self: bool = False) -> Peer:
    now_iso = _now().isoformat()
    peer = Peer(
        id=r.id,
        name=r.name,
        phone=r.phone,
        is_self=is_self,
        signal_level=r.signal_level,
        connection_type=r.connection_type,
        status=r.status,
        lat=r.lat,
        lng=r.lng,
        last_seen=now_iso,
        online=True,
        maps_url=_maps_url(r.lat, r.lng),
    )
    _peers[r.id] = peer
    return peer


def set_status(peer_id: str, status: str) -> Peer | None:
    """Force a peer's emergency status (used by the demo help simulator)."""
    p = _peers.get(peer_id)
    if p is None:
        return None
    p.status = status
    return p


def online_demo_ids() -> List[str]:
    """Demo peer ids currently considered online — candidates for the simulator."""
    return [pid for pid, mins in _demo_offset.items()
            if _is_online((_now() - timedelta(minutes=mins)).isoformat())]


def roster() -> List[Peer]:
    now = _now()
    out: List[Peer] = []
    for p in _peers.values():
        # Keep demo peers anchored to their intended freshness relative to now.
        if p.id in _demo_offset:
            p.last_seen = (now - timedelta(minutes=_demo_offset[p.id])).isoformat()
        p.online = _is_online(p.last_seen)
        p.maps_url = _maps_url(p.lat, p.lng)
        out.append(p)
    # emergency "help" first, then online, then strongest signal, then name
    out.sort(key=lambda p: (
        p.status != "help", not p.online, -p.signal_level, p.name.lower()))
    return out


def seed_demo() -> None:
    """Populate sample Philippine peers so the network is visible without any
    real reporters. Only runs in demo mode."""
    if not config.DEMO_MODE or _peers:
        return
    now = _now()

    def fresh(mins: int) -> str:
        return (now - timedelta(minutes=mins)).isoformat()

    samples = [
        # name, phone, signal, type, lat, lng, minutes_since_seen, status
        ("Mama",        "+639170000001", 4, "wifi",     14.5995, 120.9842, 1,  "safe"),    # Manila
        ("Kuya Jun",    "+639170000002", 3, "cellular", 14.6760, 121.0437, 2,  "safe"),    # QC
        ("Tita Beth",   "+639170000003", 2, "cellular", 10.3157, 123.8854, 3,  "unknown"), # Cebu
        ("Migs",        "+639170000004", 4, "wifi",      7.1907, 125.4553, 1,  "safe"),    # Davao
        ("Ana",         "+639170000005", 1, "cellular", 16.4023, 120.5960, 4,  "help"),    # Baguio
        ("Lola",        "+639170000006", 3, "cellular", 10.7202, 122.5621, 2,  "unknown"), # Iloilo
        ("Daniel Cruz", "+639170000007", 2, "cellular",  8.4542, 124.6319, 3,  "unknown"), # CDO
        ("Sofia",       "+639170000008", 0, "none",     11.2444, 125.0048, 90, "help"),    # Tacloban (offline, last: help)
        ("Grace Tan",   "+639170000009", 3, "wifi",     13.7565, 121.0583, 2,  "safe"),    # Batangas
        ("Marco",       "+639170000010", 0, "none",      9.7392, 118.7353, 240,"unknown"), # Palawan (offline)
    ]
    for name, phone, sig, ctype, lat, lng, mins, status in samples:
        pid = f"demo-{phone}"
        _demo_offset[pid] = mins
        _peers[pid] = Peer(
            id=pid, name=name, phone=phone, is_self=False,
            signal_level=sig, connection_type=ctype, status=status,
            lat=lat, lng=lng,
            last_seen=fresh(mins), online=_is_online(fresh(mins)),
            maps_url=_maps_url(lat, lng),
        )
