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

## Eintragen: nicht mehr von Hand

Seit dem 22. August 2026 schreibt [`../Scripts/asc.swift`](../Scripts/asc.swift)
diesen Ordner über die App Store Connect API in den Eintrag. Damit ist `store/`
die Quelle und der Eintrag das Abbild — vorher war es ein Ordner, den niemand
angewendet hat.

```bash
export ASC_KEY_ID=… ASC_ISSUER_ID=…
swift Scripts/asc.swift show            # was heute im Eintrag steht
swift Scripts/asc.swift set-version 1.8
swift Scripts/asc.swift category UTILITIES
swift Scripts/asc.swift metadata        # Name, Untertitel, Beschreibung, Stichworte, Werbetext
swift Scripts/asc.swift screenshots     # aus screenshots/<größe>-<sprache>/
```

Jeder Lauf schreibt denselben Zustand; die Bildschirmfotos werden vorher
geleert, damit nicht bei jedem Lauf dieselben ein zweites Mal erscheinen.

### Drei Dinge, die dabei herauskamen

* **Die API kennt kein `APP_IPHONE_69`.** 1320 × 2868 gehört in das
  6,7-Zoll-Fach; im Store heißt es „6,7 Zoll oder 6,9 Zoll". Durchprobiert, die
  API listet die zulässigen Werte im Fehler auf.
* **Eine Sprache in den App-Informationen anzulegen legt die
  Fassungsübersetzung mit an.** Eine Liste, die vorher geholt wurde, ist danach
  falsch.
* **„IDReader" ist für `en-US` von einem fremden Konto belegt.** Siehe unten.

## Zwei Namen, und warum

Der Name ist im App Store **je Sprache eindeutig**. „IDReader" ist für `en-US`
von einem fremden Konto belegt:

> The app name you entered is already being used. If you have trademark rights
> to this name and would like it released for your use, submit a claim.

Deshalb heißt die App im englischen Store **„CIE Reader"** und in den anderen
beiden „IDReader". Zwei Namen für eine App sind kein Versehen, sondern die Folge
davon, dass der eine Name in einer Sprache nicht zu haben ist. `name.txt` je
Ordner ist die Quelle.

Der Anspruch auf „IDReader" für Englisch ließe sich bei Apple anmelden — dafür
braucht es Markenrechte an dem Namen. Ohne die bleibt es bei den zwei Namen.

## Das App-Icon

Es gibt **kein Feld dafür**. Auf iOS nimmt der Store das Icon aus dem Bau —
`App/Assets.xcassets/AppIcon.appiconset/icon-1024.png` wird beim Archivieren
mitgegeben, und `altool --validate-app` fällt durch, wenn es fehlt.

Solange aber **kein Bau an der Fassung hängt**, hat der Eintrag kein Icon und
zeigt das grau gerasterte Platzhalterquadrat. Genau so war es hier: drei Bauten
hochgeladen, die Fassung fertig beschriftet, `appStoreVersions/…/build` aber
`null`. Nicht das Icon fehlte, die Verbindung.

```bash
swift Scripts/asc.swift attach-build      # den höchsten gültigen Bau
swift Scripts/asc.swift attach-build 3    # einen bestimmten
```

Danach steht das Icon in der App-Liste. Ein neuer Bau muss wieder angehängt
werden — das Hochladen allein tut es nicht.

## Noch zu überlegen

* **`en-US`-Stichworte:** dort steht „CIE Reader" noch in `keywords.txt`. Der
  App-Name wird von Apple ohnehin indexiert, das kostet also 11 von 100
  Zeichen umsonst — anders als bei `de-DE` und `it`, wo der Name „IDReader"
  heißt und das Stichwort seine Arbeit tut. Nicht geändert, weil das Stichwort
  ausdrücklich gewünscht war.
* **Vier statt sieben Bilder** für `en-US` und `it`. Dem deutschen Satz fehlen
  Hinweis, Teilen und Einstellungen nicht; den anderen zwei schon.

---

## Was am 22. August 2026 nachgesehen und gesetzt wurde

Die Prüfung ist über die Schnittstelle gelaufen, nicht über den Browser — jede
Zeile unten ist ein gelesener Wert, keine Erinnerung.

| | Stand |
|---|---|
| Preis | **kostenlos**, war schon gesetzt (Grundgebiet ITA, Kundenpreis 0,0) |
| Gebiete | **41 europäische**, Frankreich ausgenommen — so gewollt, siehe unten |
| Datenschutz-Adresse | gesetzt, je Sprache auf `store/privacy/privacy-policy-<lang>.md` im Repository |
| Altersfreigabe | **war vollständig unbeantwortet.** Beantwortet, Ergebnis 4+ |
| Inhalte Dritter | **war leer.** Gesetzt auf „keine" |
| Prüfkontakt | war gesetzt |
| Ausfuhrangabe | je Bau gesetzt |
| Bedienungshilfen | Entwurf, absichtlich nicht veröffentlicht |

Die beiden mittleren Zeilen waren **Riegel vor jeder Einreichung**: ohne
Altersfreigabe und ohne die Erklärung zu Inhalten Dritter nimmt App Store Connect
keine Einreichung an, und keine von beiden meldet sich von selbst. Gesetzt mit

```bash
swift Scripts/asc.swift age-rating
swift Scripts/asc.swift content-rights
```

### Die Gebiete: 41 und nicht 26

Der Auftrag lautete „EU außer Frankreich". Beim Nachsehen war Frankreich schon
ausgenommen und die App in 41 europäischen Gebieten verfügbar: den 26
EU-Staaten plus fünfzehn außerhalb — Schweiz, Norwegen, Island, Vereinigtes
Königreich, Ukraine, Türkei, Westbalkan, Moldau, Belarus, Russland.

Nachgefragt und **so bestätigt**. Südtirol hat Nachbarn außerhalb der EU, und ein
Werkzeug, das ein Dokument prüft, ist dort so nützlich wie hier. Aufgeschrieben,
damit es nicht bei der nächsten Durchsicht als Versehen korrigiert wird.

### Was noch fehlt

1. **Die Händlerangabe nach dem Digital Services Act.** Nicht über die
   Schnittstelle sichtbar, also von Hand nachzusehen: App Store Connect →
   Geschäftliches → Händlerstatus. Ohne Erklärung nimmt Apple die App **aus allen
   27 EU-Storefronts** — seit dem 17. Februar 2025 automatisch, auch bei einer
   bereits freigegebenen App. Eine kostenlose App ohne gewerbliche Tätigkeit darf
   „kein Händler" erklären; nur erklären muss man es. Das ist jetzt der einzige
   bekannte Riegel, der noch stehen kann.
2. **Bildschirmfotos: 7 auf Deutsch, 4 auf Englisch und Italienisch.** Kein
   Riegel — Apple verlangt eines —, aber der englische und der italienische
   Eintrag zeigen den Ersthinweis, den Führerschein und die Einstellungen nicht.
   Die drei fehlenden lassen sich im Simulator in der jeweiligen Sprache
   nachziehen.
3. **Christian Auers eigener Beleg für Apache-2.0.** Siehe COPYRIGHT: die
   Lizenzdateien liegen in beiden Repositorien, aber beide Festschreibungen im
   Android-Repository sind von Stefan Hellweger verfasst.

### Die Kontaktadresse ist absichtlich keine

Gefragt war, ob sie weggelassen werden kann. Sie kann, und sie ist es:

* **Apple** verlangt in Richtlinie 5.1.1(i) drei Dinge von einer
  Datenschutzerklärung — welche Daten erhoben werden, dass Dritte gleichwertig
  schützen, und wie man Einwilligung widerruft oder Löschung verlangt. Eine
  Adresse ist nicht darunter. Erreichbarkeit verlangt Richtlinie 1.5, und zwar
  über die **Support-Adresse**; die zeigt auf dieses Repository, und `SUPPORT.md`
  nennt die Fehler- und Fragenverwaltung.
* **Die Grundverordnung** richtet die Auskunftspflicht an den Verantwortlichen.
  Der ist hier nicht der Entwickler: die Daten verlassen das Gerät nicht, es gibt
  keinen Server, kein Analysewerkzeug, keine Übermittlung. Wer nichts verarbeitet,
  ist für nichts verantwortlich — und eine Adresse an dieser Stelle behauptete
  eine Zuständigkeit, die nicht besteht.

Der Abschnitt ist deshalb **nicht gelöscht, sondern ersetzt**: er sagt jetzt, wer
der Verantwortliche ist (die Stelle, die die App einsetzt), warum hier keine
Adresse steht, und wohin Fragen zur App gehen. Eine Überschrift ohne Inhalt wäre
schlechter als keine Überschrift.

Zu prüfen bleibt: erklärt der Anbieter sich beim Händlerstatus als **Händler**,
veröffentlicht Apple Name, Anschrift, Telefon und Adresse auf der Produktseite —
dann steht der Kontakt ohnehin öffentlich, nur an einer anderen Stelle.

