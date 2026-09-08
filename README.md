<div align="center">

# 🚀 Antigravity Account Switcher

**Super-fast, seamless 1-click Google account switcher for Google Antigravity on macOS (Intel & Apple Silicon).**

[![macOS](https://img.shields.io/badge/Platform-macOS%20(Intel%20%7C%20Apple%20Silicon)-black?logo=apple&style=for-the-badge)](https://apple.com)
[![Python 3](https://img.shields.io/badge/Python-3.8%2B-blue?logo=python&style=for-the-badge)](https://python.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

[English](#-english) • [فارسی](#-فارسی)

---

</div>

## 🇬🇧 English

### Overview
Switching between multiple Gmail / Google accounts on **Google Antigravity** can be frustrating because session tokens are securely protected inside **macOS Keychain** (`service: "gemini"`, `account: "antigravity"`).

**Antigravity Account Switcher** is an ultra-fast, native macOS utility and CLI that communicates directly with macOS Keychain to store, manage, and switch your Google Antigravity identities in under 3 seconds.

### ✨ Features
- ⚡️ **Instant 1-Click Switching**: Seamlessly swap between work, personal, or dev accounts.
- 🍏 **Native macOS App & Icon**: Beautiful `.app` bundle with tactile system sounds and notifications.
- 🔒 **Zero Data Transmission**: Everything runs 100% locally on your machine. Tokens never leave your macOS Keychain and local storage.
- 💻 **Spotlight & CLI Integration**: Run from `/Applications`, Dock, Spotlight (`Cmd+Space`), or terminal via `agy-switch`.
- 🔄 **Safe Auto-Restart**: Seamlessly restarts Antigravity with the selected account applied.

---

### 📦 Installation

Clone the repository and run the quick installer:

```bash
git clone https://github.com/m4tinbeigi-official/antigravity-account-switcher.git
cd antigravity-account-switcher
./install.sh
```

This will:
1. Build the standalone `AntigravitySwitcher.app`.
2. Install it directly to `/Applications` and `~/Desktop`.
3. Create the global terminal command `agy-switch`.

---

### 🎮 Usage

#### GUI Mode
1. Open **`AntigravitySwitcher.app`** from your Applications or Desktop.
2. Choose:
   - **`⚡️ Switch to: <Account>`**: Instantly switch to another saved account.
   - **`💾 Save Current Account`**: Save the currently logged-in account.
   - **`➕ Add New Gmail`**: Clear current session to sign in to another account.
   - **`🗑 Remove a Saved Account`**: Delete an account from the switcher list.

#### CLI Mode
```bash
# List all saved accounts and see the active one
agy-switch --list

# Switch to a specific account
agy-switch --switch user@gmail.com

# Save currently logged-in account
agy-switch --save

# Sign out to add another account
agy-switch --logout
```

---

## 🇮🇷 فارسی

### معرفی
تغییر اکانت‌های گوگل در نرم‌افزار **Google Antigravity** روی مک معمولاً زمان‌بر و دشوار است؛ زیرا توکن‌های نشست به‌صورت رمزنگاری‌شده در **macOS Keychain** ذخیره می‌شوند.

**Antigravity Account Switcher** ابزاری کاملاً نیتیو و سبک است که مستقیماً با کی‌چین مک ارتباط برقرار کرده و امکان جابه‌جایی سریع بین بی‌شمار اکانت گوگل را تنها با **یک کلیک** فراهم می‌سازد.

### 🌟 ویژگی‌های کلیدی
- ⚡️ **سوئیچ زیر ۳ ثانیه**: جابه‌جایی آنی بین اکانت‌های کاری و شخصی بدون نیاز به لاگین مجدد.
- 🍏 **اپلیکیشن نیتیو مک**: دارای آیکون رسمی با کیفیت بالا، افکت‌های صوتی بازخورد لمسی (Sound Effects) و نوتیفیکیشن.
- 🔒 **امنیت ۱۰۰٪ آفلاین**: هیچ اطلاعاتی به سرورهای خارجی ارسال نمی‌شود؛ تمام توکن‌ها در دایرکتوری امن مک و کی‌چین نگهداری می‌شوند.
- 💻 **پشتیبانی از Spotlight و ترمینال**: باز شدن با جستجوی مک (`Cmd + Space`) یا دستور ترمینال `agy-switch`.

### نحوه استفاده:
کافیه روی **`AntigravitySwitcher.app`** روی دسکتاپ دابل‌کلیک کنید و اکانت مورد نظرتون رو از لیست انتخاب کنید تا همه‌چیز در کسری از ثانیه انجام بشه!

---

### 📄 License
This project is licensed under the [MIT License](LICENSE).
