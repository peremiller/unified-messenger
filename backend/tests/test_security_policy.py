"""Regression tests: public demo remains possible, live credentials fail closed."""
import unittest
from unittest.mock import patch

from app import config
from app.security import ensure_live_integrations_protected


SAFE_DEMO_CONFIG = {
    "API_KEY": "",
    "TELEGRAM_API_ID": "",
    "TELEGRAM_API_HASH": "",
    "DISCORD_BOT_TOKEN": "",
    "SLACK_TOKEN": "",
    "FIREBASE_CREDENTIALS": "",
}


class LiveIntegrationSecurityTests(unittest.TestCase):
    def test_public_demo_without_private_integrations_is_unchanged(self):
        with patch.multiple(config, **SAFE_DEMO_CONFIG):
            ensure_live_integrations_protected()

    def test_live_integrations_refuse_unauthenticated_startup(self):
        integrations = (
            {"TELEGRAM_API_ID": "1234", "TELEGRAM_API_HASH": "example"},
            {"DISCORD_BOT_TOKEN": "example"},
            {"SLACK_TOKEN": "example"},
            {"FIREBASE_CREDENTIALS": "/tmp/service.json"},
        )
        for integration in integrations:
            with self.subTest(integration=next(iter(integration))):
                with patch.multiple(config, **{**SAFE_DEMO_CONFIG, **integration}):
                    with self.assertRaisesRegex(RuntimeError, "API_KEY is required"):
                        ensure_live_integrations_protected()

    def test_protected_integrations_remain_available(self):
        with patch.multiple(config, **{
            **SAFE_DEMO_CONFIG,
            "API_KEY": "trusted-client-only-example",
            "TELEGRAM_API_ID": "1234",
            "TELEGRAM_API_HASH": "example",
            "SLACK_TOKEN": "example",
        }):
            ensure_live_integrations_protected()

    def test_partial_telegram_config_cannot_connect_and_keeps_demo(self):
        with patch.multiple(config, **{**SAFE_DEMO_CONFIG, "TELEGRAM_API_ID": "1234"}):
            ensure_live_integrations_protected()

    def test_whitespace_api_key_is_not_sufficient(self):
        with patch.multiple(config, **{
            **SAFE_DEMO_CONFIG,
            "API_KEY": "   ",
            "SLACK_TOKEN": "example",
        }):
            with self.assertRaisesRegex(RuntimeError, "API_KEY is required"):
                ensure_live_integrations_protected()


if __name__ == "__main__":
    unittest.main()
