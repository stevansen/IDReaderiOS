# Technical dossier: cryptographic functionality of IDReader for iOS

Prepared to be handed to whoever files the export-compliance paperwork — Apple's
"App Encryption Documentation" upload, a BIS classification request, a
self-classification report, or counsel's review.

**In English on purpose.** The rest of this repository's documentation is German;
this one is read by Apple and, if it comes to that, by the U.S. Bureau of Industry
and Security.

**What this document is.** A factual, verifiable description of what the software
does with cryptography: which algorithms, at which key lengths, for what purpose,
and from whose implementation. Every statement below was checked against the
source, not recalled.

**What this document is not.** A classification. It does not name an ECCN, does not
claim an exemption, and does not decide which filing route applies. Those are
determinations for the exporter and their counsel. Where a regulatory fact matters,
it is marked as **to verify** rather than asserted — the EAR text changes, and this
document was written without access to the current text.

---

## 1. Product

| | |
|---|---|
| Name | IDReader |
| Version | 1.8 (build 1) |
| Platform | iOS 17 and later, iPhone only (arm64) |
| Bundle identifier | `com.ciereader.ios` |
| Distribution | Apple App Store, free of charge, no in-app purchases, no purchaser restriction |
| Developers | Christian Auer and Stefan Hellweger (joint) |
| Source | private repository; a port of the Android application *CIEreader* |

## 2. What the product does

Reads the contactless chip of an identity document over NFC and verifies
cryptographically that the document is genuine. Supported: the Italian electronic
identity card (CIE 3.0) and passports conforming to ICAO 9303. A third document
type, the Italian driving licence, has no chip and involves no cryptography at all
— it is captured by on-device text recognition from a photograph.

The protocols are those specified for machine readable travel documents:

| Protocol | Specification | Purpose in this product |
|---|---|---|
| PACE (Password Authenticated Connection Establishment) | ICAO 9303 Part 11; BSI TR-03110 | opens the chip using a password printed on the document, and establishes session keys |
| Secure Messaging | ICAO 9303 Part 11 | protects the APDU exchange with the chip |
| Passive Authentication | ICAO 9303 Part 11 | verifies signatures over the document's data groups against the issuing state's certificate chain |
| Chip Authentication | ICAO 9303 Part 11 | proves the chip holds the private key named in the signed security object |
| BAC (Basic Access Control) | ICAO 9303 Part 11 | legacy fallback for older passports; not reachable for the Italian identity card |

## 3. Cryptographic functionality

### 3.1 Confidentiality — implemented by the operating system

| Function | Algorithm | Key length | Implementation |
|---|---|---|---|
| Local archive of read documents, at rest | AES-GCM | 256 bit | Apple CryptoKit (`AES.GCM`) |
| Secure Messaging session encryption | AES-CBC | 128 / 192 / 256 bit, as negotiated per ICAO 9303 | Apple CommonCrypto (`CCCrypt`, `kCCAlgorithmAES`) |
| Secure Messaging, legacy documents | Triple DES-CBC, single DES-CBC | 112 / 56 bit | Apple CommonCrypto (`kCCAlgorithm3DES`, `kCCAlgorithmDES`) |

**All bulk encryption in this product is performed by Apple's own
implementations.** Neither the archive nor the communications channel uses a
third-party cipher.

### 3.2 Key agreement, authentication and signature verification — OpenSSL

| Function | Algorithm | Parameters | Purpose |
|---|---|---|---|
| PACE / Chip Authentication key agreement | ECDH, Generic Mapping | **brainpoolP256r1** (RFC 5639) as named by the Italian card; other named curves as the document specifies | derives the session keys |
| Message authentication (Secure Messaging, PACE tokens) | AES-CMAC | 128 / 192 / 256 bit | integrity and authentication, not confidentiality |
| Signature **verification** | RSA (PKCS#1, incl. RSASSA-PSS), ECDSA | as named in the document's security object | Passive Authentication |
| Hashing | SHA-1, SHA-224, SHA-256, SHA-384, SHA-512 | — | data-group hashes, key derivation |
| Certificate and message handling | X.509 (RFC 5280), PKCS#7 / CMS (RFC 5652) | — | certificate chain to the issuing state's root |

**OpenSSL performs no bulk encryption of user data in this product.** It is present
because PACE over the Italian card requires arithmetic on the brainpoolP256r1
curve, which Apple's CryptoKit does not provide.

The non-Apple cryptography is therefore confined to key agreement,
authentication, and the verification of digital signatures. Whether that
constitutes a limitation recognised by the EAR is a determination for counsel;
the factual position is stated here so the determination can be made on facts.

### 3.3 Key management

* The archive key is a 256-bit symmetric key generated on the device by
  CryptoKit's random generator on first use.
* It is stored in the iOS keychain with attribute
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: never included in a backup,
  never migrated to another device, usable only while the device is unlocked.
* PACE session keys are ephemeral, derived per session, and never persisted.
* The document access key (the printed CAN) is stored alongside the record so the
  same card is recognised again. For passports it is not stored, because there the
  key consists of personal data.
* The product contains no pre-shared or hard-coded cryptographic keys. The nine
  bundled Italian CSCA certificates are **public** trust anchors, extracted from
  the CSCA master list published by the German Federal Office for Information
  Security (BSI); they contain public keys only.

## 4. Facts likely to bear on classification

Stated as facts, not conclusions.

* **One network operation, and it uses the operating system's TLS.** The product
  makes a single kind of network request: an HTTPS `GET` for the certificate
  revocation list published by the Italian Ministry of the Interior, whose address
  is read from the bundled CSCA certificates rather than hard-coded. The request
  carries no data from any document and no device identifier. The transport
  encryption is `URLSession`'s, that is Apple's own — the product neither
  implements nor bundles any TLS code. Everything else runs offline: the
  authenticity check itself, and the comparison against the fetched list.
  A build-time check (`Scripts/check-no-network.sh`) fails the build if network
  code appears anywhere other than the single file
  `App/Revocation/RevocationDownloader.swift`, and it covers the vendored
  third-party library as well.
* **The bundled OpenSSL performs no transport encryption.** It is not used for
  TLS, and no TLS code path reaches it; the revocation download goes through
  `URLSession`. OpenSSL's role is unchanged: key agreement, CMAC, and signature
  and certificate-chain verification. The signature on the fetched revocation
  list is verified with Apple's `Security` framework
  (`SecKeyVerifySignature`).
* **No open cryptographic interface.** The product exposes no way for a user or
  another program to insert, substitute, or configure cryptographic algorithms,
  keys, or key lengths. The algorithms are fixed by the ICAO 9303 protocols and by
  what the presented document names; nothing is user-selectable.
* **No cryptographic services offered to other software.** No API, no URL scheme,
  no share extension, no keychain sharing group, no inter-process interface of any
  kind.
* **The cryptography is not the product's purpose from the user's side.** The user
  reads a document and sees whether it is genuine. There is no encryption feature,
  no key management interface, no file-encryption function.
* **Distribution.** Apple App Store, free of charge, to the general public, with
  no purchaser screening and no customisation for any customer. The functionality
  is identical for every user.
* **The source code is public and openly licensed.** The complete source,
  including everything cryptographic, is at
  `https://github.com/stevansen/IDReaderiOS` under the Apache License 2.0, with
  no registration, no fee and no access control. This has been the case since
  21 August 2026 — before that the repository was readable but unlicensed. It is
  raised here because the treatment of encryption source code that is publicly
  available differs from that of code which is not, and section 7 below asks
  which treatment applies. It is a fact, not a conclusion.
* **All algorithms are published standards.** Nothing proprietary, nothing
  non-standard: FIPS 197 (AES), FIPS 46-3 (DES/3DES), FIPS 180-4 (SHA-2),
  NIST SP 800-38B / RFC 4493 (CMAC), NIST SP 800-56A (ECDH), RFC 5639 (brainpool
  curves), PKCS#1 / FIPS 186-4 (RSA, ECDSA), RFC 5280, RFC 5652. Protocols:
  ICAO 9303, BSI TR-03110.

## 5. Third-party components

| Component | Version | Licence | Redistributed in the app? | Modified? |
|---|---|---|---|---|
| OpenSSL, via [OpenSSL-Package](https://github.com/krzyzanowskim/OpenSSL-Package) | 3.6.3 (arm64) | Apache-2.0 | Yes, as `OpenSSL.framework` | No |
| [NFCPassportReader](https://github.com/AndyQ/NFCPassportReader) | commit `6e37f1a` (tag 2.3.3) | MIT | Yes, as source | **Yes** — 3 of 39 files; see [`../ThirdParty/NFCPassportReaderCAN/UPSTREAM.md`](../ThirdParty/NFCPassportReaderCAN/UPSTREAM.md) |
| Apple CryptoKit, CommonCrypto, Security, CoreNFC, Vision | part of iOS | Apple SDK | No — provided by the operating system | No |

The modifications to NFCPassportReader add PACE with a CAN as the password; they
do not add, remove, or alter any cryptographic algorithm. The complete patch is in
the file cited above.

## 6. The question Apple asks at upload

> Welche Art von Verschlüsselungsalgorithmus verwendest du? / What type of
> encryption algorithm does your app use?

On the facts in section 3, the answer is:

> **Standard encryption algorithms instead of, or in addition to, the encryption
> used in or accessible from Apple's operating system.**

All algorithms are published standards (nothing proprietary or non-standard), and
OpenSSL is bundled **in addition to** Apple's implementations. Answering "none of
the above" was correct until PACE was added; it would require removing OpenSSL,
which would remove the ability to read the Italian identity card.

`ITSAppUsesNonExemptEncryption` is deliberately absent from `Config/Info.plist`, so
that App Store Connect asks each upload rather than a stale line answering for it.
Once documentation is approved and Apple issues a code, it belongs in that file as
`ITSEncryptionExportComplianceCode`, with `ITSAppUsesNonExemptEncryption` set to
`true`.

## 7. What remains to be decided, and by whom

Not engineering questions. Each is marked **to verify** because it depends on the
current regulatory text, which this document was written without.

1. **Classification.** Which ECCN applies — mass market encryption software or
   otherwise. *To verify against EAR Category 5, Part 2.*
2. **Filing route.** A classification request (CCATS) to BIS, or self-classification
   with reporting. *To verify against 15 CFR 742.15 and its supplements.*
3. **Encryption Registration.** Whether a one-time registration producing an ERN is
   required before relying on a licence exception. *To verify.*
3a. **The effect of the public, openly licensed source.** Publicly available
   encryption *source code* is treated differently from code that is not
   published, and the notification obligations differ accordingly — this may
   simplify the route or change it entirely. Note the distinction that matters
   here: the source is publicly available, while the **binary** in the App Store
   is a compiled object that Apple distributes. Whether one, both, or neither
   falls under the publicly-available treatment is *to verify* against
   15 CFR 734.7, 734.3(b)(3) and 742.15(b), and under EU Regulation 2021/821
   against the general note on publicly available software. Do not assume that
   open-sourcing the code removes an obligation.
4. **Recurring obligation.** If self-classification applies, an annual report is
   generally required rather than a one-time filing. Deadline and recipients *to
   verify* — do not take a remembered date from this document.
5. **France.** A separate national declaration may be required where the app is
   available. *To verify.*
6. **Italy / EU.** Dual-use export control under Regulation (EU) 2021/821 applies
   in parallel to the U.S. rules; whoever exports from the EU should confirm
   whether anything is owed there. This is the question most easily forgotten,
   because the Apple dialogue only asks about the U.S. side.

## 8. How to check any statement in this document

Everything above is verifiable in the source:

| Claim | Where |
|---|---|
| Archive encryption, algorithm and key length | `Sources/IDReaderCore/Archive/ArchiveCrypto.swift` |
| Key storage attributes | `Sources/IDReaderCore/Archive/KeychainArchiveKeyStore.swift` |
| Symmetric ciphers from CommonCrypto | `ThirdParty/NFCPassportReaderCAN/Sources/AES_3DES_DESEncryption.swift` |
| CMAC, EC operations, X.509, CMS from OpenSSL | `ThirdParty/NFCPassportReaderCAN/Sources/OpenSSLUtils.swift` |
| PACE, including the CAN password | `ThirdParty/NFCPassportReaderCAN/Sources/PACEHandler.swift` |
| Negotiable cipher and digest per ICAO | `ThirdParty/NFCPassportReaderCAN/Sources/DataGroups/PACEInfo.swift` |
| Trust anchors, public keys only | `Sources/IDReaderCore/Resources/csca/` |
| Licence of the source, and when it changed | `LICENSE`, `docs/LICENCE-CHOICE.md` |
| Network code confined to one file, and no hard-coded host | `Scripts/check-no-network.sh` |
| The single network operation | `App/Revocation/RevocationDownloader.swift` |
| Revocation-list signature verification (Apple `Security`) | `Sources/IDReaderCore/Revocation/RevocationListVerifier.swift` |
| The modifications to the vendored library | `ThirdParty/NFCPassportReaderCAN/UPSTREAM.patch` |

Prepared 21 August 2026, for version 1.8 (build 1), and revised the same day
twice: for the revocation check, which added the network operation described in
section 4, and for the move to the Apache License 2.0, which made the
cryptographic source publicly available under an open licence. It must be revised
again if the cryptographic functionality changes — in particular if
a JPEG 2000 decoder or any further third-party library is added.
