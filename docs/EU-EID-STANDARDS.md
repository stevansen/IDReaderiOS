# Ausweisdokumente in der EU: welche Standards wirklich gelten

Recherche vom 22. August 2026, ausgelöst davon, dass diese App italienische
Dokumente nicht lesen konnte und die Ursache tief in einem Verfahren lag, das in
der ganzen Werkzeugkette als Randfall behandelt wird.

Keine Rechtsberatung. Was hier steht, ist mit Quellen belegt oder am Gerät
gemessen — beides ist unten unterschieden.

---

## 1. Zwei Welten, die man nicht verwechseln darf

Es gibt in der EU **zwei** getrennte Wege zu einer digitalen Identität, und sie
haben nichts gemeinsam außer dem Zweck:

| | **Chip im Dokument** | **EUDI Wallet** |
|---|---|---|
| Was | Kontaktloser Chip in Karte oder Pass | App auf dem Telefon |
| Regelwerk | ICAO 9303, BSI TR-03110 | eIDAS 2 (VO 2024/1183) |
| Format | Datengruppen DG1–DG16, ASN.1 | mdoc (ISO/IEC 18013-5), SD-JWT |
| Übertragung | NFC nach ISO 14443, APDU nach ISO 7816 | NFC, Bluetooth, QR |
| Was man liest | Was das Dokument hergibt, alles oder nichts | Nur die Merkmale, die der Inhaber freigibt |
| Frist | seit Jahren im Feld | jeder Mitgliedstaat muss **bis Ende 2026** eine Wallet anbieten |

**Diese App liest den Chip.** Sie ist damit in der ersten Spalte, und das ist
eine bewusste Wahl mit einem Ablaufdatum: die zweite Spalte ist der Weg, den die
EU eingeschlagen hat, und sie löst genau das Problem, an dem die erste scheitert
— dass ein Lesevorgang **alles** liefert und der Bediener hinterher aussortieren
muss. Selektive Offenlegung ist im Chip nicht vorgesehen.

Für eine App, die *heute* ein Dokument in der Hand prüfen soll, ist der Chip
trotzdem der einzige Weg: Wallets sind 2026 im Aufbau, und ein vorgelegter
Ausweis hat einen Chip.

## 2. Der Chip: ICAO 9303 und BSI TR-03110

Die Kette ist überall dieselbe:

1. **Zugang** — der Chip gibt nichts heraus, bis ein Passwort vom Dokument
   selbst bewiesen ist. Zwei Verfahren:
   * **BAC** (Basic Access Control) — alt, 3DES/SHA-1, Schlüssel aus der MRZ.
   * **PACE** (Password Authenticated Connection Establishment) — der Nachfolger,
     BSI TR-03110, in ICAO 9303 Teil 11 übernommen. Passwort ist MRZ **oder CAN**.
2. **Gesicherte Verbindung** (Secure Messaging) über die aus dem Zugang
   abgeleiteten Sitzungsschlüssel.
3. **Passive Authentication** — die Prüfsummen der Datengruppen gegen das
   signierte Sicherheitsobjekt `EF.SOD`, dieses gegen das Dokumentenzertifikat,
   dieses gegen die CSCA des ausstellenden Staates.
4. **Chip Authentication** — der Chip beweist, dass er das Original ist.
5. Optional **EAC / Terminal Authentication** für geschützte Datengruppen
   (Fingerabdrücke in DG3). Braucht ein Inspektionssystem-Zertifikat, das eine
   App nicht hat und nicht bekommt.

### PACE ist nicht ein Verfahren, sondern eine Familie

Und das ist der Punkt, an dem diese App aufgelaufen ist. Die Kennung in
`EF.CardAccess` legt drei Dinge unabhängig voneinander fest:

| | Möglichkeiten |
|---|---|
| **Schlüsselaustausch** | **DH** (klassisch, über einem Primkörper) oder **ECDH** (über einer Kurve) |
| **Abbildung** | GM (Generic Mapping), IM (Integrated Mapping), CAM (Chip Authentication Mapping) |
| **Chiffre** | 3DES-CBC-CBC oder AES-CBC-CMAC in 128/192/256 |

Das sind rund zwanzig gültige Kombinationen, jede mit eigener
Objektkennung unter `0.4.0.127.0.7.2.2.4`.

**In der Praxis ist ECDH-GM-AES der Normalfall** — Reisepässe der meisten
Staaten nehmen ihn, und die gesamte offene Werkzeugkette ist darauf ausgelegt.
Die einschlägige Referenzdokumentation zu PACE beschreibt ausdrücklich nur
„general mapping with elliptic curve diffie-hellman"; der DH-Zweig kommt in ihr
nicht vor.

### Was Italien verlangt

Aus der amtlichen Chip-Spezifikation der CIE 3.0, Abschnitt 5.3, und am Gerät
bestätigt:

```
0.4.0.127.0.7.2.2.4.1.1   id-PACE-DH-GM-3DES-CBC-CBC
Version 2 · Parametersatz 2 (GFp 2048/256, RFC 5114 §2.3) · Generic Mapping
```

Also **klassisches DH über 2048 Bit mit 3DES/SHA-1** — die älteste zulässige
PACE-Variante. Das amtliche `cie-mrtd-dotnet-sdk` von IPZS akzeptiert für die
CIE ausschließlich Parametersatz 2 und wirft sonst „Parametri di default non
supportati".

**Der italienische Reisepass meldet dasselbe.** Am Gerät gemessen, mit
Passwortreferenz `83 01 01` (MRZ) statt `83 01 02` (CAN) — sonst identisch. Es
ist also kein Sonderfall einer Karte, sondern die italienische Linie.

### Und daraus folgt eine Rechnung, die alles bestimmt

Bei DH über 2048 Bit ist ein öffentlicher Schlüssel **256 Byte** groß. Mit
TLV-Hülle wird das Datenfeld des PACE-Schritts 2 **264 Byte**.

Ein kurzes APDU nach ISO 7816-4 trägt **255**.

> **Ein erweitertes APDU ist bei diesem Verfahren zwingend, nicht optional.**

Bei ECDH über brainpoolP256r1 ist derselbe Schlüssel 65 Byte, das Datenfeld
knapp 70 — alles passt bequem in ein kurzes APDU. **Deshalb fällt niemandem auf,
dass die erweiterte Form nicht funktioniert.** Wer nur Reisepässe liest, kommt
dort nie an.

## 3. Was daran am Gerät wirklich schiefging

Gemessen über siebzehn TestFlight-Bauten, jeder mit APDU-Protokoll:

| Übertragung des 264-Byte-Datenfelds | Antwort des Chips |
|---|---|
| `NFCISO7816APDU(…, expectedResponseLength: 256)` | `6C00` |
| dieselbe, wiederholt mit `Le = 256` | `6985` |
| dieselbe, wiederholt ohne Le-Feld | `6985` |
| verkettet, letztes Stück `CLA 0x00` | `6A80` |
| **selbst gebaut: `10 86 00 00 \| 00 01 08 \| 264B \| 00 00`** | **`9000` + 256 Byte** ✓ |

**Der Erzeuger war das Problem, nicht der Chip.** Was `NFCISO7816APDU` aus Daten
und `expectedResponseLength` zusammensetzt, ist nicht sichtbar und für ein
Datenfeld über 255 Byte offenbar nicht das, was die Karte erwartet. Byte für
Byte selbst gebaut und über `NFCISO7816APDU(data:)` übergeben, antwortet sie
sofort richtig:

```
→ 10 86 00 00 7C820104 8182010053 0A2A…      264 Byte
← SW 9000 7C820104 8282010028 3DF9…          der Abbildungsschlüssel des Chips
```

Tag `0x82`, 256 Byte — genau das, was Generic Mapping in Schritt 2 vorsieht.

### Was danach noch fehlt

PACE-Schritt 3 (Austausch der flüchtigen Schlüssel) und Schritt 4
(Schlüsselvereinbarung) sind in der verwendeten Lesebibliothek **ausschließlich
für EC geschrieben**:

```swift
guard let ecParams = EVP_PKEY_get0_EC_KEY(ephemeralParams),   // NULL bei DH
      let group = EC_KEY_get0_group(ecParams), …
else { throw … "Failed to generate EC key" }
```

Am Gerät genau diese Meldung. Schritt 2 hat für DH einen eigenen Zweig
(`doDHMappingAgreement`), Schritt 3 und 4 haben keinen. Das ist die verbleibende
Lücke, und sie ist umschrieben und endlich.

## 4. Was das für die App heißt

**Der Weg ist tragfähig.** Nach dem Durchbruch in Schritt 2 ist bewiesen, dass
die italienischen Dokumente über CoreNFC zu öffnen sind — es fehlt der DH-Zweig
in zwei Funktionen, nicht ein Verfahren, das das Betriebssystem nicht hergibt.

**Aber die Grundlage ist die falsche.** Die Lesebibliothek ist für Reisepässe mit
ECDH geschrieben; DH ist dort Beiwerk, und das zeigt sich an jeder Stelle:

* Schritt 3 und 4 ohne DH-Zweig.
* `61 xx` behandelt, `6C xx` nicht (berichtigt).
* Statusprüfung mit `&&` statt `||`, wodurch jedes Statuswort mit `00` als
  zweitem Byte verschluckt wurde (berichtigt).
* Der PACE-Fehler wird abgefangen und verworfen (berichtigt).

Vier Fehler in der Fehlerbehandlung, gefunden auf dem Weg zu einem
Kryptografieproblem. Das ist kein Zufall, sondern was passiert, wenn ein
Codepfad nie befahren wird.

## Quellen

* [CIE 3.0 — Specifiche Chip](https://www.cartaidentita.interno.gov.it/downloads/2021/03/cie_3.0_-_specifiche_chip.pdf), Abschnitt 5.3
* [italia/cie-mrtd-dotnet-sdk, PACE.cs](https://github.com/italia/cie-mrtd-dotnet-sdk/blob/master/CIE.MRTD.SDK/EAC/PACE.cs) — akzeptiert nur Parametersatz 2
* [italia/cie-middleware](https://github.com/italia/cie-middleware)
* [BSI TR-03110-3, Advanced Security Mechanisms for MRTD](https://www.bsi.bund.de/SharedDocs/Downloads/EN/BSI/Publications/TechGuidelines/TR03110/BSI_TR-03110_Part-3_V2-1.pdf)
* [OpenPACE — Extended Access Control Specification](https://frankmorgner.github.io/openpace/protocols.html)
* [PersoApp, PACE.md](https://github.com/PersoApp/docs/blob/main/PACE.md) — ausdrücklich nur ECDH
* [walt.id — eIDAS 2 erklärt](https://walt.id/eidas2), [EUDI Wallet](https://walt.id/eidas2/eudi-wallet)
* Alles unter „am Gerät gemessen" stammt aus den APDU-Protokollen der Bauten
  11 bis 17, iPhone 18,2 / iOS 26.6.
