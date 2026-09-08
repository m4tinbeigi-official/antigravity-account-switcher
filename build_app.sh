#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="AntigravitySwitcher.app"

echo "🔨 Building portable $APP_NAME..."

# 1. Compile AppleScript launcher
TMP_AS=$(mktemp /tmp/switcher_build.XXXXXX.applescript)
cat << 'APPLESCRIPT' > "$TMP_AS"
set appPath to POSIX path of (path to me)
set scriptPath to appPath & "Contents/Resources/switcher_core.py"
do shell script "/usr/bin/python3 " & quoted form of scriptPath
APPLESCRIPT

rm -rf "$DIR/$APP_NAME"
osacompile -o "$DIR/$APP_NAME" "$TMP_AS"
rm "$TMP_AS"

# 2. Bundle switcher_core.py inside the App
cp "$DIR/switcher_core.py" "$DIR/$APP_NAME/Contents/Resources/switcher_core.py"
chmod +x "$DIR/$APP_NAME/Contents/Resources/switcher_core.py"

# 3. Add High-Res Icon from Antigravity if available, or generate
if [ -f "/Applications/Antigravity.app/Contents/Resources/icon.icns" ]; then
    cp "/Applications/Antigravity.app/Contents/Resources/icon.icns" "$DIR/$APP_NAME/Contents/Resources/applet.icns"
fi

# 4. Refresh icon cache
touch "$DIR/$APP_NAME"

echo "✅ Build complete: $DIR/$APP_NAME"
