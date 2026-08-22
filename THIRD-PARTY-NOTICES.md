# Third-party notices

What this software carries that its authors did not write. Nothing here is
covered by [`LICENSE`](LICENSE); each component keeps its own terms.

## In the current build

| Component | Licence | Why it is here |
|---|---|---|
| Italian CSCA certificates (`App/Resources/csca/*.der`) | public documents of the Italian state, redistributed unchanged | trust anchors for the Passive Authentication chain check. Extracted from the **BSI CSCA master list** (`GermanMasterList.zip`, Bundesamt für Sicherheit in der Informationstechnik), filtered to `C=IT`. The BSI publishes the list for exactly this purpose. |
| Apple SDK frameworks (SwiftUI, CoreNFC, Vision, CryptoKit, Security) | Apple SDK licence | the platform. Not redistributed. |
| swift-testing | Apache-2.0 with LLVM exception | test target only, ships with the toolchain, not in the app. |
| **NFCPassportReaderCAN** — a modified copy of [NFCPassportReader](https://github.com/AndyQ/NFCPassportReader) | **MIT, © 2019 Andy Qua** — full text at [`ThirdParty/NFCPassportReaderCAN/LICENSE`](ThirdParty/NFCPassportReaderCAN/LICENSE) | PACE / BAC, secure messaging, data-group parsing, Passive Authentication, Chip Authentication. Vendored under `ThirdParty/` because upstream **lacks CAN-based PACE**, which the CIE needs, and the place to change it is `internal`. Three of 39 files are modified; origin commit and the complete patch are in [`ThirdParty/NFCPassportReaderCAN/UPSTREAM.md`](ThirdParty/NFCPassportReaderCAN/UPSTREAM.md). |
| [OpenSSL-Package](https://github.com/krzyzanowskim/OpenSSL-Package) → OpenSSL 3.6 | Apache-2.0 | Elliptic-curve arithmetic over **brainpoolP256r1**, which CryptoKit does not provide. Pulled in by the above as a binary xcframework; not vendored. |

### What redistributing these obliges

* **MIT** requires the copyright notice and the licence text to travel with any
  copy or substantial portion. Satisfied: the verbatim upstream `LICENSE` sits
  next to the vendored source, the modified files carry a header saying so, and
  `UPSTREAM.md` records what was changed.
* **Apache-2.0** requires the licence, retention of notices, and a statement of
  changes. OpenSSL is linked unmodified as a binary artefact; SwiftPM fetches it
  at build time and it is not redistributed from this repository.

A published build must carry both licences in its acknowledgements. There is no
`Settings.bundle` yet — that is a gap to close before any release, not a
formality.

## What the Android original carried and this port does not

Recorded because the reasoning cost effort and would otherwise be lost:

* **JMRTD 0.8.1** (LGPL-3.0) and **SCUBA** — the MRTD stack. Replaced by the
  planned dependency above.
* **BouncyCastle** `bcprov-jdk18on` / `bcutil-jdk18on` (MIT-style) — the JCE
  provider. Replaced by CryptoKit plus, for brainpool, OpenSSL.
* **`dev.keiji.jp2:jp2-android` 1.0.5** (BSD-2-Clause) — OpenJPEG 2.5.2 for the
  JPEG 2000 facial image in DG2. iOS has no public JPEG 2000 decoder either;
  see [`docs/ANDROID-TO-IOS.md`](docs/ANDROID-TO-IOS.md).
* **ML Kit text recognition** `16.0.1` (Google APIs ToS) — replaced by Apple's
  Vision framework, which is part of the platform and needs no bundled model.
* **Material Symbols** `verified` / `verified_off` (Apache-2.0, vendored as
  vector drawables) — replaced by SF Symbols (`checkmark.seal.fill`,
  `xmark.seal.fill`), part of the platform.
* **Play Core `app-update-ktx`** (Android Software Development Kit Licence) —
  forced update through the Play Store. No counterpart: the App Store has no
  in-app equivalent, and the app adds no network access to build one. (It has
  exactly one, for the revocation list — see `docs/DATA-PROTECTION.md`.)
