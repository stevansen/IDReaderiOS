// swift-tools-version: 5.9
//
// Die Werkzeugfassung ist mit Absicht 5.9 und nicht 6: damit gilt der
// Swift-5-Sprachmodus von selbst. Fremden Code an einen Modus anzupassen, den
// seine Fassung oben nicht kennt, waere eine Aenderung, die bei jedem
// Auffrischen neu zu machen waere.
//
// NFCPassportReaderCAN - fremder Code, gepatcht.
//
// Eine geaenderte Kopie von AndyQ/NFCPassportReader (MIT, siehe LICENSE).
// Herkunft, Begruendung und der vollstaendige Patch stehen in UPSTREAM.md.
//
// Ein eigenes Paket und kein Ziel im Wurzelpaket, und zwar aus einem
// handfesten Grund: dieser Code braucht CoreNFC, und CoreNFC gibt es auf dem
// Mac nicht. Waere er ein Ziel des Wurzelpakets, liesse sich `swift test`
// dort nicht mehr ausfuehren - und genau das ist der Grund, warum
// IDReaderCore ueberhaupt ein eigenes Paket ist.

import PackageDescription

let package = Package(
    name: "NFCPassportReaderCAN",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "NFCPassportReaderCAN", targets: ["NFCPassportReaderCAN"]),
    ],
    dependencies: [
        // OpenSSL, weil PACE bei der italienischen CIE ueber brainpoolP256r1
        // rechnet und CryptoKit diese Kurve nicht fuehrt. Dieselbe Abhaengigkeit
        // benutzt die Fassung oben; siehe docs/NFC-PACE.md fuer die Abwaegung.
        .package(
            url: "https://github.com/krzyzanowskim/OpenSSL-Package.git",
            .upToNextMinor(from: "3.6.3000")
        ),
    ],
    targets: [
        .target(
            name: "NFCPassportReaderCAN",
            dependencies: [
                .product(name: "OpenSSL", package: "OpenSSL-Package"),
            ],
            path: "Sources",
            resources: [.process("Resources")]
        ),
    ]
)
