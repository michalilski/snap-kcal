#!/bin/sh
# Copies API keys from .env into the app bundle as DevKeys.plist (seeded into the Keychain on launch).
set -e
ENV_FILE="${SRCROOT}/.env"
OUT="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/DevKeys.plist"
rm -f "$OUT"
plutil -create xml1 "$OUT"
[ -f "$ENV_FILE" ] || exit 0
for NAME in OPENAI_API_KEY ANTHROPIC_API_KEY OPENAI_MODEL ANTHROPIC_MODEL; do
  VALUE=$(grep -E "^${NAME}=" "$ENV_FILE" | tail -1 | cut -d= -f2- | sed -e 's/^["'\'']//' -e 's/["'\'']$//' | tr -d '[:space:]')
  [ -n "$VALUE" ] && plutil -insert "$NAME" -string "$VALUE" "$OUT"
done
exit 0
