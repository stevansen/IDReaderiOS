# PACE mit CAN

**Eingebaut.** Was das gekostet hat und warum es so und nicht anders gebaut ist,
steht hier — samt dem Patch, mit dem sich die Änderung nach oben tragen lässt.

> **Am Gerät noch nicht nachgewiesen.** Der Simulator hat kein NFC, und ohne eine
> echte CIE 3.0 in der Hand ist der Handschlag nicht bewiesen. Die Android-Fassung
> ist gegen ein echtes Dokument auf zwei Geräten vermessen; weniger ist hier keine
> Grundlage. Bis dahin gilt dieser Teil als gebaut, nicht als geprüft.

## Warum das die Arbeit war

Die CIE 3.0 öffnet sich über **PACE** nach ICAO 9303 Teil 11, mit der aufgedruckten
CAN als Passwort. PACE rechnet dabei einen Diffie-Hellman über einer elliptischen
Kurve, und die italienische Karte nennt in `EF.CardAccess` **brainpoolP256r1**
(Parameterkennung 13).

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
