# NFCPassportReaderCAN — fremder Code, gepatcht

Dieser Ordner ist **nicht unser Code**. Er ist eine geänderte Kopie von

    https://github.com/AndyQ/NFCPassportReader
    Commit 6e37f1ab249fef82771da46d32707f2b94ed090f  (Tag 2.3.3, 28. Juli 2026)
    MIT, © 2019 Andy Qua — Lizenztext in LICENSE

Drei Dateien sind geändert, alle übrigen 36 sind Byte für Byte das Original.

## Vierte Änderung: der PACE-Grund wird nicht mehr verschluckt

`PassportReader.startReading` fängt einen PACE-Fehler ab, protokolliert „PACE
Failed - falling back to BAC" und macht weiter. Für einen Reisepass geht das
meist gut aus. Für eine Karte **ohne** BAC-Rückfall — die CIE — bleibt am Ende
nur `InvalidDataPassed("PACE failed and the access key does not allow a BAC
fallback")`, und darin steht kein Wort dazu, woran PACE scheiterte.

Am Gerät ist das der Unterschied zwischen einer Diagnose und dem Raten. Zwei
Rückmeldungen aus dem Betatest waren deshalb nicht zu deuten, und die
naheliegende Erklärung — falsch eingetippter Schlüssel — hat sich als falsch
erwiesen, nachdem der Benutzer ihn von Hand eingegeben hatte.

Geändert:

* ein Feld `paceFailureReason`, das den abgefangenen Fehler behält;
* die Meldung beim fehlenden BAC-Rückfall nennt ihn.

Das Verhalten für den MRZ-Fall bleibt unverändert: dort wird weiter auf BAC
zurückgefallen, und die Meldung entsteht gar nicht.

**Nicht** gepatcht wurde der Tracking-Delegat: den gibt es schon
(`PassportReaderTrackingDelegate`), und die Wegmarken der App hängen daran —
siehe `App/NFC/ReadTrail.swift`.

## Warum eine Kopie und kein Paketverweis

Weil die Bibliothek genau das nicht kann, was die italienische CIE 3.0 braucht:
PACE mit der **CAN**. Im Original steht das ausdrücklich —

```swift
private static let CAN_PACE_KEY_REFERENCE : UInt8 = 0x02 // Not currently supported
```

— und die Stelle, an der es zu ändern wäre, ist `internal`. Von außen ist da
nichts einzuhängen: `TagReader.init` und `TagReader.secureMessaging` sind
`internal`, `DataGroupParser` hat keine öffentliche Schnittstelle. Die Bibliothek
gibt nach außen nur `PassportReader.readPassport(mrzKey:)` her, also den ganzen
Ablauf oder nichts.

**Die sauberere Form wäre ein Fork** unter eigener Adresse, als Paketverweis
eingebunden. Der Patch unten ist genau dafür gedacht und außerdem als
Beitrag nach oben brauchbar — er fügt einen Weg hinzu und nimmt keinen weg.
Solange es den Fork nicht gibt, liegt die Kopie hier, damit sich die App
überhaupt bauen lässt.

## Was geändert wurde

### `PACEHandler.swift`

1. Zwei Eingänge statt einem: `doPACE(mrzKey:)` und `doPACE(can:)`. Beide rufen
   denselben Ablauf, nur mit anderem Schlüsselkeim und anderer Schlüsselkennung.
2. Der Schlüsselkeim wird nicht mehr in der Ableitung gebildet, sondern
   hineingegeben. **Das ist der eigentliche Punkt:** beim MRZ-Schlüssel ist der
   Keim `SHA-1(MRZ-Information)`, bei der CAN die Zeichenkette selbst, ohne Hash
   (ICAO 9303 Teil 11; BSI TR-03110-1). Wer bei der CAN denselben SHA-1-Schritt
   macht, bekommt einen falschen Schlüssel und vom Chip eine Absage — und nichts
   daran zeigt, dass nicht die CAN falsch war, sondern die Ableitung.
3. `CAN_PACE_KEY_REFERENCE` trägt nicht mehr den Vermerk „not currently
   supported".
4. **Zusätzlich, nicht für CAN nötig:** der abgeleitete Schlüssel und der
   Klartext des Passworts stehen nicht mehr im Protokoll. Im Original stand
   beides je einmal drin (`Logger.pace.debug("keyLength - \(mrzKey)")` und die
   Hex-Ausgabe von `paceKey`). Die CAN ist der Zugang zum Chip; ein
   Ausweisleser ist nicht die Stelle, an der das in ein Systemprotokoll geht.

### `PassportReader.swift`

1. `AccessKey` als öffentliche Aufzählung mit den Fällen `.mrz` und `.can`.
2. `readPassport(accessKey:…)` als zweiter Eingang. `readPassport(mrzKey:…)`
   bleibt unverändert daneben stehen und ruft ihn auf — bestehender Code merkt
   nichts.
3. Der Handschlag nimmt den zum Schlüssel passenden Weg.
4. **Kein Rückfall auf BAC, wenn der Schlüssel dafür nicht taugt.** BAC kennt nur
   den MRZ-Schlüssel. Ohne diese Abfrage lief der Rückfall mit einer leeren
   Zeichenkette los und scheiterte an einer Stelle, die mit der Ursache nichts
   mehr zu tun hatte.

### `NFCPassportModel.swift`

Nicht für CAN nötig, aber für die Anzeige: das im Security Object genannte
Hashverfahren wird gemerkt (`sodHashAlgorithm`), statt es nach der Prüfung fallen
zu lassen. Die App zeigt es hinter dem Echtheitssiegel — „womit wurde geprüft?"
ist die Frage, für die dieses Blatt da ist, und die Android-Fassung beantwortet
sie dort ebenfalls.

## Auffrischen

```bash
git clone --depth 1 https://github.com/AndyQ/NFCPassportReader.git
cp -R NFCPassportReader/Sources/NFCPassportReader/* ThirdParty/NFCPassportReaderCAN/Sources/
cd ThirdParty/NFCPassportReaderCAN && patch -p1 < UPSTREAM.patch
```

Der Patch liegt als `UPSTREAM.patch` daneben. Schlägt er fehl, ist oben in Worten
beschrieben, was er tut.

## Der Patch

```diff
--- a/Sources/PACEHandler.swift	2026-08-20 19:59:53
+++ b/Sources/PACEHandler.swift	2026-08-20 21:25:51
@@ -4,6 +4,16 @@
 //
 //  Created by Andy Qua on 03/03/2021.
 //
+//  ---------------------------------------------------------------------------
+//  GEAENDERTE FASSUNG. Fremder Code unter MIT (siehe ../LICENSE), nicht unser.
+//  Was geaendert wurde und warum, steht in ../UPSTREAM.md - dort liegt auch der
+//  Patch, der sich gegen eine neuere Fassung wieder anwenden laesst.
+//
+//  Kurz: PACE mit CAN. Das Original fuehrt nur den MRZ-Fall und markiert CAN
+//  ausdruecklich als "not currently supported"; die italienische CIE 3.0 hat
+//  aber keine MRZ auf der Vorderseite, sondern die aufgedruckte CAN.
+//  ---------------------------------------------------------------------------
+//
 
 import Foundation
 import OSLog
@@ -40,7 +50,7 @@
     
     
     private static let MRZ_PACE_KEY_REFERENCE : UInt8 = 0x01
-    private static let CAN_PACE_KEY_REFERENCE : UInt8 = 0x02 // Not currently supported
+    private static let CAN_PACE_KEY_REFERENCE : UInt8 = 0x02
     private static let PIN_PACE_KEY_REFERENCE : UInt8 = 0x03 // Not currently supported
     private static let CUK_PACE_KEY_REFERENCE : UInt8 = 0x04 // Not currently supported
 
@@ -72,7 +82,38 @@
         isPACESupported = true
     }
     
+    /// PACE mit dem MRZ-Schluessel.
+    ///
+    /// Der Schluesselkeim ist SHA-1 ueber die MRZ-Information - also ueber
+    /// Dokumentnummer, Geburts- und Ablaufdatum **samt** ihrer Pruefziffern.
+    /// Dieser Hash-Schritt gehoert ausschliesslich zum MRZ-Fall.
     public func doPACE( mrzKey : String ) async throws {
+        try await doPACE(
+            keySeed: calcSHA1Hash( Array(mrzKey.utf8) ),
+            keyReference: PACEHandler.MRZ_PACE_KEY_REFERENCE
+        )
+    }
+
+    /// PACE mit der aufgedruckten CAN.
+    ///
+    /// Der Schluesselkeim ist die Zeichenkette selbst, **ohne** Hash: nach
+    /// ICAO 9303 Teil 11 und BSI TR-03110-1 ist das Passwort hier die CAN in
+    /// ihrer Kodierung, und der KDF nimmt sie unmittelbar. Wer hier denselben
+    /// SHA-1-Schritt wie beim MRZ-Fall macht, bekommt einen falschen Schluessel
+    /// und vom Chip nur eine Absage - ohne dass daran zu erkennen waere, dass
+    /// nicht die CAN falsch war, sondern die Ableitung.
+    ///
+    /// Die CAN ist dabei ein nicht sperrendes Passwort (TR-03110-1, Abschnitt
+    /// 2.3): der Chip darf sie nach Fehlversuchen nicht blockieren. Ein
+    /// Fehlversuch kostet einen Fehlversuch.
+    public func doPACE( can : String ) async throws {
+        try await doPACE(
+            keySeed: Array(can.utf8),
+            keyReference: PACEHandler.CAN_PACE_KEY_REFERENCE
+        )
+    }
+
+    private func doPACE( keySeed : [UInt8], keyReference : UInt8 ) async throws {
         guard isPACESupported else {
             throw NFCPassportReaderError.NotYetSupported( "PACE not supported" )
         }
@@ -88,8 +129,8 @@
         digestAlg = try paceInfo.getDigestAlgorithm()  // Either SHA-1 or SHA-256.
         keyLength = try paceInfo.getKeyLength()  // Get key length  the enc cipher. Either 128, 192, or 256.
 
-        paceKeyType = PACEHandler.MRZ_PACE_KEY_REFERENCE
-        paceKey = try createPaceKey( from: mrzKey )
+        paceKeyType = keyReference
+        paceKey = try createPaceKey( keySeed: keySeed )
         
         // Temporary logging
         Logger.pace.debug("doPace - inpit parameters" )
@@ -100,8 +141,11 @@
         Logger.pace.debug("cipherAlg - \(self.cipherAlg)" )
         Logger.pace.debug("digestAlg - \(self.digestAlg)" )
         Logger.pace.debug("keyLength - \(self.keyLength)" )
-        Logger.pace.debug("keyLength - \(mrzKey)" )
-        Logger.pace.debug("paceKey - \(binToHexRep(self.paceKey, asArray:true))" )
+        // Der Schluessel selbst steht hier nicht mehr im Protokoll, und der
+        // Klartext des Passworts auch nicht. Beides stand im Original je einmal
+        // drin; die CAN ist der Zugang zum Chip und ein Ausweisdokument ist
+        // nicht die Stelle, an der man das in ein Systemprotokoll schreibt.
+        Logger.pace.debug("paceKeyType - \(self.paceKeyType)" )
 
         // First start the initial auth call
         _ = try await tagReader.sendMSESetATMutualAuth(oid: paceOID, keyType: paceKeyType)
@@ -599,12 +643,9 @@
     /// Computes a key seed based on an MRZ key
     /// - Parameter the mrz key
     /// - Returns a encoded key based on the mrz key that can be used for PACE
-    func createPaceKey( from mrzKey: String ) throws -> [UInt8] {
-        let buf: [UInt8] = Array(mrzKey.utf8)
-        let hash = calcSHA1Hash(buf)
-        
+    func createPaceKey( keySeed: [UInt8] ) throws -> [UInt8] {
         let smskg = SecureMessagingSessionKeyGenerator()
-        let key = try smskg.deriveKey(keySeed: hash, cipherAlgName: cipherAlg, keyLength: keyLength, nonce: nil, mode: .PACE_MODE, paceKeyReference: paceKeyType)
+        let key = try smskg.deriveKey(keySeed: keySeed, cipherAlgName: cipherAlg, keyLength: keyLength, nonce: nil, mode: .PACE_MODE, paceKeyReference: paceKeyType)
         return key
     }
     
--- a/Sources/PassportReader.swift	2026-08-20 19:59:53
+++ b/Sources/PassportReader.swift	2026-08-20 21:26:20
@@ -1,4 +1,13 @@
 //
+//  ---------------------------------------------------------------------------
+//  GEAENDERTE FASSUNG. Fremder Code unter MIT (siehe ../LICENSE), nicht unser.
+//  Was geaendert wurde und warum, steht in ../UPSTREAM.md.
+//
+//  Kurz: ein zweiter Eingang `readPassport(accessKey:)`, damit sich der Chip
+//  auch mit der aufgedruckten CAN oeffnen laesst. Der MRZ-Eingang bleibt
+//  unveraendert daneben stehen.
+//  ---------------------------------------------------------------------------
+//
 //  PassportReader.swift
 //  NFCTest
 //
@@ -61,6 +70,30 @@
     private var caHandler : ChipAuthenticationHandler?
     private var paceHandler : PACEHandler?
     private var mrzKey : String = ""
+
+    /// Womit der Chip geoeffnet wird.
+    ///
+    /// Der Reisepass gibt seinen Schluessel aus der maschinenlesbaren Zone, die
+    /// italienische CIE 3.0 aus der aufgedruckten CAN. Alles andere am
+    /// Lesevorgang ist gleich - Datengruppen, Passive Authentication und
+    /// Chip-Authentisierung folgen bei beiden ICAO 9303.
+    public enum AccessKey {
+        case mrz(String)
+        case can(String)
+
+        /// Ob zu dieser Art ein Rueckfall auf BAC ueberhaupt denkbar ist.
+        ///
+        /// Nur beim MRZ-Schluessel. BAC kennt kein anderes Passwort, und eine
+        /// Karte, die PACE nicht kann, ist keine CIE 3.0 - dort ist der Abbruch
+        /// die richtige Antwort und nicht ein zweiter Versuch mit etwas, das
+        /// nicht passt.
+        var allowsBACFallback : Bool {
+            if case .mrz = self { return true }
+            return false
+        }
+    }
+
+    private var accessKey : AccessKey = .mrz("")
     private var aaChallenge: [UInt8]?
     private var dataAmountToReadOverride : Int? = nil
     
@@ -92,9 +125,18 @@
     }
     
     public func readPassport( mrzKey : String, tags : [DataGroupId] = [], aaChallenge: [UInt8]? = nil, skipSecureElements : Bool = true, skipCA : Bool = false, skipPACE : Bool = false, useExtendedMode : Bool = false, customDisplayMessage : ((NFCViewDisplayMessage) -> String?)? = nil) async throws -> NFCPassportModel {
+        try await readPassport( accessKey: .mrz(mrzKey), tags: tags, aaChallenge: aaChallenge, skipSecureElements: skipSecureElements, skipCA: skipCA, skipPACE: skipPACE, useExtendedMode: useExtendedMode, customDisplayMessage: customDisplayMessage )
+    }
+
+    public func readPassport( accessKey : AccessKey, tags : [DataGroupId] = [], aaChallenge: [UInt8]? = nil, skipSecureElements : Bool = true, skipCA : Bool = false, skipPACE : Bool = false, useExtendedMode : Bool = false, customDisplayMessage : ((NFCViewDisplayMessage) -> String?)? = nil) async throws -> NFCPassportModel {
         
         self.passport = NFCPassportModel()
-        self.mrzKey = mrzKey
+        self.accessKey = accessKey
+        if case let .mrz(key) = accessKey {
+            self.mrzKey = key
+        } else {
+            self.mrzKey = ""
+        }
         self.aaChallenge = aaChallenge
         self.skipCA = skipCA
         self.skipPACE = skipPACE
@@ -274,7 +316,10 @@
                 Logger.passportReader.info( "Starting Password Authenticated Connection Establishment (PACE)" )
                  
                 let paceHandler = try PACEHandler( cardAccess: cardAccess, tagReader: tagReader )
-                try await paceHandler.doPACE(mrzKey: mrzKey )
+                switch accessKey {
+                    case .mrz(let key): try await paceHandler.doPACE( mrzKey: key )
+                    case .can(let can): try await paceHandler.doPACE( can: can )
+                }
                 passport.PACEStatus = .success
                 Logger.passportReader.debug( "PACE Succeeded" )
 
@@ -290,6 +335,15 @@
         }
         
         // If either PACE isn't supported, we failed whilst doing PACE or we didn't even attempt it, then fall back to BAC
+        //
+        // Mit einer CAN gibt es diesen Rueckfall nicht: BAC kennt nur den
+        // MRZ-Schluessel. Ohne diese Abfrage lief der Rueckfall mit einer leeren
+        // Zeichenkette los und scheiterte an einer Stelle, die nichts mehr mit
+        // der eigentlichen Ursache zu tun hatte.
+        if passport.PACEStatus != .success && !accessKey.allowsBACFallback {
+            throw NFCPassportReaderError.InvalidDataPassed( "PACE failed and the access key does not allow a BAC fallback" )
+        }
+
         if passport.PACEStatus != .success {
             do {
                 trackingDelegate?.bacStarted()
--- a/Sources/NFCPassportModel.swift	2026-08-20 19:59:53
+++ b/Sources/NFCPassportModel.swift	2026-08-20 21:33:58
@@ -1,3 +1,12 @@
+//
+//  ---------------------------------------------------------------------------
+//  GEAENDERTE FASSUNG. Fremder Code unter MIT (siehe ../LICENSE), nicht unser.
+//  Was geaendert wurde und warum, steht in ../UPSTREAM.md.
+//
+//  Kurz: das im Security Object genannte Hashverfahren wird gemerkt, statt es
+//  nach der Pruefung fallen zu lassen. Die App zeigt es hinter dem Siegel an -
+//  "womit geprueft wurde" ist die Frage, fuer die dieses Blatt da ist.
+//  ---------------------------------------------------------------------------
 //
 //  NFCPassportModel.swift
 //  NFCPassportReader
@@ -117,6 +126,12 @@
 
     public internal(set) var cardAccess : CardAccess?
     public internal(set) var BACStatus : PassportAuthenticationStatus = .notDone
+    /// Das Hashverfahren, das das Security Object nennt - z. B. "SHA256".
+    ///
+    /// Nur zur Auskunft: die App zeigt es hinter dem Echtheitssiegel, wo die
+    /// Frage "womit wurde geprueft?" hingehoert. Am Urteil aendert es nichts.
+    public internal(set) var sodHashAlgorithm : String?
+
     public internal(set) var PACEStatus : PassportAuthenticationStatus = .notDone
     public internal(set) var chipAuthenticationStatus : PassportAuthenticationStatus = .notDone
 
@@ -450,6 +465,7 @@
         passportDataNotTampered = false
         let asn1Data = try OpenSSLUtils.ASN1Parse( data: signedData )
         let (sodHashAlgorythm, sodHashes) = try parseSODSignatureContent( asn1Data )
+        self.sodHashAlgorithm = sodHashAlgorythm
         
         var errors : String = ""
         for (id,dgVal) in dataGroupsRead {
```

## Was davon nach oben gehört

Vier der Änderungen sind **Fehler in `AndyQ/NFCPassportReader`**, nicht
Anpassungen an unseren Sonderfall. Sie gehören in einen Pull Request — nicht aus
Höflichkeit: solange das ein Fork ist, trägt dieses Repository die Wartung, und
`UPSTREAM.patch` wächst mit jeder fremden Fassung.

| | Fehler | Allgemein? |
|---|---|---|
| 1 | `TagReader.send`: `if rep.sw1 != 0x90 && rep.sw2 != 0x00` — ein **Und** statt eines Oder. Jedes Statuswort mit `00` als zweitem Byte rutscht durch: `6D00`, `6A00`, `6E00`, `6900`, `6F00`. Der Aufrufer bekommt leere Daten statt eines Fehlers. | **ja**, trifft jedes Dokument |
| 2 | `6C xx` wird nicht behandelt, nur `61 xx`. ISO 7816-4 verlangt die Wiederholung mit `Le = xx`. | **ja** |
| 3 | `startReading` fängt den PACE-Fehler ab und verwirft ihn. Bei einem Zugang ohne BAC-Rückfall bleibt danach keine Auskunft übrig. | **ja** |
| 4 | PACE Schritt 3 erzeugt bedingungslos ein `EC_KEY`. Bei DH gibt `EVP_PKEY_get0_EC_KEY` `NULL` → „Failed to generate EC key". Schritt 2 hat einen DH-Zweig, Schritt 3 hatte keinen. | ja, betrifft alle DH-Dokumente |
| 5 | Erweiterte APDU über `NFCISO7816APDU(…, expectedResponseLength:)` werden von italienischen Dokumenten mit `6C00` abgewiesen; selbst gebaut gehen sie durch. | **Vorsicht** — hier ist unklar, ob CoreNFC oder der Chip abweicht. Als Beobachtung melden, nicht als Fehlerbehauptung. |

Die Nummern 1 bis 3 sind klein, allgemein richtig und ohne unseren Sonderfall
verständlich — die haben die besten Aussichten. Nummer 4 braucht die Begründung
aus `docs/EU-EID-STANDARDS.md`. Nummer 5 ist eine Beobachtung, keine Diagnose:
ich weiß nicht, welche Seite vom Standard abweicht, nur dass die selbst gebaute
Form funktioniert.

## Zwei Namen, die das Gegenteil sagen

Kein Fehler im Verhalten, und trotzdem hat er mich einen Bau gekostet — deshalb
steht er hier:

| Eigenschaft | Wird gesetzt, wenn | Klingt wie |
|---|---|---|
| `passportCorrectlySigned` | die **Kette** bis zu einer CSCA in der Masterliste aufgeht (`validateAndExtractSigningCertificates`) | „die Signatur ist gut" |
| `documentSigningCertificateVerified` | die **Signatur des Security Objects** gegen das Dokumentzertifikat aufgeht (`ensureReadDataNotBeenTamperedWith`) | „das Zertifikat ist geprüft" |

Beide bedeuten das, was der andere Name sagt. Wer sie beim Wort nimmt, ordnet sie
vertauscht zu — und **solange beide Stufen zutreffen, fällt das nicht auf.** Beim
italienischen Reisepass gehen beide auf, bei der Identitätskarte kippt genau
eine; erst dort nannte die App die falsche Ursache.

Für einen Pull Request taugt das nur als Umbenennung mit Übergangsfrist, und die
ist eine Entscheidung des Projekts, nicht ein Fehlerbericht. Aufgeschrieben ist
es hier, damit die nächste Zuordnung nicht wieder an den Namen hängt.
