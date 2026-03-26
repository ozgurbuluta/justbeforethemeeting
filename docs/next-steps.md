# Next steps — develop, publish Google OAuth for everyone, notarize, deploy

Use this as your **single checklist** from first credentials through public download. Check boxes as you go. Official links are included so you can open them in order.

**Repo map (for paths in this doc):**

- Mac app: `JustBeforeTheMeeting/`
- Local secrets (gitignored): `JustBeforeTheMeeting/Config/Secrets.xcconfig` (copy from `Secrets.example.xcconfig`)
- Ship script: `scripts/build-and-distribute.sh` (run from **repository root**)
- Site: `website/` (deployed via GitHub Actions when enabled)
- Privacy page (for Google verification): `website/privacy.html` → live URL will be `https://<your-pages-domain>/privacy.html`

---

## Phase 0 — Prerequisites (once)

| Step | Done |
|------|------|
| [ ] [Apple Developer Program](https://developer.apple.com/programs/enroll/) membership (paid) | ☐ |
| [ ] [Google Cloud](https://console.cloud.google.com/) account and a **project** for this app | ☐ |
| [ ] [GitHub](https://github.com/) repo pushed (e.g. `ozgurbuluta/justbeforethemeeting`) | ☐ |
| [ ] Xcode installed (15+); Command Line Tools: `xcode-select --install` if needed | ☐ |

---

## Phase 1 — Run the app locally (Google Calendar API + OAuth client + secrets)

### 1.1 Google Cloud project

1. Open **[Google Cloud Console](https://console.cloud.google.com/)**.
2. Top bar → project dropdown → **New Project** (or pick an existing project).
3. Select that project.

### 1.2 Enable Calendar API

1. Open **[API Library](https://console.cloud.google.com/apis/library)** (or **APIs & Services** → **Library**).
2. Search **Google Calendar API** → open it → **Enable**.

Direct link (replace `PROJECT_ID` if your console uses project-specific URLs; the Library search is reliable):  
[Google Calendar API in Library](https://console.cloud.google.com/apis/library/calendar-json.googleapis.com)

### 1.3 OAuth consent screen (initial configuration)

1. Go to **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** (**APIs & Services** → **OAuth consent screen**).
2. User type: **External** (public Gmail users) *or* **Internal** (Google Workspace only — only if your org uses Workspace).
3. Complete **App information** (name, support email, developer contact).
4. **Scopes** → **Add or remove scopes** → add **`.../auth/calendar.readonly`** (Google Calendar API / “See all your calendars’ metadata… read-only”).
5. **Save and continue** through any remaining steps.

> While the app is in **Testing**, only **Test users** you add can sign in. Phase 3 below moves you to **every user**.

### 1.4 OAuth client (Desktop) + redirect URI

1. Go to **[Credentials](https://console.cloud.google.com/apis/credentials)** (**APIs & Services** → **Credentials**).
2. **+ Create credentials** → **OAuth client ID**.
3. Application type: **Desktop app**.
4. Name (example): `Just Before The Meeting Mac`.
5. **Authorized redirect URIs** → **Add URI** → exactly:

   `jbtm://oauth`

6. **Create**. Copy the **Client ID** (`….apps.googleusercontent.com`). Copy the **Client secret** if shown (this project’s `Info.plist` can use it via xcconfig).

### 1.5 Put credentials in the Mac app (keep out of git)

1. In the repo: `cd JustBeforeTheMeeting/Config`
2. `cp Secrets.example.xcconfig Secrets.xcconfig` (if you do not already have `Secrets.xcconfig`).
3. Edit **`Secrets.xcconfig`**:

   - `GOOGLE_OAUTH_CLIENT_ID` = your Client ID  
   - `GOOGLE_OAUTH_CLIENT_SECRET` = your Client secret (if the Desktop client has one)

4. The Xcode target already uses this file as a base configuration; **`Secrets.xcconfig` is gitignored** — do not commit it.

### 1.6 Build and smoke-test in Xcode

1. Open **`JustBeforeTheMeeting/JustBeforeTheMeeting.xcodeproj`** in Xcode.
2. Scheme **JustBeforeTheMeeting**, run on **My Mac**.
3. Menu bar → connect Google → sync → sound → countdown (see README for feature list).

### 1.7 Optional polish

- **Sound:** bundle `default_theme.mp3` / `.m4a` or use **Settings → Sound** (see README).
- **Icon:** [Icon Composer](https://developer.apple.com/icon-composer/) → drag into **`Assets.xcassets` → AppIcon**.

---

## Phase 2 — Google: allow **every** user (not only test users)

While publishing status is **Testing**, sign-in works only for addresses listed under **Test users**. To allow **any** Google account:

### 2.1 Finish consent screen requirements

1. Open **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** again.
2. Ensure **App domain** / **Authorized domains** match where you host the app’s **privacy policy** and **home page** if Google asks (often your **GitHub Pages** domain or custom domain).
3. **App home page:** your public marketing URL (after Phase 5), e.g. `https://<user>.github.io/<repo>/` or your custom domain.
4. **Privacy policy link:** the deployed URL of **`privacy.html`**, e.g. `https://<user>.github.io/<repo>/privacy.html`  
   (Source file in repo: `website/privacy.html` — update the text if your legal name or data practices change.)

### 2.2 Publish the app (move out of Testing)

1. Still on **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)**.
2. When all required fields are green, use **Publish app** (wording may be **Push to production** / **In production** depending on the console).
3. Read Google’s warnings (quota, verification).

**Reference:** [Google Cloud: Publishing status](https://support.google.com/cloud/answer/10311615) (testing vs production).

### 2.3 Verification (if Google requires it)

Sensitive or restricted scopes often trigger **OAuth verification** (form + review). `calendar.readonly` may require verification for production; follow the console prompts.

- **Overview:** [OAuth API verification FAQs](https://support.google.com/cloud/answer/9110914)
- **Production / sensitive scopes:** [Google Identity: verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)

If verification is requested:

1. Submit the form with **accurate** app description, **demo video** if asked, **privacy policy URL**, and **home page**.
2. Wait for Google’s decision; respond to any follow-ups in the Cloud Console.

Until verification passes (if required), production users may still be blocked or see limited access — watch **APIs & Services** → **OAuth consent screen** for status.

---

## Phase 3 — Apple: Developer ID sign + notarize the DMG

Goal: users who **download** your DMG get a **notarized** disk image (Gatekeeper-friendly).

### 3.1 Developer ID Application certificate

1. **Xcode** → **Settings** (Preferences) → **Accounts** → select your Apple ID → your team → **Manage Certificates…**
2. **+** → **Developer ID Application** → create if missing.

### 3.2 Copy your signing identity string

In Terminal:

```bash
security find-identity -v -p codesigning
```

Find the line **Developer ID Application: Your Name (TEAMID)** — copy the full string (that is `CODE_SIGN_IDENTITY`).

### 3.3 App Store Connect API key (for `notarytool`)

1. Open **[App Store Connect](https://appstoreconnect.apple.com/)**.
2. **Users and Access** → **Integrations** → **App Store Connect API**.
3. **Generate API Key** — role **Developer** (or **Admin**).
4. Download the **`.p8`** file **once**. Note **Issuer ID** (UUID on the page) and **Key ID** (10 characters).
5. Store the `.p8` **outside the repo** (e.g. `~/keys/AuthKey_XXXXX.p8`). Never commit it.

### 3.4 Run the ship script (from repo root)

**Option A — environment variables**

```bash
cd /path/to/justbeforethemeeting

export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_KEY_PATH="$HOME/keys/AuthKey_XXXXXX.p8"
export NOTARY_KEY_ID="YOUR10CHARS"
export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

./scripts/build-and-distribute.sh
```

**Option B — store notary credentials in Keychain once**

```bash
xcrun notarytool store-credentials "jbtm-notary" \
  --key "$HOME/keys/AuthKey_XXXXXX.p8" \
  --key-id "YOUR10CHARS" \
  --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export NOTARY_PROFILE="jbtm-notary"
./scripts/build-and-distribute.sh
```

Output: **`build/JustBeforeTheMeeting.dmg`** (notarized and stapled when notary env vars / profile are set).

### 3.5 Verify the DMG locally

```bash
xcrun stapler validate build/JustBeforeTheMeeting.dmg
spctl -a -vv -t install build/JustBeforeTheMeeting.dmg
```

You want stapler validation to succeed and `spctl` to report the image as accepted (notarized Developer ID).

### 3.6 If notarization fails

- `notarytool` prints a **submission ID** and often a link to logs.
- Common issues: wrong signing identity, missing hardened runtime, unsigned helper binaries inside the `.app`. Fix, rebuild, resubmit.

**Apple docs:** [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

---

## Phase 4 — Host the DMG (GitHub Releases)

### 4.1 Create or open a release

1. Open your repo on GitHub, e.g. **`https://github.com/ozgurbuluta/justbeforethemeeting/releases`** (replace with your fork/org).
2. **Draft a new release** or edit an existing tag (e.g. `v1.0.0`).
3. Attach **`build/JustBeforeTheMeeting.dmg`** from your Mac.

### 4.2 Filename must match the website

The default download button expects this exact asset name:

**`JustBeforeTheMeeting.dmg`**

So the “latest release” URL pattern works:

`https://github.com/ozgurbuluta/justbeforethemeeting/releases/latest/download/JustBeforeTheMeeting.dmg`

If you rename the file or host elsewhere, update **`website/index.html`** (`id="download-link"` `href`).

### 4.3 Mark release as latest

Ensure GitHub treats this release as **Latest** so `/releases/latest/download/...` resolves correctly.

---

## Phase 5 — Deploy the website (GitHub Pages)

### 5.1 Enable Pages (one-time)

1. GitHub repo → **Settings** → **Pages**.
2. Under **Build and deployment** → **Source**: choose **GitHub Actions** (not “Deploy from a branch” unless you change the workflow).

**Docs:** [Configuring a publishing source for GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)

### 5.2 Trigger the workflow

- The workflow **`.github/workflows/deploy-pages.yml`** runs on pushes to **`main`** that touch **`website/**`**.
- If Pages was disabled earlier, the deploy step could **404** until you enable Actions as the source; then **re-run** the failed workflow or push a small change under `website/`.

### 5.3 Confirm the live site

1. After deploy, open the URL shown under **Settings** → **Pages** (often `https://<user>.github.io/<repo>/`).
2. Test **English / Turkish** switcher; open **Privacy** → `…/privacy.html`.
3. Click **Download** — it should start the DMG from GitHub Releases (if the release asset exists).

### 5.4 Point Google at your live URLs

Return to **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** and set **Application home page** and **Privacy policy** to the **deployed** HTTPS URLs (not `localhost`).

---

## Phase 6 — Final smoke test (public path)

| Step | Done |
|------|------|
| [ ] Incognito/private window → open marketing site | ☐ |
| [ ] Download DMG → mount → drag app to Applications | ☐ |
| [ ] First launch: no unexpected Gatekeeper block (notarized build) | ☐ |
| [ ] **Connect Google Calendar** with a Google account that is **not** on the old test-user list (proves production OAuth) | ☐ |
| [ ] Calendar sync + countdown + sound | ☐ |

---

## Phase 7 — Versioning and support hygiene

| Step | Done |
|------|------|
| [ ] Bump **`CFBundleShortVersionString`** / **`CFBundleVersion`** in `JustBeforeTheMeeting/Info.plist` before each public DMG | ☐ |
| [ ] Git tag matches marketing version (e.g. `v1.0.1`) | ☐ |
| [ ] GitHub Release notes mention version + what changed | ☐ |
| [ ] Re-run `./scripts/build-and-distribute.sh` with signing + notary after each release; re-upload **`JustBeforeTheMeeting.dmg`** | ☐ |

---

## Quick reference — important URLs

| What | Link |
|------|------|
| Google Cloud Console | https://console.cloud.google.com/ |
| OAuth consent screen | https://console.cloud.google.com/apis/credentials/consent |
| Credentials (OAuth client) | https://console.cloud.google.com/apis/credentials |
| Calendar API (Library) | https://console.cloud.google.com/apis/library/calendar-json.googleapis.com |
| OAuth verification FAQ | https://support.google.com/cloud/answer/9110914 |
| Publishing / testing status | https://support.google.com/cloud/answer/10311615 |
| App Store Connect | https://appstoreconnect.apple.com/ |
| API keys (Integrations) | Users and Access → Integrations → App Store Connect API |
| Apple notarization overview | https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution |
| GitHub Pages docs | https://docs.github.com/en/pages |
| Your releases (example) | `https://github.com/ozgurbuluta/justbeforethemeeting/releases` |

---

## Troubleshooting pointers

- **OAuth / “Access blocked” / only test users:** consent screen still **Testing** or verification incomplete — Phase 2.
- **401 / invalid_client in app:** Client ID/secret in `Secrets.xcconfig`; redirect URI **`jbtm://oauth`** in Google matches `Info.plist`.
- **Download 404:** no asset named **`JustBeforeTheMeeting.dmg`** on the **latest** GitHub Release — Phase 4.
- **Site i18n fails:** wrong base path on Pages; ensure you did not move `i18n/` out of the deployed root.
- **Gatekeeper warnings:** unsigned or unstapled DMG — Phase 3 with **Developer ID** + successful **notarytool** + **stapler**.

For a short feature overview and repo layout, see **[README.md](../README.md)**.
