# Android → iOS: was wurde wie ersetzt, und warum

Nachschlagewerk zur Portierung von **CIEreader** (`cauer71/AndroidDev`, Modul
`apps/cie-reader`, Version 1.8 / versionCode 11, Commit `7ab0d20`) nach
**IDReader** für iOS.

Die Regel dabei war: Verhalten und Wortlaut bleiben, die Mechanik wird
ausgetauscht. Wo iOS etwas nicht kann, steht das hier und nicht in einem
Kommentar, den niemand liest.

> **Der Name bleibt „CIEreader".** Die Android-App heißt seit dem 2. September
> 2026 im Anzeigenamen **CIEscan** (`64468c3`); ihre Kennung ist weiterhin
> `com.ciereader.app`, und `NOTICE` und `COPYRIGHT` dort nennen sie weiterhin
> CIEreader. Auf der iOS-Seite wird **nicht** nachgezogen — entschieden am
> 4. September 2026. Wer „CIEreader" hier findet, hat also keine veraltete Stelle
> gefunden, sondern eine Festlegung. Das betrifft zwölf Stellen, darunter den
> Über-Bildschirm der App, `NOTICE`, `COPYRIGHT`, `README.md` und die
> Was-ist-neu-Texte im Store.

---

## Schichten

| Android | iOS | Anmerkung |
|---|---|---|
| `apps/cie-reader/src/main/java/…/data/` | `Sources/IDReaderCore/` | Ein eigenes Swift-Paket ohne UIKit, CoreNFC und SwiftUI. Läuft unter `swift test` auf dem Mac — das war unter Android die Absicht hinter „`LicenceScan` ist reiner Text zu Feldern", hier ist es erzwungen. |
| `…/ui/` (Compose) | `App/UI/` (SwiftUI) | |
| `…/nfc/` (JMRTD + BouncyCastle) | `ThirdParty/NFCPassportReaderCAN` + Adapter in `App/NFC/` | siehe [NFC-PACE.md](NFC-PACE.md) |
| `src/test/` (JUnit) | `Tests/IDReaderCoreTests/` (swift-testing) | 64 Tests, darunter der **unverändert übernommene** OCR-Korpus. |

## Bausteine

| Android | iOS | Warum so |
|---|---|---|
| Compose + Material 3 | SwiftUI, eigene Palette | Die sechs Farbschemata (Karte/Pass/Führerschein × hell/dunkel) sind Wert für Wert übernommen. Material-Rollennamen sind beibehalten (`primaryContainer`, `surfaceContainerLowest`, …), damit sich beide Fassungen gegeneinander halten lassen. |
| `AndroidViewModel` + `StateFlow` | `@MainActor @Observable ReaderModel` | Dieselbe Aufteilung: der Zustand liegt außerhalb der Ansichten, weil die Kamera die App in den Hintergrund schiebt. |
| `Modifier.weight` | `WeightedRow` (eigenes `Layout`) | `layoutPriority` ist **nicht** das Gegenstück — es entscheidet, wer zuerst gekürzt wird, nicht über Anteile. Am Gerät gesehen: die beiden schmalen Abschnitte des Umschalters gingen auf null, nur „Führerschein" blieb stehen. |
| `getQuantityString` / `plurals.xml` | zwei Formen im Katalog, im Code verzweigt | Englisch, Deutsch und Italienisch brauchen für diese Zählungen dieselben zwei Formen. Ein `.stringsdict` wäre dreimal derselbe XML-Baum, den kein Test erreicht. |
| eigener `ContextWrapper` für die Sprache | `Strings(language:)` mit `Bundle.module` je `.lproj` | Dasselbe Problem, dieselbe Lösung: ein **benannter** Katalog statt der Prozesssprache, weil derselbe Text auch den Export baut. |
| ML Kit `text-recognition` (gebündeltes Modell) | `VNRecognizeTextRequest` | Vision ist Teil des Systems: kein Modell im Bundle, keine fremde Bibliothek, kein Netz. `usesLanguageCorrection = false` ist dabei kein Detail — eine Sprachkorrektur macht aus `U1974B315M` ein Wort, das sie kennt. |
| JMRTD + BouncyCastle + SpongyCastle-Notiz | NFCPassportReader (gepatcht) + OpenSSL 3 | Dieselbe Abwägung wie im Original: die MRTD-Schicht wird nicht selbst geschrieben. Der Patch fügt PACE mit CAN hinzu, das die Fassung oben ausdrücklich nicht kennt. |
| `dev.keiji.jp2:jp2-android` (OpenJPEG) | **entfällt** | iOS bringt für JPEG 2000 einen Decoder mit — am Gerät gemessen, iOS 26.6: DG2 von Karte und Pass ist `image/jp2` und ImageIO liest es. Die Android-Fassung braucht die Bibliothek, weil Android es nicht kann; hier ist sie unnötig. `FaceImageDecoder` erkennt das Format weiterhin an den Magic Bytes und zeigt es an der Stelle des Bildes an, wenn es sich **nicht** lesen lässt — derselbe Umgang wie im Original bei einem unbekannten Format. |
| Material Symbols als Vektor-Drawables | SF Symbols | `checkmark.seal.fill` / `xmark.seal.fill`. Die Notiz über `viewBox="0 -960 960 960"` im Original wird damit gegenstandslos. |
| Play Core `app-update-ktx` | — | Der App Store hat kein Gegenstück, das ohne Netzzugriff auskommt. |

## Datenschutz: dieselben Zusagen, andere Mittel

| Zusage | Android | iOS |
|---|---|---|
| Archiv verschlüsselt, Schlüssel verlässt das Gerät nicht | Android Keystore, `setUnlockedDeviceRequired(true)` | CryptoKit `AES.GCM`, Schlüssel im Schlüsselbund mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| nicht in der Sicherung | `allowBackup=false`, `dataExtractionRules` | `isExcludedFromBackup` **und** `.completeFileProtection` |
| kein Abbild im App-Umschalter | `setRecentsScreenshotEnabled(false)` | Overlay bei `scenePhase != .active` |
| Bildschirmfoto bleibt möglich | bewusst kein `FLAG_SECURE` | bewusst kein Blenden über den ganzen Bildschirm |
| Zwischenablage nicht in der Systemvorschau | `EXTRA_IS_SENSITIVE` (ab Android 13) | `expirationDate` nach zwei Minuten — iOS kennt keine Kennzeichnung „vertraulich" |
| **überträgt nichts** | `INTERNET` im Manifest ausdrücklich entfernt | `Scripts/check-no-network.sh`: es gibt hier keine Berechtigung zu entfernen, also sucht ein Prüfschritt nach allem, womit sich senden ließe |
| Anhang ohne Datei im Cache | `FileProvider` + Ordner vor jedem Versand leeren | `MFMailComposeViewController` nimmt die Bytes unmittelbar an — der ganze Umgang entfällt |

### Der Archivschlüssel: warum nicht die Secure Enclave

Das nächstliegende Gegenstück zum Android-Keystore wäre die Secure Enclave. Die
führt aber nur EC-Schlüssel (P-256), also müsste der eigentliche Datenschlüssel
damit erst umhüllt und die Hülle daneben gelegt werden: zwei Schlüssel, zwei
Fehlerfälle, ein Verfahren mehr zu prüfen.

Der Schlüsselbund mit `…WhenUnlockedThisDeviceOnly` gibt, worauf es ankommt: nie
gesichert, nie auf ein anderes Gerät übertragen, nur bei entsperrtem Gerät zu
haben. Die Umhüllung bleibt der nächste Schritt, sobald jemand ein Angriffsmodell
nennt, in dem sie etwas hinzufügt.

## Drei Stellen, an denen iOS weniger kann

Nicht Auslassungen, sondern Eigenschaften der Plattform:

1. **Kein Dauerlesemodus.** `NFCTagReaderSession` wird ausdrücklich gestartet und
   zeigt ein Systemblatt. Der Weg der Android-Fassung, eine aufgelegte Karte im
   Ruhezustand wiederzuerkennen (`tryRecall` über die Tag-Kennung), ist auf iOS
   nicht möglich; der Code dafür entfällt. Das Nachschlagen über die eingetippte
   CAN bleibt und ist im Einsatz ohnehin der häufigere Fall. `StoredDocument.cardId`
   bleibt im Modell, damit ein unter Android geschriebenes Archiv lesbar ist.
2. **Keine Frage „ist NFC eingeschaltet?"** iOS hat keinen Schalter dafür. Nur
   „das Gerät kann es" oder „kann es nicht". Die Meldung „NFC ist ausgeschaltet"
   kommt deshalb nie vor; der Text bleibt im Katalog, damit die drei
   Sprachfassungen deckungsgleich bleiben.
3. **Die Kamera braucht eine Berechtigung.** Die Android-Fassung fotografiert über
   die Kamera-App des Systems und bleibt dadurch bei NFC als einziger
   Berechtigung — eine Aussage, die im Store-Eintrag steht. Auf iOS gibt es diesen
   Weg nicht: `NSCameraUsageDescription` ist Pflicht. Das gehört in den
   Store-Eintrag und in die Datenschutzerklärung, statt es zu verschweigen.

## Nebenläufigkeit: warum das App-Ziel Swift 5 fährt

`Sources/IDReaderCore` läuft im **Swift-6-Sprachmodus** mit vollständiger
Nebenläufigkeitsprüfung. Dort sitzt die Logik, dort ist die Prüfung ihr Geld wert,
und dort ist sie erfüllt — ohne ein einziges `@unchecked`, das nicht begründet ist.

Das App-Ziel steht auf `SWIFT_VERSION = 5.0` mit `SWIFT_STRICT_CONCURRENCY =
targeted`. Der Grund ist CoreNFC: `NFCTagReaderSession` und `NFCISO7816Tag` sind
nicht als `Sendable` gekennzeichnet, ihre Zusagen tragen keine Faden-Angabe, und
ihre `async`-Aufrufe sind `nonisolated`. Unter vollständiger Prüfung ergibt jeder
Lesevorgang eine Handvoll „sending value of non-Sendable type"-Fehler, die sich
nur mit Umhüllungen erledigen lassen, die nichts absichern — die Objekte werden
ohnehin nur aus einem Ablauf angesprochen.

Was stattdessen getan ist, und was mehr wert ist als die abgeschaltete Prüfung:
der ganze Leseweg liegt auf `@MainActor` (die Sitzung wird mit `queue: .main`
angelegt), und die Zusagen sind `nonisolated` mit `MainActor.assumeIsolated` —
das schreibt hin, was tatsächlich gilt. Sobald Apple CoreNFC annotiert, ist die
Zeile in `IDReader.xcodeproj` zu löschen und der Rest bleibt, wie er ist.

## Was Zeile für Zeile übernommen wurde

Und damit auch die Begründungen in den Kommentaren — sie sind der eigentliche
Wert dieses Projekts:

* `LicenceScan` — die ringweise Verteilung, die Formprüfungen, die
  Zeichen-Rückdrehungen, die Alles-oder-nichts-Regel bei den Klassen. Gemessen am
  Korpus: die Trefferquote ist dieselbe wie unter Android (Test `findet genug`,
  Untergrenze 69 von 72).
* `MrzScan` — Prüfziffern nach ICAO 9303, kein Reparaturversuch.
* `CanScan` — Eindeutigkeit als einziges belastbares Merkmal.
* `BilingualText` — der Schrägstrich, der keine Hausnummer zerlegt.
* `DocumentExport` — Spaltenbreite aus den vorkommenden Beschriftungen, die
  JSON-Feldnamen des Importskripts, `birthdate` nur wenn es wirklich ISO ist.
* Das Verhalten bei „ein Eintrag pro Person", einschließlich der Regel, dass die
  neu ausgestellte Karte gewinnt.

Und eine Stelle, an der die Fassungen **auseinandergehen**: das Archivformat. Es
war bitgleich (Version 8); mit dem Durchgang zur Datenminimierung steht iOS auf
**Version 9** — Wohnsitz, Steuernummer, Beruf und Telefon werden nicht mehr
abgelegt, dafür der Abdruck des Personenschlüssels und die Liste der
weggelassenen Felder. Das kostet die Vergleichbarkeit und war es wert: ein
Archiv, das eine Steuernummer nicht enthält, kann sie auch nicht verlieren. Die
Android-Fassung sollte dieselbe Änderung bekommen.
* Der Hinweis beim ersten Start, einschließlich der Reihenfolge seiner drei Punkte
  und der Fassungsnummer.

## Das Systemblatt sprach Englisch — und von einem „passport"

Gefunden am 8. September 2026 in zwei Videos, die für App Review gefilmt wurden.
Nicht in einem Test, nicht im Quelltext: **auf dem Bildschirm eines Geräts.**

Während der NFC-Sitzung legt iOS ein eigenes Blatt über die ganze App. Die
Überschrift kommt vom System und ist übersetzt („Bereit zum Scannen"). Der Satz
darunter kommt von der Lesebibliothek:

```
Bereit zum Scannen
Hold your iPhone near an NFC enabled passport.
```

Zwei Fehler in einer Zeile: **englisch** in einer deutsch eingestellten App, und
**„passport"**, während eine Identitätskarte auflag.

Die Ursache war eine einzige Zeile in `PassportChipReader`:

```swift
customDisplayMessage: { message in
    onProgress(PassportChipReader.step(for: message))
    return nil          // ← „nimm deinen eigenen Text"
}
```

`nil` heißt: die Bibliothek nimmt ihre eigene Zeichenkette. Sie ist auf Englisch
fest eingebaut und redet in jeder ihrer sechs Meldungen von einem Pass — das
Projekt heißt `NFCPassportReader`, und für seinen Zweck ist das richtig.

### Was jetzt dort steht

Der Text kommt von außen herein, aus `ReaderModel`, weil nur dort die Sprache
und die **gewählte Dokumentart** bekannt sind:

| Stufe | Text |
|---|---|
| wartet auf das Dokument | `step_tap_card` / `step_tap_passport` — „Karte hinten ans Handy halten" bzw. „Pass …" |
| Verbindung | `phase_connect` |
| gesicherte Verbindung | `phase_secure` |
| Datengruppen | `phase_data` |
| Prüfung | `phase_verify` |
| Fehler | `error_title` |

**Keine neuen Texte.** Es sind dieselben sechs, die hinter dem Blatt auf dem
Lesescreen stehen, und das ist kein Zufall, sondern der Punkt: eine zweite
Wortwahl für denselben Vorgang wäre für den Bediener nur Verwirrung.

Der Fehlerfall hat dabei einen eigenen Typ bekommen (`NFCSheetStage`). Grund:
`step(for:)` bildet die Fehlermeldung auf `ReadStep.verifying` ab, weil es dafür
keinen eigenen Schritt gibt. Auf dem Fortschrittsbalken ist das harmlos — auf
dem Systemblatt stünde „Echtheit prüfen", während gerade nichts mehr geprüft
wird. Genau der Fehlertyp, der diese Woche mehrfach Zeit gekostet hat: eine
Anzeige, die im Normalfall stimmt und im Fehlerfall in die Irre führt.

### Der Zusammenhang mit der Ablehnung

Apple beanstandete unter Richtlinie 4 „permissions requests that are not written
in the same language as the app's localization". Belegt und behoben sind die
Berechtigungstexte (`InfoPlist.strings`, Bau 25). **Dieses Blatt ist der zweite
Kandidat für dieselbe Beanstandung** und war in Bau 25 noch drin.

## Das italienische Register ist absichtlich gemischt

> **Bitte nicht „vereinheitlichen".** Die Regel steht auch im Kopf von
> `Sources/IDReaderCore/Resources/it.lproj/Localizable.strings`, damit sie sieht,
> wer die Datei ändert.

| | Register | Beispiele |
|---|---|---|
| Knöpfe und kurze Anweisungen | **Imperativ**, 2. Person | „Riprova", „Inserisci", „Fotografa la carta", „Appoggia la carta sul retro del telefono" |
| Fließtext | **Sie-Form** | „Dica brevemente…", „Decide lei", „Esce dal dispositivo solo se lo copia e lo incolla lei." |

Der Imperativ ist kein Versehen: es ist der Stil, den **Apple im italienischen
iOS selbst verwendet** — „Riprova", „Annulla", „Consenti". Italienische Benutzer
erwarten ihn an Knöpfen, und die Sie-Form wirkt dort steif. Umgekehrt wäre ein
geduzter Fließtext in einer App, die Ausweise liest, unpassend.

Am 8. September 2026 habe ich drei Texte auf die Sie-Form gebracht, weil ich das
Gemisch für eine Uneinheitlichkeit hielt. Eine der drei Änderungen war richtig
(`settings_diagnostics_hint`, Fließtext); die beiden anderen waren
Fehlermeldungen mit kurzer Anweisung und sind zurückgestellt. Entschieden am
8. September 2026.

