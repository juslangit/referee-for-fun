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
# How the window is made to look like the game
# --------------------------------------------
# A disk image's window appearance is not metadata in the image; it is a
# .DS_Store file written by Finder, inside the image, holding the window size,
# the icon positions and the path to a background picture. So the image cannot
# be built read-only in one pass: it is built read-write, mounted, arranged by
# telling Finder what to do, unmounted, and only then compressed into the
# read-only image that ships. tools/build/make_art.py draws the background and
# the icon; the geometry below has to agree with the numbers in that script.
#
# Usage
# -----
#     godot --headless --export-release "macOS" "build/macos/Referee For Fun.zip"
#     tools/build/make_dmg.sh
#
set -euo pipefail

NAME="Referee For Fun"
BUNDLE_ID="com.juslangit.refereeforfun"

# The window, and where the two icons stand in it. WIDTH and HEIGHT are the
# size of background.tiff; APP_X, APPLICATIONS_X and ICON_Y are the same
# numbers as in make_art.py, where the arrow is drawn between them.
WIDTH=640
HEIGHT=420
APP_X=168
APPLICATIONS_X=472
ICON_Y=236
ICON_SIZE=128

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ZIP="$REPO/build/macos/$NAME.zip"
DMG="$REPO/build/macos/$NAME.dmg"
ART="$REPO/tools/build/dmg"

if [[ ! -f "$ZIP" ]]; then
	echo "No macOS export found at: $ZIP" >&2
	echo "Export it first:  godot --headless --export-release \"macOS\" \"build/macos/$NAME.zip\"" >&2
	exit 1
fi
for art in "$ART/background.tiff" "$ART/volume.icns"; do
	if [[ ! -f "$art" ]]; then
		echo "Missing packaging art: $art" >&2
		echo "Draw it first:  tools/build/make_art.py" >&2
		exit 1
	fi
done

STAGE="$(mktemp -d)"
RW="$(mktemp -u).dmg"
MOUNT=""
cleanup() {
	[[ -n "$MOUNT" ]] && hdiutil detach "$MOUNT" -quiet -force 2>/dev/null || true
	rm -rf "$STAGE" "$RW"
}
trap cleanup EXIT

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

echo "==> dressing the window"
# The symlink is what makes the window a drag target: the game on one side,
# Applications on the other. Both are hidden files, so a player sees two icons
# and the picture behind them, nothing else.
ln -sfn /Applications "$STAGE/Applications"
mkdir -p "$STAGE/.background"
cp "$ART/background.tiff" "$STAGE/.background/background.tiff"

# An image sized to its contents has no room for the .DS_Store Finder is about
# to write, so ask for the contents plus a little.
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 60 ))

# A leftover mount from an earlier run has to go, and not only one named
# exactly this: macOS mounts a second copy as "Referee For Fun 1", and then
# "disk \"Referee For Fun\"" in the AppleScript below arranges the *old* image
# while this one is left plain. That happened while this was being written and
# it is invisible unless you look for it.
for stale in "/Volumes/$NAME" "/Volumes/$NAME "*; do
	if [[ -d "$stale" ]]; then
		echo "    detaching a leftover mount: $stale"
		hdiutil detach "$stale" -quiet -force || true
		sleep 1
	fi
done

hdiutil create -volname "$NAME" -srcfolder "$STAGE" \
	-size "${SIZE_MB}m" -fs HFS+ -format UDRW -ov -quiet "$RW"
MOUNT="$(hdiutil attach "$RW" -readwrite -noverify -noautoopen | \
	grep -Eo '/Volumes/.*$' | head -1)"
[[ -n "$MOUNT" ]] || { echo "Could not mount the read-write image" >&2; exit 1; }

# Finder is the only thing that writes a .DS_Store, so the arrangement has to
# be asked for rather than written. The delays are not superstition: Finder
# applies view options asynchronously and a close too soon loses them.
osascript <<APPLESCRIPT
tell application "Finder"
	tell disk "$NAME"
		open
		delay 1
		set current view of container window to icon view
		set toolbar visible of container window to false
		set statusbar visible of container window to false
		set viewOptions to the icon view options of container window
		set arrangement of viewOptions to not arranged
		set icon size of viewOptions to $ICON_SIZE
		set text size of viewOptions to 12
		set label position of viewOptions to bottom
		set background picture of viewOptions to file ".background:background.tiff"
		set position of item "$NAME.app" of container window to {$APP_X, $ICON_Y}
		set position of item "Applications" of container window to {$APPLICATIONS_X, $ICON_Y}
		set the bounds of container window to {240, 120, 240 + $WIDTH, 120 + $HEIGHT}
		update without registering applications
		delay 2
		-- Set a second time, on purpose. Finder restores a size it remembers
		-- for a volume of this name over the top of the first one, and it is
		-- whatever is set when the window closes that reaches the .DS_Store.
		-- The first build of this window shipped 920x464 -- Finder's default on
		-- the machine it was built on -- with a 640x420 picture inside it.
		set the bounds of container window to {240, 120, 240 + $WIDTH, 120 + $HEIGHT}
		delay 1
		close
	end tell
end tell
APPLESCRIPT

# The volume's own icon, which is what shows on the desktop and in the sidebar
# once the image is mounted. It goes in *after* Finder rather than into the
# staging folder, because Finder deletes .VolumeIcon.icns while it rearranges
# the window: staged before, it is gone by the time the image is compressed,
# which is how the first build ended up with no volume icon at all.
cp "$ART/volume.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -a C "$MOUNT"

# .DS_Store is written lazily; without this the arrangement can be detached
# before it reaches the image.
sync
sleep 2
hdiutil detach "$MOUNT" -quiet
MOUNT=""

echo "==> compressing the disk image"
hdiutil convert "$RW" -format UDZO -ov -quiet -o "$DMG"
codesign --force --sign - "$DMG"

echo "==> checking the window survived"
# Read the arrangement back out of the image that ships, rather than trusting
# that the script above worked. A .DS_Store that did not make it produces a
# plain white window on a player's machine and nothing here would say so.
#
# Two things are read out of the .DS_Store with strings rather than asked of
# Finder. The window size, because Finder reports the size of the window in
# front of you, which on this machine is a size it remembers and not the one
# saved in the image -- the very mistake this check exists to catch. And the
# background, because "background picture of icon view options" can be set but
# not read: asking for it raises AppleEvent error -10000.
CHECK="$(hdiutil attach "$DMG" -readonly -noverify -noautoopen | grep -Eo '/Volumes/.*$' | head -1)"
MOUNT="$CHECK"
VOLUME="$(basename "$CHECK")"

fail() { echo "$1" >&2; exit 1; }
[[ -f "$CHECK/.background/background.tiff" ]] || fail "No background picture in the image"
[[ -f "$CHECK/.DS_Store" ]] || fail "Finder wrote no .DS_Store: the window is unarranged"
[[ -f "$CHECK/.VolumeIcon.icns" ]] || fail "No volume icon in the image"
strings -a "$CHECK/.DS_Store" | grep -q "background.tiff" \
	|| fail "The .DS_Store does not point at the background picture"
SAVED="$(strings -a "$CHECK/.DS_Store" | grep -o "{{[0-9, ]*}, {$WIDTH, $HEIGHT}}" | head -1)"
[[ -n "$SAVED" ]] || fail "The saved window is not ${WIDTH}x${HEIGHT}: $(
	strings -a "$CHECK/.DS_Store" | grep -o '{{[0-9, ]*}, {[0-9, ]*}}' | head -1)"

# The icon positions do come from Finder, because those it reports from the
# image rather than from memory. The window has to be open to be asked.
osascript <<APPLESCRIPT
tell application "Finder"
	tell disk "$VOLUME"
		open
		delay 1
		set g to position of item "$NAME.app" of container window
		set a to position of item "Applications" of container window
		set s to icon size of icon view options of container window
		close
		return "    window ${WIDTH}x${HEIGHT}  ·  icons " & (s as text) & " px at " & ¬
			(item 1 of g as text) & "," & (item 2 of g as text) & " and " & ¬
			(item 1 of a as text) & "," & (item 2 of a as text) & "  ·  background and volume icon present"
	end tell
end tell
APPLESCRIPT
hdiutil detach "$CHECK" -quiet
MOUNT=""

echo "==> done"
ls -lh "$DMG"
