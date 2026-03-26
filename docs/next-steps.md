# Next steps — what’s left, who does what

This doc is **only what you still need to do** (and what you can hand off). Skip anything you have already finished.

**Repo visibility:** This repository is **public** on GitHub. That matches **GitHub Free + GitHub Pages** (Pages requires a public repo on Free). Source code and `website/` are visible; secrets stay **local** only — see **Security** below.

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

## Security (public repo — keep it this way)

The repo is **public**; anything **committed** can be read by anyone.

| Item | Rule |
|------|------|
| `JustBeforeTheMeeting/Config/Secrets.xcconfig` | **Never commit.** In [`.gitignore`](../.gitignore) (`**/Secrets.xcconfig`). **Never `git add -f` it.** Run **`git ls-files`** and confirm no `Secrets.xcconfig` path appears before every push. |
| Notary API key `*.p8` | Ignored; do not commit. |
| `Secrets.example.xcconfig` | Placeholders only — **safe**. |
| `Info.plist` in repo | Uses `$(GOOGLE_OAUTH_…)` — real values only at **build time** from your **local** xcconfig. |

**Shipped `.app`:** Users could extract **OAuth client ID** (and **client secret** if embedded). Treat the client as **public-ish**; use [Google Cloud Credentials](https://console.cloud.google.com/apis/credentials) restrictions where possible and **rotate** the secret if it ever leaks or was committed by mistake.

---

## GitHub Pages (public repo)

On **GitHub Free**, [GitHub Pages for this repo requires it to be public](https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site#creating-a-repository-for-your-site) — **done.**

**Your steps:**

1. Repo → **Settings** → **Pages** → **Source: GitHub Actions** (not “Deploy from a branch” unless you change the workflow).
2. Re-run the **Deploy website to GitHub Pages** workflow (Actions tab → failed run → **Re-run**), or push any change under `website/`.
3. Open the **Visit site** URL from Pages settings (often `https://<user>.github.io/<repo>/`).

The published **site** is world-readable (normal for a marketing/download page).  
If deploy failed with **404** before: [Configuring a publishing source](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

---

## Your remaining tasks (checklist)

### A. Google — sign-in for **every** user (not only test users)

1. **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** — complete fields, scope `calendar.readonly`.
2. **Public home page + privacy policy URL** once the site is live (step **D** / **E**).
3. **Publish** the app — [Publishing status](https://support.google.com/cloud/answer/10311615).
4. **Verification** if prompted — [OAuth verification FAQ](https://support.google.com/cloud/answer/9110914), [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

### B. Apple — signed + **notarized** DMG

1. Xcode → **Accounts** → **Manage Certificates** → **Developer ID Application** — [Apple Programs](https://developer.apple.com/programs/).
2. `security find-identity -v -p codesigning` → copy **Developer ID Application: …**
3. [App Store Connect](https://appstoreconnect.apple.com/) → **Integrations** → **App Store Connect API** → `.p8`, Issuer ID, Key ID.
4. From **repo root**:

   ```bash
   export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
   export NOTARY_KEY_PATH="$HOME/path/to/AuthKey_XXXXXX.p8"
   export NOTARY_KEY_ID="YOUR10CHARS"
   export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ./scripts/build-and-distribute.sh
   ```

   Or `notarytool store-credentials` + `NOTARY_PROFILE` — [README.md](../README.md) Distribution.

5. `xcrun stapler validate build/JustBeforeTheMeeting.dmg`
6. [Notarization overview](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

### C. GitHub — ship the DMG

1. **[Releases](https://github.com/ozgurbuluta/justbeforethemeeting/releases)**
2. Upload **`JustBeforeTheMeeting.dmg`** (exact name) →  
   `https://github.com/ozgurbuluta/justbeforethemeeting/releases/latest/download/JustBeforeTheMeeting.dmg`

### D. GitHub — enable **Pages** (if not done)

Follow **GitHub Pages (public repo)** above.

### E. Google — consent screen **live** URLs

1. **[OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent)** → **Application home page** + **Privacy policy** = your **HTTPS** site URLs.
2. Privacy path: `/privacy.html` → `website/privacy.html` in repo.

### F. Final smoke test

- [ ] Incognito: site → download DMG → install → Gatekeeper OK  
- [ ] Google sign-in with a non–test-user account  
- [ ] Calendar + countdown + sound  

---

## After you finish — paste this to Cursor (template)

```text
Next-steps handoff:
- [ ] Google OAuth published / verification: [done | in progress | N/A]
- [ ] Notarized DMG on GitHub Release: [yes / no]
- [ ] Site live URL: [https://…]
- [ ] Pages: [working / not yet]
Please update the repo (and tell me what you changed).
```

---

## What the agent can do next (examples)

- Adjust `website/index.html` download URL or copy.  
- Update `privacy.html`, i18n, README, or Actions workflow.  
- Bump `Info.plist` / tags when you ask.  
- Optional later: Netlify/Cloudflare **in addition** to Pages — only if you want a second host.

---

## Link cheat sheet

| Topic | URL |
|------|-----|
| Google OAuth consent | https://console.cloud.google.com/apis/credentials/consent |
| Google Credentials | https://console.cloud.google.com/apis/credentials |
| Calendar API | https://console.cloud.google.com/apis/library/calendar-json.googleapis.com |
| Publishing / testing | https://support.google.com/cloud/answer/10311615 |
| App Store Connect | https://appstoreconnect.apple.com/ |
| Apple notarization | https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution |
| GitHub Pages source | https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site |
| Pages + public repo (Free) | https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site#creating-a-repository-for-your-site |

For app features and local dev, see **[README.md](../README.md)**.
