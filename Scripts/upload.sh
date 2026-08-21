#!/bin/bash
#
# Lädt die gebaute .ipa nach App Store Connect — und damit nach TestFlight.
#
#     ASC_ISSUER_ID=<Issuer-ID> Scripts/upload.sh
#
# Die Issuer-ID steht in App Store Connect unter
# „Benutzer und Zugriff → Integrationen → App Store Connect API". Sie ist kein
# Geheimnis, nur eine Kennung; der eigentliche Schlüssel liegt als
# ~/.appstoreconnect/private_keys/AuthKey_<KeyID>.p8 und wird von altool selbst
# gelesen — er steht nie in einer Kommandozeile und nie in diesem Skript.
#
# Ein Upload ist eine Veröffentlichung an Apple. Deshalb ist er ein eigener
# Schritt und nicht das Ende von Scripts/archive.sh.

set -euo pipefail
cd "$(dirname "$0")/.."

IPA="build/export/IDReader.ipa"
KEY_ID="${ASC_KEY_ID:-D5BM7BM3H5}"
ISSUER="${ASC_ISSUER_ID:-}"

if [ ! -f "$IPA" ]; then
	echo "FEHLER: $IPA fehlt. Zuerst Scripts/archive.sh laufen lassen."
	exit 1
fi

if [ -z "$ISSUER" ]; then
	echo "FEHLER: ASC_ISSUER_ID ist nicht gesetzt."
	echo
	echo "Sie steht in App Store Connect unter Benutzer und Zugriff →"
	echo "Integrationen → App Store Connect API, und sieht aus wie"
	echo "69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx."
	exit 1
fi

if [ ! -f "$HOME/.appstoreconnect/private_keys/AuthKey_$KEY_ID.p8" ]; then
	echo "FEHLER: kein Schlüssel AuthKey_$KEY_ID.p8 in ~/.appstoreconnect/private_keys/."
	exit 1
fi

echo "==> Prüfen"
xcrun altool --validate-app \
	--file "$IPA" \
	--type ios \
	--apiKey "$KEY_ID" \
	--apiIssuer "$ISSUER"

echo
echo "==> Hochladen"
xcrun altool --upload-app \
	--file "$IPA" \
	--type ios \
	--apiKey "$KEY_ID" \
	--apiIssuer "$ISSUER"

echo
echo "Hochgeladen. Die Verarbeitung bei Apple dauert einige Minuten; danach"
echo "steht der Build in TestFlight. Für den internen Test (eigenes Team) gibt es"
echo "keine Beta-Prüfung, für externe Tester schon."
