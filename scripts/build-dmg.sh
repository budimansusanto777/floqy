#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Floqy"
APP_DIR="${ROOT_DIR}/build/${APP_NAME}.app"

"${ROOT_DIR}/scripts/build-app.sh" release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${APP_DIR}/Contents/Info.plist" 2>/dev/null || echo "1.0.0")"
DMG_PATH="${ROOT_DIR}/build/${APP_NAME}-${VERSION}.dmg"
STAGE_DIR="$(mktemp -d /tmp/floqy-dmg-stage.XXXXXX)"

cleanup() {
  rm -rf "${STAGE_DIR}"
}
trap cleanup EXIT

echo "==> Packaging ${DMG_PATH}..."
cp -R "${APP_DIR}" "${STAGE_DIR}/"
ln -s /Applications "${STAGE_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

echo "==> App size: $(du -sh "${APP_DIR}" | awk '{print $1}')"
echo "==> DMG size: $(du -sh "${DMG_PATH}" | awk '{print $1}') (${DMG_PATH})"
