#!/usr/bin/env bash
#
# Package the exported macOS build as a drag-to-Applications disk image,
# so installing the game on a Mac is the one step it already is on Windows.
#
# Why this is needed at all
# -------------------------
# Godot's macOS export is a .zip holding an .app, and that .app arrives carrying
# *Godot's* code signature — identifier "godot.macos.template_release.arm64",
# Godot's own team id — with "Sealed Resources=none", meaning the signature
# covers the executable and not the 230 MB of game data sitting beside it in
# Contents/Resources. An app in that state can be refused by macOS with "the
# app is damaged and should be moved to the Trash", which reads like a corrupt
# download rather than a security prompt and is the worst thing a player can be
# shown. Re-signing it ad-hoc under this game's own bundle identifier seals the
# game data into the signature and costs nothing.
#
# What this script cannot do
# --------------------------
# It cannot remove the single Gatekeeper prompt on a copy somebody *downloads*.
# macOS quarantines anything that arrived from elsewhere, and only Apple
# notarisation — a paid Developer ID, 99 USD a year — clears that. Until then a
# downloaded copy needs right-click -> Open once, or System Settings ->
# Privacy & Security -> Open Anyway. A copy handed over on a USB stick is not
# quarantined and opens with no prompt at all.
#
# Usage
# -----
#     godot --headless --export-release "macOS" "build/macos/Referee For Fun.zip"
#     tools/build/make_dmg.sh
#
set -euo pipefail

NAME="Referee For Fun"
BUNDLE_ID="com.juslangit.refereeforfun"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZIP="$REPO/build/macos/$NAME.zip"
DMG="$REPO/build/macos/$NAME.dmg"

if [[ ! -f "$ZIP" ]]; then
	echo "No macOS export found at: $ZIP" >&2
	echo "Export it first:  godot --headless --export-release \"macOS\" \"build/macos/$NAME.zip\"" >&2
	exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> unpacking the export"
unzip -q "$ZIP" -d "$STAGE"
APP="$STAGE/$NAME.app"
[[ -d "$APP" ]] || { echo "Expected $NAME.app inside the zip" >&2; exit 1; }

echo "==> signing it as $BUNDLE_ID (ad-hoc, hardened runtime, game data sealed)"
codesign --force --deep --sign - \
	--identifier "$BUNDLE_ID" \
	--options runtime \
	--timestamp=none \
	"$APP"

# A signature that does not verify here would fail on a player's machine too,
# so this is a hard stop rather than a warning.
codesign --verify --deep --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E 'Identifier=|Sealed Resources|flags='

echo "==> building the disk image"
# The symlink is what makes the window a drag target: the game on one side,
# Applications on the other.
ln -sfn /Applications "$STAGE/Applications"
hdiutil create \
	-volname "$NAME" \
	-srcfolder "$STAGE" \
	-ov -format UDZO -fs HFS+ \
	-quiet \
	"$DMG"
codesign --force --sign - "$DMG"

echo "==> done"
ls -lh "$DMG"
