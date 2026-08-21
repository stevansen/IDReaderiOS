# Store-Material

Alles, was in App Store Connect eingetragen wird, liegt hier als Datei. Der Grund:
im Formular ist ein Text unsichtbar, sobald man das Fenster schließt — hier ist er
nachlesbar, vergleichbar und versioniert. Wer etwas ändert, ändert es hier und
trägt es dann ein.

**Eintragen muss es jemand von Hand.** Store-Texte gehen nicht über `altool`, und
die Weboberfläche braucht eine angemeldete Sitzung.

## Was wohin

| Feld in App Store Connect | Datei | Grenze |
|---|---|---|
| Name | `<locale>/name.txt` | 30 |
| Untertitel | `<locale>/subtitle.txt` | 30 |
| Keywords | `<locale>/keywords.txt` | 100 |
| Werbetext | `<locale>/promotional-text.txt` | 170 |
| Beschreibung | `<locale>/description.txt` | 4000 |
| Neue Funktionen | `<locale>/whats-new.txt` | 4000 |
| Screenshots 6,9″ | `screenshots/6.9-<lang>/` | 1320×2868 |

Sprachen: `de-DE`, `en-US`, `it`. Prüfen mit

```bash
python3 store/check-lengths.py
```

Die Grenzen sind hart — App Store Connect kürzt nicht, es lehnt ab. Das Skript
warnt schon ab 95 Prozent, weil die Zählweise dort gelegentlich abweicht.

## Weitere Angaben im Formular

| | |
|---|---|
| Preis | **Kostenlos**, keine In-App-Käufe |
| Primäre Kategorie | Dienstprogramme |
| Sekundäre Kategorie | Wirtschaft |
| Altersfreigabe | 4+ — kein Inhalt, der eine Einstufung auslöst |
| App Privacy | **Data Not Collected.** Es wird nichts übertragen; `App/PrivacyInfo.xcprivacy` sagt dasselbe |
| SKU | `CIEREADER-IOS-001` |
| Bundle-Kennung | `com.ciereader.ios` |

## Zwei Angaben, die noch fehlen — und eine, die falsch wäre

### Support-URL — erledigt

```
https://github.com/stevansen/IDReaderiOS/blob/main/SUPPORT.md
```

Das Repository ist öffentlich, und [`SUPPORT.md`](../SUPPORT.md) ist dafür
geschrieben: dreisprachig, benutzerseitig, mit den Fällen, die im Test tatsächlich
zurückkommen — „Kein NFC verfügbar", „CAN stimmt nicht", das leere Lichtbild — und
dem Verweis auf die Issues.

Wer lieber auf die Übersichtsseite verweist, nimmt
`https://github.com/stevansen/IDReaderiOS`; Apple akzeptiert beides.

### Datenschutz-URL — vorbereitet, zwei Handgriffe fehlen

Der **Text liegt fertig** in [`privacy/`](privacy/), in drei Sprachen, und es gibt
einen Weg, ihn zu veröffentlichen, seit das Repository öffentlich ist:

```bash
python3 Scripts/build-privacy-pages.py
```

Das Skript baut aus den Markdown-Dateien eigenständige HTML-Seiten nach
`docs/privacy/` und **bricht ab, solange noch `<<…>>` im Text steht**. Danach in
den Einstellungen des Repositories *Pages → Deploy from a branch → main → /docs*
einschalten; die Adresse ist dann

```
https://stevansen.github.io/IDReaderiOS/privacy/
```

Es fehlen also zwei Handgriffe: die Platzhalter ausfüllen und Pages einschalten.

Die Seite der Android-Fassung (`https://cauer71.github.io/ciereader-privacy/`)
darf **nicht unverändert** verlinkt werden: sie sagt ausdrücklich, es erscheine
keine Kamera-Berechtigung. Für Android stimmt das, für iOS ist es falsch. Eine
Datenschutzerklärung, die an genau dem Punkt etwas Falsches behauptet, an dem sie
ein Versprechen gibt, ist schlimmer als keine. Also eine eigene Seite oder ein
eigener Abschnitt für iOS auf derselben.

Auszufüllen sind Name und Mailadresse des Verantwortlichen. Die Android-Fassung
nennt dort Christian Auer; wer es hier ist, hängt davon ab, unter welchem Konto die
App liegt, und ist keine Entscheidung, die ein Textentwurf treffen kann.

| Datei | |
|---|---|
| [`privacy/privacy-policy-de.md`](privacy/privacy-policy-de.md) | Deutsch |
| [`privacy/privacy-policy-en.md`](privacy/privacy-policy-en.md) | Englisch |
| [`privacy/privacy-policy-it.md`](privacy/privacy-policy-it.md) | Italienisch |

Jede Datei beginnt mit einer Notiz, was gegenüber der Android-Fassung geändert
wurde und warum — der Kopf ist nicht Teil des zu veröffentlichenden Textes, die
Linie trennt.

### Die Ausfuhrmeldung

Nicht hier, sondern in
[`../docs/EXPORT-COMPLIANCE.md`](../docs/EXPORT-COMPLIANCE.md). Kurz: standardmäßige
Algorithmen **zusätzlich** zu denen des Betriebssystems, seit OpenSSL für PACE mit
im Bundle liegt.

## Screenshots

15 Aufnahmen, 1320×2868 — das von Apple verlangte 6,9″-Maß (iPhone 17 Pro Max).
Deutsch vollständig, Englisch und Italienisch die vier Bildschirme, die Text
tragen. Wer nur einen Satz hinterlegt, sollte den deutschen nehmen; Apple zeigt
ihn dann in allen Sprachen.

| | zeigt |
|---|---|
| `01-hinweis` | der Hinweis beim ersten Start — die drei Sätze, um die es geht |
| `02-ausweis` | die CAN-Maske mit der Kartengrafik |
| `03-archiv` | **die wichtigste Aufnahme**: drei Dokumentarten in ihren Farben, zwei mit grünem Siegel, die Fahrerlaubnis mit „ungeprüft" in Rot |
| `04-ergebnis` | ein gelesener Datensatz, mit dem Vermerk, dass er aus dem Archiv stammt |
| `05-teilen` | was hinausgeht, aufgerechnet, mit „Ohne Lichtbild" |
| `06-fuehrerschein` | die rosé Farbwelt und die frei bearbeitbaren Felder |
| `07-einstellungen` | die Sprachwahl |

### Wie sie entstanden sind, und warum das erklärt werden muss

Im Simulator gibt es kein NFC. Ergebnis, Archiv und Teilen zeigen ohne Daten
nichts, also mussten Daten her — und ein Weg, der in einer App zum Lesen von
Ausweisen Daten **erfindet**, ist genau das, was es nicht geben darf.

Deshalb `App/Support/DemoData.swift`, mit drei Riegeln zugleich: die Datei liegt
vollständig in `#if DEBUG` und existiert im Auslieferungsbau nicht; sie läuft nur
mit dem Startargument `-IDREADER_DEMO 1`; und ihre Werte sind erkennbar erfunden —
dieselben Namen wie im anonymisierten Prüfkorpus.

Neu aufnehmen:

```bash
xcodebuild -project IDReader.xcodeproj -scheme IDReader -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO CONFIGURATION_BUILD_DIR=build/sim build
xcrun simctl install <UDID iPhone 17 Pro Max> build/sim/IDReader.app
xcrun simctl launch <UDID> com.ciereader.ios -IDREADER_DEMO 1
xcrun simctl io <UDID> screenshot store/screenshots/6.9-de/01-hinweis.png
```

Kein Rahmen, kein Text im Bild, kein Gerätebild darum. Apple erlaubt das, aber es
verdeckt, was die App zeigt — und was sie zeigt, ist hier das Argument.
