# Third-party notices

What this software carries that its authors did not write. Nothing here is
covered by [`LICENSE`](LICENSE); each component keeps its own terms.

## In the current build

| Component | Licence | Why it is here |
|---|---|---|
| Italian CSCA certificates (`App/Resources/csca/*.der`) | public documents of the Italian state, redistributed unchanged | trust anchors for the Passive Authentication chain check. Extracted from the **BSI CSCA master list** (`GermanMasterList.zip`, Bundesamt für Sicherheit in der Informationstechnik), filtered to `C=IT`. The BSI publishes the list for exactly this purpose. |
| Apple SDK frameworks (SwiftUI, CoreNFC, Vision, CryptoKit, Security) | Apple SDK licence | the platform. Not redistributed. |
| swift-testing | Apache-2.0 with LLVM exception | test target only, ships with the toolchain, not in the app. |

No third-party Swift package is linked in the current build. That is a
deliberate state and not a permanent one — see the next section.

## Planned, once the PACE back end is wired up

The chip-reading path needs elliptic-curve arithmetic over **brainpoolP256r1**,
which CryptoKit does not provide. Rolling that by hand in an application that
reads identity documents would be the wrong call. The intended dependency:

| Component | Licence | Note |
|---|---|---|
| [NFCPassportReader](https://github.com/AndyQ/NFCPassportReader) | MIT, © 2019 Andy Qua | PACE / BAC, secure messaging, data-group parsing, Passive Authentication, Chip Authentication. **Lacks CAN-based PACE**, which the CIE needs; see [`docs/NFC-PACE.md`](docs/NFC-PACE.md) for the patch. |
| [OpenSSL-Package](https://github.com/krzyzanowskim/OpenSSL-Package) | Apache-2.0 (OpenSSL 3) | pulled in transitively by the above. |

MIT and Apache-2.0 both require the copyright notice and licence text to travel
with any redistribution. When either is linked, add its full licence text under
`ThirdParty/` and list it in the table above — a table entry alone does not
satisfy MIT.

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
  in-app equivalent, and the app takes no network access to build one.
