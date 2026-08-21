# Stand

Stand vom **20. August 2026**, nach dem Einbau von PACE mit CAN. Quelle: `cauer71/AndroidDev`, `apps/cie-reader`,
Commit `7ab0d20`, Version 1.8 / versionCode 11.

## Fertig und geprüft

| Bereich | Stand | Nachweis |
|---|---|---|
| Modell (`DocumentData`, `Authenticity`, `DocumentType`, `RecordProvenance`, `AccessKey`, `StoredDocument`) | portiert | |
| `LicenceScan` — Fahrerlaubnis aus erkanntem Text | portiert, Zeile für Zeile | 12 Tests, davon zwei am gemessenen OCR-Korpus |
| `MrzScan` — Prüfziffern nach ICAO 9303 | portiert | 4 Tests |
| `CanScan` — sechs Ziffern, Eindeutigkeit | portiert | 8 Tests |
| `BilingualText` — zweisprachige Orte | portiert | 4 Tests |
| Archivformat (JSON, Version 8) | **bitgleich zur Android-Fassung** | 4 Tests |
| Archiv (AES-256-GCM, Schlüsselbund, ein Eintrag pro Person, 30 Tage) | portiert | 8 Tests |
| Export: lesbarer Text, JSON, HTML für Mail | portiert | 10 Tests |
| Lokalisierung en / de / it, 208 Einträge je Sprache | vollständig übernommen | 9 Tests, darunter „kein Schlüssel fehlt" je Sprache |
| Die sechs Farbschemata | Wert für Wert übernommen | am Gerät gesehen |
| Drei Eingabemasken, Lesescreen, Ergebnis, Archiv, Teilen, Einstellungen, erster Start, Fehlerblatt | gebaut | im Simulator durchlaufen |
| Texterkennung (Vision statt ML Kit) | gebaut | am Simulator nicht prüfbar (keine Kamera) |
| CSCA-Vertrauensanker (9 Zertifikate) | übernommen | 1 Test |
| **PACE mit CAN**, Datengruppen, Passive Authentication, Chip Authentication | gebaut, **am Gerät nicht nachgewiesen** | siehe [NFC-PACE.md](NFC-PACE.md) |
| Urteilsbildung aus den vier Teilprüfungen | portiert | `PassportChipReader.authenticity(from:)` |
| CSCA-Vertrauensanker als PEM-Bündel für die Kettenprüfung | erzeugt | 2 Tests |
| Datenschutz-Gegenstücke (Sicherung, Dateischutz, App-Umschalter, Zwischenablage, Netzprüfung) | gebaut | `Scripts/check-no-network.sh` |

**Fassung 1.8 (Build 1) liegt seit dem 21. August 2026 in App Store Connect**
(Delivery `10e2826e-8bae-4b29-a954-eb089e6a5f9b`), signiert mit
`Apple Distribution`, für TestFlight freigegeben. Damit ist der Weg auf ein Gerät
offen — der Nachweis am Gerät selbst ist Punkt 1 unten.

64 Tests, `swift test`, alle grün. Die App baut ohne eine einzige Warnung im
eigenen Code (`xcodebuild -scheme IDReader -sdk iphonesimulator`) und läuft im
Simulator.

## Offen

In der Reihenfolge, in der es sich lohnt:

1. **Der Nachweis am Gerät.** Der Build steht in TestFlight; jetzt eine echte
   CIE 3.0 an ein iPhone halten und die vier Phasen durchlaufen sehen. Ohne das gilt der Leseweg als gebaut, nicht als
   geprüft — die Android-Fassung ist gegen ein echtes Dokument auf zwei Geräten
   vermessen, und weniger ist hier keine Grundlage. Zu prüfen sind besonders: der
   schnelle Weg ohne Lichtbild, das grüne Siegel bei einer echten Karte, und dass
   eine falsche CAN als „CAN stimmt nicht" ankommt und nicht als „unbekannter
   Fehler".
2. **Der Fork statt der Kopie.** `ThirdParty/NFCPassportReaderCAN` ist eine
   gepatchte Kopie fremden Codes. Sauberer wäre ein Fork unter eigener Adresse als
   Paketverweis; der Patch liegt dafür bereit und ist auch als Beitrag nach oben
   brauchbar.
3. **JPEG 2000 für DG2** — OpenJPEG einbinden. Bis dahin zeigt die App das erkannte
   Format an der Stelle des Bildes, wie das Original bei einem unbekannten Format.
4. **Die Elastik der Eingabemasken.** Die drei Masken sollen ohne Scrollen auf
   einen Bildschirm passen; Dokumentgrafik und Ziffernblock nehmen ihre Höhe aus
   dem Restplatz, und unter einem Mindestmaß weicht die Grafik ganz. Heute steht
   die Kartenmaske fest und die beiden anderen scrollen. Bei 100 %, 130 % und
   200 % Systemschrift zu prüfen. Die Falle, in die die Compose-Fassung dreimal
   gelaufen ist: in einem scrollenden Vorfahren ist die Höhe unendlich, und dort
   ergibt ein Gewicht null.
5. **Store-Material.** Texte in drei Sprachen und 15 Bildschirmfotos liegen in
   [`../store/`](../store/); die Längen sind gegen Apples Feldgrenzen geprüft. Es
   fehlt eine **Support-URL** und ein Ort, an dem die **Datenschutzerklärung**
   steht — deren Text liegt fertig in [`../store/privacy/`](../store/privacy/), in
   drei Sprachen, mit zwei auszufüllenden Stellen (Name und Mailadresse des
   Verantwortlichen). Die Seite der Android-Fassung darf nicht unverändert
   verlinkt werden: sie behauptet, es erscheine keine Kamera-Berechtigung, und das
   ist auf iOS falsch. Das App-Zeichen ist ein Entwurf aus
   `Scripts/make-app-icon.swift`.
6. **Die Anerkennungen für MIT und Apache-2.0** müssen in der App erreichbar
   sein. Es gibt noch keinen Ort dafür.
7. **Die Wiedererkennung einer aufgelegten Karte** entfällt dauerhaft — iOS hat
   keinen Dauerlesemodus. Kein offener Punkt, sondern eine Festlegung; hier
   aufgeführt, damit niemand sie sucht.

## Nicht übernommen, mit Absicht

* Der erzwungene Aktualisierungshinweis über den Play Store. Der App Store hat kein
  Gegenstück, das ohne Netzzugriff auskommt.
* Die Meldung „NFC ist ausgeschaltet". iOS hat keinen Schalter dafür. Der Text
  bleibt im Katalog, damit die drei Sprachfassungen deckungsgleich bleiben.
* `StoredDocument.cardId` wird nicht mehr gefüllt (siehe Punkt 7), bleibt aber im
  Format — ein unter Android geschriebenes Archiv soll lesbar sein.
