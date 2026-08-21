# Auf das Gerät kommen: TestFlight

Für den ersten Test auf einem echten iPhone — mit einer echten CIE 3.0, was der
Punkt ist, an dem der Leseweg zum ersten Mal etwas beweist.

## Was schon da ist

Auf diesem Rechner geprüft:

| | |
|---|---|
| Entwicklerteam | `JF8N3J347R` (Stefan Hellweger) |
| Verteilungszertifikat | `Apple Distribution: Stefan Hellweger (JF8N3J347R)` ✓ |
| App-Store-Connect-Schlüssel | `AuthKey_D5BM7BM3H5.p8` in `~/.appstoreconnect/private_keys/` ✓ |
| App-Zeichen 1024×1024 | ✓ (Entwurf, siehe unten) |
| Datenschutzangabe `PrivacyInfo.xcprivacy` | ✓ |
| Gerätebau für arm64, Release | ✓ ohne Warnung |
| Fassung / Build | 1.8 / 1 |
| App-ID `com.ciereader.ios` mit **NFC Tag Reading** | ✓ — am signierten Bundle geprüft |
| Verteilungsfertige `.ipa` | ✓ 4,2 MB, `Apple Distribution`, `get-task-allow = false`, `beta-reports-active = true` |
| OpenSSL im Bundle | ✓ 3.6.3, arm64, brainpoolP256r1 vorhanden |

Der Archivlauf hat die Berechtigung dabei selbst bestätigt: ohne **NFC Tag
Reading** an der App-ID wäre er an der Signatur gescheitert, und die fertige
`.ipa` trägt `com.apple.developer.nfc.readersession.formats = ["TAG"]`.

## Was noch fehlt, und warum es nur Sie tun können

### 1. Die App-ID mit der NFC-Berechtigung anlegen

Die Bundle-Kennung ist **`com.ciereader.ios`** — festgelegt und im Projekt
gesetzt, in der Familie der Android-Fassung (`com.ciereader.app`), mit `.ios` als
Platz für weitere Apple-Plattformen unter demselben Namen. Ab dem ersten
App-Eintrag in App Store Connect ist sie nicht mehr zu ändern.

Im Entwicklerportal, unter *Certificates, Identifiers & Profiles → Identifiers*:
eine App-ID mit dieser Kennung, und darin **NFC Tag Reading** einschalten.

Ohne diese Berechtigung lässt sich das Ziel nicht signieren — das ist keine
Fußnote, sondern der Grund, warum ein Bau sonst mit
„No profiles for 'com.ciereader.ios' were found" abbricht.

Xcode kann die App-ID auch selbst anlegen (`-allowProvisioningUpdates`), aber nur
mit einem angemeldeten Apple-ID-Konto oder einem API-Schlüssel mit ausreichender
Rolle. Auf diesem Rechner ist kein Xcode-Konto angemeldet.

### 2. Den App-Eintrag in App Store Connect anlegen

*Meine Apps → Neue App*. Ohne diesen Eintrag nimmt Apple keinen Upload an.

| Feld | Wert |
|---|---|
| Plattform | iOS |
| Bundle-Kennung | `com.ciereader.ios` |
| SKU | `CIEREADER-IOS-001` |
| Name | „IDReader" |
| Primärsprache | Deutsch |

Zur **SKU**: sie ist nur intern, kein Nutzer sieht sie je — aber sie ist
**endgültig**, wie die Bundle-Kennung. `CIEREADER` hält die Verbindung zur
Android-Fassung, `IOS` trennt von einem möglichen Mac- oder iPad-Eintrag, und
`001` ist die Reserve: eine falsch gesetzte Bundle-Kennung lässt sich nicht
ändern, ein neuer Eintrag braucht dann eine neue SKU, und `-002` ist besser als
sich etwas ausdenken zu müssen.

Bewusst nicht die Bundle-Kennung als SKU, obwohl das verbreitet ist: App Store
Connect zeigt beide Felder in Berichten, und bei gleichem Wert sieht man nicht
mehr, welches man vor sich hat.

Der **Name** muss App-Store-weit eindeutig sein. „IDReader" ist womöglich
vergeben; dann geht ein Zusatz wie „IDReader CIE" — für einen Test spielt er
keine Rolle, und ändern lässt er sich später.

### 3. Die Issuer-ID heraussuchen

*Benutzer und Zugriff → Integrationen → App Store Connect API*. Sie sieht aus wie
`69a6de70-xxxx-xxxx-xxxx-xxxxxxxxxxxx` und ist kein Geheimnis, nur eine Kennung —
der eigentliche Schlüssel ist die `.p8`-Datei, und die liest `altool` selbst.

## Dann läuft es in zwei Befehlen

```bash
Scripts/archive.sh
```

```bash
ASC_ISSUER_ID=<Ihre-Issuer-ID> Scripts/upload.sh
```

Das erste Skript prüft die Netzzusage, lässt die Tests laufen, archiviert und
exportiert die `.ipa`. Das zweite prüft und lädt hoch. Getrennt, weil ein Archiv
zu bauen harmlos ist und ein Upload eine Veröffentlichung an Apple.

Jeder Upload braucht eine **höhere Buildnummer** als der vorige — auch nach dem
Löschen des alten. `Scripts/archive.sh 2` setzt sie.

## Die Frage, die Apple beim Upload stellt

**Ausfuhrmeldung.** In `Config/Info.plist` stand `ITSAppUsesNonExemptEncryption =
false`, solange die App für ihr Archiv nur CryptoKit benutzte — dann greift die
Ausnahme „ausschließlich Verschlüsselung des Betriebssystems".

Seit PACE eingebaut ist, liegt **OpenSSL 3** mit im Bundle. Damit ist diese
Ausnahme weg, und der Schlüssel steht bewusst nicht mehr in der Datei: App Store
Connect fragt bei jedem Upload nach, und die Frage soll bewusst beantwortet
werden statt von einer Zeile, die vor dem Einbau geschrieben wurde.

Für einen Test im eigenen Team genügt die Antwort im Dialog. Vor einer
öffentlichen Verteilung zu klären — und das ist eine Rechtsfrage, keine
Programmierfrage:

* greift die Ausnahme für massenmarktgängige Software (5D992.c)?
* ist der Jahresbericht an die BIS fällig?
* braucht Frankreich eine eigene Erklärung?

## Intern oder extern testen

* **Intern** (bis 100 Personen aus dem eigenen Team): keine Beta-Prüfung, der
  Build steht nach der Verarbeitung sofort bereit. **Der Weg für diesen Test.**
* **Extern** (bis 10 000 Tester): Apple prüft den ersten Build einer Fassung. Dann
  braucht es zusätzlich eine Datenschutzerklärung im Netz, eine
  Beschreibung, was zu testen ist, und eine Begründung, wozu die App NFC braucht.

## Was die Tester wissen müssen

Sonst kommen Fehlermeldungen zurück, die keine sind:

* **NFC gibt es nur auf einem echten iPhone.** Im Simulator meldet die App „Kein
  NFC verfügbar", und das ist richtig.
* **Es braucht eine echte CIE 3.0** und ihre aufgedruckte CAN (sechs Ziffern,
  Vorderseite unten rechts). Eine ältere CIE ohne PACE meldet die App als solche.
* **Das Lichtbild bleibt vorerst leer.** DG2 der CIE ist JPEG 2000, und iOS bringt
  dafür keinen Decoder mit; die App zeigt statt des Bildes das erkannte Format an.
  Das ist ein offener Punkt und kein Fehler — siehe [STATUS.md](STATUS.md).
* **Der Leseweg ist noch nie gegen eine Karte gelaufen.** Genau darum geht dieser
  Test. Was besonders interessiert: laufen die vier Phasen durch, kommt bei einer
  echten Karte das grüne Siegel, und meldet eine falsche CAN „CAN stimmt nicht"
  und nicht „unbekannter Fehler"?
* Bildschirmfotos sind absichtlich möglich — genau dafür, damit Rückmeldungen
  belegt werden können. Dieselbe Abwägung wie in der Android-Fassung.

## Was für eine öffentliche Verteilung noch fehlt

Für den Test nicht nötig, für den Store schon:

* Ein **App-Zeichen, das jemand entworfen hat.** Das jetzige ist ein Entwurf von
  mir, aus `Scripts/make-app-icon.swift` gezeichnet.
* Bildschirmfotos und die Store-Texte. Für Deutsch liegt die Android-Fassung vor:
  `apps/cie-reader/store/listing-de-DE.txt` im Android-Repository.
* Eine **Datenschutzerklärung im Netz.** Auch dafür gibt es die Vorlage:
  `apps/cie-reader/store/privacy-policy-{de,en,it}.md`. Sie ist zu überarbeiten —
  auf iOS braucht die App die **Kamera-Berechtigung**, die die Android-Fassung
  nicht braucht, und das gehört hinein.
* Die Datenschutzangaben im App-Store-Eintrag („App Privacy"). Die Antwort ist
  kurz: es wird nichts erhoben. `App/PrivacyInfo.xcprivacy` sagt dasselbe.
* Die **Lizenzfrage** aus [`../LICENSE`](../LICENSE) und
  [`../COPYRIGHT`](../COPYRIGHT), und die Bestätigung der Miturheberschaft.
* Die Anerkennungen für **MIT (NFCPassportReader)** und **Apache-2.0 (OpenSSL)**
  müssen in der App erreichbar sein. Es gibt noch keinen Ort dafür — siehe
  [`../THIRD-PARTY-NOTICES.md`](../THIRD-PARTY-NOTICES.md).

## Preis: kostenlos

Festgelegt. In App Store Connect unter *Preise und Verfügbarkeit* → **Kostenlos**,
ohne In-App-Käufe. Für TestFlight ist das gleichgültig — Testbuilds sind für
Tester immer kostenlos —, es greift erst beim Store.

Bemerkenswert ist daran, dass die App das nicht nur behauptet, sondern **nicht
anders kann**: es gibt kein StoreKit, keine Werbung, keine Messtechnik und keinen
Netzzugriff, und `Scripts/check-no-network.sh` hält das so. Bei einer kostenlosen
App ist die nächste Frage sonst immer, womit sie stattdessen bezahlt wird; hier
lautet die Antwort: mit nichts. Dasselbe sagen die Datenschutzangaben — **Data Not
Collected** — und `App/PrivacyInfo.xcprivacy`.

Nicht zu verwechseln: **kostenlos ist nicht dasselbe wie offen.** Der Quelltext
steht weiterhin unter „alle Rechte vorbehalten"
([`../LICENSE`](../LICENSE)); wer die App gratis lädt, bekommt sie nicht
lizenziert. Das sind zwei Entscheidungen, und nur die erste ist getroffen.

## Öffentlich verteilt: was das heißt

Die App geht als Werkzeug an jeden, der sie lädt. Das ist keine neue Haltung,
sondern die der Android-Fassung: deren erster Bildschirm nennt **die
Verantwortung und nicht die Norm**, gerade weil die App nicht wissen kann, unter
welchen Regeln ein bestimmter Leser arbeitet. Auf iOS bleibt das so, und der
Hinweis beim ersten Start ist auch hier die Antwort darauf.

Praktisch folgt daraus dreierlei:

* **App Review wird nach der NFC-Nutzung fragen** — wozu die App Chips liest und
  was mit den Daten passiert. Die Antwort ist kurz und steht schon geschrieben:
  nichts verlässt das Gerät, das Archiv löscht sich nach 30 Tagen,
  `Scripts/check-no-network.sh` setzt das durch. Verweisen kann man auf
  [DATA-PROTECTION.md](DATA-PROTECTION.md).
* **Die Datenschutzerklärung im Netz ist Pflicht**, nicht optional. Vorlage:
  `apps/cie-reader/store/privacy-policy-{de,en,it}.md` im Android-Repository —
  zu überarbeiten, weil auf iOS die **Kamera-Berechtigung** dazukommt.
* **Externe Tester bedeuten Beta-Prüfung.** Für den ersten Test aus dem eigenen
  Team fällt sie weg; sobald jemand von außen dazukommt, prüft Apple den ersten
  Build einer Fassung.

Die Datenschutzangaben im Eintrag („App Privacy") sind dagegen schnell erledigt:
**Data Not Collected.** `App/PrivacyInfo.xcprivacy` sagt dasselbe, und beides ist
richtig, weil die App keinen Netzzugriff hat.
