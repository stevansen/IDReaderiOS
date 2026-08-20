#!/bin/bash
#
# Die Zusage: diese App überträgt nichts.
#
# Unter Android trägt diese Zusage das Manifest — die INTERNET-Berechtigung wird
# dort ausdrücklich wieder entfernt, weil eine Bibliothek sie stillschweigend
# hinzufügen könnte und damit eine Aussage im Store-Eintrag und in der
# Datenschutzerklärung aufheben würde, ohne dass irgendwo im Code steht, dass
# etwas übertragen wird.
#
# iOS kennt keine solche Berechtigung. Es gibt hier nichts zu entfernen und
# damit auch nichts, was einen versehentlichen Netzzugriff auffallen ließe. Also
# tut es dieses Skript: es sucht nach allem, womit sich überhaupt etwas senden
# ließe, und schlägt fehl, wenn es etwas findet.
#
# Aufruf: Scripts/check-no-network.sh
# In CI oder als "Run Script"-Phase vor dem Kompilieren einhängen.

set -uo pipefail
cd "$(dirname "$0")/.."

# Was einen Netzzugriff möglich macht. Absichtlich weit gefasst: ein Treffer, der
# sich als harmlos erweist, kostet eine Minute — ein übersehener kostet die
# Zusage.
PATTERN='URLSession|NSURLConnection|CFNetwork|import Network|NWConnection|CFStream|Socket\(|getaddrinfo|CFHTTP'

TARGETS="App Sources"
HITS=$(grep -rnE "$PATTERN" $TARGETS --include='*.swift' || true)

if [ -n "$HITS" ]; then
	echo "FEHLER: Netzzugriff im Quelltext gefunden."
	echo
	echo "$HITS"
	echo
	echo "Diese App verspricht, nichts zu übertragen — im Hinweis beim ersten"
	echo "Start, in der Datenschutzerklärung und im Store-Eintrag. Wenn hier"
	echo "wirklich etwas gesendet werden soll, dann ändere zuerst diese drei"
	echo "Texte und danach dieses Skript."
	exit 1
fi

echo "OK: kein Netzzugriff in $TARGETS."
