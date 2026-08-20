# Stand

Stand vom **20. August 2026**. Quelle: `cauer71/AndroidDev`, `apps/cie-reader`,
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
| CoreNFC-Sitzung, `EF.CardAccess`, `PACEInfo` zerlegen | gebaut | am Simulator nicht prüfbar |
| Datenschutz-Gegenstücke (Sicherung, Dateischutz, App-Umschalter, Zwischenablage, Netzprüfung) | gebaut | `Scripts/check-no-network.sh` |

60 Tests, `swift test`, alle grün. Die App baut ohne Warnung
(`xcodebuild -target IDReader -sdk iphonesimulator`) und läuft im Simulator.

## Offen

In der Reihenfolge, in der es sich lohnt:

1. **PACE mit CAN** — die gesicherte Verbindung zum Chip, und damit der ganze
   Leseweg. Siehe [NFC-PACE.md](NFC-PACE.md); der Patch für die einzubindende
   Bibliothek steht dort ausformuliert. Bis dahin wirft die App an dieser Stelle
   einen benannten Fehler mit einem Text, der sagt, was fehlt.
2. **Datengruppen und Passive Authentication** — hängt an 1. Die Reihenfolge und
   die Fallen stehen ebenfalls in [NFC-PACE.md](NFC-PACE.md).
3. **JPEG 2000 für DG2** — OpenJPEG einbinden. Bis dahin zeigt die App das erkannte
   Format an der Stelle des Bildes, wie das Original bei einem unbekannten Format.
4. **Die Elastik der Eingabemasken.** Die drei Masken sollen ohne Scrollen auf
   einen Bildschirm passen; Dokumentgrafik und Ziffernblock nehmen ihre Höhe aus
   dem Restplatz, und unter einem Mindestmaß weicht die Grafik ganz. Heute steht
   die Kartenmaske fest und die beiden anderen scrollen. Bei 100 %, 130 % und
   200 % Systemschrift zu prüfen. Die Falle, in die die Compose-Fassung dreimal
   gelaufen ist: in einem scrollenden Vorfahren ist die Höhe unendlich, und dort
   ergibt ein Gewicht null.
5. **App-Icon und Store-Material.** Bisher nur ein Platzhalter.
6. **Die Wiedererkennung einer aufgelegten Karte** entfällt dauerhaft — iOS hat
   keinen Dauerlesemodus. Kein offener Punkt, sondern eine Festlegung; hier
   aufgeführt, damit niemand sie sucht.

## Nicht übernommen, mit Absicht

* Der erzwungene Aktualisierungshinweis über den Play Store. Der App Store hat kein
  Gegenstück, das ohne Netzzugriff auskommt.
* Die Meldung „NFC ist ausgeschaltet". iOS hat keinen Schalter dafür. Der Text
  bleibt im Katalog, damit die drei Sprachfassungen deckungsgleich bleiben.
* `StoredDocument.cardId` wird nicht mehr gefüllt (siehe Punkt 6), bleibt aber im
  Format — ein unter Android geschriebenes Archiv soll lesbar sein.
