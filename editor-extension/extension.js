const vscode = require('vscode');
const { exec, execFile } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

let statusBarItem;

function getAgySwitchBin() {
    const candidates = [
        '/opt/homebrew/bin/agy-switch',
        '/usr/local/bin/agy-switch',
        path.join(os.homedir(), '.local/bin/agy-switch'),
        path.join(os.homedir(), 'antigravity-account-switcher/switcher_core.py')
    ];
    for (const p of candidates) {
        if (fs.existsSync(p)) return p;
    }
    return 'agy-switch';
}

function runCmd(cmd) {
    return new Promise((resolve) => {
        exec(cmd, (err, stdout, stderr) => {
            resolve({ code: err ? err.code : 0, stdout: stdout ? stdout.trim() : '', stderr: stderr ? stderr.trim() : '' });
        });
    });
}

function loadManifest() {
    const manifestPath = path.join(os.homedir(), '.gemini/accounts/manifest.json');
    if (fs.existsSync(manifestPath)) {
        try {
            return JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
        } catch (e) {
            return {};
        }
    }
    return {};
}

async function getActiveAccountInfo() {
    const manifest = loadManifest();
    let currToken = null;

    if (process.platform === 'darwin') {
        const res = await runCmd('security find-generic-password -s gemini -a antigravity -w 2>/dev/null');
        if (res.code === 0 && res.stdout.startsWith('go-keyring-base64:')) {
            currToken = res.stdout;
        }
    }

    let activeKey = null;
    if (currToken) {
        for (const [key, val] of Object.entries(manifest)) {
            const tf = val.token_file;
            if (tf && fs.existsSync(tf)) {
                try {
                    const tok = fs.readFileSync(tf, 'utf8').trim();
                    if (tok === currToken) {
                        activeKey = key;
                        break;
                    }
                } catch (e) {}
            }
        }
    }

    return { manifest, activeKey, hasActiveToken: !!currToken };
}

async function updateStatusBar() {
    if (!statusBarItem) return;
    try {
        const { activeKey, hasActiveToken } = await getActiveAccountInfo();
        if (activeKey) {
            statusBarItem.text = `$(account) Antigravity: ${activeKey}`;
            statusBarItem.tooltip = `Antigravity Active Account: ${activeKey} (Click to switch or view limits)`;
        } else if (hasActiveToken) {
            statusBarItem.text = `$(account) Antigravity: Active Session`;
            statusBarItem.tooltip = `Antigravity Session Active (Unsaved). Click to save or switch.`;
        } else {
            statusBarItem.text = `$(account) Antigravity: Not Signed In`;
            statusBarItem.tooltip = `No active Antigravity account. Click to sign in.`;
        }
    } catch (e) {
        statusBarItem.text = `$(account) Antigravity Switcher`;
    }
}

function activate(context) {
    statusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusBarItem.command = 'antigravitySwitcher.openMenu';
    statusBarItem.show();
    context.subscriptions.push(statusBarItem);

    updateStatusBar();
    const interval = setInterval(updateStatusBar, 15000);
    context.subscriptions.push({ dispose: () => clearInterval(interval) });

    const disposable = vscode.commands.registerCommand('antigravitySwitcher.openMenu', async () => {
        const { manifest, activeKey, hasActiveToken } = await getActiveAccountInfo();
        const bin = getAgySwitchBin();
        const items = [];

        // 1. Saved Accounts
        const keys = Object.keys(manifest).sort();
        for (const k of keys) {
            const isActive = (k === activeKey);
            items.push({
                label: `${isActive ? '🟢' : '⚡️'} Switch to: ${k}`,
                description: isActive ? '(Active Account)' : '',
                action: 'switch',
                target: k
            });
        }

        if (items.length > 0) {
            items.push({ label: '─────────────────────────────', kind: vscode.QuickPickItemKind.Separator });
        }

        // 2. Action Buttons
        items.push({
            label: '➕ Add New Account (Wizard)',
            description: 'Step-by-step sign in with another Gmail',
            action: 'wizard'
        });

        items.push({
            label: '📊 View Quotas & Limits',
            description: 'Claude-style live model limits dashboard',
            action: 'usage'
        });

        const activeDisplay = activeKey || (hasActiveToken ? 'Current Session' : null);
        if (activeDisplay) {
            items.push({
                label: `💾 Save Current Account (${activeDisplay})`,
                description: 'Save active session into account list',
                action: 'save'
            });
        }

        items.push({
            label: '🚀 Open Standalone Switcher App',
            description: 'Launch Mac applet window',
            action: 'app'
        });

        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: `Antigravity Switcher [Active: ${activeKey || 'Unsaved'}] - Choose an action:`
        });

        if (!selected || !selected.action) return;

        if (selected.action === 'switch') {
            vscode.window.showInformationMessage(`Switching to '${selected.target}'... Antigravity will reload.`);
            await runCmd(`"${bin}" --switch "${selected.target}"`);
            setTimeout(updateStatusBar, 2000);
        } else if (selected.action === 'wizard') {
            // Launch guided wizard
            vscode.window.showInformationMessage('Starting Add Account Wizard...');
            runCmd(`"${bin}" --wizard`);
        } else if (selected.action === 'usage') {
            runCmd(`"${bin}" --usage-gui`);
        } else if (selected.action === 'save') {
            const label = await vscode.window.showInputBox({
                prompt: 'Enter a name or label for this account:',
                value: activeKey || ''
            });
            if (label && label.trim()) {
                await runCmd(`"${bin}" --save "${label.trim()}"`);
                vscode.window.showInformationMessage(`Account '${label.trim()}' saved!`);
                updateStatusBar();
            }
        } else if (selected.action === 'app') {
            runCmd('open /Applications/AntigravitySwitcher.app 2>/dev/null || agy-switch');
        }
    });

    context.subscriptions.push(disposable);
}

function deactivate() {
    if (statusBarItem) {
        statusBarItem.dispose();
    }
}

module.exports = {
    activate,
    deactivate
};
