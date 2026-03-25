#!/usr/bin/env bash
#
# Build, sign, notarize, and package Just Before The Meeting for distribution.
#
# Prerequisites:
#   - Xcode command line tools
#   - Apple Developer Program: Developer ID Application certificate
#   - App Store Connect API key OR Apple ID for notarytool
#
# Usage:
#   export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   export NOTARY_KEY_PATH="$HOME/AuthKey_XXXXX.p8"
#   export NOTARY_KEY_ID="XXXXXXXXXX"
#   export NOTARY_ISSUER="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   ./scripts/build-and-distribute.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="${ROOT}/JustBeforeTheMeeting"
SCHEME="JustBeforeTheMeeting"
CONFIGURATION="Release"
BUILD_DIR="${ROOT}/build"
ARCHIVE_PATH="${BUILD_DIR}/JustBeforeTheMeeting.xcarchive"
APP_NAME="JustBeforeTheMeeting.app"
DMG_NAME="JustBeforeTheMeeting.dmg"

mkdir -p "${BUILD_DIR}"

echo "==> Archive"
xcodebuild archive \
  -project "${PROJECT_DIR}/JustBeforeTheMeeting.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "Missing app at ${APP_PATH}" >&2
  exit 1
fi

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  echo "==> Deep sign"
  codesign --force --deep --options runtime --sign "${CODE_SIGN_IDENTITY}" "${APP_PATH}"
fi

echo "==> Create DMG"
STAGING="${BUILD_DIR}/dmg_staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${APP_PATH}" "${STAGING}/"
ln -sf /Applications "${STAGING}/Applications"

hdiutil create -volname "Just Before The Meeting" -srcfolder "${STAGING}" -ov -format UDZO "${BUILD_DIR}/${DMG_NAME}"

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  echo "==> Sign DMG"
  codesign --force --sign "${CODE_SIGN_IDENTITY}" "${BUILD_DIR}/${DMG_NAME}"
fi

if [[ -n "${NOTARY_KEY_PATH:-}" && -n "${NOTARY_KEY_ID:-}" && -n "${NOTARY_ISSUER:-}" ]]; then
  echo "==> Notarize (API key)"
  xcrun notarytool submit "${BUILD_DIR}/${DMG_NAME}" \
    --key "${NOTARY_KEY_PATH}" \
    --key-id "${NOTARY_KEY_ID}" \
    --issuer "${NOTARY_ISSUER}" \
    --wait
  xcrun stapler staple "${BUILD_DIR}/${DMG_NAME}"
elif [[ -n "${NOTARY_PROFILE:-}" ]]; then
  echo "==> Notarize (stored profile)"
  xcrun notarytool submit "${BUILD_DIR}/${DMG_NAME}" --wait --keychain-profile "${NOTARY_PROFILE}"
  xcrun stapler staple "${BUILD_DIR}/${DMG_NAME}"
else
  echo "Skipping notarization (set NOTARY_* env vars or NOTARY_PROFILE)."
fi

echo "Done: ${BUILD_DIR}/${DMG_NAME}"
