"""Curated sample data used when an adapter has no live credentials.

This keeps the whole app demonstrable end-to-end before you wire up a single
real token. Each platform gets a couple of believable conversations.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Dict, List

from .models import Conversation, Message, Platform

def _ago(minutes: int) -> str:
    # Anchor to the real clock so demo data reads naturally ("8m", "2h ago").
    return (datetime.now(timezone.utc) - timedelta(minutes=minutes)).isoformat()


# (conversation, [messages]) blueprints keyed by platform.
_BLUEPRINT = {
    Platform.telegram: [
        ("Family ❤️", True, [
            ("Mama", "Did you eat na?", 8, False),
            ("Me", "Not yet po, later na", 6, True),
            ("Kuya Jun", "Send GCash pls 😅", 3, False),
        ]),
        ("Dev Tips PH", True, [
            ("Ana", "New Flutter 3.44 dropped", 40, False),
            ("Me", "nice, upgrading now", 35, True),
        ]),
    ],
    Platform.discord: [
        ("indie-hackers / #general", True, [
            ("nightcoder", "shipped my MVP today 🚀", 22, False),
            ("Me", "congrats! link?", 20, True),
        ]),
        ("Maya", False, [
            ("Maya", "you around for a quick call?", 12, False),
        ]),
    ],
    Platform.slack: [
        ("acme-team / #engineering", True, [
            ("priya", "deploy is green ✅", 55, False),
            ("Me", "merging the hotfix", 50, True),
        ]),
        ("Daniel Cruz", False, [
            ("Daniel Cruz", "can you review the PR?", 18, False),
        ]),
    ],
    Platform.substack: [
        ("Lenny's Newsletter", False, [
            ("Lenny", "How the best PMs run discovery", 180, False),
        ]),
        ("The Pragmatic Engineer", False, [
            ("Gergely", "Inside a big-tech layoff week", 600, False),
        ]),
    ],
    Platform.skool: [
        ("Maker Community / Wins", True, [
            ("Sofia", "Hit $1k MRR this month 🎉", 240, False),
        ]),
    ],
    Platform.sms: [
        ("+63 917 555 0142", False, [
            ("Globe", "You have 2GB free data until tomorrow", 90, False),
        ]),
        ("Lola", False, [
            ("Lola", "Happy birthday apo!", 300, False),
        ]),
    ],
    Platform.whatsapp: [
        ("Barkada 🍻", True, [
            ("Migs", "Tara inom this weekend?", 15, False),
            ("Me", "G! Saturday", 14, True),
        ]),
    ],
    Platform.messenger: [
        ("Tita Beth", False, [
            ("Tita Beth", "Anak, available ka ba Sunday?", 70, False),
        ]),
    ],
    Platform.viber: [
        ("Office Group", True, [
            ("HR", "Payday moved to the 14th", 500, False),
        ]),
    ],
    Platform.linkedin: [
        ("Recruiter — Grace Tan", False, [
            ("Grace Tan", "Interested in a Senior Flutter role?", 130, False),
        ]),
    ],
}


def conversations_for(platform: Platform) -> List[Conversation]:
    out: List[Conversation] = []
    for idx, (name, is_group, msgs) in enumerate(_BLUEPRINT.get(platform, [])):
        last_sender, last_text, last_min, _ = msgs[-1]
        # treat messages not from me as unread (capped below)
        unread = sum(1 for m in msgs if not m[3])
        out.append(Conversation(
            id=f"demo-{idx}",
            platform=platform,
            name=name,
            is_group=is_group,
            last_message=last_text,
            last_sender=last_sender,
            timestamp=_ago(last_min),
            unread_count=min(unread, 3),
        ))
    return out


def messages_for(platform: Platform, conversation_id: str) -> List[Message]:
    try:
        idx = int(conversation_id.split("-")[-1])
        name, is_group, msgs = _BLUEPRINT[platform][idx]
    except (ValueError, IndexError, KeyError):
        return []
    out: List[Message] = []
    for m_idx, (sender, text, mins, from_me) in enumerate(msgs):
        out.append(Message(
            id=f"{conversation_id}-m{m_idx}",
            conversation_id=conversation_id,
            platform=platform,
            sender_name=sender,
            text=text,
            timestamp=_ago(mins),
            is_from_me=from_me,
        ))
    return out


def all_demo_conversations() -> Dict[Platform, List[Conversation]]:
    return {p: conversations_for(p) for p in Platform}
