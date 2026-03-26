# Just Before The Meeting

A native macOS **menu bar app** that connects to **Google Calendar**, plays your **custom news-style theme music** with a **pulsing countdown** in the menu bar before selected meetings.

**Setup and ship checklist:** **[docs/next-steps.md](docs/next-steps.md)** (Google OAuth for all users, notarization, GitHub Releases, Pages)

---

## Features

- **Menu bar only** — runs in the background with no Dock icon (`LSUIElement`)
- **Google Calendar sync** — OAuth 2.0 with PKCE, polls your calendars on a configurable interval
- **Countdown timer** — pulsing red/orange `⏰ 0:30` → `0:00` in the status bar; click to dismiss early
- **Custom audio** — bring your own news theme (mp3/m4a) with fade-in/out; volume control in settings
- **Event filtering** — rules (all events / video-only / keyword match) plus per-event toggles
- **Settings UI** — SwiftUI tabbed window: Calendar, Events, Sound, General
- **Launch at login** — via `SMAppService` on macOS 13+
- **Backup notifications** — optional `UNUserNotificationCenter` alert when countdown starts

## Project layout

```
JustBeforeTheMeeting/          Xcode project and Swift sources
  Config/
    Secrets.example.xcconfig   Copy to Secrets.xcconfig and add your credentials
  JustBeforeTheMeeting/
    App/                       AppDelegate, StatusBarController, SettingsWindowController
    Services/                  AudioManager, CountdownManager, GoogleCalendarService,
                               OAuthManager, EventScheduler, KeychainHelper, SettingsManager
    Models/                    CalendarEvent, EventFilterRule
    Views/                     SettingsView, CalendarSettingsView, SoundSettingsView,
                               GeneralSettingsView, EventRulesSettingsView
    Resources/                 Assets.xcassets (app icon), default_theme.mp3
    Info.plist                 Uses $(GOOGLE_OAUTH_CLIENT_ID) and $(GOOGLE_OAUTH_CLIENT_SECRET)
website/                       Static landing page (replace download link when you ship)
scripts/build-and-distribute.sh  Archive → sign → DMG → notarize
docs/next-steps.md            Step-by-step: dev, Google production OAuth, notarize, deploy
```

## Quick start

### 1. Clone and set up secrets

```bash
git clone https://github.com/ozgurbuluta/justbeforethemeeting.git
cd justbeforethemeeting/JustBeforeTheMeeting/Config
cp Secrets.example.xcconfig Secrets.xcconfig
```

Edit `Secrets.xcconfig` with your Google OAuth credentials:

```
GOOGLE_OAUTH_CLIENT_ID = your-client-id.apps.googleusercontent.com
GOOGLE_OAUTH_CLIENT_SECRET = your-client-secret
```

### 2. Google Cloud setup

1. [Google Cloud Console](https://console.cloud.google.com/) → create or select a project
2. **APIs & Services** → **Library** → enable **Google Calendar API**
3. **OAuth consent screen** → External → add scope `calendar.readonly` → add yourself as test user
4. **Credentials** → **OAuth client ID** → type **Desktop app** → create
5. Copy the **Client ID** and **Client Secret** into `Secrets.xcconfig`

### 3. Build and run

1. Open `JustBeforeTheMeeting/JustBeforeTheMeeting.xcodeproj` in Xcode
2. Destination: **My Mac** (no simulator needed — this is a native Mac app)
3. **Command+R** to build and run
4. Look for **JBTM** in the menu bar (top-right of screen)
5. Click → **Connect Google Calendar** → sign in via browser
6. Use **Test Countdown + Music** to verify it works

### 4. Custom sound

The app looks for `default_theme.mp3` or `default_theme.m4a` in the bundle. To use your own:

- Drag your audio file into the Xcode project under Resources
- Check **Copy items if needed** and **Add to targets: JustBeforeTheMeeting**
- Or pick any file at runtime via **Settings → Sound → Choose sound file**

## How it works

```
Google Calendar API
        │ polls every N minutes
        ▼
  GoogleCalendarService → events
        │
        ▼
   EventScheduler → schedules timers (advance warning seconds before each event)
        │
        ├──▶ CountdownManager → pulsing ⏰ timer in NSStatusItem
        │
        └──▶ AudioManager → plays theme with fade-in
        
  When countdown hits 0 → fade out audio → restore normal menu bar icon
  Click countdown → cancel early → stop audio immediately
```

## Website (GitHub Pages)

The [`website/`](website/) folder deploys with **GitHub Actions** (`.github/workflows/deploy-pages.yml`) when you push to `main`. In the repo’s **Settings → Pages**, set **Source** to **GitHub Actions** (not “Deploy from a branch”) so the workflow can publish. If the workflow fails with **Failed to create deployment (404)**, Pages is not enabled yet—open **Settings → Pages**, choose **GitHub Actions**, save, then re-run the failed workflow or push an empty commit.

## Distribution (optional)

To ship a signed + notarized DMG for others to download:

1. **Apple Developer Program** ($99/year) → **Developer ID Application** certificate
2. Set credentials:

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEY_PATH="$HOME/AuthKey_XXXXX.p8"
export NOTARY_KEY_ID="XXXXXXXXXX"
export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
./scripts/build-and-distribute.sh
```

3. Upload `build/JustBeforeTheMeeting.dmg` to **GitHub Releases** with the exact filename **`JustBeforeTheMeeting.dmg`** so the site’s button works with  
   `https://github.com/ozgurbuluta/justbeforethemeeting/releases/latest/download/JustBeforeTheMeeting.dmg`  
   (or use your own host and change [`website/index.html`](website/index.html).)
4. The landing page download link targets that URL by default; adjust if you host the DMG elsewhere.

## Requirements

- macOS **13.0**+
- Xcode **15**+ (for building)

## Security and privacy

- OAuth credentials are stored in a **local `.xcconfig`** file that is **gitignored**
- Calendar tokens are stored in the **macOS Keychain**
- Calendar data is read-only (`calendar.readonly` scope) and kept in memory only
- No data leaves your machine except Google Calendar API requests
