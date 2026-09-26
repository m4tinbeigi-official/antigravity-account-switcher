#!/usr/bin/env python3
"""
Antigravity Account Switcher
Created by Rick Sanchez (https://github.com/m4tinbeigi-official)
Universal (Apple Silicon & Intel) 1-click Google account switcher for Google Antigravity on macOS.
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
import platform

ACCOUNTS_DIR = os.path.expanduser('~/.gemini/accounts')
MANIFEST_PATH = os.path.join(ACCOUNTS_DIR, 'manifest.json')
GITHUB_REPO_URL = "https://github.com/m4tinbeigi-official/antigravity-account-switcher"
AUTHOR_NAME = "Rick Sanchez (@m4tinbeigi-official)"

_CID_CODES = [49, 48, 55, 49, 48, 48, 54, 48, 54, 48, 53, 57, 49, 45, 116, 109, 104, 115, 115, 105, 110, 50, 104, 50, 49, 108, 99, 114, 101, 50, 51, 53, 118, 116, 111, 108, 111, 106, 104, 52, 103, 52, 48, 51, 101, 112, 46, 97, 112, 112, 115, 46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109]
_SEC_CODES = [71, 79, 67, 83, 80, 88, 45, 75, 53, 56, 70, 87, 82, 52, 56, 54, 76, 100, 76, 74, 49, 109, 76, 66, 56, 115, 88, 67, 52, 122, 54, 113, 68, 65, 102]
OAUTH_CLIENT_ID = "".join(chr(x) for x in _CID_CODES)
OAUTH_CLIENT_SECRET = "".join(chr(x) for x in _SEC_CODES)
USAGE_DASHBOARD_PATH = os.path.join(ACCOUNTS_DIR, "usage_dashboard.html")

def get_arch_label():
    m = platform.machine()
    if m == 'arm64':
        return "🍏 Apple Silicon (M1/M2/M3/M4)"
    elif m in ('x86_64', 'i386'):
        return "⚡️ Intel (x86_64)"
    return f"💻 {m}"

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

def open_github():
    """Open GitHub repository in default browser."""
    run_cmd(['open', GITHUB_REPO_URL])

def show_about():
    """Display Creator and GitHub info dialog."""
    play_sound("Glass")
    as_script = f'''
    tell application "System Events"
        activate
        set res to display dialog "🚀 Antigravity Account Switcher\\n\\n👨‍💻 Creator: {AUTHOR_NAME}\\n🌐 GitHub: {GITHUB_REPO_URL}\\n\\nIf you love this tool, please consider giving it a ⭐ Star on GitHub!" buttons {{"Close", "⭐ Open GitHub & Star"}} default button 2 with icon note
        return button returned of res
    end tell
    '''
    res = osascript(as_script)
    if "Open GitHub" in res:
        open_github()

def format_countdown(iso_str):
    """Calculate remaining time string and local time from ISO timestamp."""
    if not iso_str:
        return "N/A", "N/A", 0, ""
    try:
        import datetime
        dt = datetime.datetime.fromisoformat(iso_str.replace('Z', '+00:00'))
        now = datetime.datetime.now(datetime.timezone.utc)
        diff = dt - now
        secs = int(diff.total_seconds())
        local_time_str = dt.astimezone().strftime('%a %I:%M %p')
        if secs <= 0:
            return "Ready to reset", local_time_str, 0, iso_str
        d = secs // 86400
        h = (secs % 86400) // 3600
        m = (secs % 3600) // 60
        parts = []
        if d > 0:
            parts.append(f"{d}d")
        if h > 0:
            parts.append(f"{h}h")
        if m > 0 and d == 0:
            parts.append(f"{m}m")
        if not parts:
            parts.append("1m")
        return " ".join(parts), local_time_str, secs, iso_str
    except Exception:
        return "N/A", "N/A", 0, ""

def fetch_antigravity_usage(token_str, known_email=None):
    """Fetch live Antigravity quota and model limits for an account token."""
    if not token_str or not token_str.startswith('go-keyring-base64:'):
        return None
    try:
        import urllib.parse
        raw_b64 = token_str.split('go-keyring-base64:', 1)[1]
        data = json.loads(base64.b64decode(raw_b64).decode('utf-8'))
        t_obj = data.get('token', {})
        access_token = t_obj.get('access_token')
        rf = t_obj.get('refresh_token')

        # Attempt query, refresh token automatically if expired
        models_data = None
        for attempt in range(2):
            try:
                req_models = urllib.request.Request(
                    'https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels',
                    headers={
                        'Authorization': f'Bearer {access_token}',
                        'Content-Type': 'application/json',
                        'User-Agent': 'antigravity'
                    },
                    data=b'{}'
                )
                with urllib.request.urlopen(req_models, timeout=3.5) as resp:
                    models_data = json.loads(resp.read().decode('utf-8'))
                break
            except Exception:
                if attempt == 0 and rf:
                    try:
                        params = urllib.parse.urlencode({
                            'client_id': OAUTH_CLIENT_ID,
                            'client_secret': OAUTH_CLIENT_SECRET,
                            'grant_type': 'refresh_token',
                            'refresh_token': rf
                        }).encode('utf-8')
                        req_rf = urllib.request.Request('https://oauth2.googleapis.com/token', data=params)
                        with urllib.request.urlopen(req_rf, timeout=3.5) as r:
                            tok_d = json.loads(r.read().decode('utf-8'))
                            access_token = tok_d.get('access_token')
                    except Exception:
                        pass
                else:
                    return None

        if not models_data:
            return None

        tier_name = "Antigravity Free"

        # Extract Email if not provided
        email = known_email
        if not email:
            try:
                req_u = urllib.request.Request(
                    'https://www.googleapis.com/oauth2/v3/userinfo',
                    headers={'Authorization': f'Bearer {access_token}'}
                )
                with urllib.request.urlopen(req_u, timeout=2.0) as r:
                    email = json.loads(r.read().decode('utf-8')).get('email')
            except Exception:
                pass

        models = models_data.get('models', {})
        pools_map = {}
        for m_id, m_info in models.items():
            if m_info.get('isInternal'):
                continue
            quota = m_info.get('quotaInfo')
            if not quota:
                continue
            rem = quota.get('remainingFraction', 1.0)
            reset_time = quota.get('resetTime')
            disp = m_info.get('displayName', m_id)

            if 'claude' in m_id.lower() or 'claude' in disp.lower():
                cat = 'Claude 4.6 (Sonnet & Opus)'
            elif 'gpt' in m_id.lower():
                cat = 'GPT-OSS 120B'
            elif 'gemini' in m_id.lower() or 'flash' in m_id.lower() or 'pro' in m_id.lower():
                # Skip unlimited preview tabs from masking true quota
                if 'preview' in m_id.lower() and rem == 1.0 and not reset_time:
                    continue
                cat = 'Gemini (Pro & Flash)'
            else:
                cat = 'Other Models'

            if cat not in pools_map:
                pools_map[cat] = {'rem': rem, 'reset_time': reset_time, 'models': []}
            else:
                # Keep the lowest remaining fraction to reflect actual active rate limit
                if rem < pools_map[cat]['rem']:
                    pools_map[cat]['rem'] = rem
                    if reset_time:
                        pools_map[cat]['reset_time'] = reset_time
            pools_map[cat]['models'].append(disp)

        ordered_cats = ['Gemini (Pro & Flash)', 'Claude 4.6 (Sonnet & Opus)', 'GPT-OSS 120B']
        for k in pools_map:
            if k not in ordered_cats:
                ordered_cats.append(k)

        pools = []
        for cat in ordered_cats:
            if cat in pools_map:
                p = pools_map[cat]
                rem_val = p['rem']
                used_pct = round((1.0 - rem_val) * 100, 1)
                rem_pct = round(rem_val * 100, 1)
                countdown, local_reset, secs, iso_dt = format_countdown(p['reset_time'])
                pools.append({
                    'name': cat,
                    'used_pct': used_pct,
                    'remaining_pct': rem_pct,
                    'resets_in': countdown,
                    'reset_time': local_reset,
                    'reset_secs': secs,
                    'reset_iso': iso_dt,
                    'models': p['models']
                })

        daily = next((p for p in pools if 'Gemini' in p['name']), None)
        weekly = next((p for p in pools if 'Claude' in p['name']), None) or next((p for p in pools if 'GPT' in p['name']), None)
        if not daily and pools:
            daily = pools[0]
        if not daily:
            daily = {'name': 'Daily Limit (Gemini)', 'used_pct': 0.0, 'remaining_pct': 100.0, 'resets_in': 'N/A', 'reset_time': 'N/A', 'reset_secs': 0, 'reset_iso': ''}
        if not weekly:
            weekly = {'name': 'Weekly Limit (Claude & GPT)', 'used_pct': 0.0, 'remaining_pct': 100.0, 'resets_in': 'N/A', 'reset_time': 'N/A', 'reset_secs': 0, 'reset_iso': ''}

        return {
            'email': email or 'Unknown',
            'tier': tier_name,
            'session': daily,
            'daily': daily,
            'weekly': weekly,
            'pools': pools
        }
    except Exception as e:
        return None

def make_ascii_bar(pct, width=20):
    """Generate ASCII progress bar like Claude Code."""
    filled = int(round((pct / 100.0) * width))
    filled = max(0, min(width, filled))
    empty = width - filled
    return "█" * filled + "░" * empty

def print_claude_cli_usage(usage):
    """Print a Claude Code style terminal card for usage with daily and weekly limits."""
    if not usage:
        print("\n❌ Could not retrieve Antigravity usage. Please ensure you are signed in.\n")
        return

    email = usage.get('email', 'Unknown')
    tier = usage.get('tier', 'Antigravity')
    daily = usage.get('daily', usage.get('session', {}))
    weekly = usage.get('weekly', {})

    d_used = daily.get('used_pct', 0.0)
    d_rem = daily.get('remaining_pct', 100.0)
    d_count = daily.get('resets_in', 'N/A')
    d_time = daily.get('reset_time', 'N/A')

    w_used = weekly.get('used_pct', 0.0)
    w_rem = weekly.get('remaining_pct', 100.0)
    w_count = weekly.get('resets_in', 'N/A')
    w_time = weekly.get('reset_time', 'N/A')

    # Color codes (Antigravity Signature Cyan & Indigo)
    CYAN = "\033[38;2;56;189;248m"    # Antigravity Cyan #38BDF8
    INDIGO = "\033[38;2;129;140;248m" # Antigravity Indigo #818CF8
    BOLD = "\033[1m"
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RESET = "\033[0m"

    d_bar = make_ascii_bar(d_used, width=20)
    d_col = GREEN if d_used < 60 else (YELLOW if d_used < 85 else CYAN)

    w_bar = make_ascii_bar(w_used, width=20)
    w_col = GREEN if w_used < 60 else (YELLOW if w_used < 85 else CYAN)

    print(f"\n{CYAN}{BOLD}┌─────────────────────────────────────────────────────────────┐{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}                       {BOLD}ANTIGRAVITY USAGE{RESET}                     {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}   {DIM}Plan:{RESET} {INDIGO}{tier}{RESET}  •  {DIM}Account:{RESET} {email:<26} {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}├─────────────────────────────────────────────────────────────┤{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  ⚡️ {BOLD}Daily Limit (Gemini 2.5 & 3.x){RESET}                         {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  {d_col}{d_used}% used{RESET} {DIM}({d_rem}% remaining){RESET}                             {CYAN}{BOLD}│{RESET}")
    d_reset_str = f"Resets in {d_count} (at {d_time})" if d_count != 'N/A' else "No active limit window"
    print(f"{CYAN}{BOLD}│{RESET}  {DIM}⏱  {d_reset_str:<54}{RESET} {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  [{d_col}{d_bar}{RESET}]  {BOLD}{d_used}%{RESET}                                {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}├─────────────────────────────────────────────────────────────┤{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  🔮 {BOLD}Weekly Limit (Claude 4.6 & GPT-OSS){RESET}                    {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  {w_col}{w_used}% used{RESET} {DIM}({w_rem}% remaining){RESET}                             {CYAN}{BOLD}│{RESET}")
    w_reset_str = f"Resets in {w_count} (at {w_time})" if w_count != 'N/A' else "No active limit window"
    print(f"{CYAN}{BOLD}│{RESET}  {DIM}⏱  {w_reset_str:<54}{RESET} {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  [{w_col}{w_bar}{RESET}]  {BOLD}{w_used}%{RESET}                                {CYAN}{BOLD}│{RESET}")
    print(f"{CYAN}{BOLD}├─────────────────────────────────────────────────────────────┤{RESET}")
    print(f"{CYAN}{BOLD}│{RESET}  {BOLD}Model Quotas Breakdown{RESET}                                     {CYAN}{BOLD}│{RESET}")

    for p in usage.get('pools', []):
        p_name = p.get('name')
        p_used = p.get('used_pct', 0.0)
        p_bar = make_ascii_bar(p_used, width=14)
        p_col = GREEN if p_used < 60 else (YELLOW if p_used < 85 else CYAN)
        p_count = p.get('resets_in', 'N/A')
        print(f"{CYAN}{BOLD}│{RESET}  • {BOLD}{p_name:<26}{RESET}                             {CYAN}{BOLD}│{RESET}")
        line = f"    {p_col}{p_used:>5.1f}% used{RESET} [{p_col}{p_bar}{RESET}]  {DIM}Resets: {p_count}{RESET}"
        raw_len = 4 + 11 + 2 + 14 + 10 + len(p_count)
        pad = max(0, 57 - raw_len)
        print(f"{CYAN}{BOLD}│{RESET}{line}{' ' * pad}{CYAN}{BOLD}│{RESET}")

    print(f"{CYAN}{BOLD}└─────────────────────────────────────────────────────────────┘{RESET}\n")

def generate_claude_html_dashboard(all_accounts_data, active_key):
    """Generate a pixel-perfect Antigravity styled usage dashboard."""
    os.makedirs(ACCOUNTS_DIR, exist_ok=True)
    
    # Pre-render JSON payload for client-side account switcher
    json_data = json.dumps(all_accounts_data)
    
    html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Antigravity Usage</title>
  <style>
    * {{
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }}
    :root {{
      --bg: #0B0F19;
      --card-bg: #131B2E;
      --card-border: #232F4D;
      --text: #F1F5F9;
      --text-muted: #94A3B8;
      --accent: #38BDF8;
      --accent-hover: #7DD3FC;
      --accent-secondary: #818CF8;
      --bar-bg: #1E293B;
      --badge-bg: #1E293B;
      --green: #22C55E;
      --yellow: #F59E0B;
    }}
    body {{
      background: var(--bg);
      color: var(--text);
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      padding: 28px 20px;
      -webkit-font-smoothing: antialiased;
      user-select: none;
    }}
    .container {{
      width: 100%;
      max-width: 440px;
      display: flex;
      flex-direction: column;
      gap: 20px;
    }}
    .header {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
    }}
    .header-left {{
      display: flex;
      flex-direction: column;
      gap: 4px;
    }}
    .logo-title {{
      display: flex;
      align-items: center;
      gap: 10px;
    }}
    .claude-icon {{
      width: 26px;
      height: 26px;
      color: var(--accent);
    }}
    h1 {{
      font-size: 22px;
      font-weight: 700;
      letter-spacing: -0.4px;
    }}
    .subtitle {{
      font-size: 13px;
      color: var(--text-muted);
      margin-top: 2px;
    }}
    .account-badge {{
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: var(--badge-bg);
      border: 1px solid var(--card-border);
      border-radius: 20px;
      padding: 4px 12px;
      font-size: 12px;
      color: var(--text-muted);
      margin-top: 10px;
    }}
    .dot {{
      width: 7px;
      height: 7px;
      border-radius: 50%;
      background: var(--green);
    }}
    .tier-tag {{
      background: rgba(218, 119, 86, 0.18);
      color: var(--accent);
      padding: 2px 8px;
      border-radius: 12px;
      font-weight: 600;
      font-size: 11px;
    }}
    .account-select-wrap {{
      margin-top: 4px;
    }}
    select {{
      width: 100%;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      color: var(--text);
      padding: 8px 12px;
      border-radius: 10px;
      font-size: 13px;
      outline: none;
      cursor: pointer;
    }}
    select:focus {{
      border-color: var(--accent);
    }}
    .card {{
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 14px;
      padding: 18px 20px;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }}
    .card-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    .card-title {{
      font-size: 14px;
      font-weight: 600;
      color: var(--text);
    }}
    .stat-main {{
      display: flex;
      align-items: baseline;
      gap: 8px;
    }}
    .stat-pct {{
      font-size: 28px;
      font-weight: 800;
      letter-spacing: -0.6px;
    }}
    .stat-rem {{
      font-size: 13px;
      color: var(--text-muted);
    }}
    .stat-reset {{
      font-size: 12px;
      color: var(--text-muted);
      display: flex;
      align-items: center;
      gap: 6px;
    }}
    .progress-bar {{
      width: 100%;
      height: 9px;
      background: var(--bar-bg);
      border-radius: 10px;
      overflow: hidden;
      position: relative;
    }}
    .progress-fill {{
      height: 100%;
      background: var(--accent);
      border-radius: 10px;
      transition: width 0.6s cubic-bezier(0.16, 1, 0.3, 1);
    }}
    .section-title {{
      font-size: 13px;
      font-weight: 600;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 0.6px;
      margin-top: 6px;
    }}
    .pool-card {{
      background: rgba(255,255,255,0.02);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 14px 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }}
    .pool-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
    }}
    .pool-name {{
      font-size: 13px;
      font-weight: 600;
    }}
    .pool-pct {{
      font-size: 13px;
      font-weight: 700;
      color: var(--accent);
    }}
    .pool-reset {{
      font-size: 11px;
      color: var(--text-muted);
    }}
    .footer {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-top: 10px;
      padding-top: 14px;
      border-top: 1px solid var(--card-border);
    }}
    .btn {{
      background: transparent;
      border: 1px solid var(--card-border);
      color: var(--text);
      padding: 7px 16px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 600;
      cursor: pointer;
      display: inline-flex;
      align-items: center;
      gap: 6px;
      transition: all 0.2s ease;
    }}
    .btn:hover {{
      background: rgba(255,255,255,0.06);
      border-color: #555;
    }}
    .btn-primary {{
      background: var(--accent);
      border-color: var(--accent);
      color: #fff;
    }}
    .btn-primary:hover {{
      background: var(--accent-hover);
    }}
    .author-note {{
      font-size: 11px;
      color: var(--text-muted);
    }}
  </style>
</head>
<body>

<div class="container">
  <div class="header">
    <div class="header-left">
      <div class="logo-title">
        <svg class="claude-icon" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 2L14.2 8.4L20.6 6.2L16.4 12L20.6 17.8L14.2 15.6L12 22L9.8 15.6L3.4 17.8L7.6 12L3.4 6.2L9.8 8.4L12 2Z"/>
        </svg>
        <h1>Usage</h1>
      </div>
      <div class="subtitle">Track your usage limits and reset times.</div>
      <div class="account-badge">
        <div class="dot"></div>
        <span id="activeEmail">Loading...</span>
        <span class="tier-tag" id="tierTag">Pro</span>
      </div>
    </div>
  </div>

  <div id="accountSelectorWrap" class="account-select-wrap" style="display:none;">
    <select id="accountSelect" onchange="onAccountChange()"></select>
  </div>

  <!-- Daily Session Card -->
  <div class="card">
    <div class="card-header">
      <div class="card-title">⚡️ Daily Limit (Gemini 2.5 & 3.x)</div>
      <div class="stat-reset" id="dailyCountdown">⏱ Resets in --</div>
    </div>
    
    <div class="stat-main">
      <div class="stat-pct" id="dailyUsedPct">0%</div>
      <div class="stat-rem" id="dailyRemPct">used</div>
    </div>

    <div class="progress-bar">
      <div class="progress-fill" id="dailyProgressBar" style="width: 0%;"></div>
    </div>

    <div class="stat-reset" id="dailyDetail">Resets at --</div>
  </div>

  <!-- Weekly Session Card -->
  <div class="card">
    <div class="card-header">
      <div class="card-title">🔮 Weekly Limit (Claude 4.6 & GPT-OSS)</div>
      <div class="stat-reset" id="weeklyCountdown">⏱ Resets in --</div>
    </div>
    
    <div class="stat-main">
      <div class="stat-pct" id="weeklyUsedPct">0%</div>
      <div class="stat-rem" id="weeklyRemPct">used</div>
    </div>

    <div class="progress-bar">
      <div class="progress-fill" id="weeklyProgressBar" style="width: 0%;"></div>
    </div>

    <div class="stat-reset" id="weeklyDetail">Resets at --</div>
  </div>

  <!-- Model Quotas Section -->
  <div class="section-title">Model Quotas Breakdown</div>
  <div id="poolsContainer" style="display:flex; flex-direction:column; gap:10px;"></div>

  <div class="footer">
    <div class="author-note">Antigravity Switcher by Rick Sanchez</div>
    <button class="btn btn-primary" onclick="location.reload()">🔄 Refresh</button>
  </div>
</div>

<script>
  const accountsData = {json_data};
  let activeKey = "{active_key}";

  function updateDisplay(accKey) {{
    const data = accountsData[accKey];
    if (!data) return;

    document.getElementById("activeEmail").innerText = data.email || accKey;
    document.getElementById("tierTag").innerText = data.tier || "Free";

    // Daily
    const daily = data.daily || data.session || {{}};
    const dUsed = daily.used_pct || 0;
    const dRem = daily.remaining_pct || 100;
    document.getElementById("dailyUsedPct").innerText = dUsed + "% used";
    document.getElementById("dailyRemPct").innerText = "(" + dRem + "% remaining)";
    const dFill = document.getElementById("dailyProgressBar");
    dFill.style.width = Math.min(100, Math.max(0, dUsed)) + "%";
    dFill.style.background = dUsed > 85 ? "#E05252" : (dUsed > 60 ? "var(--yellow)" : "var(--accent)");
    document.getElementById("dailyCountdown").innerText = daily.resets_in !== "N/A" ? ("⏱ Resets in " + daily.resets_in) : "⏱ No active limit";
    document.getElementById("dailyDetail").innerText = daily.reset_time !== "N/A" ? ("Window refreshes at " + daily.reset_time) : "Full capacity available";

    // Weekly
    const weekly = data.weekly || {{}};
    const wUsed = weekly.used_pct || 0;
    const wRem = weekly.remaining_pct || 100;
    document.getElementById("weeklyUsedPct").innerText = wUsed + "% used";
    document.getElementById("weeklyRemPct").innerText = "(" + wRem + "% remaining)";
    const wFill = document.getElementById("weeklyProgressBar");
    wFill.style.width = Math.min(100, Math.max(0, wUsed)) + "%";
    wFill.style.background = wUsed > 85 ? "#E05252" : (wUsed > 60 ? "var(--yellow)" : "var(--accent)");
    document.getElementById("weeklyCountdown").innerText = weekly.resets_in !== "N/A" ? ("⏱ Resets in " + weekly.resets_in) : "⏱ No active limit";
    document.getElementById("weeklyDetail").innerText = weekly.reset_time !== "N/A" ? ("Window refreshes at " + weekly.reset_time) : "Full capacity available";

    // Pools
    const poolsContainer = document.getElementById("poolsContainer");
    poolsContainer.innerHTML = "";
    (data.pools || []).forEach(p => {{
      const poolDiv = document.createElement("div");
      poolDiv.className = "pool-card";
      
      const pUsed = p.used_pct || 0;
      const pColor = pUsed > 85 ? "#E05252" : (pUsed > 60 ? "var(--yellow)" : "var(--accent)");
      const pReset = (p.resets_in && p.resets_in !== "N/A") ? ("Resets in " + p.resets_in + (p.reset_time && p.reset_time !== "N/A" ? " (" + p.reset_time + ")" : "")) : "Ready to use";

      poolDiv.innerHTML = `
        <div class="pool-header">
          <div class="pool-name">${{p.name}}</div>
          <div class="pool-pct" style="color:${{pColor}};">${{pUsed}}% used</div>
        </div>
        <div class="progress-bar">
          <div class="progress-fill" style="width: ${{pUsed}}%; background: ${{pColor}};"></div>
        </div>
        <div class="pool-reset">${{pReset}}</div>
      `;
      poolsContainer.appendChild(poolDiv);
    }});
  }}

  // Setup account selector if multiple accounts
  const keys = Object.keys(accountsData);
  if (keys.length > 1) {{
    const select = document.getElementById("accountSelect");
    keys.forEach(k => {{
      const opt = document.createElement("option");
      opt.value = k;
      opt.text = (k === activeKey ? "🟢 " : "") + k;
      if (k === activeKey) opt.selected = true;
      select.appendChild(opt);
    }});
    document.getElementById("accountSelectorWrap").style.display = "block";
  }}

  function onAccountChange() {{
    const sel = document.getElementById("accountSelect");
    updateDisplay(sel.value);
  }}

  updateDisplay(activeKey);

  // Real-time ticking countdown for both daily and weekly
  setInterval(() => {{
    const sel = document.getElementById("accountSelect");
    const currentKey = sel ? sel.value : activeKey;
    const data = accountsData[currentKey];
    if (!data) return;

    function tickTimer(elemId, isoStr) {{
      if (!isoStr) return;
      const target = new Date(isoStr).getTime();
      const now = new Date().getTime();
      const diff = Math.floor((target - now) / 1000);
      if (diff > 0) {{
        const d = Math.floor(diff / 86400);
        const h = Math.floor((diff % 86400) / 3600);
        const m = Math.floor((diff % 3600) / 60);
        const s = diff % 60;
        let str = "";
        if (d > 0) str += d + "d ";
        if (h > 0 || d > 0) str += h + "h ";
        str += m + "m " + s + "s";
        const el = document.getElementById(elemId);
        if (el) el.innerText = "⏱ Resets in " + str;
      }}
    }}

    if (data.daily && data.daily.reset_iso) tickTimer("dailyCountdown", data.daily.reset_iso);
    if (data.weekly && data.weekly.reset_iso) tickTimer("weeklyCountdown", data.weekly.reset_iso);
  }}, 1000);
</script>

</body>
</html>
"""
    with open(USAGE_DASHBOARD_PATH, "w") as f:
        f.write(html_content)
    return USAGE_DASHBOARD_PATH

def open_claude_usage_window(target_key=None, force_refresh=False):
    """Fetch usage and open the Claude-style HTML desktop window fast."""
    manifest = load_manifest()
    curr_token = get_current_keychain_token()
    cache_path = os.path.join(ACCOUNTS_DIR, "usage_cache.json")
    
    all_data = {}
    active_key = None

    # Check cache (45s TTL)
    if not force_refresh and os.path.exists(cache_path):
        try:
            mtime = os.path.getmtime(cache_path)
            if time.time() - mtime < 45:
                all_data = json.load(open(cache_path))
        except Exception:
            pass

    if not all_data:
        tasks = {}
        for k, v in manifest.items():
            tf = v.get('token_file')
            if tf and os.path.exists(tf):
                try:
                    tok = open(tf).read().strip()
                    if curr_token and tok == curr_token:
                        active_key = k
                    tasks[k] = (tok, v.get('email'))
                except Exception:
                    pass

        if curr_token and not active_key:
            tasks['Active Account'] = (curr_token, None)
            active_key = 'Active Account'

        import concurrent.futures
        def _fetch_one(item):
            name, (tok, email) = item
            return name, fetch_antigravity_usage(tok, known_email=email)

        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            for name, u in executor.map(_fetch_one, tasks.items()):
                if u:
                    all_data[name] = u

        try:
            with open(cache_path, "w") as f:
                json.dump(all_data, f)
        except Exception:
            pass

    if not all_data:
        osascript('tell application "System Events" to display alert "Error" message "Could not retrieve Antigravity usage. Please check your internet connection or sign in to Antigravity first." as critical')
        return

    chosen_key = target_key if (target_key and target_key in all_data) else (active_key or list(all_data.keys())[0])
    dashboard_path = generate_claude_html_dashboard(all_data, chosen_key)
    
    play_sound("Glass")
    
    chrome_path = "/Applications/Google Chrome.app"
    if os.path.exists(chrome_path):
        subprocess.Popen(['open', '-a', 'Google Chrome', f'file://{dashboard_path}'])
    else:
        run_cmd(['open', dashboard_path])

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

def get_antigravity_app_path():
    """Locate Antigravity application path on macOS."""
    candidates = [
        "/Applications/Antigravity.app",
        "/Applications/Antigravity IDE.app",
        os.path.expanduser("~/Applications/Antigravity.app"),
        os.path.expanduser("~/Applications/Antigravity IDE.app")
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return "/Applications/Antigravity.app"

def restart_antigravity():
    """Cleanly terminate Antigravity and language server, then restart."""
    app_path = get_antigravity_app_path()
    run_cmd(['pkill', '-9', '-f', f"{app_path}/Contents/MacOS/Antigravity"])
    run_cmd(['pkill', '-9', '-f', f"{app_path}/Contents/Resources/bin/language_server"])
    time.sleep(1)
    run_cmd(['open', app_path])

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
    restart_antigravity()
    
    play_sound("Hero")
    notify(f"Switched to {account_key}!", sound=False)
    print(f"✓ Successfully switched to: {account_key}")
    return True

def add_account_wizard():
    """Interactive guided wizard to log in and automatically save a new Gmail account."""
    curr = get_current_keychain_token()
    manifest = load_manifest()
    
    # 1. Protect unsaved active account
    if curr:
        is_saved = any(
            v.get('token_file') and os.path.exists(v['token_file']) and open(v['token_file']).read().strip() == curr
            for v in manifest.values()
        )
        if not is_saved:
            ans = osascript('tell application "System Events" to button returned of (display dialog "⚠️ Your currently active account is not saved yet.\\n\\nSave it first before switching to a new account?" buttons {"Save Active First", "Skip & Logout", "Cancel"} default button 1 with icon caution)')
            if ans == "Cancel" or not ans:
                return
            if ans == "Save Active First":
                if not save_current_account():
                    return

    # 2. Confirm logout & launch login
    step1 = osascript('tell application "System Events" to button returned of (display dialog "🧙‍♂️ Add New Account Wizard\\n\\nStep 1: Antigravity will restart in login mode.\\nStep 2: Sign in with your new Gmail inside Antigravity.\\nStep 3: This wizard will automatically capture and save your new account!" buttons {"Cancel", "Start Login"} default button 2 with icon note)')
    if step1 != "Start Login":
        return

    # Remove current token from Keychain
    run_cmd(['security', 'delete-generic-password', '-s', 'gemini', '-a', 'antigravity'])
    restart_antigravity()
    play_sound("Blow")

    # 3. Wait for user to complete login in Antigravity
    while True:
        step2 = osascript('tell application "System Events" to button returned of (display dialog "⏳ Waiting for Login...\\n\\nPlease complete sign-in with your new Gmail inside Antigravity.\\n\\nWhen done, click \\"I Have Signed In\\" below:" buttons {"Cancel", "I Have Signed In"} default button 2 with icon note)')
        if step2 != "I Have Signed In":
            return

        new_tok = get_current_keychain_token()
        if new_tok and new_tok != curr:
            email = extract_email_from_token(new_tok)
            def_label = email if email else f"Account {len(manifest) + 1}"
            label = osascript(f'tell application "System Events" to text returned of (display dialog "🎉 Login detected!\\n\\nEnter a friendly name/label for this account:" default answer "{def_label}" buttons {{"Save Account"}} default button 1)')
            label = label.strip() if label else def_label
            save_current_account(custom_label=label)
            play_sound("Hero")
            osascript(f'tell application "System Events" to display dialog "✅ Account \'{label}\' saved successfully!\\n\\nYou can now switch between accounts with 1 click." buttons {{"Done"}} default button 1 with icon note')
            return
        elif new_tok and new_tok == curr:
            retry = osascript('tell application "System Events" to button returned of (display dialog "⚠️ Same account detected.\\n\\nPlease log in with a different Gmail account in Antigravity." buttons {"Cancel", "Try Again"} default button 2 with icon caution)')
            if retry != "Try Again":
                return
        else:
            retry = osascript('tell application "System Events" to button returned of (display dialog "⚠️ No active login detected in Antigravity yet.\\n\\nPlease ensure you completed Google sign-in in the Antigravity window." buttons {"Cancel", "Try Again"} default button 2 with icon caution)')
            if retry != "Try Again":
                return

def logout_and_add_account():
    """Launch add account wizard."""
    add_account_wizard()

def main_menu():
    """Interactive GUI dialog picker."""
    manifest = load_manifest()
    curr_token = get_current_keychain_token()
    
    # Quick live usage fetch for active account
    active_usage = fetch_antigravity_usage(curr_token) if curr_token else None
    active_email = active_usage.get('email') if active_usage else (extract_email_from_token(curr_token) if curr_token else None)
    
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
    for k in sorted(manifest.keys()):
        if k == active_key:
            items.append(f"🟢 [ACTIVE] {k}")
        else:
            items.append(f"⚡️ Switch to: {k}")
        
    items.append("─────────────────────────────")
    curr_display = active_email or (active_key if active_key else "Active Session") if curr_token else "Not Signed In"
    
    usage_info_line = ""
    if active_usage:
        sess = active_usage.get('session', {})
        u_pct = sess.get('used_pct', 0.0)
        r_in = sess.get('resets_in', 'N/A')
        usage_info_line = f" • ⚡️ {u_pct}% used"
        if r_in != 'N/A':
            usage_info_line += f" (Resets: {r_in})"
            
    items.append("📊 View Usage & Limits (Claude Style)")
    items.append(f"💾 Save Current Account ({curr_display})")
    items.append("➕ Add New Account (Guided Wizard)")
    if manifest:
        items.append("🗑 Remove a Saved Account")
    items.append("─────────────────────────────")
    items.append("⭐ About & Star on GitHub (by Rick Sanchez)")
        
    items_applescript = '{' + ', '.join([f'"{it}"' for it in items]) + '}'
    arch_info = get_arch_label()
    prompt = f"🚀 Antigravity Account Switcher\\n{arch_info} • by Rick Sanchez\\n🟢 Active Account: {curr_display}{usage_info_line}\\n\\nChoose an action:"
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
    elif choice == "📊 View Usage & Limits (Claude Style)":
        open_claude_usage_window(active_key)
    elif choice.startswith("💾 Save Current Account"):
        save_current_account()
    elif choice.startswith("➕ Add New Account") or choice.startswith("➕ Add New Gmail"):
        logout_and_add_account()
    elif choice.startswith("⭐ About"):
        show_about()
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
    parser = argparse.ArgumentParser(description=f"Antigravity Account Switcher by {AUTHOR_NAME}")
    parser.add_argument('-u', '--usage', action='store_true', help="Display Antigravity usage in Claude Code CLI style")
    parser.add_argument('--usage-gui', action='store_true', help="Open interactive Claude-style desktop usage dashboard")
    parser.add_argument('--list', action='store_true', help="List saved accounts")
    parser.add_argument('--switch', type=str, help="Switch to specific account")
    parser.add_argument('--save', nargs='?', const='', help="Save current account with optional name")
    parser.add_argument('--wizard', '--add', action='store_true', dest='wizard', help="Run interactive guided wizard to add a new account")
    parser.add_argument('--logout', action='store_true', help="Log out from current account")
    parser.add_argument('--github', action='store_true', help="Open GitHub project page")
    parser.add_argument('--about', action='store_true', help="Display creator & project info")
    args = parser.parse_args()

    if args.usage:
        curr = get_current_keychain_token()
        if not curr:
            print("\n❌ No active Antigravity session found in Keychain. Please sign in first.\n")
            sys.exit(1)
        usage = fetch_antigravity_usage(curr)
        print_claude_cli_usage(usage)
    elif args.usage_gui:
        open_claude_usage_window()
    elif args.list:
        m = load_manifest()
        curr = get_current_keychain_token()
        print(f"\n🚀 Antigravity Accounts [{get_arch_label()}]")
        print(f"👨‍💻 Created by Rick Sanchez ({GITHUB_REPO_URL})\n")
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
    elif args.wizard:
        add_account_wizard()
    elif args.logout:
        logout_and_add_account()
    elif args.github:
        open_github()
    elif args.about:
        show_about()
    else:
        main_menu()
