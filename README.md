<p align="center">
  <a href="https://devsponsors.github.io">
    <img src="https://devsponsors.github.io/assets/badges/sponsor.svg" alt="DevSponsors Badge">
  </a>
</p>

<!-- DevSponsors Badges -->
<p align="center">
  <a href="https://devsponsors.github.io"><img src="https://img.shields.io/badge/DevSponsors-Verified_OSS-6366f1?style=for-the-badge&logo=github" alt="DevSponsors Verified"></a>
  <a href="https://devsponsors.github.io"><img src="https://img.shields.io/badge/Sponsor-DevSponsors_Hub-emerald?style=for-the-badge&logo=github-sponsors" alt="DevSponsors Sponsor"></a>
  <a href="https://devsponsors.github.io/mediakit.html"><img src="https://img.shields.io/badge/Infrastructure-DevSponsors_Cloud-ec4899?style=for-the-badge&logo=server" alt="DevSponsors Cloud"></a>
</p>

<div align="center">

# 🚀 Antigravity Account Switcher

**Super-fast, seamless 1-click Google account switcher for Google Antigravity on macOS (Intel & Apple Silicon) and Windows.**

Developed with ❤️ by **[Rick Sanchez](https://github.com/m4tinbeigi-official)**

[![macOS](https://img.shields.io/badge/Platform-macOS%20(Intel%20%7C%20Apple%20Silicon)-black?logo=apple&style=for-the-badge)](https://apple.com)
[![Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows&style=for-the-badge)](https://microsoft.com)
[![Website](https://img.shields.io/badge/Website-GitHub%20Pages-0969da?style=for-the-badge)](https://m4tinbeigi-official.github.io/antigravity-account-switcher/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)
[![GitHub Star](https://img.shields.io/badge/Support-Give%20a%20⭐%20Star-yellow.svg?style=for-the-badge)](https://github.com/m4tinbeigi-official/antigravity-account-switcher)

[🌐 Live Website & Docs](https://m4tinbeigi-official.github.io/antigravity-account-switcher/) • [English](#-english) • [فارسی](#-فارسی)

<br/>

<img src="assets/promo_banner.jpg" alt="Antigravity Account Switcher Banner" width="820" style="border-radius: 16px; box-shadow: 0 12px 36px rgba(0,0,0,0.6);" />

<br/><br/>

### 📸 Application Interface & Live Quotas Dashboard
<p align="center">
  <img src="assets/dashboard_preview.png" alt="Antigravity Live Dual Quotas Dashboard" width="440" style="border-radius: 14px; box-shadow: 0 12px 36px rgba(0,0,0,0.6); border: 1px solid rgba(255,255,255,0.15); margin: 6px;" />
  <img src="assets/screenshot.png" alt="Antigravity Account Switcher Interface" width="440" style="border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); border: 1px solid rgba(255,255,255,0.15); margin: 6px;" />
</p>

</div>

---

## 👨‍💻 Creator & Author
- **Author**: Rick Sanchez
- **GitHub Profile**: [@m4tinbeigi-official](https://github.com/m4tinbeigi-official)
- **Repository**: [github.com/m4tinbeigi-official/antigravity-account-switcher](https://github.com/m4tinbeigi-official/antigravity-account-switcher)

⭐ **If you find this tool helpful, please star the repository to support further open-source development!**

---

## 🇬🇧 English

### Overview
Switching between multiple Gmail / Google accounts on **Google Antigravity** can be frustrating because session tokens are securely protected inside **macOS Keychain** or **Windows Credential Manager** (`service: "gemini"`, `account: "antigravity"`).

**Antigravity Account Switcher** is an ultra-fast, native cross-platform utility (GUI & CLI) that communicates directly with native credential managers to store, manage, and switch your Google Antigravity identities in under 3 seconds.

### ✨ Features
- ⚡️ **Instant 1-Click Switching**: Seamlessly swap between work, personal, or dev accounts.
- 🖥 **macOS Menu Bar Applet**: Sleek, compact 1-click status bar item next to system clock for instant switching and quota viewing.
- 🧩 **Antigravity IDE Status Bar Integration**: QuickPick account switcher and limit viewer built right into the code editor's status bar.
- 📊 **Dual Quota Monitoring (Daily & Weekly)**: Separate live tracking for Gemini daily rolling limits & Claude 4.6 / GPT-OSS weekly limits with live ticking countdowns.
- 🧙‍♂️ **Guided Add Account Wizard**: Interactive step-by-step sign-in flow that detects and saves new accounts automatically without CLI commands.
- 🚀 **Parallel Sub-Second Engine**: Parallel thread querying with smart local caching for instant dashboard opening.
- 🍏 **Universal macOS Support**: Native Universal 2 binary for **Apple Silicon (M1/M2/M3/M4)** and **Intel (x86_64)** with tactile sound effects and high-res icon.
- 🪟 **Native Windows 10 & 11 Support**: Direct integration with Windows Credential Manager (`advapi32.dll`) via PowerShell and WinForms UI.
- 🔒 **Zero Data Transmission**: Everything runs 100% locally on your machine. Tokens never leave your local credential store.
- 💻 **Spotlight & CLI Integration**: Run from `/Applications`, Desktop, Spotlight (`Cmd+Space`), or terminal via `agy-switch`.
- 🔄 **Safe Auto-Restart**: Cleanly terminates background language servers and restarts Antigravity with the selected account applied.

---

### 📦 Installation & Setup

#### 🍏 macOS (Apple Silicon & Intel)
```bash
git clone https://github.com/m4tinbeigi-official/antigravity-account-switcher.git
cd antigravity-account-switcher
./install.sh
```
*Creates `AntigravitySwitcher.app` in `/Applications` and `~/Desktop`, and registers `agy-switch` in your terminal PATH.*

#### 🪟 Windows (10 & 11)
```powershell
git clone https://github.com/m4tinbeigi-official/antigravity-account-switcher.git
cd antigravity-account-switcher
.\install.bat
```
*Creates `AntigravitySwitcher.bat` on your Desktop.*

---

### 🎮 Usage

#### GUI Mode
- **macOS**: Open **`AntigravitySwitcher.app`** from Applications, Desktop, or Spotlight (`Cmd+Space`). Select **`📊 View Usage & Limits (Claude Style)`**.
- **Windows**: Double-click **`AntigravitySwitcher.bat`** on your Desktop.

#### CLI Mode
```bash
# macOS terminal:
agy-switch --usage            # 📊 Display live quota in Claude Code style
agy-switch --usage-gui        # 🖥 Open standalone Claude usage desktop window
agy-switch --list             # List saved accounts
agy-switch --switch user@gmail.com
agy-switch --save
agy-switch --logout
agy-switch --about

# Windows PowerShell:
powershell -File .\switcher_windows.ps1 -Usage   # 📊 Display live quota in Claude Code style
powershell -File .\switcher_windows.ps1 -List
powershell -File .\switcher_windows.ps1 -Switch user@gmail.com
powershell -File .\switcher_windows.ps1 -Save
powershell -File .\switcher_windows.ps1 -Logout
powershell -File .\switcher_windows.ps1 -About
```

---

## 🇮🇷 فارسی

### درباره سازنده
این ابزار توسط **[ریک سانچز (Rick Sanchez)](https://github.com/m4tinbeigi-official)** برای جامعه توسعه‌دهندگان و کاربران Google Antigravity به صورت کاملاً آزاد و متن‌باز (Open Source) توسعه داده شده است.
اگر این ابزار براتون کاربردی بود، لطفاً با **[دادن ستاره (Star ⭐) در گیت‌هاب](https://github.com/m4tinbeigi-official/antigravity-account-switcher)** از این پروژه حمایت کنید!

### معرفی
تغییر اکانت‌های گوگل در نرم‌افزار **Google Antigravity** به دلیل ذخیره‌سازی رمزنگاری‌شده در **macOS Keychain** و **Windows Credential Manager** پیچیده است.

**Antigravity Account Switcher** ابزاری کاملاً نیتیو و سبک برای **مک و ویندوز** است که مستقیماً با مدیریت اعتبار سیستم‌عامل ارتباط برقرار کرده و امکان جابه‌جایی سریع بین بی‌شمار اکانت گوگل را تنها با **یک کلیک** فراهم می‌سازد.

### 🌟 ویژگی‌های کلیدی
- ⚡️ **سوئیچ زیر ۳ ثانیه**: جابه‌جایی آنی بین اکانت‌های کاری و شخصی بدون نیاز به لاگین مجدد.
- 🖥 **آیکون نیتیو Menu Bar مک**: آیکون اختصاصی و کم‌حجم در نوار بالای مک کنار ساعت برای دسترسی سریع به تمام امکانات.
- 🧩 **اکستنشن ادیتور Antigravity IDE**: دسترسی مستقیم از نوار وضعیت پایین ادیتور (Status Bar).
- 📊 **تفکیک سهمیه روزانه و هفتگی**: رهگیری مجزای سهمیه روزانه مدل‌های Gemini و سهمیه هفتگی مدل‌های Claude 4.6 و GPT-OSS با تایمر معکوس زنده.
- 🧙‍♂️ **ویزارد هوشمند افزودن اکانت**: هدایت مرحله‌به‌مرحله برای ورود به جیمیل جدید و ذخیره خودکار بدون تایپ دستور در ترمینال.
- 🚀 **سرعت فوق‌العاده با کش محلی**: بارگذاری موازی و کش هوشمند برای باز شدن آنی در کسری از ثانیه.
- 🍏 **مک‌های سیلیکون و اینتل**: باینری دوگانه Universal 2 برای چیپ‌های سری M اپل و اینتل به همراه افکت صوتی و آیکون HD.
- 🪟 **ویندوز ۱۰ و ۱۱**: پیاده‌سازی نیتیو با PowerShell و WinForms با اتصال به `advapi32.dll` بدون نیاز به نصب پیش‌نیاز.
- 🔒 **امنیت ۱۰۰٪ آفلاین**: هیچ اطلاعاتی به هیچ سروری ارسال نمی‌شود؛ تمام داده‌ها به صورت امن در سیستم خودتان ذخیره می‌شوند.

---

### 📄 License
This project is licensed under the [MIT License](LICENSE).
