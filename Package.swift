// swift-tools-version: 6.0
//
// IDReaderCore - die UI-freie Haelfte der App.
//
// Bewusst ein eigenes Paket und kein Ordner im App-Ziel: alles hier drin laeuft
// ohne UIKit, ohne CoreNFC und ohne Geraet, also auch auf dem Mac unter
// `swift test`. Genau das war beim Android-Original der Grund, `LicenceScan`,
// `MrzScan` und `CanScan` frei von Framework-Bezuegen zu halten - die
// Rueckmeldungen aus dem Feld lassen sich so in Sekunden pruefen statt in
// Minuten auf einem Telefon.
//
// Was hier NICHT hineingehoert: CoreNFC, SwiftUI, UIKit, alles mit Bildschirm
// oder Chip. Das liegt im App-Ziel.

import PackageDescription

let package = Package(
    name: "IDReaderCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "IDReaderCore", targets: ["IDReaderCore"]),
    ],
    targets: [
        .target(
            name: "IDReaderCore",
            resources: [
                // Lokalisierte Kataloge. Sie liegen hier und nicht im App-Ziel,
                // weil der Ausgabetext (siehe DocumentExport) aus denselben
                // Zeichenketten gebaut wird wie die Oberflaeche. Zwei Kataloge
                // waeren zwei Wahrheiten. `process` legt sie als lokalisierte
                // Ressourcen ab.
                .process("Resources/en.lproj"),
                .process("Resources/de.lproj"),
                .process("Resources/it.lproj"),
                // Die Vertrauensanker unveraendert, mit ihrem Ordner. `copy` und
                // nicht `process`: es sind DER-Bytes, an denen nichts umgewandelt
                // werden darf, und der Unterordner soll bleiben.
                .copy("Resources/csca"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "IDReaderCoreTests",
            dependencies: ["IDReaderCore"],
            resources: [
                // Eine selbst erzeugte Pruefstelle mit eigener Sperrliste. Keine
                // echten Behoerdendaten, und ausdruecklich *nicht* eines der
                // hinterlegten CSCA-Zertifikate: die Tests sollen die Wege durch
                // Leser und Signaturpruefung abgehen, nicht die Echtheit einer
                // fremden Liste bezeugen.
                .copy("Fixtures"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
