#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-build/Build/Products/Release/NetControlKZ.app}"
OUT_PATH="${2:-LANControlKZ-unsigned.ipa}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

OUT_DIR="$(dirname "$OUT_PATH")"
OUT_NAME="$(basename "$OUT_PATH")"
mkdir -p "$OUT_DIR"
OUT_ABS="$(cd "$OUT_DIR" && pwd)/$OUT_NAME"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/Payload"
cp -R "$APP_PATH" "$TMP_DIR/Payload/NetControlKZ.app"
(
  cd "$TMP_DIR"
  /usr/bin/zip -qr "$OUT_ABS" Payload
)
/usr/bin/unzip -t "$OUT_ABS"
echo "Created $OUT_ABS (unsigned; sign with SideStore or an Apple signing identity)."
