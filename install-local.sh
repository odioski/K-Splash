#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.mrod.k-splash"
DEFAULT_ARCHIVE="$SCRIPT_DIR/${PLUGIN_ID}.plasmoid"
ARCHIVE_PATH="${1:-$DEFAULT_ARCHIVE}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PLASMOID_ROOT="$XDG_DATA_HOME/plasma/plasmoids"
TARGET_DIR="$PLASMOID_ROOT/$PLUGIN_ID"
TMP_DIR="$(mktemp -d)"
RESTORE_LOCAL_CONFIG=0
LOCAL_CONFIG_BACKUP="$TMP_DIR/local.json.backup"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT

if [[ ! -f "$ARCHIVE_PATH" ]]; then
    echo "Archive not found: $ARCHIVE_PATH" >&2
    echo "Usage: $0 [/path/to/${PLUGIN_ID}.plasmoid]" >&2
    exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
    echo "'unzip' is required to install $PLUGIN_ID" >&2
    exit 1
fi

mkdir -p "$PLASMOID_ROOT"

if [[ -f "$TARGET_DIR/contents/config/local.json" ]]; then
    cp "$TARGET_DIR/contents/config/local.json" "$LOCAL_CONFIG_BACKUP"
    RESTORE_LOCAL_CONFIG=1
fi

unzip -q "$ARCHIVE_PATH" -d "$TMP_DIR/unpacked"

if [[ ! -f "$TMP_DIR/unpacked/metadata.json" || ! -d "$TMP_DIR/unpacked/contents" ]]; then
    echo "Archive does not look like a Plasma plasmoid package: $ARCHIVE_PATH" >&2
    exit 1
fi

rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
cp -a "$TMP_DIR/unpacked/." "$TARGET_DIR/"

if [[ "$RESTORE_LOCAL_CONFIG" -eq 1 ]]; then
    mkdir -p "$TARGET_DIR/contents/config"
    cp "$LOCAL_CONFIG_BACKUP" "$TARGET_DIR/contents/config/local.json"
fi

echo "Installed $PLUGIN_ID to $TARGET_DIR"
echo "Restart plasmashell to reload the updated widget:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
