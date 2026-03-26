# First-time setup walkthrough

This guide expands the checklist from the main README. Follow the sections in order the first time you run the app.

---

## 1. Google Cloud: Calendar API and OAuth

You need a Google Cloud **project**, the **Calendar API** turned on, and an **OAuth client** whose redirect URI matches the app (`jbtm://oauth`).

### 1.1 Create or pick a project

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Sign in with the Google account you use for development.
3. Top bar: click the project name → **New Project** (or select an existing one).
4. Wait until the project is created and **select it** in the project picker.

### 1.2 Enable Google Calendar API

1. Left menu: **APIs & Services** → **Library** (or search “API Library”).
2. Search for **Google Calendar API**.
3. Open it → click **Enable**.

### 1.3 Configure the OAuth consent screen

1. **APIs & Services** → **OAuth consent screen**.
2. Choose **External** (any Google account can test, subject to limits) or **Internal** (only your Google Workspace org—if you have one).
3. Fill in the required fields (App name, user support email, developer contact).
4. **Scopes**: add **`.../auth/calendar.readonly`** (Google Calendar API → `.../auth/calendar.readonly`). The app only needs read access.
5. If you chose **External**, add **Test users** (your Gmail address) until you publish the app—otherwise only test users can sign in.
6. Save and continue through any remaining steps.

### 1.4 Create OAuth credentials (Desktop)

1. **APIs & Services** → **Credentials**.
2. **+ Create credentials** → **OAuth client ID**.
3. Application type: **Desktop app** (Google’s name for native clients like this Mac app).
4. Name it (e.g. `Just Before The Meeting Mac`).
5. **Authorized redirect URIs**: click **Add URI** and enter exactly:

   `jbtm://oauth`

6. Create. Copy the **Client ID** (looks like `123456789-xxxx.apps.googleusercontent.com`).  
   You do **not** need the Client Secret for this app’s PKCE flow.

If Google’s UI does not show redirect URIs for “Desktop app”, create the client anyway, then edit it and add **`jbtm://oauth`** under authorized redirect URIs, or create an OAuth client type that allows custom URL schemes (some consoles label this differently; the URI must match the app).

### 1.5 Testing vs public users

- **Testing (small audience):** Keep the OAuth consent screen in **Testing** and add every sign-in account under **Test users**. No Google verification required.
- **Production (any Google account):** Publish the consent screen and complete **Google verification** for sensitive/restricted scopes if prompted. Google often asks for an **app homepage** and **privacy policy URL**—use your deployed site and [`website/privacy.html`](../website/privacy.html) when that page is live.

---

## 2. Put the Client ID into the Mac app

The app reads the key **`GoogleOAuthClientID`** from its **Info.plist**.

### Option A — Easiest: edit in Xcode (good for local testing)

1. Open **`JustBeforeTheMeeting/JustBeforeTheMeeting.xcodeproj`** in Xcode.
2. In the Project Navigator, open **`JustBeforeTheMeeting/Info.plist`**.
3. Find the row **`GoogleOAuthClientID`**.
4. Double-click the **Value** column (currently empty) and paste your **Client ID** (the whole `….apps.googleusercontent.com` string).
5. Save (⌘S).

**Warning:** If you paste a real Client ID and commit `Info.plist`, it will be in git history. For a public repo, prefer Option B or a private build configuration.

### Option B — Keep secrets out of git (recommended for sharing the repo)

1. Do **not** put the real ID in a committed `Info.plist`.
2. Locally only, either:
   - Keep using Option A but **never commit** that change (easy to forget), or  
   - Add a **User-Defined** build setting in Xcode: select the **JustBeforeTheMeeting** target → **Build Settings** → **+** → **Add User-Defined Setting** → name `INFOPLIST_KEY_GoogleOAuthClientID`, value = your Client ID. (Requires the key to be merged at build time; your project may need that key added in Build Settings—we can add this to the project in a follow-up if you want it wired automatically.)

For most solo developers, **Option A** is fine for a **private** repo.

Confirm **`GoogleOAuthRedirectURI`** in `Info.plist` stays **`jbtm://oauth`** unless you changed it in Google Cloud (they must match).

---

## 3. Add theme audio (`default_theme.mp3` or `.m4a`)

The app looks for **`default_theme.mp3`** or **`default_theme.m4a`** in the app **bundle**, or you can pick any file under **Settings → Sound**.

### Add a file to the Xcode target

1. Put your audio file somewhere on disk (royalty-free clip you’re allowed to use).
2. In Xcode, drag the file into the **JustBeforeTheMeeting** group (e.g. under `Resources` or the app folder).
3. In the dialog, check:
   - **Copy items if needed**
   - **Add to targets:** **JustBeforeTheMeeting**
4. Select the project → **JustBeforeTheMeeting** target → **Build Phases** → **Copy Bundle Resources**.
5. Confirm your file is listed. If not, click **+** and add it.
6. Rename the file in the project to **`default_theme.mp3`** or **`default_theme.m4a`** so it matches what the code expects—or keep any name and use **Settings → Choose sound file**.

Run the app and use the menu **Test Sound (5s preview)** to verify.

---

## 4. App icon (menu bar / Finder)

The asset catalog **`Resources/Assets.xcassets/AppIcon.appiconset`** lists the sizes Xcode expects; slots can be empty until you add PNGs.

### Practical approaches

1. **Design** a square master image (at least **1024×1024** px is a good source).
2. **Generate macOS icon sizes** using:
   - Apple’s **[Icon Composer](https://developer.apple.com/icon-composer/)** (or similar), or  
   - Any trusted “macOS app icon” / `.icns` generator that exports the sizes Xcode needs.
3. In Xcode, open **`Assets.xcassets`** → **AppIcon**.
4. Drag each generated PNG into the matching **1x / 2x** slots for **16, 32, 128, 256, 512** pt (macOS).

Until you add images, macOS shows a generic icon; the app still runs.

---

## 5. Ship a DMG for download (Developer ID + notarization)

You need a **paid Apple Developer Program** membership ($99/year) to sign with **Developer ID Application** and **notarize** for strangers’ Macs to open the app without scary warnings.

### 5.1 Certificates in Xcode

1. Xcode → **Settings** (or **Preferences**) → **Accounts** → add your Apple ID.
2. Select your team → **Manage Certificates** → add **Developer ID Application** if missing.

### 5.2 Archive from Xcode (sanity check)

1. Open the project, scheme **JustBeforeTheMeeting**, destination **Any Mac (Apple Silicon, Intel)** or **My Mac**.
2. **Product** → **Archive**.
3. If archive succeeds, you can **Distribute App** → **Developer ID** → export a `.app` for testing signing (optional).

### 5.3 Notarization with `notarytool`

Apple recommends an **App Store Connect API key** for CI/notarytool.

1. [App Store Connect](https://appstoreconnect.apple.com/) → **Users and Access** → **Integrations** → **App Store Connect API** → generate a key with **Developer** access.
2. Download the **`.p8`** file once; note **Key ID** and **Issuer ID**.
3. **Never commit** the `.p8` file (it is in `.gitignore`).

From Terminal (adjust paths and IDs):

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEY_PATH="$HOME/path/to/AuthKey_XXXXX.p8"
export NOTARY_KEY_ID="XXXXXXXXXX"
export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

./scripts/build-and-distribute.sh
```

Alternatively, store a profile once:

```bash
xcrun notarytool store-credentials "jbtm-notary" \
  --key "$HOME/path/to/AuthKey_XXXXX.p8" \
  --key-id "XXXXXXXXXX" \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export NOTARY_PROFILE="jbtm-notary"
./scripts/build-and-distribute.sh
```

The script builds **`build/JustBeforeTheMeeting.dmg`** (path may vary; see script output).

### 5.4 Host the DMG and link the website

1. Upload the DMG to **GitHub Releases**, **S3**, **Cloudflare R2**, etc.
2. Copy the **direct download HTTPS URL**.
3. The landing page defaults to the GitHub Releases “latest” DMG URL; if you host the file elsewhere, edit **`website/index.html`** (`id="download-link"`) and keep the asset filename consistent if you still use the same URL pattern.

---

## Quick checklist

| Step | Done? |
|------|--------|
| Calendar API enabled | ☐ |
| OAuth consent screen + scope `calendar.readonly` | ☐ |
| OAuth Desktop client + redirect `jbtm://oauth` | ☐ |
| `GoogleOAuthClientID` set in Info.plist (or local build setting) | ☐ |
| Sound file in bundle or chosen in Settings | ☐ |
| App Icon PNGs (optional but nice) | ☐ |
| Developer ID sign + notarize + DMG + website link (only for public download) | ☐ |
| OAuth published + verified (only if non–test users sign in) | ☐ |

If something fails (OAuth error, blank calendar, no sound), check **README.md** and the in-app **About** text for reminders about Client ID and redirect URI.
