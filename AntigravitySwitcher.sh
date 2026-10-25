#!/usr/bin/env bash
# 🚀 Antigravity Account Switcher Launcher for Linux
# Created by Rick Sanchez (https://github.com/m4tinbeigi-official)

set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve Python 3 binary
if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
else
    echo "❌ Error: Python 3 is required but not installed." >&2
    exit 1
fi

exec "$PYTHON_BIN" "$DIR/switcher_core.py" "$@"
