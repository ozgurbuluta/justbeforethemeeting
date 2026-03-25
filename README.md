# Just Before The Meeting

macOS menu bar app: connects to **Google Calendar**, plays your **custom news-style theme** with a **pulsing countdown** in the menu bar before selected meetings.

**New to setup?** Follow the click-by-click guide: **[docs/SETUP.md](docs/SETUP.md)** (Google Cloud, Client ID, sound file, icon, DMG + notarization).

## Project layout

- [`JustBeforeTheMeeting/`](JustBeforeTheMeeting/) — Xcode project and Swift sources
- [`website/`](website/) — static landing page (replace download link when you ship a DMG)
- [`scripts/build-and-distribute.sh`](scripts/build-and-distribute.sh) — archive, sign, DMG, notarize (with env vars)

## Build (Xcode)

1. Open `JustBeforeTheMeeting/JustBeforeTheMeeting.xcodeproj`
2. Select scheme **JustBeforeTheMeeting** and **My Mac**
3. Run (⌘R)

## Google OAuth setup

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → enable **Google Calendar API**
2. OAuth consent screen (External or Internal)
3. Credentials → **OAuth client ID** → Application type **Desktop app** (or use a macOS client that allows custom scheme)
4. Authorized redirect URIs: **`jbtm://oauth`**
5. Copy the Client ID into the app’s **Info.plist** key **`GoogleOAuthClientID`** (or override via build settings / `.xcconfig`)

Optional: **`GoogleOAuthRedirectURI`** (default `jbtm://oauth`) must match the console.

## Custom sound

- Add **`default_theme.mp3`** or **`default_theme.m4a`** to the Xcode target (Copy Bundle Resources), **or**
- Choose a file in **Settings → Sound**

## Distribution

1. Set **Developer ID Application** signing in Xcode or pass `CODE_SIGN_IDENTITY` to the script
2. Run `scripts/build-and-distribute.sh` with notarytool credentials (see script header)
3. Upload the DMG (e.g. GitHub Releases) and set `website/index.html` download link

## Requirements

- macOS **13**+
- Xcode **15**+ recommended

## Privacy

Calendar data is read via Google’s API with **read-only** scope and stored only in memory for scheduling; tokens are kept in the **Keychain**. Review Google’s policies before shipping to end users.
