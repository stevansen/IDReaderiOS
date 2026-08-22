# PACE mit CAN

**Eingebaut.** Was das gekostet hat und warum es so und nicht anders gebaut ist,
steht hier — samt dem Patch, mit dem sich die Änderung nach oben tragen lässt.

> **Am Gerät noch nicht nachgewiesen.** Der Simulator hat kein NFC, und ohne eine
> echte CIE 3.0 in der Hand ist der Handschlag nicht bewiesen. Die Android-Fassung
> ist gegen ein echtes Dokument auf zwei Geräten vermessen; weniger ist hier keine
> Grundlage. Bis dahin gilt dieser Teil als gebaut, nicht als geprüft.

## Warum das die Arbeit war

Die CIE 3.0 öffnet sich über **PACE** nach ICAO 9303 Teil 11, mit der aufgedruckten
CAN als Passwort.

> **Berichtigung vom 22. August 2026.** Hier stand, die Karte nenne in
> `EF.CardAccess` **brainpoolP256r1** (Parameterkennung 13), PACE rechne also
> einen Diffie-Hellman über einer elliptischen Kurve. **Das war eine Annahme, und
> die Karte widerlegt sie.**
>
> Am Gerät meldet der Chip genau eine SecurityInfo:
> `0.4.0.127.0.7.2.2.4.1.1` = `id-PACE-DH-GM-3DES-CBC-CBC` — **klassisches**
> Diffie-Hellman über einem Primkörper, 3DES/SHA-1, Generic Mapping. Keine Kurve.
>
> Beides bestätigt das:
>
> * Die amtliche Chip-Spezifikation, Abschnitt 5.3: Schlüsselaustausch „Diffie
>   Hellman (DH) mit Domänenparametern von mindestens 2048 Bit" **oder** ECDH ab
>   192 Bit; symmetrisch AES-192/256 **oder** 3DES-112; Abbildung: Generic
>   Mapping.
> * Das amtliche `cie-mrtd-dotnet-sdk` von IPZS akzeptiert für die CIE
>   **ausschließlich Parametersatz 2** und wirft sonst „Parametri di default …
>   non supportati". Parametersatz 2 ist `GFp 2048/256`, also RFC 5114 §2.3 —
>   ein Primkörper, keine Kurve.
>
> Was das für die Begründung unten heißt: OpenSSL bleibt nötig — für DH über
> 2048 Bit, für 3DES und für die Kettenprüfung. Der genannte *Anlass*
> (brainpool, das CryptoKit fehlt) ist aber nicht der, der bei dieser Karte
> zählt. Die Entscheidung war richtig, die Begründung war es nur zur Hälfte.

CryptoKit führt P-256, P-384, P-521 und Curve25519. **Brainpool nicht.** Damit
gibt es genau drei Wege:

1. Eine Bibliothek einbinden, die OpenSSL mitbringt. **Der empfohlene Weg**, siehe
   unten.
2. OpenSSL selbst einbinden und den Ablauf schreiben.
3. Eigene EC-Arithmetik über einem Primkörper, mit eigener großer Zahl.

Der dritte Weg kommt nicht in Frage. Handgeschriebene Kryptografie in einer App,
die Ausweisdokumente liest, ist kein Sparen — sie ist ein Risiko, das niemand mehr
sieht, weil sie funktioniert, solange man sie nicht angreift. Die Android-Fassung
hat aus demselben Grund JMRTD und BouncyCastle genommen und nicht selbst gerechnet.

**Gewählt ist der erste Weg.** `ThirdParty/NFCPassportReaderCAN` ist eine
geänderte Kopie von `AndyQ/NFCPassportReader` (MIT); drei Dateien sind angefasst,
36 sind Byte für Byte das Original. Was geändert wurde und warum, steht in
[`../ThirdParty/NFCPassportReaderCAN/UPSTREAM.md`](../ThirdParty/NFCPassportReaderCAN/UPSTREAM.md),
der Patch liegt daneben als `UPSTREAM.patch`.

## Warum kein Paketverweis auf die Fassung oben

Weil sich von außen nichts einhängen lässt. Die Stelle, an der die CAN
hineingehört, ist `internal`, und der Rest ist es auch: `TagReader.init` und
`TagReader.secureMessaging` sind `internal`, `DataGroupParser` hat keine
öffentliche Schnittstelle. Nach außen gibt die Bibliothek genau eines her —
`PassportReader.readPassport(mrzKey:)`, also den ganzen Ablauf oder nichts.

Der Gedanke, nur den Handschlag selbst zu schreiben und die fertigen
Sitzungsschlüssel danach an ihr Secure Messaging zu übergeben, scheitert an
derselben Wand.

**Die sauberere Form bleibt ein Fork** unter eigener Adresse, als Paketverweis
eingebunden. Der Patch ist genau dafür gemacht — und weil er einen Weg hinzufügt
und keinen wegnimmt, ist er auch als Beitrag nach oben brauchbar. Solange es den
Fork nicht gibt, liegt die Kopie im Repository, damit sich die App überhaupt
bauen lässt.

## Wo die Grenze jetzt verläuft

`App/NFC/PassportChipReader.swift` rechnet nichts. Er übergibt den Schlüssel,
übersetzt den Fortschritt in die vier Phasen des Lesescreens und bildet danach
das Ergebnis auf `DocumentData` ab:

```
PassportChipReader     Schlüssel übergeben, Fortschritt, Abbildung, Urteil
   ↓ readPassport(accessKey: .can("482913"))
NFCPassportReaderCAN   PACE über brainpoolP256r1, Secure Messaging,
                       DG1/2/11/12/14 + EF.SOD, Passive Auth, Chip Auth
   ↓ OpenSSL 3
```

Die eigentliche Arbeit im Adapter ist das **Urteil**: die Bibliothek liefert vier
voneinander unabhängige Wahrheiten, und daraus eines zu machen folgt Zeile für
Zeile der Android-Fassung — alle müssen aufgehen, sonst ist es kein Ja. Siehe
`PassportChipReader.authenticity(from:)`.

## Der Patch, in Worten

[`AndyQ/NFCPassportReader`](https://github.com/AndyQ/NFCPassportReader) (MIT,
iOS 15+) bringt alles mit: PACE über GM und IM, BAC, Secure Messaging,
Datengruppen-Zerlegung, Passive Authentication, Chip Authentication — und OpenSSL
über [`krzyzanowskim/OpenSSL-Package`](https://github.com/krzyzanowskim/OpenSSL-Package).

**Was ihm fehlt: CAN.** In `PACEHandler.swift` steht das ausdrücklich:

```swift
private static let MRZ_PACE_KEY_REFERENCE : UInt8 = 0x01
private static let CAN_PACE_KEY_REFERENCE : UInt8 = 0x02 // Not currently supported
```

Und die Schlüsselableitung kennt nur den MRZ-Fall:

```swift
func createPaceKey( from mrzKey: String ) throws -> [UInt8] {
    let buf: [UInt8] = Array(mrzKey.utf8)
    let hash = calcSHA1Hash(buf)          // <- gilt nur für MRZ
    let smskg = SecureMessagingSessionKeyGenerator()
    return try smskg.deriveKey(keySeed: hash, cipherAlgName: cipherAlg,
                               keyLength: keyLength, nonce: nil,
                               mode: .PACE_MODE, paceKeyReference: paceKeyType)
}
```

### Der Patch

Nach ICAO 9303 Teil 11 (und BSI TR-03110-1, Abschnitt 2.3) ist der Schlüsselkeim
für die CAN die **rohe Zeichenkette selbst**, nicht ihr SHA-1. Der SHA-1-Schritt
gehört ausschließlich zum MRZ-Fall, wo aus Dokumentnummer, Geburts- und
Ablaufdatum samt Prüfziffern erst die „MRZ-Information" gebildet wird.

Zu ändern ist deshalb genau zweierlei:

```swift
// 1. Ein zweiter Weg hinein, neben doPACE(mrzKey:)
public func doPACE( can: String ) async throws {
    paceKeyType = PACEHandler.CAN_PACE_KEY_REFERENCE
    try await doPACE(keySeed: Array(can.utf8))
}

public func doPACE( mrzKey: String ) async throws {
    paceKeyType = PACEHandler.MRZ_PACE_KEY_REFERENCE
    try await doPACE(keySeed: calcSHA1Hash(Array(mrzKey.utf8)))
}

// 2. Die Ableitung nimmt den Keim, statt ihn selbst zu bilden
private func createPaceKey( keySeed: [UInt8] ) throws -> [UInt8] {
    let smskg = SecureMessagingSessionKeyGenerator()
    return try smskg.deriveKey(keySeed: keySeed, cipherAlgName: cipherAlg,
                               keyLength: keyLength, nonce: nil,
                               mode: .PACE_MODE, paceKeyReference: paceKeyType)
}
```

Der Rest des Ablaufs — `MSE:Set AT` mit `keyType`, die vier Schritte des
Handschlags, die Sitzungsschlüssel — bleibt unverändert. `paceKeyReference` geht
schon in die Ableitung ein, und `sendMSESetATMutualAuth(oid:keyType:)` nimmt den
Typ schon als Parameter.

Dazu kommen zwei Dinge, die für CAN nicht nötig, aber richtig sind: der
abgeleitete Schlüssel und der Klartext des Passworts stehen nicht mehr im
Protokoll (im Original stand beides je einmal drin), und ein Rückfall auf BAC
findet nur noch statt, wenn der Schlüssel dafür überhaupt taugt — BAC kennt nur
den MRZ-Schlüssel, und mit einer leeren Zeichenkette loszulaufen scheitert an
einer Stelle, die mit der Ursache nichts mehr zu tun hat.

## Was noch offen ist

1. **Der Nachweis am Gerät.** Eine echte CIE 3.0, ein iPhone, und die vier Phasen
   müssen durchlaufen. Zu prüfen sind dabei besonders: der schnelle Weg ohne DG2,
   das grüne Siegel bei einer echten Karte, und dass eine falsche CAN als „CAN
   stimmt nicht" ankommt und nicht als „unbekannter Fehler".
2. **JPEG 2000.** Siehe unten — daran hat sich nichts geändert.
3. **Der Fork statt der Kopie**, sobald jemand ihn anlegt.

## Was die Bibliothek dabei tut

Nicht mehr unsere Baustelle, aber wissenswert — es sind dieselben Entscheidungen,
die die Android-Fassung in ihren Kommentaren festhält, und sie sind der Grund,
diese Bibliothek zu nehmen statt selbst zu schreiben:

* Jede Datengruppe wird **zuerst als rohe Bytes** gelesen und erst danach
  zerlegt. Die Hash-Prüfung braucht genau die Bytes, die von der Karte kamen — ein
  neu kodiertes Objekt ergibt nicht zwingend denselben Hash.
* DG11, DG2, DG12, DG14 und EF.SOD sind optional. Fehlt eines, läuft der
  Lesevorgang weiter und nur der betroffene Teil des Ergebnisses ist schwächer.
* Chip Authentication läuft **nach** allen Lesevorgängen. PACE sichert die
  Verbindung schon, und ein Stolpern hier soll eine ansonsten einwandfreie Karte
  nicht unlesbar machen.
* Bei der Signaturprüfung sind zwei Fallen behandelt, die im Original der
  Android-Fassung beide einen falschen „Signatur ungültig" erzeugt haben: der in
  `SignerInfo` genannte Algorithmus ist häufig kein brauchbarer Name, und für
  RSASSA-PSS müssen die Parameter aus dem SignerInfo mitgegeben werden.
* Die Kettenprüfung ignoriert `X509_V_ERR_EC_KEY_EXPLICIT_PARAMS` — OpenSSL 3
  lehnt explizite Kurvenparameter ab, ICAO verlangt sie.

Womit geprüft wird, geben wir mit: das PEM-Bündel der neun italienischen CSCA aus
`Sources/IDReaderCore/Resources/csca/`. Fehlt es, wird gelesen und nicht geprüft —
und das Ergebnis sagt das dann auch, statt ein Siegel zu malen, das nichts belegt.
Die **Sperrlistenabfrage** ist inzwischen dabei, und zwar als CRL: die Liste wird
als Ganzes geholt und danach offline abgeglichen. OCSP bleibt draußen — dort ginge
die Seriennummer des gerade geprüften Zertifikats mit hinaus. Siehe
[DATA-PROTECTION.md](DATA-PROTECTION.md); geprüft wird der Dokumentsignierer, nicht
ob ein Dokument als gestohlen gemeldet ist.

## Und JPEG 2000

DG2 hält das Lichtbild als JPEG 2000. iOS hat dafür keinen öffentlichen Decoder;
`FaceImageDecoder` erkennt heute das Format an den Magic Bytes — nicht am MIME-Typ
aus DG2, der auf manchen Karten falsch ist, unter Android gemessen — und gibt es
an die Oberfläche weiter, die es an der Stelle des Bildes anzeigt.

Einzubinden ist OpenJPEG als C-Ziel in `Package.swift`. Zu erkennen sind beide
Formen: der JP2-Container und der nackte J2K-Codestream.

## Was am Gerät wirklich passiert (22. August 2026)

Acht Bauten in TestFlight, drei Rückmeldungen mit Bildschirmfotos. Der Weg von
„Lesen fehlgeschlagen" zu einer Diagnose lief über drei Fehler **in der
Fehlerbehandlung**, nicht in der Kryptografie:

1. **Der „Zurück"-Knopf war auf null Punkte gequetscht** (`layoutPriority` neben
   `maxWidth: .infinity`). Ein fehlgeschlagener Lesevorgang ließ sich nur durch
   einen weiteren fortsetzen — das war die Meldung „ich kann den Scan nicht
   abbrechen".
2. **`ReadError.detail` wurde weggeworfen** und `lastStep` nie fortgeschrieben.
   Jeder Fehlschlag sah gleich aus.
3. **Die Lesebibliothek verschluckt den PACE-Fehler** (`catch` → Logzeile →
   weiter mit BAC). Für die CIE bleibt danach nur „PACE failed"; für den
   Reisepass läuft BAC an und der Chip sagt `SW 6985` — die Absage eines Chips,
   der PACE verlangt. **Beide Dokumente scheitern also an derselben Stelle.**

Nach dem Beheben dieser drei sagte das Gerät:

```
InvalidDataPassed("PACE fehlgeschlagen: InvalidASN1Value") · CAN(6 Ziffern) ·
Chip erkannt → PACE begonnen
→ CardAccess gelesen (1 SecurityInfo: 0.4.0.127.0.7.2.2.4.1.1)
→ PACE gescheitert
```

### Der vierte Fehler, und er ist der Grund für die Blindheit

`TagReader.send` prüfte den Status so:

```swift
if rep.sw1 != 0x90 && rep.sw2 != 0x00 {   // FALSCH
```

Ein **Und** statt eines Oder. Damit rutscht jedes Statuswort durch, dessen
zweites Byte `0x00` ist — `0x6D00` „instruction not supported", `0x6A00` „wrong
parameters", `0x6E00`, `0x6900`, `0x6F00`. Der Aufrufer bekommt dann keinen
Fehler, sondern **leere Daten**, und scheitert eine Zeile später beim Auspacken
der erwarteten TLV-Struktur.

Deshalb hieß es `InvalidASN1Value`: nicht die Antwort war unlesbar, es gab
**keine** Antwort — nur eine verschluckte Absage. Berichtigt zu
`if !(rep.sw1 == 0x90 && rep.sw2 == 0x00)`.

### Was der Chip wirklich anbietet (Bau 9, Reisepass)

```
SW 6985 · MRZ(Nr 9, Geb 6, Abl 6) · Chip erkannt → PACE begonnen
→ CardAccess gelesen (1): 0.4.0.127.0.7.2.2.4.1.1 v2 Param 2 GM
→ PACE gescheitert → BAC begonnen → BAC gescheitert
```

**Damit ist die Kryptografie der Karte endgültig geklärt**, und alle Vermutungen
über eine Fehlinterpretation sind erledigt:

| | |
|---|---|
| Verfahren | `id-PACE-DH-GM-3DES-CBC-CBC` — klassisches DH, kein ECDH |
| Version | 2 |
| Domänenparameter | **2** = `GFp 2048/256`, RFC 5114 §2.3 |
| Abbildung | Generic Mapping |

Kennung und Parametersatz sind **widerspruchsfrei**: DH-Verfahren, DH-Parameter.
Und Parametersatz 2 ist genau der, den das amtliche `cie-mrtd-dotnet-sdk`
als einzigen akzeptiert. Der italienische **Reisepass** meldet dasselbe wie die
Karte — beide Dokumente wollen den DH-Pfad.

Auf dem Papier führt die Bibliothek ihn: `createMappingKey` ruft für
Parametersatz 2 `DH_get_2048_256()`, `getParameterSpec` bildet 0/1/2 richtig ab,
und `doDHMappingAgreement` rechnet die Abbildung. Trotzdem scheitert PACE. Warum,
sagt erst ein sauberer Durchgang mit berichtigter Statusprüfung.

Ein Verdacht, ausdrücklich als solcher: RFC-5114-Parameter tragen ein `q`
(Untergruppenordnung). OpenSSL macht daraus einen Schlüssel vom Typ
**`EVP_PKEY_DHX`** statt `EVP_PKEY_DH`, und `DH_get_2048_256()` ist seit
OpenSSL 3.0 veraltet. Beides sind Stellen, an denen ein Pfad brechen kann, der
mit Reisepässen — die ECDH nehmen — nie befahren wird.

### Die Ursache, aus dem APDU-Protokoll eines Geräts (Bau 11)

```
0.91s → 00 22 C1 A4 800A04007F00070202040101830102
0.94s ← SW 9000                                        MSE:Set AT angenommen
0.94s → 10 86 00 00 7C00
0.98s ← SW 9000 7C0A8008356899530694DF57               Schritt 1: Nonce, 8 Byte
0.99s → 10 86 00 00 7C820104 8182010003E04C19…         Schritt 2: 264 Byte
2.38s ← SW 6C00                                        „falsches Le"
```

**Der Verdacht mit Tag 0x84 ist damit widerlegt.** Der MSE:Set AT enthält nur
`80` (Verfahren) und `83 01 02` (CAN) — und der Chip antwortet `9000`. Er
verlangt die Domänenparameter nicht. Gut, dass die Änderung nicht ins Blaue
eingebaut wurde.

Die Ursache steht eine Zeile weiter. Der öffentliche DH-Schlüssel ist bei
2048 Bit **256 Byte** groß, das Datenfeld mit TLV-Hülle also 264 — mehr als ein
kurzes APDU trägt (255). CoreNFC macht daraus ein **erweitertes** APDU, und der
Chip beanstandet dessen `Le` mit `6C00`.

Nach ISO 7816-4 heißt `6C xx`: *falsches Le, das richtige ist xx* — der Befehl
ist damit zu wiederholen. Die Lesebibliothek behandelt `61 xx` (GET RESPONSE),
aber **`6C xx` nicht**; sie wirft es als Fehler.

**Und damit ist auch erklärt, warum das in einer weit verbreiteten Bibliothek
niemandem auffällt:** ein Reisepass mit ECDH hat einen öffentlichen Schlüssel von
32 bis 66 Byte. Alles passt in ein kurzes APDU, `6C00` kommt nie. Nur wer
klassisches DH über 2048 Bit rechnet — die italienischen Dokumente — läuft
hinein.

Behoben: `6C xx` wird behandelt, der Befehl mit `Le = xx` wiederholt
(`xx = 0x00` heißt nach üblicher Auslegung 256).

### Was `6C00` wirklich sagt (Bau 13)

Der erste Versuch, `6C xx` zu behandeln, war halb richtig. Das lückenlose
Protokoll:

```
2.95s → 00 22 C1 A4 800A04007F00070202040101830102
2.96s ← SW 9000                                     MSE:Set AT angenommen
2.96s → 10 86 00 00 7C00
2.99s ← SW 9000 7C0A8008BF431992757BF747            Schritt 1: Nonce
3.00s → 10 86 00 00 7C820104 8182010043 23A5…       Schritt 2: 264 Byte
3.69s ↻ 6C00 → Wiederholung mit Le=256
3.73s ← SW 6985                                     „conditions of use…"
```

**Der Fehler war meiner.** Bei `61 00` (GET RESPONSE) heißt SW2 = 0 nach
Gewohnheit 256. Bei `6C 00` nicht: dort nennt SW2 die Zahl der **verfügbaren**
Bytes, und null heißt null. Wiederholt wurde trotzdem mit `Le = 256` — mit genau
dem Wert, den der Chip gerade beanstandet hatte. Er hat dieselbe Frage ein
zweites Mal bekommen und abgelehnt.

Berichtigt: `Le = xx`, buchstäblich.

**Und die Antwort passt zum Befehl.** `CLA 0x10` ist das Verkettungsbit — ein
Zwischenglied einer Befehlskette liefert **keine** Antwortdaten. Der Chip sagt
also die Wahrheit: null Bytes verfügbar. Die Lesebibliothek erwartet hier
trotzdem Daten, weil Reisepässe sie an dieser Stelle liefern.

Damit stehen zwei Lesarten, und der nächste Durchgang entscheidet:

1. **Nur das Le war falsch.** Dann antwortet der Chip auf die berichtigte
   Wiederholung mit `9000` und seinem Abbildungsschlüssel, und PACE läuft weiter.
2. **Der Chip verkettet wirklich.** Dann kommt `9000` **ohne** Daten, und die
   Antwort ist erst mit dem nächsten, unverketteten Befehl zu holen. Das wäre ein
   Umbau des PACE-Ablaufs für den DH-Fall und kein Einzeiler mehr.

### Der Reisepass rechnet nur langsam (Bau 13)

```
1.42s → 10 86 00 00 7C00
4.76s ← SW 9000 7C0A8008B7E5C4DE0769515A     3,34 Sekunden
```

Damit ist das zweite Rätsel erledigt. Der Reisepass ist nicht verrutscht und
antwortet nicht „gar nicht" — er braucht für den ersten PACE-Schritt **3,3
Sekunden**, und die Läufe davor sind an einem Zeitfenster gestorben, nicht an
der Lage. Danach zeigt er denselben Verlauf wie die Karte: `6C00`, Wiederholung,
`6985`. Und BAC beantwortet er mit `6985` — die Absage eines Chips, der PACE
verlangt.

**Beide Dokumente verhalten sich identisch.** Ein Fehler, nicht zwei.

### Zweimal danebengelegen an derselben Zeile

`6C xx` und `61 xx` sehen gleich aus und bedeuten Verschiedenes:

| Versuch | `Le` | Ergebnis |
|---|---|---|
| Bau 12 | 256 (Gewohnheit von `61 00`) | `6985` — derselbe Wert, den der Chip beanstandet hatte |
| Bau 14 | 0 | in CoreNFC ist `0` ein Le-**Feld** mit Wert null: kurz gelesen 256, erweitert 65536 |
| Bau 15 | **kein Le-Feld** (`-1`) | die buchstäbliche Lesart von „null Bytes verfügbar" |

CoreNFC unterscheidet „Le = 0" und „kein Le" über `expectedResponseLength: -1`.
Das ist die Falle, in die beide Versuche gelaufen sind.

### Es liegt nicht am `Le` (Bau 15)

Drei Fassungen der Wiederholung durchprobiert, mit **beiden** Dokumenten:

| Bau | Wiederholung mit | Antwort |
|---|---|---|
| 12 | `Le = 256` | `6985` |
| 14 | `Le = 0` | (übersprungen — wäre wieder 256/65536 gewesen) |
| 15 | **kein Le-Feld** | `6985` |

**Damit ist die Le-Spur zu Ende.** Und was übrig bleibt, ist eindeutig:

* Schritt 1 mit `CLA 0x10` beantwortet der Chip **mit Daten**. Das
  Verkettungsbit stört ihn also nicht.
* Schritt 2 mit 264 Byte lehnt er ab. Danach ist der PACE-Zustand verdorben —
  deshalb `6985` auf jede Wiederholung, unabhängig vom `Le`.

Was ihn stört, ist die **Länge**. 264 Byte passen nicht in ein kurzes APDU (255),
CoreNFC macht daraus ein erweitertes, und dieses Dokument nimmt es nicht an.
`6C00` — „null Bytes verfügbar" — ist seine Art, das zu sagen.

Behoben in Bau 16: **kein erweitertes APDU mehr.** Das Datenfeld wird in Stücke
von 255 Byte zerlegt und verkettet gesendet — Verkettungsbit bei allen außer dem
letzten. Nach ISO 7816-4 setzt der Chip sie zusammen und beantwortet das letzte.

Dass das die richtige Lesart ist, ist noch nicht bewiesen. Aber es ist die
einzige verbliebene, und das Protokoll zeigt jedes Stück einzeln — die Antwort
auf das erste Stück sagt schon, ob der Chip verkettet.

### Die Rechnung, die alles umdreht

264 Byte im Datenfeld. Ein kurzes APDU trägt 255.

**Damit ist ein erweitertes APDU bei diesem Verfahren zwingend, nicht optional.**
Ein Chip, der PACE mit DH über 2048 Bit vorschreibt — und die CIE schreibt es
vor, sie bietet in `EF.CardAccess` nichts anderes an —, *muss* erweiterte APDU
annehmen können. Es gibt keinen Weg, einen 256-Byte-Schlüssel anders zu
übertragen.

Er antwortet trotzdem `6C00`. Damit ist der nächste Verdächtige **nicht der
Chip**, sondern der Weg dorthin: was `NFCISO7816APDU` aus Daten und
`expectedResponseLength` zusammensetzt, sieht man nicht.

Deshalb zwei weitere Formen, die die Bytes selbst bauen und über
`NFCISO7816APDU(data:)` übergeben:

```
Fall 3E   10 86 00 00 | 00 01 08 | <264 Byte>
Fall 4E   10 86 00 00 | 00 01 08 | <264 Byte> | 00 00
```

Sie stehen in der Probierreihenfolge **vorn**, aus genau diesem Grund: die
Verkettungsformen sind Ausweichmanöver, die erweiterten APDU sind der
vorgeschriebene Weg.

### Gefunden (Bau 17): der Erzeuger war es, nicht der Chip

```
1.17s ⋯ selbst gebaut: 10 86 00 00 | 00 01 08 | 264B | 00 00
1.17s → 10 86 00 00 7C820104 8182010053 0A2A…
1.88s ← SW 9000 7C820104 8282010028 3DF9…       ← 9000 MIT DATEN
```

Tag `0x82`, 256 Byte — der Abbildungsschlüssel des Chips. **PACE Schritt 2 läuft.**

Damit ist die Ursache benannt: `NFCISO7816APDU(…, expectedResponseLength:)`
erzeugt für ein Datenfeld über 255 Byte etwas, das dieses Dokument mit `6C00`
abweist. Byte für Byte selbst gebaut und über `NFCISO7816APDU(data:)` übergeben,
antwortet es sofort richtig. Alle Ausweichmanöver — Le-Varianten, Verkettung —
waren Umwege um einen Fehler im Erzeuger.

Die vollständige Messreihe an dieser einen Stelle:

| Übertragung | Antwort |
|---|---|
| `expectedResponseLength: 256` | `6C00` |
| Wiederholung mit `Le = 256` | `6985` |
| Wiederholung ohne Le-Feld | `6985` |
| verkettet, letztes Stück `CLA 0x00` | `6A80` |
| **selbst gebaut, Fall 4E** | **`9000` + 256 Byte** ✓ |

### Schritt 3, der DH-Zweig (Bau 18)

Eingebaut. Und es war weniger, als es aussah: **Schritt 4 ist bereits
algorithmusunabhängig** — `computeSharedSecret`, `decodePublicKeyFromBytes`,
`getPublicKeyData` und `encodePublicKey` führen alle einen DH-Fall. Gefehlt hat
genau eine Erzeugung, nämlich die des flüchtigen Schlüsselpaars in Schritt 3.

Neu: `makeEphemeralKeyPair(from:)` verzweigt nach `EVP_PKEY_get_base_id`. Für DH
werden die **abgebildeten** Domänenparameter übernommen (p und q wie gehabt, das
in Schritt 2 gerechnete neue g) und darüber ein Paar erzeugt. Der Rest von
Schritt 3 — Tag `0x83` senden, Tag `0x84` auspacken — war schon
algorithmusunabhängig.

### Der ursprüngliche Befund

PACE Schritt 3 war in der Bibliothek **nur für EC** geschrieben:

```swift
guard let ecParams = EVP_PKEY_get0_EC_KEY(ephemeralParams),   // NULL bei DH
      let group = EC_KEY_get0_group(ecParams), …
else { throw … "Failed to generate EC key" }
```

Am Gerät genau diese Meldung. Schritt 2 hat einen DH-Zweig
(`doDHMappingAgreement`), Schritt 3 und 4 haben keinen. Das ist umschrieben und
endlich — der Auftrag dafür steht in
[`../REWORK_PROMPT.md`](../REWORK_PROMPT.md).

Nebenbefund: nach dem erfolgreichen Schritt 2 antwortet die Karte auf ein
`SELECT` mit `6883` („last command of the chain expected"). Unser Schritt 2 trug
`CLA 0x10`, die Kette gilt für sie also noch als offen. Ob das nach einem
vollständigen PACE-Durchlauf verschwindet, zeigt der nächste Bau.

### Was als nächstes zu prüfen ist

Mit der berichtigten Statusprüfung nennt das Gerät das Statuswort des Chips.
Danach steht die Frage, die ich **nicht** ins Blaue beantworten will:

`sendMSESetATMutualAuth` sendet nur **Tag 0x80** (Verfahrenskennung) und
**Tag 0x83** (Passwortreferenz). **Tag 0x84** — die Angabe, welche
Domänenparameter das Terminal gewählt hat — wird nie gesendet. Nach TR-03110 ist
das „conditional": erforderlich, wenn der Chip mehrere Sätze anbietet. Die
CIE-Spezifikation nennt DH **und** ECDH, also mehrere.

Das ist der Verdacht. Ihn ohne Beleg einzubauen wäre falsch — die Ergänzung
könnte den Reisepass-Pfad brechen, der heute weiter kommt als der Kartenpfad.
Erst das Statuswort, dann die Änderung.

## Es liest (Bau 18, 22. August 2026)

Beide Dokumente, am Gerät, mit vollständigem Protokoll.

```
1.49s · CardAccess gelesen (1): 0.4.0.127.0.7.2.2.4.1.1 v2 Param 2 GM
1.52s ← SW 9000                                  MSE:Set AT
1.57s ← SW 9000 7C0A80084E39…                    Schritt 1, Nonce
1.58s ⋯ erweitert, selbst gebaut: 264B
2.34s ← SW 9000 7C820104 8282…                   Schritt 2, Tag 0x82
2.35s ⋯ erweitert, selbst gebaut: 264B
2.58s ← SW 9000 7C820104 8482…                   Schritt 3, Tag 0x84
2.58s → 00 86 00 00 7C0A8508228136415F1ABCA2     Schritt 4, Token
2.63s ← SW 9000 7C0A86085FA8AC8EF043F421         Tag 0x86
2.63s · PACE erfolgreich
```

Danach greift die Weiche und es stehen nur noch Längen und Statuswörter da — dort
fließen die Personendaten.

### Was dabei nebenbei bewiesen wurde

* **Chip Authentication läuft auch.** `00 22 41 A6` mit 260 Byte (Karte) bzw.
  131 Byte (Pass) → `9000`. Das war eine offene Wette: dieselbe DH-Familie,
  dieselbe Bibliothek.
* **Die Datengruppen kommen vollständig.** Bei der Karte ~12 KB in DG2, also das
  Lichtbild.

### Zeiten, und was daran auffällt

| | Karte | Reisepass |
|---|---|---|
| PACE | 1,25 s | **11,7 s** |
| davon Schritt 1 | 0,05 s | **9,91 s** |
| Datengruppen | 3,04 s | 3,37 s |
| **gesamt** | **5,67 s** | **15,31 s** |

Der Reisepass braucht für den ersten PACE-Schritt zehn Sekunden — und **damit
sind alle früheren `ConnectionError` erklärt.** Der erste Versuch in dieser
Sitzung scheiterte an genau dieser Stelle nach 0,64 s. Es war nie die Lage, es
war immer die Geduld.

Fünfzehn Sekunden ein Dokument ruhig halten ist lang. Das ist kein Fehler, aber
es gehört in die Bedienung: die App sagt heute nicht, dass es so lange dauern
kann.
