# Ausfuhrmeldung: was die App tatsächlich tut

Bestandsaufnahme für die Fragen, die App Store Connect beim Upload stellt, und für
jeden, der die Unterlagen dafür zusammenstellt.

**Keine Rechtsberatung.** Was hier steht, sind nachprüfbare Tatsachen über den
Quelltext — welcher Algorithmus, woher, wofür. Welche Ausnahme davon greift und
welche Unterlagen einzureichen sind, entscheidet das nicht.

> **Zum Einreichen** gibt es die englische Fassung dieser Aufstellung, in der
> Form, die eine solche Unterlage verlangt:
> [EXPORT-COMPLIANCE-DOSSIER.md](EXPORT-COMPLIANCE-DOSSIER.md). Sie ist für Apples
> Feld „Dokumentation zur App-Verschlüsselung", für eine Einstufungsanfrage beim
> BIS oder für die Durchsicht durch einen Anwalt gedacht — und auf Englisch, weil
> sie dort gelesen wird.

## Woher die Verschlüsselung kommt

Die Trennung ist der Kern der Sache, denn die Frage von Apple lautet genau so:
Verschlüsselung **des Betriebssystems** oder **zusätzlich dazu**?

### Aus dem Betriebssystem von Apple

| Verfahren | Wofür | Woher |
|---|---|---|
| AES-256-GCM | das verschlüsselte Archiv (Daten auf dem Gerät) | CryptoKit |
| AES-128/192/256-CBC | Secure Messaging zum Chip, Vertraulichkeit der Übertragung | CommonCrypto (`CCCrypt`) |
| 3DES, DES-CBC | dasselbe für ältere Dokumente (BAC) | CommonCrypto (`CCCrypt`) |
| Schlüsselaufbewahrung | der Archivschlüssel | Schlüsselbund, `…WhenUnlockedThisDeviceOnly` |

**Die eigentliche Vertraulichkeit — Archiv und Übertragungskanal — läuft
vollständig über Apples eigene Verfahren.** Das war vor dem Einbau von PACE so und
ist es danach.

### Zusätzlich aus OpenSSL 3.6.3 (im Bundle, arm64)

| Verfahren | Wofür | Norm |
|---|---|---|
| ECDH über brainpoolP256r1 | Schlüsselvereinbarung bei PACE und Chip-Authentisierung | RFC 5639, NIST SP 800-56A |
| AES-CMAC | Nachrichtenauthentisierung im Secure Messaging und die PACE-Token | RFC 4493, NIST SP 800-38B |
| RSA, ECDSA, SHA-2 | **Prüfung** von Signaturen (Passive Authentication) | PKCS#1, FIPS 186-4, FIPS 180-4 |
| X.509, PKCS#7 / CMS | Zertifikatskette bis zu den italienischen CSCA | RFC 5280, RFC 5652 |
| Bignum-Arithmetik | trägt die EC-Rechnung | — |

Warum OpenSSL überhaupt: PACE rechnet bei der italienischen CIE über
**brainpoolP256r1**, und diese Kurve führt CryptoKit nicht. Siehe
[NFC-PACE.md](NFC-PACE.md).

**Was OpenSSL hier NICHT tut: Nutzdaten verschlüsseln.** Es vereinbart Schlüssel,
bildet Prüfsummen zur Authentisierung und prüft Signaturen. Die Bulk-Verschlüsselung
liegt bei Apple — nachzulesen in `ThirdParty/NFCPassportReaderCAN/Sources/`,
`AES_3DES_DESEncryption.swift` (CommonCrypto) gegen `OpenSSLUtils.swift` (OpenSSL).

### Was die App nicht tut

* Keine eigenen oder abgewandelten Verfahren. Jeder Algorithmus ist veröffentlicht
  und von IETF, NIST oder ISO genormt; die Protokolle sind ICAO 9303 und
  BSI TR-03110.
* Keine Netzverbindung, also auch kein TLS und keine HTTPS-Aufrufe — geprüft von
  `Scripts/check-no-network.sh`.
* Keine Ver- oder Entschlüsselung für Dritte, keine Schlüsselverwaltung, kein VPN,
  kein Kopierschutz.

## Die Fragen im Upload-Formular

### „Welche Art von Verschlüsselungsalgorithmus verwendest du?"

**Standardmäßige Verschlüsselungsalgorithmen statt oder zusätzlich zu der im
Betriebssystem von Apple verwendeten bzw. zugänglichen Verschlüsselung.**

Nach den Tatsachen oben: alle Verfahren sind genormt (nichts Geschütztes,
nichts Nichtstandardisiertes), und OpenSSL liegt **zusätzlich** zu Apples
Verfahren im Bundle. Damit ist es nicht die erste Antwort (nichts Proprietäres),
nicht „beide" und auch nicht „keinen davon".

„Keinen davon" **war** die richtige Antwort — bis zum Einbau von PACE. Sie kommt
nur zurück, wenn OpenSSL wieder herausfällt, und dann kann die App die CIE nicht
mehr lesen. Das ist der Preis, und er ist zu hoch.

### `ITSAppUsesNonExemptEncryption`

Steht bewusst **nicht** in `Config/Info.plist`. Vor dem Einbau von PACE stand dort
`false`, gestützt auf die Ausnahme „ausschließlich Verschlüsselung des
Betriebssystems" — die greift nicht mehr. Solange die Frage nicht beantwortet ist,
soll App Store Connect bei jedem Upload nachfragen, statt dass eine alte Zeile
etwas behauptet.

Sobald Apple nach genehmigten Unterlagen einen Schlüsselwert vergibt, gehört er als
`ITSEncryptionExportComplianceCode` in dieselbe Datei; `ITSAppUsesNonExemptEncryption`
wird dann `true`.

## Was noch zu klären ist, und von wem

Das ist der Punkt, an dem es aufhört, eine Programmierfrage zu sein:

1. **Greift eine Ausnahme?** Bemerkenswert an der Aufstellung oben ist, dass das
   nicht von Apple stammende Material auf Schlüsselvereinbarung, Authentisierung
   und Signaturprüfung beschränkt ist — das ist die Formulierung, die in den
   Ausnahmen der EAR (Kategorie 5 Teil 2) vorkommt. Ob sie im Sinne der Vorschrift
   zutrifft, wenn eine Schlüsselvereinbarung Schlüssel liefert, mit denen danach
   verschlüsselt wird, ist keine Frage, die dieser Text entscheiden kann.
2. **Welche Unterlagen?** CCATS beim BIS, oder Selbsteinstufung als
   massenmarktgängige Software (ECCN 5D992.c) mit Jahresbericht an BIS und NSA. Was
   Apple im Bereich „Dokumentation zur App-Verschlüsselung" annimmt, sagt Apple.
3. **Frankreich** verlangt für Verschlüsselung eine eigene Erklärung, wenn die App
   dort verfügbar ist.
4. **Der Jahresbericht**, falls Selbsteinstufung greift, ist wiederkehrend und
   nicht einmalig.

Wer das beantwortet, braucht die Aufstellung oben — deshalb steht sie hier und
nicht in einer Mail.
