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

## Was noch fehlt, und warum es nur Sie tun können

### 1. Die Bundle-Kennung festlegen

Sie steht derzeit auf **`com.ciereader.IDReader`**, und das ist ein Platzhalter
von mir. **Diese Entscheidung ist praktisch endgültig:** sobald in App Store
Connect ein App-Eintrag damit besteht, lässt sich die Kennung nicht mehr ändern —
eine andere Kennung ist eine andere App, mit eigenem Eintrag und eigenen Testern.

Zu bedenken: die Android-Fassung heißt `com.ciereader.app`. Wenn die App für die
Provinz betrieben wird, gehört sie vielleicht in deren Namensraum. Geändert wird
sie an einer Stelle, in `IDReader.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`, zweimal
— Debug und Release).

### 2. Die App-ID mit der NFC-Berechtigung anlegen

Im Entwicklerportal, unter *Certificates, Identifiers & Profiles → Identifiers*:
eine App-ID mit dieser Kennung, und darin **NFC Tag Reading** einschalten.

Ohne diese Berechtigung lässt sich das Ziel nicht signieren — das ist keine
Fußnote, sondern der Grund, warum ein Bau sonst mit „No profiles for …" abbricht.

Xcode kann die App-ID auch selbst anlegen (`-allowProvisioningUpdates`), aber nur
mit einem angemeldeten Apple-ID-Konto oder einem API-Schlüssel mit ausreichender
Rolle. Auf diesem Rechner ist kein Xcode-Konto angemeldet.

### 3. Den App-Eintrag in App Store Connect anlegen

*Meine Apps → Neue App*: Plattform iOS, die Bundle-Kennung von oben, ein Name
(„IDReader"), Primärsprache. Ohne diesen Eintrag nimmt Apple keinen Upload an.

Der Name muss App-Store-weit eindeutig sein. „IDReader" ist womöglich vergeben;
dann geht auch ein Name mit Zusatz — für einen Test spielt er keine Rolle.

### 4. Die Issuer-ID heraussuchen

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

**Und eine Überlegung, die vor den Store gehört:** wenn die App für eine Behörde
betrieben wird, ist die öffentliche Verteilung vielleicht der falsche Weg. Apple
Business Manager mit einer *Custom App* verteilt an eine benannte Organisation,
ohne Store-Eintrag, ohne Beta-Prüfung und ohne dass jemand sie zufällig lädt und
Ausweise liest. Für ein Werkzeug, das genau das tut, ist das die nähere Form.
