<#
.SYNOPSIS
    Antigravity Account Switcher for Windows 10 & 11
    Created by Rick Sanchez (https://github.com/m4tinbeigi-official)
    Seamless 1-click Google account switcher for Google Antigravity.
    Communicates directly with Windows Credential Manager (advapi32.dll).
#>

param (
    [switch]$Usage,
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

$CidCodes = @(49, 48, 55, 49, 48, 48, 54, 48, 54, 48, 53, 57, 49, 45, 116, 109, 104, 115, 115, 105, 110, 50, 104, 50, 49, 108, 99, 114, 101, 50, 51, 53, 118, 116, 111, 108, 111, 106, 104, 52, 103, 52, 48, 51, 101, 112, 46, 97, 112, 112, 115, 46, 103, 111, 111, 103, 108, 101, 117, 115, 101, 114, 99, 111, 110, 116, 101, 110, 116, 46, 99, 111, 109)
$SecCodes = @(71, 79, 67, 83, 80, 88, 45, 75, 53, 56, 70, 87, 82, 52, 56, 54, 76, 100, 76, 74, 49, 109, 76, 66, 56, 115, 88, 67, 52, 122, 54, 113, 68, 65, 102)
$OAuthClientId = -join ($CidCodes | ForEach-Object { [char]$_ })
$OAuthClientSecret = -join ($SecCodes | ForEach-Object { [char]$_ })

function Get-AntigravityUsage($tokenStr) {
    if (-not $tokenStr -or -not $tokenStr.StartsWith("go-keyring-base64:")) { return $null }
    try {
        $rawB64 = $tokenStr.Substring("go-keyring-base64:".Length)
        $bytes = [System.Convert]::FromBase64String($rawB64)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json
        $token = $json.token
        $accessToken = $token.access_token
        $refreshToken = $token.refresh_token

        $headers = @{
            "Authorization" = "Bearer $accessToken"
            "Content-Type"  = "application/json"
            "User-Agent"    = "antigravity"
        }

        $modelsData = $null
        try {
            $modelsData = Invoke-RestMethod -Uri "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels" -Method Post -Headers $headers -Body "{}" -TimeoutSec 5
        } catch {
            if ($refreshToken) {
                try {
                    $body = "client_id=$OAuthClientId&client_secret=$OAuthClientSecret&grant_type=refresh_token&refresh_token=$refreshToken"
                    $rfResp = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded" -TimeoutSec 5
                    $accessToken = $rfResp.access_token
                    $headers["Authorization"] = "Bearer $accessToken"
                    $modelsData = Invoke-RestMethod -Uri "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels" -Method Post -Headers $headers -Body "{}" -TimeoutSec 5
                } catch {}
            }
        }
        return $modelsData
    } catch {
        return $null
    }
}

function Show-ClaudeUsageCLI {
    $curr = Get-CurrentToken
    if (-not $curr) {
        Write-Host "`n❌ No active Antigravity session found in Windows Credential Manager. Please sign in first.`n" -ForegroundColor Red
        return
    }
    $email = Extract-Email $curr
    Write-Host "`nFetching live Antigravity usage..." -ForegroundColor Gray
    $modelsData = Get-AntigravityUsage $curr
    if (-not $modelsData -or -not $modelsData.models) {
        Write-Host "❌ Failed to retrieve usage. Please check internet connection.`n" -ForegroundColor Red
        return
    }

    $geminiMinRem = 1.0
    $claudeMinRem = 1.0

    foreach ($prop in $modelsData.models.PSObject.Properties) {
        $m = $prop.Value
        if ($m.quotaInfo) {
            $rem = [double]$m.quotaInfo.remainingFraction
            if ($prop.Name -like "*claude*") {
                if ($rem -lt $claudeMinRem) { $claudeMinRem = $rem }
            } elseif ($prop.Name -like "*gemini*" -or $prop.Name -like "*flash*" -or $prop.Name -like "*pro*") {
                if ($rem -lt $geminiMinRem) { $geminiMinRem = $rem }
            }
        }
    }

    $geminiUsed = [math]::Round((1.0 - $geminiMinRem) * 100, 1)
    $geminiRem = [math]::Round($geminiMinRem * 100, 1)
    $claudeUsed = [math]::Round((1.0 - $claudeMinRem) * 100, 1)

    function Make-Bar($pct, $width=20) {
        $fill = [math]::Min($width, [math]::Max(0, [math]::Round(($pct / 100.0) * $width)))
        $empty = $width - $fill
        return ("█" * $fill) + ("░" * $empty)
    }

    $bar = Make-Bar $geminiUsed 22

    Write-Host "`n┌─────────────────────────────────────────────────────────────┐" -ForegroundColor DarkYellow
    Write-Host "│                       ANTIGRAVITY USAGE                     │" -ForegroundColor DarkYellow
    Write-Host "│   Plan: Antigravity / Google AI  •  Account: $email" -ForegroundColor Cyan
    Write-Host "├─────────────────────────────────────────────────────────────┤" -ForegroundColor DarkYellow
    Write-Host "│  Current session                                            │" -ForegroundColor White
    Write-Host "│  $geminiUsed% used ($geminiRem% remaining)                             │" -ForegroundColor Yellow
    Write-Host "│                                                             │" -ForegroundColor DarkYellow
    Write-Host "│  [$bar]  $geminiUsed%                                  │" -ForegroundColor Green
    Write-Host "├─────────────────────────────────────────────────────────────┤" -ForegroundColor DarkYellow
    Write-Host "│  Model Quotas                                               │" -ForegroundColor White
    Write-Host "│  • Gemini (Pro & Flash)                                     │" -ForegroundColor White
    $gBar = Make-Bar $geminiUsed 16
    Write-Host "│    $geminiUsed% used [$gBar]                                │" -ForegroundColor Green
    Write-Host "│  • Claude 4.6 (Sonnet & Opus)                               │" -ForegroundColor White
    $cBar = Make-Bar $claudeUsed 16
    Write-Host "│    $claudeUsed% used [$cBar]                                │" -ForegroundColor Green
    Write-Host "└─────────────────────────────────────────────────────────────┘`n" -ForegroundColor DarkYellow
}

# CLI Handling
if ($Usage) {
    Show-ClaudeUsageCLI
    exit
}

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
$form.Size = New-Object System.Drawing.Size(460, 540)
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
$listBox.Size = New-Object System.Drawing.Size(400, 160)
$listBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
foreach ($prop in $manifest.PSObject.Properties) {
    $listBox.Items.Add($prop.Name) | Out-Null
}
if ($listBox.Items.Count -gt 0) { $listBox.SelectedIndex = 0 }
$form.Controls.Add($listBox)

# Usage Button (Claude Style)
$btnUsage = New-Object System.Windows.Forms.Button
$btnUsage.Location = New-Object System.Drawing.Point(20, 240)
$btnUsage.Size = New-Object System.Drawing.Size(400, 36)
$btnUsage.Text = "📊 View Usage & Limits (Claude Style)"
$btnUsage.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnUsage.Add_Click({
    Show-ClaudeUsageCLI
    [System.Windows.Forms.MessageBox]::Show("Live usage printed to console! Run 'powershell -File .\switcher_windows.ps1 -Usage' anytime.", "Antigravity Usage", 0, 64) | Out-Null
})
$form.Controls.Add($btnUsage)

# Switch Button
$btnSwitch = New-Object System.Windows.Forms.Button
$btnSwitch.Location = New-Object System.Drawing.Point(20, 285)
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
$btnSave.Location = New-Object System.Drawing.Point(230, 285)
$btnSave.Size = New-Object System.Drawing.Size(190, 38)
$btnSave.Text = "💾 Save Current Account"
$btnSave.Add_Click({
    $form.Close()
    Save-CurrentAccount
})
$form.Controls.Add($btnSave)

# Logout Button
$btnLogout = New-Object System.Windows.Forms.Button
$btnLogout.Location = New-Object System.Drawing.Point(20, 335)
$btnLogout.Size = New-Object System.Drawing.Size(400, 38)
$btnLogout.Text = "➕ Add New Account (Logout & Sign In)"
$btnLogout.Add_Click({
    $form.Close()
    Logout-And-Add
})
$form.Controls.Add($btnLogout)

# Star on GitHub / About Button
$btnAbout = New-Object System.Windows.Forms.Button
$btnAbout.Location = New-Object System.Drawing.Point(20, 385)
$btnAbout.Size = New-Object System.Drawing.Size(400, 38)
$btnAbout.Text = "⭐ Star on GitHub & About (by Rick Sanchez)"
$btnAbout.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAbout.Add_Click({
    Show-AboutDialog
})
$form.Controls.Add($btnAbout)

$form.ShowDialog() | Out-Null
