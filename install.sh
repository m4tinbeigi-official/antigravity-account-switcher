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

# Install Antigravity IDE Status Bar Extension
EXT_SRC="$DIR/editor-extension"
/usr/bin/python3 -c "
import json, os, shutil, time

ext_dirs = [os.path.expanduser('~/.antigravity-ide/extensions'), os.path.expanduser('~/.antigravity/extensions')]
src = '$EXT_SRC'
target_name = 'm4tinbeigi.antigravity-account-switcher-1.1.0-universal'

for ext_dir in ext_dirs:
    parent = os.path.dirname(ext_dir)
    if not os.path.exists(parent):
        continue
    os.makedirs(ext_dir, exist_ok=True)
    target_path = os.path.join(ext_dir, target_name)
    if os.path.exists(target_path):
        shutil.rmtree(target_path)
    shutil.copytree(src, target_path)

    json_path = os.path.join(ext_dir, 'extensions.json')
    try:
        with open(json_path, 'r') as f:
            exts = json.load(f)
    except Exception:
        exts = []

    exts = [x for x in exts if x.get('identifier', {}).get('id') != 'm4tinbeigi.antigravity-account-switcher']
    exts.append({
        'identifier': {'id': 'm4tinbeigi.antigravity-account-switcher'},
        'version': '1.1.0',
        'location': {'\$mid': 1, 'path': target_path, 'scheme': 'file'},
        'relativeLocation': target_name,
        'metadata': {
            'isApplicationScoped': False,
            'isMachineScoped': False,
            'isBuiltin': False,
            'installedTimestamp': int(time.time() * 1000),
            'pinned': False,
            'source': 'custom',
            'id': 'm4tinbeigi.antigravity-account-switcher',
            'publisherDisplayName': 'm4tinbeigi',
            'targetPlatform': 'universal',
            'updated': False,
            'private': False,
            'isPreReleaseVersion': False,
            'hasPreReleaseVersion': False
        }
    })
    with open(json_path, 'w') as f:
        json.dump(exts, f, indent=2)
    print('✓ Editor status bar extension registered in', ext_dir)
"

# Build and Install Native macOS Menu Bar App
if command -v swiftc >/dev/null 2>&1; then
    echo "🔨 Building native macOS Menu Bar app..."
    swiftc -O "$DIR/menubar-app/main.swift" -o "$DIR/menubar-app/AntigravityMenuBar"
    MENU_APP="/Applications/AntigravityMenuBar.app"
    rm -rf "$MENU_APP"
    mkdir -p "$MENU_APP/Contents/MacOS" "$MENU_APP/Contents/Resources"
    cp "$DIR/menubar-app/AntigravityMenuBar" "$MENU_APP/Contents/MacOS/"
    if [ -f "/Applications/Antigravity.app/Contents/Resources/icon.icns" ]; then
        cp "/Applications/Antigravity.app/Contents/Resources/icon.icns" "$MENU_APP/Contents/Resources/AppIcon.icns"
    fi
    cat << 'PLIST' > "$MENU_APP/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AntigravityMenuBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.m4tinbeigi.antigravitymenubar</string>
    <key>CFBundleName</key>
    <string>AntigravityMenuBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST
    pkill -f AntigravityMenuBar 2>/dev/null || true
    sleep 0.5
    open "$MENU_APP"
    echo "✓ Antigravity Menu Bar app installed and running in macOS menu bar"
fi

echo "🎉 Installation successful on $ARCH!"
echo "Open 'AntigravitySwitcher' from Applications, Desktop, or Spotlight (Cmd+Space)."
