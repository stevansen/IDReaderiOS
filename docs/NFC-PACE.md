# PACE mit CAN: was fehlt, und wie es hineinkommt

Der einzige Teil der Portierung, der noch nicht arbeitet — und der einzige, bei
dem eine Abkürzung wirklich schadet.

## Warum das nicht schon fertig ist

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

## Wo die Naht liegt

`App/NFC/ChipDocumentReader.swift` zieht die Grenze genau dort, wo die Portierung
aufhört und die Kryptografie anfängt:

```
CoreNFCChipReader          Sitzung, EF.CardAccess lesen, PACEInfo zerlegen   ← fertig
   ↓ PACEEngine.establish(info:key:transceive:)                              ← die Naht
PACE-Handschlag            brainpoolP256r1, gesicherte Kanalschlüssel        ← fehlt
   ↓ SecureChannel.send(_:)
Datengruppen + EF.SOD      DG1, DG2, DG11, DG12, DG14, Passive Auth          ← fehlt
```

Alles über der Naht ist fertig und geprüft: Oberfläche, Archiv, Export, das
Urteilsmodell, die drei Parser. Solange darunter nichts steckt, wirft
`UnavailablePACEEngine` einen **benannten** Fehler (`ReadErrorKind.paceUnavailable`)
mit einem Text, der sagt, was fehlt. Bewusst nicht `unknown`: „unbekannter Fehler
beim Lesen der Karte" schickt den Bediener los, die Karte zu putzen und das Telefon
neu zu starten, und was hier fehlt, ist nichts an der Karte.

## Der empfohlene Weg: NFCPassportReader mit CAN

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

### Schritte

1. `AndyQ/NFCPassportReader` forken, den Patch setzen, taggen.
2. Den Fork als Paketabhängigkeit in `IDReader.xcodeproj` aufnehmen.
3. `App/NFC/PACEEngine.swift` gegen den Fork schreiben und
   `UnavailablePACEEngine` in `IDReaderApp.swift` austauschen.
4. **Gegen eine echte CIE 3.0 prüfen.** Ohne diesen Nachweis gilt der Punkt als
   offen — die Android-Fassung ist gegen ein echtes Dokument auf zwei Geräten
   vermessen, und weniger ist hier keine Grundlage.
5. `THIRD-PARTY-NOTICES.md` um den **vollständigen** MIT-Text ergänzen. Ein
   Tabelleneintrag genügt der MIT-Lizenz nicht.

## Was danach noch fehlt

`CoreNFCChipReader.readDocument` endet heute hinter dem Handschlag. Zu ergänzen,
in dieser Reihenfolge und mit denselben Entscheidungen wie im Original:

1. `sendSelectApplet` mit der Angabe, ob PACE lief — der Parameter sagt dem Secure
   Messaging, welches Verfahren gelaufen ist; er fragt die Karte nicht.
2. DG1 → DG11 → DG12 → DG2 (nur auf Wunsch) → DG14 → EF.SOD. **Jede Datengruppe
   zuerst als rohe Bytes**, erst danach zerlegen: die Hash-Prüfung braucht genau
   die Bytes, die von der Karte kamen — ein neu kodiertes Objekt ergibt nicht
   zwingend denselben Hash.
3. DG11, DG2, DG12, DG14 und EF.SOD sind **optional**. Fehlt eines, läuft der
   Lesevorgang weiter und nur der betroffene Teil des Ergebnisses ist schwächer.
   Ein Verbindungsabriss wird weiterhin als solcher gemeldet — sonst sähe eine
   weggezogene Karte wie „Datei nicht vorhanden" aus.
4. Chip Authentication **nach** allen Lesevorgängen. PACE sichert die Verbindung
   schon, und ein Stolpern hier soll eine ansonsten einwandfreie Karte nicht
   unlesbar machen. Ob die Karte sie überhaupt anbietet, kommt aus dem
   **signierten** Security Object und nicht daraus, ob DG14 lesbar war — sonst käme
   eine Kopie damit durch, DG14 einfach weglassen.
5. Passive Authentication, vier Prüfungen, alle vier müssen aufgehen. Die dritte —
   Kette bis zu einer hinterlegten italienischen CSCA — ist die, auf die es
   ankommt: ohne sie könnte jemand eine Karte mit selbst erzeugtem Schlüsselpaar
   bespielen, und die ersten zwei wären trotzdem grün. Die Anker liegen in
   `Sources/IDReaderCore/Resources/csca/`.
6. Zwei Fallen bei der Signaturprüfung, die im Original beide einen falschen
   „Signatur ungültig" erzeugt haben: der in `SignerInfo` genannte Algorithmus ist
   häufig kein brauchbarer JCE/OpenSSL-Name (`SSAwithRSA/PSS`, oder nur `RSA`, das
   nach RFC 5652 erst mit dem Digest zu `SHA256withRSA` zusammenzusetzen ist), und
   für RSASSA-PSS müssen die Parameter aus dem SignerInfo mitgegeben werden.
7. Ein abgelaufener **Dokumentsignierer** gilt nicht als Fehlschlag. Signierer
   laufen nach Monaten ab, die Karten, die sie signiert haben, bleiben zehn Jahre
   gültig. Sperrlistenabfrage (CRL/OCSP) bleibt bewusst aus: sie bräuchte Netz.

## Und JPEG 2000

DG2 hält das Lichtbild als JPEG 2000. iOS hat dafür keinen öffentlichen Decoder;
`FaceImageDecoder` erkennt heute das Format an den Magic Bytes — nicht am MIME-Typ
aus DG2, der auf manchen Karten falsch ist, unter Android gemessen — und gibt es
an die Oberfläche weiter, die es an der Stelle des Bildes anzeigt.

Einzubinden ist OpenJPEG als C-Ziel in `Package.swift`. Zu erkennen sind beide
Formen: der JP2-Container und der nackte J2K-Codestream.
