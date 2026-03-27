# LLM agent briefing — Just Before The Meeting

Read this at the **start of a new session** before editing the repo or advising the human. Keep **[README.md](README.md)** for product/features and **[docs/next-steps.md](docs/next-steps.md)** for the human’s step-by-step ship checklist.

---

## What this project is

Native **macOS menu bar app** (Swift / SwiftUI): Google Calendar (read-only OAuth), countdown + optional theme audio before meetings. Static **marketing site** in `website/`. **Public** GitHub repo: `ozgurbuluta/justbeforethemeeting`.

---

## Where we left off (state as of last handoff)

### Already in the repo / done earlier (do not redo blindly)

- Repo is **public**; `.gitignore` excludes `Secrets.xcconfig` and `*.p8`.
- **Website**: download CTA points at GitHub Releases “latest” DMG URL; EN/TR i18n; `privacy.html`.
- **GitHub Actions**: [`.github/workflows/deploy-pages.yml`](.github/workflows/deploy-pages.yml) deploys `website/` to **GitHub Pages** when `website/**` changes (source must be **GitHub Actions** under repo **Settings → Pages**).
- **Google Search Console** verification file: [`website/googlefc6d9bc1efe2648c.html`](website/googlefc6d9bc1efe2648c.html) (for homepage ownership in Google Cloud branding).
- **App versioning** in git: `Info.plist` marketing version **1.0.0**, build **100** (bump when shipping a new binary).
- **Google OAuth (Cloud Console)**: Branding URLs set to GitHub Pages (`https://ozgurbuluta.github.io/justbeforethemeeting/` and `…/privacy.html`); authorised domain `ozgurbuluta.github.io`. User hit **branding verification** (Search Console) and **Data access** requirements: **scope justification** + **demo video** for `calendar.readonly` — typical for production verification.

### Not done yet (human said they did **not** proceed here)

Treat everything below as **still outstanding** until the human explicitly says otherwise:

| Area | Status | Notes |
|------|--------|--------|
| **Google OAuth verification** | Likely **in progress** or **not submitted** | May take weeks. Until approved, only **test users** (Testing mode) get easy sign-in for broad Gmail use. |
| **Scope justification + demo video** | Human may still need to complete | Required in Cloud Console **Data access** / verification for sensitive scope. |
| **Developer ID sign + notarize** | **Not done** | Run [`scripts/build-and-distribute.sh`](scripts/build-and-distribute.sh) with `CODE_SIGN_IDENTITY` + `NOTARY_*` or `NOTARY_PROFILE` from repo root. |
| **Upload DMG to GitHub Release** | **Not done** | Asset name must be exactly **`JustBeforeTheMeeting.dmg`** for the default site link. |
| **GitHub Pages** | **Confirm** | Human should verify **Settings → Pages → GitHub Actions** and that the site loads; fix workflow if deploy failed. |
| **End-to-end smoke test** | **Not done** | Public site → download → install → Google sign-in (non–test user only after verification). |

**Important:** Shipping the **DMG** and **notarization** does **not** depend on Google verification. The human can notarize and attach the DMG **while** verification is pending. Download link will 404 until a release asset exists.

---

## What the agent can do

- Edit **source, website, docs, workflows**; run **tests/builds** in sandbox when asked; **git commit/push** when the human requests and credentials/network allow.
- **Cannot**: log into **Google Cloud**, **App Store Connect**, or **GitHub** as the user; create **Developer ID** certs; run **notarytool** with their `.p8` on the user’s machine unless their environment is configured.

## What the human must do

- **Apple**: Developer ID Application cert; notary API key `.p8`; run `./scripts/build-and-distribute.sh` locally; upload DMG to **Releases**.
- **Google**: Complete verification form, **scope justification**, **YouTube (unlisted) demo video**; respond to Google emails; **Publish app** when appropriate.
- **GitHub**: Enable **Pages** (Actions source); confirm green deploy workflow.

When they finish a slice, they should say e.g. *“DMG is on the v1.0.0 release”* or *“verification approved”* so the agent can update links, copy, versions, or docs.

---

## Instructions for the agent on proceed

1. **Do not commit** `JustBeforeTheMeeting/Config/Secrets.xcconfig` or any `*.p8` file.
2. Prefer **small, focused** changes; match existing Swift / website style.
3. After substantive ship steps, consider bumping **`CFBundleShortVersionString` / `CFBundleVersion`** and documenting the tag in release notes (only when the human ships a new binary).
4. If the human’s **live site URL** or **repo name** changes, update **`website/index.html`**, **`docs/next-steps.md`**, and any hardcoded `github.io` examples.
5. Point the human to **[docs/next-steps.md](docs/next-steps.md)** for the ordered checklist and links.

---

## Reminder for the human (copy checklist)

Do these when you have time; verification pending is **not** a blocker for Apple/GitHub ship work.

1. **Pages**: [Settings → Pages](https://github.com/ozgurbuluta/justbeforethemeeting/settings/pages) → source **GitHub Actions** → confirm [Actions](https://github.com/ozgurbuluta/justbeforethemeeting/actions) deploy is green → open `https://ozgurbuluta.github.io/justbeforethemeeting/`.
2. **Search Console**: After Pages works, verify property using `googlefc6d9bc1efe2648c.html` if not already verified.
3. **Google Data access**: Add **scope justification** + **demo video** URL; submit verification; wait for Google.
4. **Notarize** (from repo root, with your secrets in env):

   ```bash
   export CODE_SIGN_IDENTITY="Developer ID Application: …"
   export NOTARY_KEY_PATH="…/AuthKey_XXX.p8"
   export NOTARY_KEY_ID="…"
   export NOTARY_ISSUER="…"
   ./scripts/build-and-distribute.sh
   xcrun stapler validate build/JustBeforeTheMeeting.dmg
   ```

5. **Release**: Upload **`JustBeforeTheMeeting.dmg`** to [GitHub Releases](https://github.com/ozgurbuluta/justbeforethemeeting/releases) (exact filename).
6. **Smoke test**: Incognito → site → download → install → sign-in (test users until verification passes).

---

## File map (quick)

| Path | Role |
|------|------|
| `JustBeforeTheMeeting/` | Xcode project + Swift app |
| `JustBeforeTheMeeting/Config/Secrets.xcconfig` | **Local only** — OAuth client ID/secret |
| `website/` | Static landing + `privacy.html` + Search Console file |
| `scripts/build-and-distribute.sh` | Archive, sign, DMG, notarize, staple |
| `docs/next-steps.md` | Human-facing remaining tasks + links |
| `.github/workflows/deploy-pages.yml` | Pages deploy |

---

*Update this briefing when major state changes (e.g. verification approved, first DMG shipped, URL changes).*
