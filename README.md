# IDReader für iOS

Liest die italienische elektronische Identitätskarte **CIE 3.0** und den
**ePass** über NFC, sowie den **italienischen Führerschein** aus einem Foto —
und sagt bei jedem Datensatz, woher er stammt und ob daran etwas geprüft ist.

Portierung der Android-App **CIEreader**
([`cauer71/AndroidDev`](https://github.com/cauer71/AndroidDev), Modul
`apps/cie-reader`). Verhalten, Wortlaut und Archivformat sind übernommen; die
Mechanik ist die von Apple. Was dabei anders werden musste, steht in
[`docs/ANDROID-TO-IOS.md`](docs/ANDROID-TO-IOS.md) — mit Begründung, nicht als
Liste.

© 2026 Christian Auer und Stefan Hellweger. Lizenziert unter der
**Apache-Lizenz 2.0** — siehe [`LICENSE`](LICENSE), [`NOTICE`](NOTICE) und
[`COPYRIGHT`](COPYRIGHT). Warum diese und nicht eine andere, steht in
[`docs/LICENCE-CHOICE.md`](docs/LICENCE-CHOICE.md).

**Der Code ist frei, der Name nicht.** Abschnitt 6 der Lizenz gibt keine
Namensrechte mit, und das ist Absicht: wer diesen Code forkt, kann die
Echtheitsprüfung entschärfen und das Ergebnis trotzdem „geprüft" nennen. Keine
Lizenz verhindert das — aber ein solcher Fork darf nicht „IDReader" heißen.
Nehmen Sie den Code und geben Sie Ihrem Bau einen eigenen Namen.

Das Repository ist ohnehin offen, damit nachprüfbar ist, was die App tut — die
Zusagen in der Datenschutzerklärung sind sonst nur Behauptungen. Wer sie prüfen
will, braucht dafür seit jeher keine Lizenz; wer den Code benutzen will, hat
jetzt eine.

Hilfe für Benutzer: [`SUPPORT.md`](SUPPORT.md), dreisprachig.

---

## Der Stand in einem Satz

Vollständig gebaut und durch 64 Tests gedeckt — **aber der Leseweg ist noch nicht
gegen eine echte Karte gehalten worden.** Bis das passiert ist, gilt er als
gebaut, nicht als geprüft; siehe [`docs/STATUS.md`](docs/STATUS.md) und
[`docs/NFC-PACE.md`](docs/NFC-PACE.md).

## Bauen

```bash
swift test
```

```bash
xcodebuild -project IDReader.xcodeproj -scheme IDReader -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

`-scheme` und nicht `-target`: mit `-target` baut Xcode die Paketabhängigkeiten
nicht mit, und der Bau bricht an einem nicht auflösbaren Modul ab.

Für ein Gerät braucht die App-ID die Berechtigung **NFC Tag Reading** im
Entwicklerkonto — ohne sie lässt sich das Ziel nicht signieren. Der Weg auf ein
Testgerät steht in [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md):

```bash
Scripts/archive.sh
```

```bash
Scripts/check-no-network.sh
```

Der letzte Aufruf ist keine Formsache: die App verspricht, nichts zu übertragen,
und auf iOS gibt es keine Berechtigung, deren Fehlen das absichern würde.

## Aufbau

```
IDReaderiOS/
├── Package.swift              IDReaderCore — ohne UIKit, ohne CoreNFC, ohne SwiftUI
├── Sources/IDReaderCore/
│   ├── Model/                 Datensatz, Urteil, Dokumentarten, Zugangsschlüssel
│   ├── Parsing/               LicenceScan, MrzScan, CanScan, BilingualText
│   ├── Archive/               AES-256-GCM, Schlüsselbund, Format Version 8
│   ├── Export/                lesbarer Text, JSON, HTML, Lokalisierung
│   └── Resources/             en/de/it + die italienischen CSCA-Zertifikate
├── Tests/IDReaderCoreTests/   64 Tests, darunter der gemessene OCR-Korpus
├── App/
│   ├── UI/                    SwiftUI: drei Masken, Lesen, Ergebnis, Archiv, Teilen
│   ├── NFC/                   Adapter auf die Lesebibliothek, Urteilsbildung
│   ├── Capture/               Kamera und Vision
│   └── Support/               Farbschemata, Schriftstile, Ausgabewege
├── ThirdParty/                fremder Code, gepatcht — MIT, siehe dort
│   └── NFCPassportReaderCAN/  PACE, Secure Messaging, Passive Auth, Chip Auth
├── Config/                    Info.plist, Berechtigungen
├── docs/                      STATUS, ANDROID-TO-IOS, NFC-PACE, DATA-PROTECTION,
│                              TESTFLIGHT, EXPORT-COMPLIANCE (+ DOSSIER),
│                              LICENCE-CHOICE
├── store/                     Store-Texte in drei Sprachen und die Screenshots
└── MIGRATION_PROMPT.md        der Prompt, mit dem sich das fortsetzen lässt
```

Warum `IDReaderCore` ein eigenes Paket ist: alles darin läuft ohne Gerät, also
auch auf dem Mac. Die Rückmeldungen aus dem Feld betreffen fast immer einen der
drei Parser, und die lassen sich so in Sekunden prüfen statt in Minuten auf einem
Telefon. Unter Android war das die Absicht hinter „`LicenceScan` ist reiner Text
zu Feldern"; hier erzwingt es die Paketgrenze.

## Was diese App über sich selbst sagt

Drei Sätze, und sie sind der Grund, warum sie so gebaut ist, wie sie gebaut ist:

* **Ein falscher Wert ist schlimmer als ein leeres Feld.** Ein leeres Feld sieht
  der Bediener und füllt es. Ein plausibel gefülltes sieht er nur, wenn er genau
  hinschaut — und beim Führerschein gibt es nichts, was einen Lesefehler danach
  noch auffangen würde.
* **Geprüft und ungeprüft sehen nie gleich aus.** Ein Chip-Datensatz, der die
  Prüfung bestanden hat, trägt das grüne Siegel. Ein Datensatz aus einem Foto
  trägt gar keins — kein graues, kein durchgestrichenes —, sondern den Vorbehalt
  in Worten. Ein durchgestrichenes Siegel liest sich als „durchgefallen", und
  hier gab es nie eine Prüfung.
* **Nichts Personenbezogenes verlässt das Gerät von selbst.** Genau ein
  Netzzugriff, und der holt eine öffentliche Sperrliste, ohne etwas über das
  Dokument mitzuteilen — abschaltbar, und ein Prüfschritt beim Bauen hält ihn auf
  diese eine Datei begrenzt. Dazu ein Archiv, das sich nach 30 Tagen selbst
  löscht.
* **Vier Felder werden angezeigt und nicht aufbewahrt** — Wohnsitz, Steuernummer,
  Beruf, Telefon. Abschaltbar, vorbelegt eingeschaltet, und beim Abschalten fragt
  die App nach dem Grund.

Was die App **nicht** entscheiden kann — die Rechtsgrundlage, die Unterrichtung
der betroffenen Person, die Aufbewahrungsdauer —, sagt sie beim ersten Start und
steht in [`docs/DATA-PROTECTION.md`](docs/DATA-PROTECTION.md). Das ist keine
Rechtsberatung und ersetzt keinen Datenschutzbeauftragten.
