"""Regression: inbox overlay must not alter adapter-cached source records."""
import unittest
from unittest.mock import patch

from app import live_store
from app.api.routes import _apply_overlay
from app.models import Conversation, Message, Platform


class OverlaySnapshotTests(unittest.TestCase):
    def setUp(self):
        self.source = Conversation(
            id="chat-1", platform=Platform.telegram, name="Existing chat",
            last_message="Original", last_sender="A",
            timestamp="2026-11-22T00:00:00+00:00", unread_count=2,
        )
        self.pushed = Message(
            id="pushed-1", conversation_id="chat-1", platform=Platform.telegram,
            sender_name="B", text="New message",
            timestamp="2026-11-22T01:00:00+00:00",
        )

    def test_repeated_refresh_keeps_original_and_count_stable(self):
        with patch.object(live_store, "latest", return_value=self.pushed), \
             patch.object(live_store, "incoming_count", return_value=1):
            first = _apply_overlay(self.source)
            second = _apply_overlay(self.source)
        for result in (first, second):
            self.assertIsNot(result, self.source)
            self.assertEqual(result.unread_count, 3)
            self.assertEqual(result.last_message, "New message")
            self.assertEqual(result.last_sender, "B")
        self.assertEqual(self.source.unread_count, 2)
        self.assertEqual(self.source.last_message, "Original")
        self.assertEqual(self.source.timestamp, "2026-11-22T00:00:00+00:00")

    def test_older_live_message_does_not_replace_newer_platform_summary(self):
        self.pushed.timestamp = "2026-11-21T00:00:00+00:00"
        with patch.object(live_store, "latest", return_value=self.pushed), \
             patch.object(live_store, "incoming_count", return_value=1):
            result = _apply_overlay(self.source)
        self.assertEqual(result.last_message, "Original")
        self.assertEqual(result.unread_count, 3)
        self.assertEqual(self.source.unread_count, 2)

    def test_no_overlay_retains_existing_behavior(self):
        with patch.object(live_store, "latest", return_value=None):
            self.assertIs(_apply_overlay(self.source), self.source)


if __name__ == "__main__":
    unittest.main()
