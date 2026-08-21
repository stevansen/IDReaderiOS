#!/bin/bash
#
# Die Zusage: diese App greift an genau EINER Stelle ins Netz.
#
# Bis zur Sperrprüfung war die Zusage weiter gefasst — die App übertrug nichts,
# und dieses Skript ließ keinen einzigen Netzzugriff durch. Das ist vorbei, und
# zwar mit Ansage: `App/Revocation/RevocationDownloader.swift` holt die
# öffentliche Sperrliste der Ausweisbehörde. Der Hinweis beim ersten Start, die
# drei Store-Beschreibungen und die drei Datenschutzerklärungen sagen das.
#
# Was dieses Skript jetzt durchsetzt, ist die engere und darum überprüfbare
# Zusage: außerhalb dieser einen Datei gibt es keinen Netzzugriff. Ein zweiter
# wäre der Anfang davon, dass niemand mehr weiß, was hinausgeht — und genau das
# soll hier auffallen, bevor es niemandem auffällt.
#
# Aufruf: Scripts/check-no-network.sh
# In CI oder als "Run Script"-Phase vor dem Kompilieren einhängen.

set -uo pipefail
cd "$(dirname "$0")/.."

# Was einen Netzzugriff möglich macht. Absichtlich weit gefasst: ein Treffer, der
# sich als harmlos erweist, kostet eine Minute — ein übersehener kostet die
# Zusage.
PATTERN='URLSession|NSURLConnection|CFNetwork|import Network|NWConnection|CFStream|Socket\(|getaddrinfo|CFHTTP|Data\(contentsOf: *URL\(string|String\(contentsOf: *URL\(string'

# Die eine erlaubte Datei.
ALLOWED='App/Revocation/RevocationDownloader.swift'

# ThirdParty ist mit dabei, und das ist der eigentliche Grund, dass dieses Skript
# nicht bloß Zierde ist: dort liegt fremder Code, der bei jedem Auffrischen neu
# hereinkommt. Die Fassung, gegen die geprüft wurde, greift nicht ins Netz — dass
# das so bleibt, sagt niemand zu.
TARGETS="App Sources ThirdParty"
HITS=$(grep -rnE "$PATTERN" $TARGETS --include='*.swift' | grep -v "^$ALLOWED:" || true)

STATUS=0

if [ -n "$HITS" ]; then
	echo "FEHLER: Netzzugriff außerhalb von $ALLOWED."
	echo
	echo "$HITS"
	echo
	echo "Diese App greift an genau einer Stelle ins Netz, und die steht in"
	echo "$ALLOWED. Was dort hinausgeht, ist im Hinweis beim ersten Start, in"
	echo "den Store-Beschreibungen und in den Datenschutzerklärungen benannt."
	echo "Soll hier wirklich etwas Zweites gesendet werden, dann ändere zuerst"
	echo "diese Texte und danach dieses Skript."
	STATUS=1
fi

if [ ! -f "$ALLOWED" ]; then
	echo "FEHLER: $ALLOWED fehlt."
	echo
	echo "Entweder ist die Sperrprüfung ausgebaut worden — dann gehört dieses"
	echo "Skript auf die alte, strengere Fassung zurück und die Texte mit ihm —"
	echo "oder die Datei ist umbenannt worden, ohne die Ausnahme hier"
	echo "mitzuführen. Beides soll auffallen."
	exit 1
fi

# Kein Rechnername im Quelltext. Die Adresse der Verteilstelle steht in den
# CSCA-Zertifikaten und wird von dort gelesen — siehe
# CertificateReader.crlDistributionPoints. Eine hier eingetragene Adresse wäre
# eine Behauptung über eine fremde Behörde, und niemand würde merken, wenn sie
# irgendwann nicht mehr stimmt.
URLS=$(grep -nE '"https?://' "$ALLOWED" || true)
if [ -n "$URLS" ]; then
	echo "FEHLER: feste Adresse in $ALLOWED."
	echo
	echo "$URLS"
	echo
	echo "Die Verteilstelle kommt aus den hinterlegten Zertifikaten, nicht aus"
	echo "dem Quelltext."
	STATUS=1
fi

if [ "$STATUS" -ne 0 ]; then
	exit "$STATUS"
fi

echo "OK: Netzzugriff in $TARGETS nur in $ALLOWED, und dort ohne feste Adresse."
