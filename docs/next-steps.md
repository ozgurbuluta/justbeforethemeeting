# Next steps — what’s left, who does what, public repo safety

This doc is **only what you still need to do** (and what you can hand off). Skip anything you have already finished.

---

## Working together

| Who | What |
|-----|------|
| **You** | Anything that needs **your** Apple Developer login, **Google Cloud** console, **notary** `.p8` key, or **uploading** a DMG from your Mac. |
| **Cursor / AI agent** | Repo edits: website copy, `website/index.html` download URL, workflow tweaks, README, commits/pushes, small bugfixes—**after** you say what’s done (e.g. “Pages is on”, “DMG is on the release”, “here is my live site URL”). |

**When you’re ready for the agent:** send a short note like:

> I finished steps **A + B** (or list which). Live site URL: `https://…` — please update whatever’s needed in the repo and continue.

The agent **cannot** log into App Store Connect, Google Cloud, or GitHub as you; it can only change files and run git in **your** workspace when you ask.

---

## Security: is this repo safe to make **public**?

**Short answer:** For a **public GitHub repo**, the committed tree looks **reasonable**: no OAuth secrets are tracked in git.

**Checks that matter:**

| Item | Status |
|------|--------|
| `JustBeforeTheMeeting/Config/Secrets.xcconfig` | **Must stay local only.** It is listed in [`.gitignore`](../.gitignore) (`**/Secrets.xcconfig`). **Never `git add -f` it.** Before going public, run **`git ls-files`** and confirm no `Secrets.xcconfig` path appears. |
| Notary API key `*.p8` | Ignored; do not commit. |
| `Secrets.example.xcconfig` | Only placeholders — **safe**. |
| `Info.plist` in repo | Uses `$(GOOGLE_OAUTH_CLIENT_ID)` / `$(GOOGLE_OAUTH_CLIENT_SECRET)` — **placeholders at rest in git**; real values are injected at **build time** from your local xcconfig. |

**Still true even if the repo is public:**

- Anyone who installs your **released `.app`** could try to extract the **client ID** (and **client secret** if you embed it in the shipped app). That is normal for many desktop OAuth setups but means you should treat the OAuth client as **public-ish**: use **Google’s OAuth client restrictions** where available, and **rotate the client secret** in [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials) if it ever leaks or was committed by mistake.
- If `Secrets.xcconfig` was **ever** committed in the past, assume it’s compromised: **rotate** the secret in Google Cloud and consider `git filter-repo` / support help to purge history—or treat the repo as needing a fresh OAuth client.

**Bottom line:** Making the repo **public** is **not** the same as publishing your Google password. The risk is **accidentally committing** `Secrets.xcconfig` or a `.p8` file—double-check before you flip visibility.

---

## GitHub Pages vs private repo

Official note from GitHub:

- On **GitHub Free**, the **repository used for GitHub Pages must be public**. See: [Creating a GitHub Pages site](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site#creating-a-repository-for-your-site) (“If the account … uses GitHub Free … the repository must be public”).
- Even when Pages is allowed from a **private** repo (paid plans), the **website itself is still public on the internet** — same doc warns that Pages URLs are world-readable.

**Your options if you don’t want the whole app repo public:**

1. **GitHub Pro** (or Team/Enterprise): Pages from a **private** repo (repo private; site still public).
2. **Separate tiny public repo** (e.g. `justbeforethemeeting-site`) with **only** the contents of `website/` — main app repo stays private; you’d adjust deploy (second remote or copy workflow). The agent can help wire this after you create the repo.
3. **Netlify / Cloudflare Pages** (or similar): connect **private** GitHub repo; often free tier; only build/deploy the `website/` folder if configured. No need to make the Mac app repo public **for hosting alone** (you’d add their config in-repo or in their UI).

**If you’re OK making this repo public:** enable Pages (next section) and rely on the security checks above.

---

## Your remaining tasks (checklist)

Check these off in order where it makes sense; skip what you already did.

### A. Google — sign-in for **every** user (not only test users)

1. Open **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)**.
2. Complete any required fields (app name, support email, scopes including `calendar.readonly`, etc.).
3. You need a **public app home page** and **privacy policy URL** for production / verification. Plan URLs first (see **D** once the site is live), then:
4. **Publish** the app (move out of **Testing**) when ready — [Publishing status](https://support.google.com/cloud/answer/10311615).
5. If Google asks for **verification**, complete it — [OAuth verification FAQ](https://support.google.com/cloud/answer/9110914), [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

### B. Apple — signed + **notarized** DMG

1. Xcode → **Settings** → **Accounts** → **Manage Certificates** → **Developer ID Application** — [Apple Programs](https://developer.apple.com/programs/).
2. Terminal: `security find-identity -v -p codesigning` → copy the full **Developer ID Application: …** string.
3. [App Store Connect](https://appstoreconnect.apple.com/) → **Users and Access** → **Integrations** → **App Store Connect API** → create key → download **`.p8`** once; note **Issuer ID** and **Key ID**.
4. From **repo root**:

   ```bash
   export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
   export NOTARY_KEY_PATH="$HOME/path/to/AuthKey_XXXXXX.p8"
   export NOTARY_KEY_ID="YOUR10CHARS"
   export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ./scripts/build-and-distribute.sh
   ```

   Or use `notarytool store-credentials` + `NOTARY_PROFILE` as in [README.md](../README.md) Distribution section.

5. Validate: `xcrun stapler validate build/JustBeforeTheMeeting.dmg`
6. [Notarization overview](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### C. GitHub — ship the DMG

1. Open **[Releases](https://github.com/ozgurbuluta/justbeforethemeeting/releases)** (replace with your repo if different).
2. Create/edit a release (e.g. tag `v1.0.0`).
3. Upload **`JustBeforeTheMeeting.dmg`** with **exact filename** `JustBeforeTheMeeting.dmg` so this URL works:  
   `https://github.com/ozgurbuluta/justbeforethemeeting/releases/latest/download/JustBeforeTheMeeting.dmg`

### D. GitHub — **Pages** (or alternative host)

**If using GitHub Pages on this repo:**

1. Decide **public repo** (Free) or upgrade / use another option (see above).
2. Repo → **Settings** → **Pages** → **Source: GitHub Actions**.
3. Re-run the latest **Deploy website to GitHub Pages** workflow (or push any change under `website/`).
4. Copy the published site URL from the Pages settings (e.g. `https://<user>.github.io/<repo>/`).

**If Pages failed with 404 before:** [Configuring a publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

### E. Google — point consent screen at the **live** site

1. **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** → set **Application home page** and **Privacy policy** to your **HTTPS** URLs (not `localhost`).
2. Privacy policy path on site: `/privacy.html` (file in repo: `website/privacy.html`).

### F. Final smoke test

- [ ] Private/incognito: open marketing site → download DMG → install → first launch acceptable for Gatekeeper  
- [ ] Sign in with a Google account **not** on the old test-user list  
- [ ] Calendar + countdown + sound  

---

## After you finish — paste this to Cursor (template)

Fill in the brackets and send in chat:

```text
Next-steps handoff:
- [ ] Google OAuth published / verification: [done | in progress | N/A]
- [ ] Notarized DMG uploaded to GitHub Release: [yes / no]
- [ ] Site live URL: [https://…]
- [ ] Repo visibility: [public / still private — I want Netlify|second public repo|GitHub Pro]
Please update the repo (and tell me what you changed).
```

---

## What the agent can do next (examples)

- Point `website/index.html` download link at a **different** DMG URL or repo name.  
- Add Netlify/Cloudflare config to deploy **only** `website/` while the app repo stays private.  
- Add a **public** `*-site` repo workflow or documented copy steps.  
- Update `privacy.html` wording, version dates, or footer links.  
- Fix broken i18n paths, README, or Actions workflow.  
- Bump `Info.plist` version strings and tag (when you ask).

---

## Link cheat sheet (detail when you need it)

| Topic | URL |
|------|-----|
| Google OAuth consent | https://console.cloud.google.com/apis/credentials/consent |
| Google Credentials | https://console.cloud.google.com/apis/credentials |
| Calendar API | https://console.cloud.google.com/apis/library/calendar-json.googleapis.com |
| Publishing / testing | https://support.google.com/cloud/answer/10311615 |
| App Store Connect | https://appstoreconnect.apple.com/ |
| Apple notarization | https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution |
| GitHub Pages source | https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site |
| GitHub Pages + public repo (Free) | https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site#creating-a-repository-for-your-site |

For app features and local dev overview, see **[README.md](../README.md)**.
