<#
.SYNOPSIS
    Antigravity Account Switcher for Windows 10 & 11
    Created by Rick Sanchez (https://github.com/m4tinbeigi-official)
    Seamless 1-click Google account switcher for Google Antigravity.
    Communicates directly with Windows Credential Manager (advapi32.dll).
#>

param (
    [switch]$List,
    [string]$Switch,
    [switch]$Save,
    [switch]$Logout,
    [switch]$About,
    [switch]$GitHub
)

$GitHubRepoUrl = "https://github.com/m4tinbeigi-official/antigravity-account-switcher"
$AuthorName = "Rick Sanchez (@m4tinbeigi-official)"

# -------------------------------------------------------------
# C# Native Windows Credential Manager Interop
# -------------------------------------------------------------
if (-not ([System.Management.Automation.PSTypeName]'WinCred').Type) {
    $csharpCode = @"
    using System;
    using System.Text;
    using System.Runtime.InteropServices;

    public class WinCred {
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredRead(string target, int type, int reservedFlag, out IntPtr credentialPtr);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredWrite([In] ref CREDENTIAL userCredential, int flags);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredDelete(string target, int type, int flags);

        [DllImport("advapi32.dll", SetLastError = true)]
        public static extern void CredFree([In] IntPtr cred);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct CREDENTIAL {
            public int Flags;
            public int Type;
            public string TargetName;
            public string Comment;
            public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
            public int CredentialBlobSize;
            public IntPtr CredentialBlob;
            public int Persist;
            public int AttributeCount;
            public IntPtr Attributes;
            public string TargetAlias;
            public string UserName;
        }

        public static string Read(string target) {
            IntPtr credPtr;
            if (!CredRead(target, 1, 0, out credPtr)) return null;
            try {
                CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(credPtr, typeof(CREDENTIAL));
                byte[] bytes = new byte[cred.CredentialBlobSize];
                Marshal.Copy(cred.CredentialBlob, bytes, 0, cred.CredentialBlobSize);
                string utf8 = Encoding.UTF8.GetString(bytes);
                if (utf8.StartsWith("go-keyring-base64:")) return utf8;
                return Encoding.Unicode.GetString(bytes);
            } finally {
                CredFree(credPtr);
            }
        }

        public static bool Write(string target, string username, string secret) {
            byte[] bytes = Encoding.UTF8.GetBytes(secret);
            IntPtr secretPtr = Marshal.AllocHGlobal(bytes.Length);
            try {
                Marshal.Copy(bytes, 0, secretPtr, bytes.Length);
                CREDENTIAL cred = new CREDENTIAL();
                cred.Type = 1;
                cred.TargetName = target;
                cred.UserName = username;
                cred.CredentialBlob = secretPtr;
                cred.CredentialBlobSize = bytes.Length;
                cred.Persist = 2;
                return CredWrite(ref cred, 0);
            } finally {
                Marshal.FreeHGlobal(secretPtr);
            }
        }

        public static bool Delete(string target) {
            return CredDelete(target, 1, 0);
        }
    }
"@
    Add-Type -TypeDefinition $csharpCode -Language CSharp
}

$AccountsDir = Join-Path $HOME ".gemini\accounts"
$ManifestPath = Join-Path $AccountsDir "manifest.json"

if (!(Test-Path $AccountsDir)) {
    New-Item -ItemType Directory -Path $AccountsDir -Force | Out-Null
}

function Get-Manifest {
    if (Test-Path $ManifestPath) {
        try {
            return Get-Content $ManifestPath -Raw | ConvertFrom-Json
        } catch {
            return @{}
        }
    }
    return @{}
}

function Save-Manifest($manifest) {
    $manifest | ConvertTo-Json -Depth 4 | Set-Content $ManifestPath -Encoding UTF8
}

function Get-CurrentToken {
    return [WinCred]::Read("gemini")
}

function Extract-Email($tokenStr) {
    if (!$tokenStr -or !$tokenStr.StartsWith("go-keyring-base64:")) { return $null }
    try {
        $b64 = $tokenStr.Substring("go-keyring-base64:".Length)
        $jsonBytes = [System.Convert]::FromBase64String($b64)
        $jsonStr = [System.Text.Encoding]::UTF8.GetString($jsonBytes)
        $data = $jsonStr | ConvertFrom-Json
        $accessToken = $data.token.access_token
        if ($accessToken) {
            $headers = @{ "Authorization" = "Bearer $accessToken" }
            $resp = Invoke-RestMethod -Uri "https://www.googleapis.com/oauth2/v3/userinfo" -Headers $headers -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($resp.email) { return $resp.email }
        }
    } catch {}
    return $null
}

function Restart-Antigravity {
    Write-Host "🔄 Restarting Antigravity..." -ForegroundColor Cyan
    Get-Process -Name "Antigravity" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    
    $paths = @(
        "$env:LOCALAPPDATA\Programs\Antigravity\Antigravity.exe",
        "$env:ProgramFiles\Antigravity\Antigravity.exe",
        "$env:ProgramFiles(x86)\Antigravity\Antigravity.exe"
    )
    $exe = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($exe) {
        Start-Process $exe
    } else {
        Start-Process "Antigravity" -ErrorAction SilentlyContinue
    }
}

function Switch-Account($accountKey) {
    $manifest = Get-Manifest
    $prop = $manifest.PSObject.Properties[$accountKey]
    if (!$prop) {
        [System.Windows.Forms.MessageBox]::Show("Account '$accountKey' not found.", "Error", 0, 16) | Out-Null
        return
    }
    $tokenFile = $prop.Value.token_file
    if (!(Test-Path $tokenFile)) {
        [System.Windows.Forms.MessageBox]::Show("Token file missing for '$accountKey'.", "Error", 0, 16) | Out-Null
        return
    }
    $token = Get-Content $tokenFile -Raw
    $ok = [WinCred]::Write("gemini", "antigravity", $token.Trim())
    if ($ok) {
        Restart-Antigravity
        [System.Windows.Forms.MessageBox]::Show("Successfully switched to $accountKey!`n`nCreated by Rick Sanchez", "Antigravity Switcher", 0, 64) | Out-Null
    } else {
        [System.Windows.Forms.MessageBox]::Show("Failed to write to Windows Credential Manager.", "Error", 0, 16) | Out-Null
    }
}

function Save-CurrentAccount {
    $token = Get-CurrentToken
    if (!$token) {
        [System.Windows.Forms.MessageBox]::Show("No active Antigravity account found in Windows Credential Manager. Please sign in to Antigravity first.", "Notice", 0, 48) | Out-Null
        return
    }
    $email = Extract-Email $token
    if (!$email) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        $email = [Microsoft.VisualBasic.Interaction]::InputBox("Enter name/email for this account:", "Save Account", "account@gmail.com")
        if (!$email) { return }
    }
    $tokenFile = Join-Path $AccountsDir "$($email -replace '[\\/:*?""<>|]', '_').token"
    $token | Set-Content $tokenFile -Encoding UTF8
    
    $manifest = Get-Manifest
    $newEntry = [PSCustomObject]@{
        label = $email
        email = $email
        token_file = $tokenFile
        saved_at = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $manifest | Add-Member -MemberType NoteProperty -Name $email -Value $newEntry -Force
    Save-Manifest $manifest
    [System.Windows.Forms.MessageBox]::Show("Account '$email' saved successfully!", "Antigravity Switcher", 0, 64) | Out-Null
}

function Logout-And-Add {
    $token = Get-CurrentToken
    if ($token) {
        $res = [System.Windows.Forms.MessageBox]::Show("Would you like to save the current account before logging out?", "Confirm", 3, 32)
        if ($res -eq [System.Windows.Forms.DialogResult]::Cancel) { return }
        if ($res -eq [System.Windows.Forms.DialogResult]::Yes) { Save-CurrentAccount }
    }
    [WinCred]::Delete("gemini") | Out-Null
    Restart-Antigravity
    [System.Windows.Forms.MessageBox]::Show("Logged out from Antigravity!`n`nAntigravity is reopening. Sign in with your other Gmail, then run Switcher again to save it!", "Notice", 0, 64) | Out-Null
}

function Show-AboutDialog {
    $msg = "🚀 Antigravity Account Switcher`n`n👨‍💻 Creator: $AuthorName`n🌐 GitHub: $GitHubRepoUrl`n`nWould you like to open the GitHub repository to give it a ⭐ Star?"
    $ans = [System.Windows.Forms.MessageBox]::Show($msg, "About Antigravity Switcher", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information)
    if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
        Start-Process $GitHubRepoUrl
    }
}

# CLI Handling
if ($About) {
    Write-Host "`n🚀 Antigravity Account Switcher (Windows)" -ForegroundColor Cyan
    Write-Host "👨‍💻 Creator: $AuthorName" -ForegroundColor Yellow
    Write-Host "⭐ Star on GitHub: $GitHubRepoUrl`n" -ForegroundColor White
    exit
}

if ($GitHub) {
    Start-Process $GitHubRepoUrl
    exit
}

if ($List) {
    $manifest = Get-Manifest
    $curr = Get-CurrentToken
    Write-Host "`n🚀 Antigravity Accounts (Windows)" -ForegroundColor Green
    Write-Host "👨‍💻 Creator: $AuthorName ($GitHubRepoUrl)`n" -ForegroundColor Gray
    foreach ($prop in $manifest.PSObject.Properties) {
        $active = ""
        $tf = $prop.Value.token_file
        if ($curr -and (Test-Path $tf) -and ((Get-Content $tf -Raw).Trim() -eq $curr.Trim())) {
            $active = " [ACTIVE]"
        }
        Write-Host " • $($prop.Name)$active (Saved: $($prop.Value.saved_at))"
    }
    Write-Host ""
    exit
}

if ($Switch) {
    Switch-Account $Switch
    exit
}

if ($Save) {
    Save-CurrentAccount
    exit
}

if ($Logout) {
    Logout-And-Add
    exit
}

# Interactive WinForms GUI Menu
Add-Type -AssemblyName System.Windows.Forms
$manifest = Get-Manifest
$curr = Get-CurrentToken
$activeEmail = if ($curr) { Extract-Email $curr } else { $null }

$form = New-Object System.Windows.Forms.Form
$form.Text = "🚀 Antigravity Account Switcher • by Rick Sanchez"
$form.Size = New-Object System.Drawing.Size(460, 480)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$lbl = New-Object System.Windows.Forms.Label
$lbl.Location = New-Object System.Drawing.Point(20, 15)
$lbl.Size = New-Object System.Drawing.Size(400, 24)
$lbl.Text = "Active Account: $(if ($activeEmail) { $activeEmail } else { 'Not Signed In' })"
$lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($lbl)

$lblAuthor = New-Object System.Windows.Forms.Label
$lblAuthor.Location = New-Object System.Drawing.Point(20, 40)
$lblAuthor.Size = New-Object System.Drawing.Size(400, 18)
$lblAuthor.Text = "Created by Rick Sanchez • Windows 10/11 Edition"
$lblAuthor.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Italic)
$lblAuthor.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblAuthor)

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(20, 68)
$listBox.Size = New-Object System.Drawing.Size(400, 170)
$listBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
foreach ($prop in $manifest.PSObject.Properties) {
    $listBox.Items.Add($prop.Name) | Out-Null
}
if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }
$form.Controls.Add($listBox)

# Switch Button
$btnSwitch = New-Object System.Windows.Forms.Button
$btnSwitch.Location = New-Object System.Drawing.Point(20, 250)
$btnSwitch.Size = New-Object System.Drawing.Size(190, 38)
$btnSwitch.Text = "⚡️ Switch to Selected"
$btnSwitch.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnSwitch.Add_Click({
    if ($listBox.SelectedItem) {
        $form.Close()
        Switch-Account $listBox.SelectedItem
    }
})
$form.Controls.Add($btnSwitch)

# Save Button
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Location = New-Object System.Drawing.Point(230, 250)
$btnSave.Size = New-Object System.Drawing.Size(190, 38)
$btnSave.Text = "💾 Save Current Account"
$btnSave.Add_Click({
    $form.Close()
    Save-CurrentAccount
})
$form.Controls.Add($btnSave)

# Logout Button
$btnLogout = New-Object System.Windows.Forms.Button
$btnLogout.Location = New-Object System.Drawing.Point(20, 300)
$btnLogout.Size = New-Object System.Drawing.Size(400, 38)
$btnLogout.Text = "➕ Add New Account (Logout & Sign In)"
$btnLogout.Add_Click({
    $form.Close()
    Logout-And-Add
})
$form.Controls.Add($btnLogout)

# Star on GitHub / About Button
$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Location = New-Object System.Drawing.Point(20, 350)
$btnAbout.Size = New-Object System.Drawing.Size(400, 38)
$btnAbout.Text = "⭐ Star on GitHub & About (by Rick Sanchez)"
$btnAbout.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAbout.Add_Click({
    Show-AboutDialog
})
$form.Controls.Add($btnAbout)

$form.ShowDialog() | Out-Null
