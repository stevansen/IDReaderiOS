# Stand

Stand vom **21. August 2026**, nach der Datenminimierung und der Sperrprüfung. Quelle: `cauer71/AndroidDev`, `apps/cie-reader`,
Commit `7ab0d20`, Version 1.8 / versionCode 11.

## Fertig und geprüft

| Bereich | Stand | Nachweis |
|---|---|---|
| Modell (`DocumentData`, `Authenticity`, `DocumentType`, `RecordProvenance`, `AccessKey`, `StoredDocument`) | portiert | |
| `LicenceScan` — Fahrerlaubnis aus erkanntem Text | portiert, Zeile für Zeile | 12 Tests, davon zwei am gemessenen OCR-Korpus |
| `MrzScan` — Prüfziffern nach ICAO 9303 | portiert | 4 Tests |
| `CanScan` — sechs Ziffern, Eindeutigkeit | portiert | 8 Tests |
| `BilingualText` — zweisprachige Orte | portiert | 4 Tests |
| Archivformat (JSON, Version 9) | **nicht mehr bitgleich zur Android-Fassung** — vier Felder fallen weg, ein Personenabdruck kommt hinzu | 4 Tests |
| Archiv (AES-256-GCM, Schlüsselbund, ein Eintrag pro Person, 30 Tage) | portiert | 8 Tests |
| Datenminimierung: Wohnsitz, Steuernummer, Beruf, Telefon werden angezeigt und nicht gespeichert; abschaltbar, vorbelegt an | gebaut | 6 Tests, Schalter und Rückfrage im Simulator durchlaufen |
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
| Lizenz: Apache-2.0 | umgestellt, **Christians Zustimmung fehlt noch** | [LICENCE-CHOICE.md](LICENCE-CHOICE.md) |
| Bedienungshilfen: Schriftgrößen, Vorlesefunktion, Kontrast | geprüft und nachgebessert | [ACCESSIBILITY.md](ACCESSIBILITY.md) |
| Store-Eintrag über die API | Fassung 1.8, Kategorie, Texte und Bilder für `de-DE` und `it` gesetzt; **`en-US` fehlt** | [`../Scripts/asc.swift`](../Scripts/asc.swift), [`../store/README.md`](../store/README.md) |
| Sperrprüfung: CRL lesen, Signatur prüfen, ablegen, offline abgleichen, offene Prüfungen nachholen, Datum am Datensatz | gebaut, **gegen die echte italienische CRL durchlaufen** | 29 Tests; im Simulator geholt, geprüft und angezeigt |

**Fassung 1.8 (Build 2) liegt seit dem 21. August 2026 in App Store Connect**
(Delivery `1b03a02f-6914-4c84-a9d8-3b0fc8f69ab3`), signiert mit
`Apple Distribution`, für TestFlight freigegeben. Build 1 vom
selben Tag ist damit überholt: er kannte weder die Datenminimierung noch die
Sperrprüfung. Die Fassungsnummer bleibt 1.8 — veröffentlicht war Build 1 nie,
also ist dies weiterhin die erste iOS-Auslieferung und nur ein neuer Bau.

Damit ist der Weg auf ein Gerät offen — der Nachweis am Gerät selbst ist Punkt 1
unten. Was ein Tester an Build 2 gegenüber Build 1 prüfen soll: dass beim ersten
Start der Hinweis **erneut** erscheint (Fassung 2, weil der Satz über den
Netzzugriff nicht mehr stimmte), dass bei einem gelesenen Dokument „gelesen,
nicht gespeichert" steht statt einer Anschrift, und dass die Sperrprüfung ein
Datum zeigt statt „noch nicht geprüft".

103 Tests, `swift test`, alle grün. Die App baut ohne eine einzige Warnung im
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
   Die **Support-URL** ist erledigt, seit das Repository öffentlich ist:
   [`../SUPPORT.md`](../SUPPORT.md), dreisprachig und benutzerseitig. Für die
   **Datenschutzerklärung** liegt der Text in
   [`../store/privacy/`](../store/privacy/) und ein Weg, ihn zu veröffentlichen
   (`Scripts/build-privacy-pages.py` → GitHub Pages aus `/docs`); es fehlen zwei
   Handgriffe: Name und Mailadresse des Verantwortlichen ausfüllen — der Generator
   bricht bis dahin ab — und Pages einschalten. Das App-Zeichen ist ein Entwurf
   aus `Scripts/make-app-icon.swift`.
6. **Die Anerkennungen müssen in der App erreichbar sein** — die fremden (MIT für
   NFCPassportReader, Apache-2.0 für OpenSSL) und seit der Umstellung auch die
   eigene: die App steht selbst unter Apache-2.0, und Abschnitt 4(d) will
   `NOTICE` beim Empfänger sehen. „In der Quelltextform oder der Dokumentation"
   genügt dafür, und beides liegt im öffentlichen Repository — aber ein Ort in
   der App wäre der ehrlichere. Es gibt noch keinen.
7. **Die Wiedererkennung einer aufgelegten Karte** entfällt dauerhaft — iOS hat
   keinen Dauerlesemodus. Kein offener Punkt, sondern eine Festlegung; hier
   aufgeführt, damit niemand sie sucht.
8. **Drei CSCA ohne Verteilstelle.** Sechs der neun hinterlegten Zertifikate
   nennen eine Adresse für ihre Sperrliste, drei nicht. Wer von einem der drei
   signiert wurde, ist nicht zu prüfen; der Datensatz sagt dann „für diesen
   Aussteller liegt keine Liste vor". Ob es die drei Listen woanders gibt, ist
   nicht nachgesehen — die BSI-Masterliste enthält Zertifikate, keine CRLs.
9. **Die Sperrprüfung am echten Dokument.** Der Weg ist gegen die echte
   italienische CRL durchlaufen (geholt, Signatur geprüft, abgelegt, verglichen),
   aber der Signierer kam dabei aus Beispieldaten. Am Gerät zu sehen bleibt, dass
   ein echtes Dokumentsignierer-Zertifikat den Ausstellerabdruck einer der sechs
   Listen trifft — trifft es keinen, steht überall „keine Liste für diesen
   Aussteller", und das sähe wie ein Fehler aus, wäre aber die Zuordnung.

## Nicht übernommen, mit Absicht

* Der erzwungene Aktualisierungshinweis über den Play Store. Der App Store hat kein
  Gegenstück, das ohne Netzzugriff auskommt.
* Die Meldung „NFC ist ausgeschaltet". iOS hat keinen Schalter dafür. Der Text
  bleibt im Katalog, damit die drei Sprachfassungen deckungsgleich bleiben.
* `StoredDocument.cardId` wird nicht mehr gefüllt (siehe Punkt 7), bleibt aber im
  Format — die Feldnamen sollen zur Android-Fassung passen, auch wenn Format 9
  nicht mehr bitgleich zu ihr ist.
