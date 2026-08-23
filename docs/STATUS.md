# Stand

Stand vom **22. August 2026**, nach dem ersten gelungenen Lesevorgang an
echten Dokumenten. Quelle: `cauer71/AndroidDev`, `apps/cie-reader`,
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
| **PACE mit CAN und mit MRZ**, Datengruppen, Passive Authentication, Chip Authentication | **am Gerät nachgewiesen, beide Dokumente, alle vier Stufen** | [NFC-PACE.md](NFC-PACE.md) |
| Urteilsbildung aus den vier Teilprüfungen | portiert | `PassportChipReader.authenticity(from:)` |
| CSCA-Vertrauensanker als PEM-Bündel für die Kettenprüfung | erzeugt | 2 Tests |
| Datenschutz-Gegenstücke (Sicherung, Dateischutz, App-Umschalter, Zwischenablage, Netzprüfung) | gebaut | `Scripts/check-no-network.sh` |
| Lizenz: Apache-2.0 | in **beiden** Repositorien; Christians eigener Beleg fehlt noch | [LICENCE-CHOICE.md](LICENCE-CHOICE.md), [`../COPYRIGHT`](../COPYRIGHT) |
| Bedienungshilfen: Schriftgrößen, Vorlesefunktion, Kontrast | geprüft und nachgebessert | [ACCESSIBILITY.md](ACCESSIBILITY.md) |
| **Lesen am echten Chip** | **geht, mit grünem Siegel für beide Dokumente** — Karte 4,3 s, Reisepass 5,5 s (Bau 21, iPhone 18,2 / iOS 26.6) | [NFC-PACE.md](NFC-PACE.md), [EU-EID-STANDARDS.md](EU-EID-STANDARDS.md), [`../REWORK_PROMPT.md`](../REWORK_PROMPT.md) |
| Store-Eintrag über die API | **vollständig** — drei Sprachen, 21 Bildschirmfotos, Datenschutz-Adresse, Altersfreigabe 4+, Inhalte Dritter, Preis, Gebiete, Händlerangabe | [`../Scripts/asc.swift`](../Scripts/asc.swift), [`../store/README.md`](../store/README.md) |
| Sperrprüfung: CRL lesen, Signatur prüfen, ablegen, offline abgleichen, offene Prüfungen nachholen, Datum am Datensatz | gebaut, **gegen die echte italienische CRL durchlaufen** | 29 Tests; im Simulator geholt, geprüft und angezeigt |

**Fassung 1.8 mit Bau 22 liegt in App Store Connect** und steht den internen
Testern zur Verfügung. Bau 23 ist gebaut und geprüft, aber nicht hochgeladen:
Apple hat das Tageslimit gezogen, nachdem heute fünfzehn Bauten hochgegangen sind
(8 bis 22). Die `.ipa` liegt fertig in `build/export/`.

Fünfzehn Bauten an einem Tag sind keine Auszeichnung. Fünf davon waren je eine
Vermutung zu PACE, drei je eine Vermutung darüber, **wo** die Auskunft über eine
gescheiterte Prüfung landet. Was die Suche entschieden hat, war jedes Mal ein
Instrument und keine Vermutung — erst das APDU-Protokoll, dann die sechs
Übertragungsformen in einem Kartenkontakt, dann die Aufschlüsselung der vier
Echtheitsstufen, dann der festgehaltene Fehler aus dem verworfenen `catch`. Die
Lehre steht in [`../REWORK_PROMPT.md`](../REWORK_PROMPT.md) und ist an einem Tag
zweimal gebraucht worden.

104 Tests, `swift test`, alle grün. Die App baut ohne eine einzige Warnung im
eigenen Code (`xcodebuild -scheme IDReader -sdk iphonesimulator`) und läuft im
Simulator.

## Offen

In der Reihenfolge, in der es sich lohnt:

1. **Christian Auers eigener Beleg für Apache-2.0.** Die Lizenzdateien liegen in
   beiden Repositorien, aber **beide** Festschreibungen im Android-Repository sind
   von Stefan Hellweger verfasst (`447a8f6`, `94369bb`). Kein Artefakt in einem
   der beiden ist von Christian. Eine Festschreibung von ihm oder ein Wort in
   einem Issue, mit Datum, schließt das; `AndroidDev/COPYRIGHT` trägt in der
   Zustimmungstabelle noch die Platzhalter, die dafür angelegt wurden.

2. **Der Fork statt der Kopie.** `ThirdParty/NFCPassportReaderCAN` ist eine
   gepatchte Kopie fremden Codes. Sauberer wäre ein Fork unter eigener Adresse als
   Paketverweis; der Patch liegt dafür bereit und ist auch als Beitrag nach oben
   brauchbar.
3. ~~JPEG 2000 für DG2 — OpenJPEG einbinden~~ — **entfällt.** Gemessen unter
   Bau 23: DG2 ist auf Karte und Pass `image/jp2`, rund 10 KB, und **ImageIO liest
   es** — das Lichtbild wird angezeigt und verschlüsselt aufbewahrt. Die
   Gegenbehauptung stand in fünf Dateien, darunter in der Datenschutzerklärung und
   in der Store-Beschreibung, und stammte aus einem Schluss: die Android-Fassung
   bindet OpenJPEG ein, *also* kann iOS es auch nicht. Alle Stellen berichtigt.

   Der Zweig für ein nicht lesbares Format bleibt: welche Formate ImageIO kann,
   ist eine Eigenschaft des Betriebssystems und keine Zusage.
4. **Die Elastik der Eingabemasken.** Die drei Masken sollen ohne Scrollen auf
   einen Bildschirm passen; Dokumentgrafik und Ziffernblock nehmen ihre Höhe aus
   dem Restplatz, und unter einem Mindestmaß weicht die Grafik ganz. Heute steht
   die Kartenmaske fest und die beiden anderen scrollen. Bei 100 %, 130 % und
   200 % Systemschrift zu prüfen. Die Falle, in die die Compose-Fassung dreimal
   gelaufen ist: in einem scrollenden Vorfahren ist die Höhe unendlich, und dort
   ergibt ein Gewicht null.
5. **Store-Material: erledigt.** Drei Sprachen, 21 Bildschirmfotos, Beschreibung,
   Stichworte, Support- und Datenschutz-Adresse, Altersfreigabe, Inhalte Dritter,
   Preis, Gebiete, Händlerangabe — alles über die Schnittstelle gesetzt und dort
   nachgelesen. GitHub Pages braucht es nicht: die Datenschutz-Adresse zeigt auf
   die Fassung im Repository, und die Erklärungen kommen **ohne Kontaktadresse**
   aus, weil der Entwickler keine Daten verarbeitet und damit nicht
   Verantwortlicher ist — begründet in [`../store/README.md`](../store/README.md).
   Das App-Zeichen ist weiterhin ein Entwurf aus `Scripts/make-app-icon.swift`.

   Was noch offen ist, ist eine Entscheidung und kein Handgriff: im englischen
   Store heißt der Eintrag „CIE Reader", weil `IDReader` für `en-US` belegt ist —
   auf jedem Bildschirmfoto steht aber „IDReader". Zwei Namen für eine App, und
   zu ändern nur mit einem zweiten Anzeigenamen im Bundle.
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
9. **Ein Durchgang mit eingeschaltetem VoiceOver am Gerät.** Danach kann die
   Bedienungshilfen-Erklärung im Store vom Entwurf in die Veröffentlichung; heute
   ist sie absichtlich Entwurf, weil eine Zusage über die Vorlesefunktion, die
   niemand gehört hat, genau der Fehler wäre, den
   [ACCESSIBILITY.md](ACCESSIBILITY.md) anderen vorwirft.
10. **Die Sperrprüfung am echten Dokument.** Der Weg ist gegen die echte
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
