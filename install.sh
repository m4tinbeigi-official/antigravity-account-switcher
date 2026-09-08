#!/bin/bash
set -e

echo "🚀 Installing Antigravity Account Switcher..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build latest app
"$DIR/build_app.sh"

# Destination
DEST="/Applications/AntigravitySwitcher.app"
DESKTOP_DEST="$HOME/Desktop/AntigravitySwitcher.app"

echo "📦 Installing to /Applications and Desktop..."
rm -rf "$DEST"
cp -r "$DIR/AntigravitySwitcher.app" "$DEST"

rm -rf "$DESKTOP_DEST"
cp -r "$DIR/AntigravitySwitcher.app" "$DESKTOP_DEST"

# Register in PATH as a CLI command too
CLI_BIN="/usr/local/bin/agy-switch"
if [ -w "/usr/local/bin" ]; then
    ln -sf "$DIR/switcher_core.py" "$CLI_BIN"
    echo "⚡️ CLI shortcut created: 'agy-switch'"
fi

echo "🎉 Installation successful!"
echo "You can now open 'AntigravitySwitcher' from your Applications, Desktop, or Spotlight (Cmd+Space)!"
