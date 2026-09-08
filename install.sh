#!/bin/bash
set -e

ARCH="$(uname -m)"
echo "🚀 Installing Antigravity Account Switcher..."
if [ "$ARCH" = "arm64" ]; then
    echo "🍏 Detected Architecture: Apple Silicon (M1/M2/M3/M4 - arm64)"
else
    echo "⚡️ Detected Architecture: Intel (x86_64)"
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build Universal binary (x86_64 + arm64)
"$DIR/build_app.sh"

DEST="/Applications/AntigravitySwitcher.app"
DESKTOP_DEST="$HOME/Desktop/AntigravitySwitcher.app"

echo "📦 Installing to /Applications and ~/Desktop..."
rm -rf "$DEST"
cp -r "$DIR/AntigravitySwitcher.app" "$DEST"

rm -rf "$DESKTOP_DEST"
cp -r "$DIR/AntigravitySwitcher.app" "$DESKTOP_DEST"

# Setup CLI shortcut in both /usr/local/bin (Intel default) and /opt/homebrew/bin (Apple Silicon default)
CLI_TARGET="$DIR/switcher_core.py"
INSTALLED_CLI=false

if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
    ln -sf "$CLI_TARGET" "/usr/local/bin/agy-switch"
    echo "✓ CLI shortcut registered in /usr/local/bin/agy-switch"
    INSTALLED_CLI=true
fi

if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
    ln -sf "$CLI_TARGET" "/opt/homebrew/bin/agy-switch"
    echo "✓ CLI shortcut registered in /opt/homebrew/bin/agy-switch (Apple Silicon Homebrew)"
    INSTALLED_CLI=true
fi

if [ "$INSTALLED_CLI" = false ]; then
    # Fallback to user local bin
    mkdir -p "$HOME/.local/bin"
    ln -sf "$CLI_TARGET" "$HOME/.local/bin/agy-switch"
    echo "✓ CLI shortcut registered in $HOME/.local/bin/agy-switch"
fi

echo "🎉 Installation successful on $ARCH!"
echo "Open 'AntigravitySwitcher' from Applications, Desktop, or Spotlight (Cmd+Space)."
