#!/usr/bin/env bash
# Start the Unified Messenger backend.
set -e
cd "$(dirname "$0")"
if [ ! -d venv ]; then
  python3 -m venv venv
fi
source venv/bin/activate
pip install -q -r requirements.txt
exec uvicorn app.main:app --host "${HOST:-127.0.0.1}" --port "${PORT:-8000}" --reload
