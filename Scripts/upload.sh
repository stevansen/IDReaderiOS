#!/bin/bash
#
# Lädt die gebaute .ipa nach App Store Connect — und damit nach TestFlight.
#
#     ASC_KEY_ID=<Schlüsselkennung> ASC_ISSUER_ID=<Issuer-ID> Scripts/upload.sh
#
# Beide Angaben stehen in App Store Connect unter
# „Benutzer und Zugriff → Integrationen → App Store Connect API". Keine von beiden
# steht in dieser Datei, und das ist Absicht: das Repository ist öffentlich, und
# Kennungen, die auf ein bestimmtes Konto zeigen, gehören dort nicht hinein — auch
# wenn sie für sich allein nutzlos sind.
#
# Der eigentliche Schlüssel liegt als
# ~/.appstoreconnect/private_keys/AuthKey_<Schlüsselkennung>.p8 und wird von
# altool selbst gelesen. Er steht nie in einer Kommandozeile und nie hier.
#
# Ein Upload ist eine Veröffentlichung an Apple. Deshalb ist er ein eigener
# Schritt und nicht das Ende von Scripts/archive.sh.

set -euo pipefail
cd "$(dirname "$0")/.."

IPA="build/export/IDReader.ipa"
KEY_ID="${ASC_KEY_ID:-}"
ISSUER="${ASC_ISSUER_ID:-}"

if [ ! -f "$IPA" ]; then
	echo "FEHLER: $IPA fehlt. Zuerst Scripts/archive.sh laufen lassen."
	exit 1
fi

if [ -z "$KEY_ID" ] || [ -z "$ISSUER" ]; then
	echo "FEHLER: ASC_KEY_ID und/oder ASC_ISSUER_ID sind nicht gesetzt."
	echo
	echo "Beide stehen in App Store Connect unter Benutzer und Zugriff →"
	echo "Integrationen → App Store Connect API. Die Schlüsselkennung ist die"
	echo "Spalte neben dem Schlüssel, die Issuer-ID steht über der Liste."
	echo
	echo "  ASC_KEY_ID=XXXXXXXXXX ASC_ISSUER_ID=xxxxxxxx-xxxx-... Scripts/upload.sh"
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
