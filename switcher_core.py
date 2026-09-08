#!/usr/bin/env python3
"""
Antigravity Account Switcher
Fast, seamless 1-click Google account switcher for Google Antigravity on macOS.
Interacts directly with macOS Keychain (service: 'gemini', account: 'antigravity').
"""

import os
import sys
import json
import base64
import subprocess
import urllib.request
import time
import argparse

ACCOUNTS_DIR = os.path.expanduser('~/.gemini/accounts')
MANIFEST_PATH = os.path.join(ACCOUNTS_DIR, 'manifest.json')

def run_cmd(cmd):
    """Run a shell command safely."""
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

def play_sound(sound_name="Hero"):
    """Play a native macOS system sound non-blocking."""
    sound_path = f"/System/Library/Sounds/{sound_name}.aiff"
    if os.path.exists(sound_path):
        subprocess.Popen(['afplay', sound_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def osascript(script):
    """Execute an AppleScript snippet and return stdout."""
    code, out, err = run_cmd(['osascript', '-e', script])
    return out

def notify(msg, title="Antigravity Switcher", sound=True):
    """Display a native macOS banner notification."""
    if sound:
        play_sound("Hero")
    osascript(f'display notification "{msg}" with title "{title}"')

def get_current_keychain_token():
    """Retrieve raw base64 Go-keyring string from macOS Keychain."""
    code, out, _ = run_cmd(['security', 'find-generic-password', '-s', 'gemini', '-a', 'antigravity', '-w'])
    if code == 0 and out.startswith('go-keyring-base64:'):
        return out
    return None

def extract_email_from_token(token_str):
    """Query Google userinfo API to get email associated with access token."""
    if not token_str or not token_str.startswith('go-keyring-base64:'):
        return None
    try:
        raw_b64 = token_str.split('go-keyring-base64:', 1)[1]
        data = json.loads(base64.b64decode(raw_b64).decode('utf-8'))
        access_token = data.get('token', {}).get('access_token')
        if access_token:
            req = urllib.request.Request(
                'https://www.googleapis.com/oauth2/v3/userinfo',
                headers={'Authorization': f'Bearer {access_token}'}
            )
            with urllib.request.urlopen(req, timeout=2.5) as r:
                info = json.loads(r.read().decode('utf-8'))
                return info.get('email')
    except Exception:
        pass
    return None

def load_manifest():
    """Load the manifest of saved accounts."""
    os.makedirs(ACCOUNTS_DIR, exist_ok=True)
    if os.path.exists(MANIFEST_PATH):
        try:
            with open(MANIFEST_PATH, 'r') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_manifest(manifest):
    """Save the manifest of accounts."""
    os.makedirs(ACCOUNTS_DIR, exist_ok=True)
    with open(MANIFEST_PATH, 'w') as f:
        json.dump(manifest, f, indent=2)

def save_current_account(custom_label=None):
    """Save the currently active Keychain account to disk."""
    token = get_current_keychain_token()
    if not token:
        osascript('tell application "System Events" to display alert "Error" message "No active Antigravity account found in macOS Keychain. Please sign in to Antigravity first." as critical')
        return False
    
    email = extract_email_from_token(token)
    if not email:
        email = osascript('tell application "System Events" to text returned of (display dialog "Enter email or name for this account:" default answer "my-account@gmail.com")')
        if not email:
            return False

    key = custom_label if custom_label else email
    token_file = os.path.join(ACCOUNTS_DIR, f"{key.replace('/', '_')}.token")
    with open(token_file, 'w') as f:
        f.write(token)
    
    manifest = load_manifest()
    manifest[key] = {
        'label': key,
        'email': email,
        'token_file': token_file,
        'saved_at': time.strftime('%Y-%m-%d %H:%M:%S')
    }
    save_manifest(manifest)
    play_sound("Glass")
    notify(f"Account '{key}' saved successfully!", sound=False)
    print(f"✓ Account saved: {key}")
    return True

def switch_to_account(account_key):
    """Switch active Antigravity account in macOS Keychain and restart app."""
    manifest = load_manifest()
    if account_key not in manifest:
        osascript(f'tell application "System Events" to display alert "Error" message "Account \'{account_key}\' not found in saved list." as critical')
        return False
    
    token_file = manifest[account_key].get('token_file')
    if not token_file or not os.path.exists(token_file):
        osascript(f'tell application "System Events" to display alert "Error" message "Token file for \'{account_key}\' is missing." as critical')
        return False
        
    with open(token_file, 'r') as f:
        token = f.read().strip()
        
    # Write to macOS Keychain
    code, _, err = run_cmd(['security', 'add-generic-password', '-U', '-s', 'gemini', '-a', 'antigravity', '-w', token])
    if code != 0:
        osascript(f'tell application "System Events" to display alert "Error" message "Failed to update macOS Keychain: {err}" as critical')
        return False

    # Restart Antigravity
    run_cmd(['pkill', '-9', '-f', '/Applications/Antigravity.app'])
    time.sleep(1)
    run_cmd(['open', '/Applications/Antigravity.app'])
    
    play_sound("Hero")
    notify(f"Switched to {account_key}!", sound=False)
    print(f"✓ Successfully switched to: {account_key}")
    return True

def logout_and_add_account():
    """Logout current account to allow signing into a new Gmail."""
    curr = get_current_keychain_token()
    if curr:
        ans = osascript('tell application "System Events" to button returned of (display dialog "Would you like to save the current account before logging out?" buttons {"Yes, Save First", "No, Just Logout", "Cancel"} default button 1)')
        if ans == "Cancel" or not ans:
            return
        if ans == "Yes, Save First":
            save_current_account()

    # Delete Keychain password
    run_cmd(['security', 'delete-generic-password', '-s', 'gemini', '-a', 'antigravity'])
    
    # Restart Antigravity into login flow
    run_cmd(['pkill', '-9', '-f', '/Applications/Antigravity.app'])
    time.sleep(1)
    run_cmd(['open', '/Applications/Antigravity.app'])
    
    play_sound("Blow")
    osascript('tell application "System Events" to display dialog "Logged out successfully!\\n\\nAntigravity is reopening. Please sign in with your other Gmail.\\n\\nOnce signed in, open this Switcher and select \\"Save Current Account\\" to keep it!" buttons {"OK"} default button 1 with icon note')

def main_menu():
    """Interactive GUI dialog picker."""
    manifest = load_manifest()
    curr_token = get_current_keychain_token()
    active_email = extract_email_from_token(curr_token) if curr_token else None
    
    active_key = None
    if curr_token:
        for k, v in manifest.items():
            tf = v.get('token_file')
            if tf and os.path.exists(tf):
                try:
                    if open(tf).read().strip() == curr_token:
                        active_key = k
                        break
                except Exception:
                    pass

    items = []
    # Saved accounts
    for k in sorted(manifest.keys()):
        if k == active_key:
            items.append(f"🟢 [ACTIVE] {k}")
        else:
            items.append(f"⚡️ Switch to: {k}")
        
    items.append("─────────────────────────────")
    curr_display = active_email or (active_key if active_key else "Active Session") if curr_token else "Not Signed In"
    items.append(f"💾 Save Current Account ({curr_display})")
    items.append("➕ Add New Gmail (Logout & Sign In)")
    if manifest:
        items.append("🗑 Remove a Saved Account")
        
    items_applescript = '{' + ', '.join([f'"{it}"' for it in items]) + '}'
    
    prompt = f"🚀 Antigravity Account Switcher\\n🟢 Active Account: {curr_display}\\n\\nChoose an action:"
    as_script = f'''
    tell application "System Events"
        activate
        set chosen to choose from list {items_applescript} with prompt "{prompt}" default items {{"{items[0]}"}} OK button name "Select" cancel button name "Cancel"
    end tell
    if chosen is false then
        return ""
    else
        return item 1 of chosen
    end if
    '''
    choice = osascript(as_script)
    if not choice or "──────" in choice:
        return

    if choice.startswith("⚡️ Switch to: "):
        acc = choice.replace("⚡️ Switch to: ", "").strip()
        switch_to_account(acc)
    elif choice.startswith("🟢 [ACTIVE] "):
        play_sound("Tink")
        osascript('tell application "System Events" to display dialog "This account is already active!" buttons {"OK"} default button 1 with icon note')
    elif choice.startswith("💾 Save Current Account"):
        save_current_account()
    elif choice.startswith("➕ Add New Gmail"):
        logout_and_add_account()
    elif choice.startswith("🗑 Remove a Saved Account"):
        del_items = '{' + ', '.join([f'"{k}"' for k in manifest.keys()]) + '}'
        del_choice = osascript(f'''
        tell application "System Events"
            activate
            set delChosen to choose from list {del_items} with prompt "Select an account to remove from Switcher:" OK button name "Delete" cancel button name "Cancel"
        end tell
        if delChosen is false then
            return ""
        else
            return item 1 of delChosen
        end if
        ''')
        if del_choice and del_choice in manifest:
            tf = manifest[del_choice].get('token_file')
            if tf and os.path.exists(tf):
                try:
                    os.remove(tf)
                except Exception:
                    pass
            del manifest[del_choice]
            save_manifest(manifest)
            play_sound("Submarine")
            notify(f"Removed account {del_choice}", sound=False)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Antigravity Account Switcher CLI / GUI")
    parser.add_argument('--list', action='store_true', help="List saved accounts")
    parser.add_argument('--switch', type=str, help="Switch to specific account")
    parser.add_argument('--save', nargs='?', const='', help="Save current account with optional name")
    parser.add_argument('--logout', action='store_true', help="Log out from current account")
    args = parser.parse_args()

    if args.list:
        m = load_manifest()
        curr = get_current_keychain_token()
        print("\nSaved Antigravity Accounts:")
        for k, v in m.items():
            active = ""
            tf = v.get('token_file')
            if curr and tf and os.path.exists(tf) and open(tf).read().strip() == curr:
                active = " [ACTIVE]"
            print(f" • {k}{active} (Saved: {v.get('saved_at', 'N/A')})")
        print()
    elif args.switch:
        switch_to_account(args.switch)
    elif args.save is not None:
        save_current_account(args.save if args.save else None)
    elif args.logout:
        logout_and_add_account()
    else:
        main_menu()
