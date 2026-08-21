# Migrations-Prompt: CIEreader (Android) → IDReader (iOS)

Dies ist der Prompt, mit dem sich die Migration führen lässt — für einen Agenten
oder für einen Menschen als Auftragsbeschreibung. Er ist zweiteilig: **Teil A**
beschreibt den Auftrag von Anfang an (falls jemand von Null beginnt oder das
Ergebnis gegenprüfen will), **Teil B** ist der Prompt für den Stand, der in
diesem Repository liegt.

Was schon gemacht ist, steht in [`docs/STATUS.md`](docs/STATUS.md). Die
Entscheidungen samt Begründung in
[`docs/ANDROID-TO-IOS.md`](docs/ANDROID-TO-IOS.md).

---

## Teil A — der Auftrag im Ganzen

> Migriere die Android-App **CIEreader** (`cauer71/AndroidDev`, Modul
> `apps/cie-reader`, Kotlin/Compose, ~14 000 Zeilen) auf iOS. Sie liest die
> italienische elektronische Identitätskarte CIE 3.0 und den ePass über NFC
> (PACE, Datengruppen, Passive Authentication, Chip Authentication) sowie den
> italienischen Führerschein aus einem Foto per Texterkennung, und führt ein
> verschlüsseltes Archiv mit 30 Tagen Aufbewahrung.
>
> **Lies zuerst `apps/cie-reader/README.md` vollständig.** Die Datei ist keine
> Übersicht, sondern das Entwurfsdokument: sie begründet fast jede Entscheidung,
> die im Code steht, und nennt die Fallen, in die die Android-Fassung schon
> hineingelaufen ist. Lies danach die Kommentare im Code — sie sind auf Deutsch
> und tragen den eigentlichen Wert des Projekts. Eine Portierung, die den Code
> übersetzt und die Begründungen wegwirft, wirft das Projekt weg.
>
> ### Maßstäbe, in dieser Reihenfolge
>
> 1. **Ein falscher Wert ist schlimmer als ein leeres Feld.** Das ist die Regel,
>    unter der die Führerschein-Erkennung überhaupt zulässig ist, und sie gilt
>    für die ganze App. Jede Abkürzung, die ein Feld „meistens richtig" füllt,
>    ist abzulehnen.
> 2. **Geprüft und ungeprüft dürfen nie gleich aussehen.** Die Trennung von
>    `RecordProvenance` (Chip vs. Foto) und `AuthenticityStatus` (bestanden vs.
>    nicht bestanden vs. *nicht prüfbar*) ist die wichtigste Unterscheidung der
>    App. Ein durchgestrichenes Siegel dort, wo es nie eine Prüfung gab, ist ein
>    Fehler, kein Schönheitsmangel.
> 3. **Nichts verlässt das Gerät von selbst.** Die Android-Fassung entfernt die
>    `INTERNET`-Berechtigung ausdrücklich im Manifest, weil die Zusage im
>    Store-Eintrag und in der Datenschutzerklärung steht. iOS kennt keine solche
>    Berechtigung — also braucht die Zusage hier eine andere Absicherung: kein
>    Netzwerkcode, und ein Prüfschritt, der das durchsetzt.
> 4. **Das Archivformat bleibt.** Gleiche JSON-Schlüssel, gleiche Formatnummer
>    (8), gleicher Datei-Aufbau. Es kostet nichts und macht die beiden Fassungen
>    vergleichbar.
> 5. **Der Wortlaut bleibt.** Alle Texte in Englisch, Deutsch und Italienisch
>    werden übernommen, nicht neu formuliert. Sie sind an Rückmeldungen aus dem
>    geschlossenen Test gefeilt, und der Exporttext landet unverändert in einem
>    Einsatzbericht.
>
> ### Aufbau, den ich erwarte
>
> * `Sources/IDReaderCore/` — ein Swift-Paket ohne UIKit, ohne CoreNFC, ohne
>   SwiftUI. Modell, die drei Parser, Archiv, Export, Lokalisierung. Läuft unter
>   `swift test` auf dem Mac.
> * `Tests/IDReaderCoreTests/` — die Android-Tests portiert, **mit dem
>   gemessenen OCR-Korpus**. Er ist maschinell zu übernehmen, nicht
>   abzuschreiben: die kaputten Zeichen sind der Gegenstand.
> * `App/` — die iOS-App: SwiftUI, CoreNFC, Vision.
> * `IDReader.xcodeproj` — baubar mit `xcodebuild`, ohne Handgriffe in Xcode.
>
> ### Zuordnung Android → iOS
>
> | Android | iOS | Anmerkung |
> |---|---|---|
> | Compose + Material 3 | SwiftUI | Die sechs Farbschemata (Karte/Pass/Führerschein × hell/dunkel) werden Wert für Wert übernommen. |
> | ViewModel + StateFlow | `@Observable` + `@MainActor` | |
> | `NfcAdapter.enableReaderMode` | `NFCTagReaderSession` | **Nicht gleichwertig** — siehe unten. |
> | JMRTD + BouncyCastle | siehe „PACE" unten | |
> | ML Kit `text-recognition` | `VNRecognizeTextRequest` | Modell ist Teil des Systems; kein Bundle-Ballast, kein Netz. |
> | Android Keystore + AES/GCM | CryptoKit `AES.GCM` + Keychain (`…WhenUnlockedThisDeviceOnly`) | |
> | `allowBackup=false`, `dataExtractionRules` | `isExcludedFromBackup` + `.completeFileProtection` | |
> | `setRecentsScreenshotEnabled(false)` | Overlay bei `scenePhase != .active` | |
> | `getQuantityString` / plurals | zwei Formen im Katalog, im Code verzweigt | Englisch, Deutsch und Italienisch brauchen für diese Zählungen dieselben zwei Formen. |
> | Kamera über `ACTION_IMAGE_CAPTURE` (keine CAMERA-Berechtigung) | `UIImagePickerController` **mit** `NSCameraUsageDescription` | Auf iOS nicht zu vermeiden. Im Datenschutztext benennen. |
>
> ### Drei Stellen, an denen iOS nicht kann, was Android kann
>
> Diese sind **nicht** stillschweigend zu umgehen. Sie gehören dokumentiert und
> in der App sichtbar gemacht:
>
> 1. **Kein Dauerlesemodus.** `NFCTagReaderSession` wird vom Benutzer
>    ausgelöst und zeigt ein Systemblatt. Die Android-Fassung erkennt eine
>    aufgelegte Karte im Ruhezustand wieder (`tryRecall` über die Tag-Kennung) —
>    das ist auf iOS nicht möglich, und der Code dafür entfällt.
> 2. **PACE mit CAN.** Der Zugangsschlüssel der CIE ist die aufgedruckte CAN;
>    PACE läuft dabei über **brainpoolP256r1**, und diese Kurve führt CryptoKit
>    nicht. Es gibt genau drei ehrliche Wege: (a) `NFCPassportReader` (MIT) mit
>    einem kleinen Fork für CAN-PACE — der Patch steht in
>    [`docs/NFC-PACE.md`](docs/NFC-PACE.md); (b) OpenSSL direkt einbinden und den
>    Ablauf selbst schreiben; (c) es lassen. Was nicht in Frage kommt: eigene
>    EC-Arithmetik in einer App, die Ausweise liest.
> 3. **JPEG 2000.** DG2 der CIE ist JPEG 2000, und iOS bringt dafür keinen
>    öffentlichen Decoder mit. Bis OpenJPEG eingebunden ist, zeigt die App —
>    genau wie die Android-Fassung bei einem unbekannten Format — das erkannte
>    Format an der Stelle des Bildes, statt stillschweigend nichts zu zeigen.
>
> ### Lizenz und Copyright
>
> Die App ist eine Zusammenarbeit von **Christian Auer** und **Stefan
> Hellweger**. Erzeuge `LICENSE`, `COPYRIGHT`, `NOTICE` und
> `THIRD-PARTY-NOTICES.md` mit gemeinschaftlichem Copyright zu gleichen Teilen
> und mit dem ausdrücklichen Vorbehalt, dass eine Umlizenzierung die Zustimmung
> beider braucht. Halte in `COPYRIGHT` fest, dass die Android-Historie nur einen
> Autor nennt, und warum trotzdem zwei genannt sind.
>
> Beginne **ohne** Lizenzgewährung nach außen — der Android-Ursprung trägt keine,
> und eine erteilte Lizenz nimmt man nicht zurück. Trage dann in einem eigenen
> Papier die Wahl zusammen, mit dem, was sie einschränkt: der App Store schließt
> die GPL-Familie praktisch aus, die mitgelieferten Bibliotheken sind MIT und
> Apache-2.0, und der Name der App ist wertvoller als der Code. Empfiehl, und
> lasse den Menschen entscheiden.
>
> ### Womit ich nicht zufrieden bin
>
> * Ein Port, der die Parser „sinngemäß" nachbaut. Sie werden Zeile für Zeile
>   übernommen und am Korpus gemessen; der Test `findet genug` hält die
>   Trefferquote bei mindestens 69 von 72.
> * Ein Port, der die deutschen Kommentare wegwirft oder zu „// parse date"
>   eindampft.
> * „TODO"-Attrappen, die aussehen wie fertige Funktionen. Was nicht geht, wirft
>   einen benannten Fehler mit einem Text, der sagt, was fehlt.

---

## Teil B — der Prompt für diesen Stand

Für die nächste Sitzung. Kopierbar.

> Im Repository `IDReaderiOS` liegt eine Portierung der Android-App CIEreader
> auf iOS. Sie ist vollständig gebaut — einschließlich PACE mit CAN — und durch 64
> Tests gedeckt (`swift test`). Lies zuerst `docs/STATUS.md`,
> `docs/ANDROID-TO-IOS.md` und `docs/NFC-PACE.md`.
>
> Arbeite die offenen Punkte aus `docs/STATUS.md` in dieser Reihenfolge ab:
>
> 1. **Der Nachweis am Gerät.** Halte eine echte CIE 3.0 an ein iPhone und lass
>    die vier Phasen durchlaufen. Prüfe besonders: der schnelle Weg ohne
>    Lichtbild, das grüne Siegel bei einer echten Karte, und dass eine falsche CAN
>    als „CAN stimmt nicht" ankommt und nicht als „unbekannter Fehler". Ohne
>    diesen Nachweis gilt der Leseweg als gebaut, nicht als geprüft — und das ist
>    ein Unterschied, den diese App an jeder anderen Stelle auch macht.
> 2. **Der Fork statt der Kopie.** `ThirdParty/NFCPassportReaderCAN` ist eine
>    gepatchte Kopie fremden Codes (MIT). Lege einen Fork von
>    `AndyQ/NFCPassportReader` an, setze `UPSTREAM.patch`, binde ihn als
>    Paketverweis ein und lösche die Kopie. Reiche den Patch außerdem nach oben
>    ein — er fügt einen Weg hinzu und nimmt keinen weg.
> 3. **DG2 / JPEG 2000.** Binde OpenJPEG ein (SwiftPM-C-Target) und erweitere
>    `FaceImageDecoder`. Erkenne das Format an den Magic Bytes und nicht am
>    MIME-Typ aus DG2 — der ist auf manchen Karten falsch, das ist unter Android
>    gemessen worden. Sowohl JP2-Container als auch nackter J2K-Codestream.
> 4. **Die Elastik der Eingabemasken.** Die drei Masken sollen ohne Scrollen auf
>    einen Bildschirm passen; Dokumentgrafik und Ziffernblock nehmen ihre Höhe
>    aus dem Restplatz. Unter Compose war die Falle ein scrollender Vorfahr, in
>    dem `weight` null ergibt (dreimal hineingelaufen, siehe README des
>    Originals). Das SwiftUI-Gegenstück ist `ViewThatFits` bzw. eine `GeometryReader`
>    -Messung — prüfe bei 100 %, 130 % und 200 % Systemschrift.
> 5. **App-Icon und Store-Material.** Bisher nur ein Platzhalter.
>
> Halte dabei die Maßstäbe aus Teil A dieses Dokuments ein, besonders den
> ersten. Wenn du an eine Stelle kommst, an der iOS etwas nicht kann, dann
> schreibe das hin, statt es zu umgehen.
