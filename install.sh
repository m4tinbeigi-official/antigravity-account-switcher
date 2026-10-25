#!/bin/bash
set -e

OS="$(uname -s)"
ARCH="$(uname -m)"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Installing Antigravity Account Switcher..."

if [ "$OS" = "Darwin" ]; then
    if [ "$ARCH" = "arm64" ]; then
        echo "🍏 Detected Platform: macOS on Apple Silicon (M1/M2/M3/M4 - arm64)"
    else
        echo "⚡️ Detected Platform: macOS on Intel (x86_64)"
    fi

    # Build Universal binary (x86_64 + arm64)
    "$DIR/build_app.sh"

    DEST="/Applications/AntigravitySwitcher.app"
    DESKTOP_DEST="$HOME/Desktop/AntigravitySwitcher.app"

    echo "📦 Installing to /Applications and ~/Desktop..."
    rm -rf "$DEST"
    cp -r "$DIR/AntigravitySwitcher.app" "$DEST"

    rm -rf "$DESKTOP_DEST"
    cp -r "$DIR/AntigravitySwitcher.app" "$DESKTOP_DEST"

    # Setup CLI shortcut
    CLI_TARGET="$DIR/switcher_core.py"
    chmod +x "$CLI_TARGET"
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
        mkdir -p "$HOME/.local/bin"
        ln -sf "$CLI_TARGET" "$HOME/.local/bin/agy-switch"
        echo "✓ CLI shortcut registered in $HOME/.local/bin/agy-switch"
    fi

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
        open "$MENU_APP" 2>/dev/null || true
        echo "✓ Antigravity Menu Bar app installed and running in macOS menu bar"
    fi

elif [ "$OS" = "Linux" ]; then
    DISTRO="Linux"
    if [ -f /etc/os-release ]; then
        DISTRO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi
    echo "🐧 Detected Platform: $DISTRO ($ARCH)"

    CLI_TARGET="$DIR/switcher_core.py"
    chmod +x "$CLI_TARGET"
    chmod +x "$DIR/AntigravitySwitcher.sh"

    INSTALLED_CLI=false
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        ln -sf "$CLI_TARGET" "/usr/local/bin/agy-switch"
        ln -sf "$DIR/AntigravitySwitcher.sh" "/usr/local/bin/antigravity-switcher"
        echo "✓ CLI shortcuts registered in /usr/local/bin (agy-switch, antigravity-switcher)"
        INSTALLED_CLI=true
    fi

    if [ "$INSTALLED_CLI" = false ]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "$CLI_TARGET" "$HOME/.local/bin/agy-switch"
        ln -sf "$DIR/AntigravitySwitcher.sh" "$HOME/.local/bin/antigravity-switcher"
        echo "✓ CLI shortcuts registered in $HOME/.local/bin (agy-switch, antigravity-switcher)"
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            echo "⚠️  Make sure $HOME/.local/bin is in your PATH."
        fi
    fi

    # Install Desktop launcher
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cp "$DIR/antigravity-switcher.desktop" "$DESKTOP_DIR/"
    echo "✓ Desktop application entry registered in $DESKTOP_DIR"

    if [ -d "$HOME/Desktop" ]; then
        cp "$DIR/antigravity-switcher.desktop" "$HOME/Desktop/AntigravitySwitcher.desktop"
        chmod +x "$HOME/Desktop/AntigravitySwitcher.desktop"
        if command -v gio >/dev/null 2>&1; then
            gio set "$HOME/Desktop/AntigravitySwitcher.desktop" metadata::trusted true 2>/dev/null || true
        fi
        echo "✓ Desktop shortcut created at ~/Desktop/AntigravitySwitcher.desktop"
    fi

    # Check dependencies
    if ! command -v secret-tool >/dev/null 2>&1; then
        echo ""
        echo "⚠️  Note: 'secret-tool' (Secret Service CLI) was not found."
        echo "    Install libsecret to enable 1-click Linux keyring token access:"
        echo "      • Ubuntu/Debian: sudo apt install libsecret-tools"
        echo "      • Fedora/RHEL:   sudo dnf install libsecret"
        echo "      • Arch Linux:    sudo pacman -S libsecret"
        echo ""
    fi

    if ! command -v zenity >/dev/null 2>&1 && ! command -v kdialog >/dev/null 2>&1; then
        echo "💡 Tip: Install 'zenity' for native desktop GUI popup dialogs:"
        echo "      • sudo apt install zenity"
        echo ""
    fi
else
    echo "❌ Unsupported operating system: $OS. On Windows, run install.bat."
    exit 1
fi

# Install Antigravity IDE Status Bar Extension (Cross-platform)
EXT_SRC="$DIR/editor-extension"
PYTHON_CMD="python3"
if ! command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python"
fi

$PYTHON_CMD -c "
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

echo "🎉 Installation successful on $OS ($ARCH)!"
if [ "$OS" = "Darwin" ]; then
    echo "Open 'AntigravitySwitcher' from Applications, Desktop, or Spotlight (Cmd+Space)."
else
    echo "Launch 'Antigravity Account Switcher' from application menu, or run 'agy-switch' in terminal."
fi
