# Auf das Gerät kommen: TestFlight

Für den ersten Test auf einem echten iPhone — mit einer echten CIE 3.0, was der
Punkt ist, an dem der Leseweg zum ersten Mal etwas beweist.

## Was schon da ist

Auf diesem Rechner geprüft:

| | |
|---|---|
| Entwicklerteam | `JF8N3J347R` (Stefan Hellweger) |
| Verteilungszertifikat | `Apple Distribution: Stefan Hellweger (JF8N3J347R)` ✓ |
| App-Store-Connect-Schlüssel | vorhanden in `~/.appstoreconnect/private_keys/` ✓ (Kennung steht nicht im Repository) |
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

### 3. Schlüssel- und Issuer-Kennung heraussuchen

*Benutzer und Zugriff → Integrationen → App Store Connect API*. Beide stehen dort;
keine von beiden liegt im Repository, weil es öffentlich ist. Für sich allein sind
sie nutzlos — der eigentliche Schlüssel ist die `.p8`-Datei, und die liest `altool`
selbst.

## Dann läuft es in zwei Befehlen

```bash
Scripts/archive.sh
```

```bash
ASC_KEY_ID=<Schlüsselkennung> ASC_ISSUER_ID=<Issuer-ID> Scripts/upload.sh
```

Das erste Skript prüft die Netzzusage, lässt die Tests laufen, archiviert und
exportiert die `.ipa`. Das zweite prüft und lädt hoch. Getrennt, weil ein Archiv
zu bauen harmlos ist und ein Upload eine Veröffentlichung an Apple.

Jeder Upload braucht eine **höhere Buildnummer** als der vorige — auch nach dem
Löschen des alten. `Scripts/archive.sh 2` setzt sie.

## Die Frage, die Apple beim Upload stellt

**Ausfuhrmeldung.** Die Antwort auf „Welche Art von Verschlüsselungsalgorithmus
verwendest du?" ist **„Standardmäßige Verschlüsselungsalgorithmen statt oder
zusätzlich zu der im Betriebssystem von Apple verwendeten bzw. zugänglichen
Verschlüsselung"** — seit OpenSSL für PACE mit im Bundle liegt.

Die Bestandsaufnahme dazu, Verfahren für Verfahren und mit der Trennung zwischen
Apples Kryptografie und OpenSSL, steht in
[EXPORT-COMPLIANCE.md](EXPORT-COMPLIANCE.md). Zum **Einreichen** gibt es davon eine
englische, vollständige Fassung:
[EXPORT-COMPLIANCE-DOSSIER.md](EXPORT-COMPLIANCE-DOSSIER.md) — für Apples Feld
„Dokumentation zur App-Verschlüsselung", für eine Einstufungsanfrage beim BIS oder
für die Durchsicht durch einen Anwalt.

Beide beantworten die Frage nicht, welche Ausnahme greift. Dabei hört es auf, eine
Programmierfrage zu sein.

## Preis: kostenlos

Festgelegt. In App Store Connect unter *Preise und Verfügbarkeit* → **Kostenlos**,
ohne In-App-Käufe. Für TestFlight ist das gleichgültig — Testbuilds sind für
Tester immer kostenlos —, es greift erst beim Store.

Bemerkenswert ist daran, dass die App das nicht nur behauptet, sondern **nicht
anders kann**: es gibt kein StoreKit, keine Werbung und keine Messtechnik. Der
einzige Netzzugriff holt eine öffentliche Sperrliste bei der Behörde, die sie
ausgibt — kein Server des Entwicklers ist beteiligt, und
`Scripts/check-no-network.sh` setzt durch, dass es bei dieser einen Stelle
bleibt. Bei einer kostenlosen App ist die nächste Frage sonst immer, womit sie
stattdessen bezahlt wird; hier lautet die Antwort: mit nichts. Dasselbe sagen die
Datenschutzangaben — **Data Not Collected** — und `App/PrivacyInfo.xcprivacy`.

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
  gelesene Daten verlassen das Gerät nur, wenn der Benutzer sie teilt, das Archiv
  löscht sich nach 30 Tagen, und der eine Netzzugriff holt eine öffentliche
  Sperrliste, ohne etwas über das Dokument mitzuteilen.
  `Scripts/check-no-network.sh` setzt durch, dass es dabei bleibt. Verweisen kann
  man auf [DATA-PROTECTION.md](DATA-PROTECTION.md).
* **Die Datenschutzerklärung im Netz ist Pflicht**, nicht optional. Vorlage:
  `apps/cie-reader/store/privacy-policy-{de,en,it}.md` im Android-Repository —
  zu überarbeiten, weil auf iOS die **Kamera-Berechtigung** dazukommt.
* **Externe Tester bedeuten Beta-Prüfung.** Für den ersten Test aus dem eigenen
  Team fällt sie weg; sobald jemand von außen dazukommt, prüft Apple den ersten
  Build einer Fassung.

Die Datenschutzangaben im Eintrag („App Privacy") bleiben **Data Not Collected**,
und das ist auch mit dem Netzzugriff richtig: gefragt wird dort, welche Daten die
App **vom Benutzer erhebt**. Ein Abruf einer öffentlichen Datei erhebt nichts —
es wird nichts gesendet, nichts gespeichert und nichts mit einer Person
verknüpft. `App/PrivacyInfo.xcprivacy` sagt dasselbe. Wer trotzdem fragt, findet
die Begründung in [DATA-PROTECTION.md](DATA-PROTECTION.md).
