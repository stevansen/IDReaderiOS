#!/bin/bash
#
# Baut ein Archiv und macht daraus eine .ipa für App Store Connect.
#
#     Scripts/archive.sh [Buildnummer]
#
# Ohne Argument wird die Buildnummer aus dem Projekt genommen. **Jeder Upload
# braucht eine höhere Nummer als der vorige** — App Store Connect nimmt dieselbe
# nicht zweimal an, auch nicht nach dem Löschen.
#
# Was dieses Skript NICHT tut: hochladen. Das steht in Scripts/upload.sh, und die
# Trennung ist Absicht — ein Archiv zu bauen ist harmlos, ein Upload ist eine
# Veröffentlichung an Apple und soll ein eigener Schritt bleiben.

set -euo pipefail
cd "$(dirname "$0")/.."

BUILD="${1:-}"
SCHEME="IDReader"
ARCHIVE="build/IDReader.xcarchive"
EXPORT="build/export"

# Die Zusage prüfen, bevor irgendetwas gebaut wird. Ein Bau, der schon läuft,
# lädt zum Wegsehen ein.
Scripts/check-no-network.sh

echo
echo "==> Tests"
swift test

echo
echo "==> Archiv"
rm -rf "$ARCHIVE" "$EXPORT"

ARGS=(
	-project IDReader.xcodeproj
	-scheme "$SCHEME"
	-configuration Release
	-destination 'generic/platform=iOS'
	-archivePath "$ARCHIVE"
	-allowProvisioningUpdates
)
if [ -n "$BUILD" ]; then
	ARGS+=(CURRENT_PROJECT_VERSION="$BUILD")
fi

xcodebuild "${ARGS[@]}" archive

echo
echo "==> Ausfuhr"
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE" \
	-exportOptionsPlist Config/ExportOptions.plist \
	-exportPath "$EXPORT" \
	-allowProvisioningUpdates

echo
ls -la "$EXPORT"
echo
echo "Fertig. Hochladen mit: Scripts/upload.sh"
