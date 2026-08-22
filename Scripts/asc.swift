// Der Store-Eintrag über die App Store Connect API statt über Klicken.
//
//     ASC_KEY_ID=… ASC_ISSUER_ID=… swift Scripts/asc.swift <Befehl>
//
// Befehle:
//   show                 Was heute im Eintrag steht
//   set-version <x.y>    Die Fassungsnummer des Datensatzes „in Vorbereitung"
//   metadata             store/<locale>/* in den Eintrag schreiben
//   category <ID>        Hauptkategorie setzen, z. B. UTILITIES
//   screenshots          store/screenshots/* hochladen
//
// ## Warum ein eigenes Werkzeug und nicht der Browser
//
// Drei Sprachen mal sechs Felder mal Bildschirmfotos sind von Hand eine Stunde
// Tippen und danach nicht nachvollziehbar. Vor allem aber: `store/` war bis
// jetzt ein Ordner, den niemand angewendet hat. Mit diesem Werkzeug ist er die
// Quelle, der Eintrag das Abbild, und ein `git diff` zeigt, was sich am
// Ladenschild geändert hat.
//
// Es ist absichtlich wiederholbar: jeder Lauf schreibt denselben Zustand.
//
// ## Der Schlüssel
//
// Liegt als ~/.appstoreconnect/private_keys/AuthKey_<Kennung>.p8 und wird hier
// **über seinen Pfad** gelesen, nie über eine Kommandozeile und nie ausgegeben.
// Auch der erzeugte Token wird nicht ausgegeben - er ist zwanzig Minuten lang
// ein Vollzugriff auf das Konto.

import CryptoKit
import Foundation

// ---------------------------------------------------------------------------
// Zugang
// ---------------------------------------------------------------------------

struct Fehler: Error, CustomStringConvertible {
    let description: String
    init(_ text: String) { description = text }
}

func env(_ name: String) throws -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        throw Fehler("""
            \(name) ist nicht gesetzt.

            Beide Angaben stehen in App Store Connect unter Benutzer und Zugriff →
            Integrationen → App Store Connect API. Keine von beiden gehört in das
            Repository: es ist öffentlich.
            """)
    }
    return value
}

func base64url(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

/// Baut den Token. Gültigkeit zwanzig Minuten - das ist Apples Obergrenze.
func token() throws -> String {
    let keyID = try env("ASC_KEY_ID")
    let issuer = try env("ASC_ISSUER_ID")

    let home = FileManager.default.homeDirectoryForCurrentUser
    let path = home
        .appendingPathComponent(".appstoreconnect/private_keys")
        .appendingPathComponent("AuthKey_\(keyID).p8")
    guard let pem = try? String(contentsOf: path, encoding: .utf8) else {
        throw Fehler("Kein Schlüssel AuthKey_\(keyID).p8 in ~/.appstoreconnect/private_keys/.")
    }
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)

    let now = Int(Date().timeIntervalSince1970)
    let header = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
    let payload: [String: Any] = [
        "iss": issuer,
        "iat": now,
        "exp": now + 20 * 60,
        "aud": "appstoreconnect-v1",
    ]
    let head = base64url(try JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]))
    let body = base64url(try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]))
    let signing = Data("\(head).\(body)".utf8)
    let signature = try key.signature(for: signing)
    return "\(head).\(body).\(base64url(signature.rawRepresentation))"
}

// ---------------------------------------------------------------------------
// HTTP
// ---------------------------------------------------------------------------

let base = URL(string: "https://api.appstoreconnect.apple.com/v1/")!
let bearer = try token()

@discardableResult
func call(
    _ method: String,
    _ pathAndQuery: String,
    body: [String: Any]? = nil,
    absolute: String? = nil,
    raw: Data? = nil,
    headers: [String: String] = [:]
) async throws -> [String: Any] {
    let url = absolute.flatMap(URL.init(string:)) ?? URL(string: pathAndQuery, relativeTo: base)!
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
    if let raw {
        request.httpBody = raw
    } else if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
    }

    let (data, response) = try await URLSession.shared.data(for: request)
    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
    guard (200..<300).contains(code) else {
        let text = String(data: data, encoding: .utf8) ?? ""
        throw Fehler("HTTP \(code) auf \(method) \(url.path)\n\(text)")
    }
    if data.isEmpty { return [:] }
    return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

func rows(_ json: [String: Any]) -> [[String: Any]] {
    json["data"] as? [[String: Any]] ?? []
}
func one(_ json: [String: Any]) -> [String: Any] {
    json["data"] as? [String: Any] ?? [:]
}
func attr(_ row: [String: Any], _ name: String) -> String {
    (row["attributes"] as? [String: Any])?[name] as? String ?? ""
}
func ident(_ row: [String: Any]) -> String { row["id"] as? String ?? "" }

// ---------------------------------------------------------------------------
// store/ lesen
// ---------------------------------------------------------------------------

let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let storeDir = repoRoot.appendingPathComponent("store")

/// Die Sprachen, wie App Store Connect sie nennt, und der Ordner dazu.
let sprachen: [(locale: String, ordner: String)] = [
    ("de-DE", "de-DE"),
    ("en-US", "en-US"),
    ("it", "it"),
]

func feld(_ ordner: String, _ name: String) -> String? {
    let url = storeDir.appendingPathComponent(ordner).appendingPathComponent("\(name).txt")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

let appID = ProcessInfo.processInfo.environment["ASC_APP_ID"] ?? "6803925048"

// ---------------------------------------------------------------------------
// Die Datensätze finden
// ---------------------------------------------------------------------------

/// Die iOS-Fassung, die noch nicht veröffentlicht ist.
func inflightVersion() async throws -> [String: Any] {
    let json = try await call(
        "GET",
        "apps/\(appID)/appStoreVersions?filter[platform]=IOS&limit=20"
    )
    let offen: Set<String> = [
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
        "METADATA_REJECTED", "WAITING_FOR_REVIEW", "IN_REVIEW",
        "DEVELOPER_REMOVED_FROM_SALE", "READY_FOR_REVIEW",
    ]
    for row in rows(json) where offen.contains(attr(row, "appStoreState")) {
        return row
    }
    guard let first = rows(json).first else { throw Fehler("Keine iOS-Fassung gefunden.") }
    return first
}

func appInfoID() async throws -> String {
    let json = try await call("GET", "apps/\(appID)/appInfos?limit=10")
    // Der Datensatz, der noch bearbeitbar ist.
    for row in rows(json) {
        let state = attr(row, "appStoreState")
        if state != "READY_FOR_SALE" { return ident(row) }
    }
    guard let first = rows(json).first else { throw Fehler("Kein appInfo gefunden.") }
    return ident(first)
}

// ---------------------------------------------------------------------------
// Befehle
// ---------------------------------------------------------------------------

func zeigeStand() async throws {
    let version = try await inflightVersion()
    print("Fassung   \(attr(version, "versionString"))   \(attr(version, "appStoreState"))")

    let info = try await appInfoID()
    let infoJSON = try await call("GET", "appInfos/\(info)?include=primaryCategory")
    let included = infoJSON["included"] as? [[String: Any]] ?? []
    let kategorie = included.first { $0["type"] as? String == "appCategories" }
    print("Kategorie \(kategorie.map(ident) ?? "— nicht gesetzt —")")

    print("\nApp-Informationen je Sprache (Name, Untertitel, Datenschutz-URL):")
    for row in rows(try await call("GET", "appInfos/\(info)/appInfoLocalizations?limit=50")) {
        let locale = attr(row, "locale")
        let name = attr(row, "name")
        let sub = attr(row, "subtitle")
        let url = attr(row, "privacyPolicyUrl")
        print("  \(locale.padding(toLength: 8, withPad: " ", startingAt: 0)) "
              + "\(name.isEmpty ? "—" : name) | "
              + "\(sub.isEmpty ? "—" : sub) | \(url.isEmpty ? "—" : url)")
    }

    print("\nFassungstexte je Sprache:")
    for row in rows(
        try await call("GET", "appStoreVersions/\(ident(version))/appStoreVersionLocalizations?limit=50")
    ) {
        let locale = attr(row, "locale")
        let beschreibung = attr(row, "description")
        let stichworte = attr(row, "keywords")
        let support = attr(row, "supportUrl")
        print("  \(locale.padding(toLength: 8, withPad: " ", startingAt: 0)) "
              + "Beschreibung \(beschreibung.isEmpty ? "— leer —" : "\(beschreibung.count) Zeichen") | "
              + "Stichworte \(stichworte.isEmpty ? "— leer —" : stichworte) | "
              + "Support \(support.isEmpty ? "—" : support)")

        for set in rows(
            try await call("GET", "appStoreVersionLocalizations/\(ident(row))/appScreenshotSets?limit=20")
        ) {
            let art = attr(set, "screenshotDisplayType")
            let bilder = rows(try await call("GET", "appScreenshotSets/\(ident(set))/appScreenshots?limit=20"))
            print("           \(art): \(bilder.count) Bilder")
        }
    }
}

func setzeFassung(_ neu: String) async throws {
    let version = try await inflightVersion()
    let alt = attr(version, "versionString")
    guard alt != neu else { print("Fassung steht schon auf \(neu)."); return }
    try await call("PATCH", "appStoreVersions/\(ident(version))", body: [
        "data": [
            "type": "appStoreVersions",
            "id": ident(version),
            "attributes": ["versionString": neu],
        ],
    ])
    print("Fassung \(alt) → \(neu)")
}

func setzeKategorie(_ kennung: String) async throws {
    let info = try await appInfoID()
    try await call("PATCH", "appInfos/\(info)", body: [
        "data": [
            "type": "appInfos",
            "id": info,
            "relationships": [
                "primaryCategory": ["data": ["type": "appCategories", "id": kennung]],
            ],
        ],
    ])
    print("Hauptkategorie → \(kennung)")
}

/// Die Texte. Was in `store/` fehlt, wird nicht angetastet - ein leeres Feld
/// hier soll nicht ein gefülltes dort löschen.
func setzeTexte() async throws {
    let version = try await inflightVersion()
    let versionID = ident(version)
    let info = try await appInfoID()

    let vorhandeneInfo = Dictionary(
        uniqueKeysWithValues: rows(
            try await call("GET", "appInfos/\(info)/appInfoLocalizations?limit=50")
        ).map { (attr($0, "locale"), ident($0)) }
    )
    /// Frisch nachfragen, und zwar je Sprache.
    ///
    /// Eine Sprache in den App-Informationen anzulegen legt die
    /// Fassungsuebersetzung **mit** an. Eine Liste, die vor dem Anlegen geholt
    /// wurde, ist danach falsch, und der Versuch anzulegen endet in
    /// „409 already exists. Try updating." - genau so gesehen.
    func fassungsUebersetzung(_ locale: String) async throws -> String? {
        rows(
            try await call(
                "GET",
                "appStoreVersions/\(versionID)/appStoreVersionLocalizations?limit=50"
            )
        ).first { attr($0, "locale") == locale }.map(ident)
    }

    let supportURL = "https://github.com/stevansen/IDReaderiOS"

    // Welche Sprache die Hauptsprache ist, entscheidet, wo der **Name** stehen
    // darf.
    //
    // Er ist im App Store je Sprache eindeutig, und „IDReader" ist fuer en-US
    // schon von einem fremden Konto belegt - der Versuch endete in „The app name
    // you entered is already being used". Fuer die Nebensprachen braucht es ihn
    // auch nicht: fehlt er dort, zeigt der Store den Namen der Hauptsprache, und
    // genau das ist gewollt. Der Name der App ist in allen drei `name.txt`
    // derselbe.
    let appRow = one(try await call("GET", "apps/\(appID)"))
    let hauptsprache = attr(appRow, "primaryLocale")
    print("Hauptsprache: \(hauptsprache) - nur dort wird der Name gesetzt")

    for (locale, ordner) in sprachen {
        // --- Name, Untertitel: hängen an der App, nicht an der Fassung -----
        var infoFelder: [String: Any] = [:]
        if locale == hauptsprache, let name = feld(ordner, "name") {
            infoFelder["name"] = name
        }
        if let sub = feld(ordner, "subtitle") { infoFelder["subtitle"] = sub }

        if let id = vorhandeneInfo[locale] {
            if !infoFelder.isEmpty {
                try await call("PATCH", "appInfoLocalizations/\(id)", body: [
                    "data": ["type": "appInfoLocalizations", "id": id, "attributes": infoFelder],
                ])
            }
        } else {
            // Beim Anlegen verlangt Apple einen Namen, und der ist je Sprache
            // eindeutig. Fuer eine Nebensprache ist das eine Zwickmuehle: den
            // Namen der Hauptsprache darf man nicht nehmen, wenn ihn dort schon
            // jemand hat, und einen anderen erfindet ein Programm nicht.
            //
            // Also: melden und weitermachen. Die Fassungstexte - Beschreibung,
            // Stichworte, Werbetext - haengen nicht daran.
            infoFelder["locale"] = locale
            if infoFelder["name"] == nil {
                infoFelder["name"] = feld(ordner, "name") ?? "IDReader"
            }
            do {
                try await call("POST", "appInfoLocalizations", body: [
                    "data": [
                        "type": "appInfoLocalizations",
                        "attributes": infoFelder,
                        "relationships": ["appInfo": ["data": ["type": "appInfos", "id": info]]],
                    ],
                ])
            } catch {
                print("""
                    \(locale): Sprache NICHT angelegt.
                    \(error)
                    """)
                continue
            }
        }

        // --- Beschreibung, Stichworte, Werbetext: an der Fassung -----------
        var versionFelder: [String: Any] = ["supportUrl": supportURL]
        if let text = feld(ordner, "description") { versionFelder["description"] = text }
        if let text = feld(ordner, "keywords") { versionFelder["keywords"] = text }
        if let text = feld(ordner, "promotional-text") { versionFelder["promotionalText"] = text }
        // „Neuheiten" bleibt aussen vor, solange keine Fassung veroeffentlicht
        // ist: bei der ersten gibt es nichts, das neu waere, und Apple weist das
        // Feld dort ab. `store/*/whats-new.txt` liegt fuer die zweite bereit.

        if let id = try await fassungsUebersetzung(locale) {
            try await call("PATCH", "appStoreVersionLocalizations/\(id)", body: [
                "data": [
                    "type": "appStoreVersionLocalizations",
                    "id": id,
                    "attributes": versionFelder,
                ],
            ])
            print("\(locale): Texte aktualisiert")
        } else {
            versionFelder["locale"] = locale
            try await call("POST", "appStoreVersionLocalizations", body: [
                "data": [
                    "type": "appStoreVersionLocalizations",
                    "attributes": versionFelder,
                    "relationships": [
                        "appStoreVersion": [
                            "data": ["type": "appStoreVersions", "id": versionID],
                        ],
                    ],
                ],
            ])
            print("\(locale): Texte angelegt")
        }
    }
}

// ---------------------------------------------------------------------------
// Bildschirmfotos
// ---------------------------------------------------------------------------

/// Welche Bildergröße in welchen Anzeigetyp gehört. Apple prüft die Pixelmaße;
/// ein falscher Typ wird abgewiesen, nicht stillschweigend umgerechnet.
func anzeigeTyp(breite: Int, hoehe: Int) -> String? {
    switch (breite, hoehe) {
    // 6,9 Zoll hat keinen eigenen Typ: die API kennt kein `APP_IPHONE_69`
    // (durchprobiert, sie listet die zulaessigen Werte im Fehler auf). Apple
    // nimmt 1320 × 2868 im 6,7-Zoll-Fach an - dort heisst das Fach im Store
    // „6,7 Zoll oder 6,9 Zoll".
    case (1320, 2868), (2868, 1320): return "APP_IPHONE_67"
    case (1290, 2796), (2796, 1290): return "APP_IPHONE_67"
    case (1242, 2688), (2688, 1242): return "APP_IPHONE_65"
    case (1284, 2778), (2778, 1284): return "APP_IPHONE_65"
    case (1242, 2208), (2208, 1242): return "APP_IPHONE_55"
    default: return nil
    }
}

func pixelmasse(_ url: URL) -> (Int, Int)? {
    guard let data = try? Data(contentsOf: url), data.count > 24 else { return nil }
    // PNG: Breite und Höhe stehen als Big-Endian-Wörter im IHDR ab Byte 16.
    let png: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
    guard Array(data.prefix(4)) == png else { return nil }
    func wort(_ offset: Int) -> Int {
        var value = 0
        for i in 0..<4 { value = value << 8 | Int(data[offset + i]) }
        return value
    }
    return (wort(16), wort(20))
}

func ladeBilder() async throws {
    let version = try await inflightVersion()
    let vorhandene = Dictionary(
        uniqueKeysWithValues: rows(
            try await call("GET", "appStoreVersions/\(ident(version))/appStoreVersionLocalizations?limit=50")
        ).map { (attr($0, "locale"), ident($0)) }
    )

    // store/screenshots/<groesse>-<sprache>/NN-name.png
    let ordnerListe = (try? FileManager.default.contentsOfDirectory(
        at: storeDir.appendingPathComponent("screenshots"),
        includingPropertiesForKeys: nil
    )) ?? []

    let sprachKuerzel: [String: String] = ["de": "de-DE", "en": "en-US", "it": "it"]

    for ordner in ordnerListe.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let name = ordner.lastPathComponent
        guard let kuerzel = name.split(separator: "-").last.map(String.init),
              let locale = sprachKuerzel[kuerzel],
              let localizationID = vorhandene[locale] else {
            print("\(name): übersprungen - keine Sprache dazu im Eintrag")
            continue
        }

        let bilder = ((try? FileManager.default.contentsOfDirectory(
            at: ordner, includingPropertiesForKeys: nil
        )) ?? []).filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let erstes = bilder.first, let (breite, hoehe) = pixelmasse(erstes),
              let typ = anzeigeTyp(breite: breite, hoehe: hoehe) else {
            print("\(name): übersprungen - Pixelmaße nicht erkannt oder nicht zugelassen")
            continue
        }

        // Der Satz für diesen Anzeigetyp: vorhandenen nehmen, sonst anlegen.
        var setID = rows(
            try await call("GET", "appStoreVersionLocalizations/\(localizationID)/appScreenshotSets?limit=20")
        ).first { attr($0, "screenshotDisplayType") == typ }.map(ident)

        if setID == nil {
            let neu = try await call("POST", "appScreenshotSets", body: [
                "data": [
                    "type": "appScreenshotSets",
                    "attributes": ["screenshotDisplayType": typ],
                    "relationships": [
                        "appStoreVersionLocalization": [
                            "data": [
                                "type": "appStoreVersionLocalizations",
                                "id": localizationID,
                            ],
                        ],
                    ],
                ],
            ])
            setID = ident(one(neu))
        }
        guard let satz = setID else { continue }

        // Wiederholbar: was schon im Satz liegt, wird weggeräumt, damit nicht
        // bei jedem Lauf dieselben Bilder ein zweites Mal erscheinen.
        for alt in rows(try await call("GET", "appScreenshotSets/\(satz)/appScreenshots?limit=30")) {
            try await call("DELETE", "appScreenshots/\(ident(alt))")
        }

        for bild in bilder {
            let daten = try Data(contentsOf: bild)
            let reservierung = try await call("POST", "appScreenshots", body: [
                "data": [
                    "type": "appScreenshots",
                    "attributes": [
                        "fileSize": daten.count,
                        "fileName": bild.lastPathComponent,
                    ],
                    "relationships": [
                        "appScreenshotSet": [
                            "data": ["type": "appScreenshotSets", "id": satz],
                        ],
                    ],
                ],
            ])
            let satzDaten = one(reservierung)
            let bildID = ident(satzDaten)
            let operationen = (satzDaten["attributes"] as? [String: Any])?["uploadOperations"]
                as? [[String: Any]] ?? []

            for operation in operationen {
                guard let url = operation["url"] as? String,
                      let method = operation["method"] as? String,
                      let offset = operation["offset"] as? Int,
                      let length = operation["length"] as? Int else { continue }
                var kopf: [String: String] = [:]
                for eintrag in operation["requestHeaders"] as? [[String: Any]] ?? [] {
                    if let n = eintrag["name"] as? String, let v = eintrag["value"] as? String {
                        kopf[n] = v
                    }
                }
                let teil = daten.subdata(in: offset..<(offset + length))
                var request = URLRequest(url: URL(string: url)!)
                request.httpMethod = method
                for (n, v) in kopf { request.setValue(v, forHTTPHeaderField: n) }
                let (_, antwort) = try await URLSession.shared.upload(for: request, from: teil)
                let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(code) else {
                    throw Fehler("Hochladen von \(bild.lastPathComponent) gab HTTP \(code)")
                }
            }

            let summe = Insecure.MD5.hash(data: daten).map { String(format: "%02x", $0) }.joined()
            try await call("PATCH", "appScreenshots/\(bildID)", body: [
                "data": [
                    "type": "appScreenshots",
                    "id": bildID,
                    "attributes": ["uploaded": true, "sourceFileChecksum": summe],
                ],
            ])
        }
        print("\(name) → \(locale) / \(typ): \(bilder.count) Bilder")
    }
}

// ---------------------------------------------------------------------------
// Bedienungshilfen-Angaben
// ---------------------------------------------------------------------------

/// Setzt die Angaben, die der Store neben der App zeigt.
///
/// **Angekreuzt wird nur, was belegt ist.** Die Grundlage steht in
/// `docs/ACCESSIBILITY.md`, und was dort unter „Was offen ist" steht, bleibt
/// hier falsch:
///
/// * Vorlesefunktion - die Beschriftungen sind da, aber am Geraet mit
///   eingeschaltetem VoiceOver ist nichts durchgesprochen. Der Simulator zeigt
///   die Beschriftungen, nicht die Reihenfolge, in der man sie hoert.
/// * Bewegung reduzieren - der Uebergang zwischen den Masken haengt nicht an
///   `accessibilityReduceMotion`.
/// * Sprachsteuerung - ungeprueft.
/// * Untertitel und Audiodeskription - die App hat keine Medien.
///
/// Eine falsche Angabe hier waere nicht ein Haken zu viel: sie steht im Store
/// und jemand richtet sich danach.
func setzeBedienungshilfen(veroeffentlichen: Bool) async throws {
    let angaben: [String: Any] = [
        "supportsLargerText": true,
        "supportsSufficientContrast": true,
        "supportsDifferentiateWithoutColorAlone": true,
        "supportsDarkInterface": true,
        "supportsVoiceover": false,
        "supportsVoiceControl": false,
        "supportsReducedMotion": false,
        "supportsCaptions": false,
        "supportsAudioDescriptions": false,
    ]

    // Nur iPhone. Der Bau laeuft auch auf dem iPad - `CFBundleIcons~ipad` ist
    // gesetzt -, aber geprueft wurde dort nichts. Ein erster Lauf hatte die
    // iPad-Angabe mit denselben Werten angelegt; sie ist wieder geloescht. Eine
    // Angabe, die von einer nicht geprueften Geraeteklasse behauptet, was auf
    // einer anderen geprueft wurde, ist genau der Fehler, den dieser Kommentar
    // sonst anderen vorwirft.
    let vorhandene = rows(try await call("GET", "apps/\(appID)/accessibilityDeclarations?limit=50"))
    for familie in ["IPHONE"] {
        var felder = angaben
        if let row = vorhandene.first(where: {
            ($0["attributes"] as? [String: Any])?["deviceFamily"] as? String == familie
        }) {
            try await call("PATCH", "accessibilityDeclarations/\(ident(row))", body: [
                "data": [
                    "type": "accessibilityDeclarations",
                    "id": ident(row),
                    "attributes": felder,
                ],
            ])
            print("\(familie): Angaben aktualisiert")
        } else {
            felder["deviceFamily"] = familie
            let neu = try await call("POST", "accessibilityDeclarations", body: [
                "data": [
                    "type": "accessibilityDeclarations",
                    "attributes": felder,
                    "relationships": ["app": ["data": ["type": "apps", "id": appID]]],
                ],
            ])
            print("\(familie): Angaben angelegt (\(ident(one(neu))))")
        }
    }

    guard veroeffentlichen else {
        print("Als Entwurf gespeichert. Zum Veroeffentlichen: accessibility --publish")
        return
    }
    for row in rows(try await call("GET", "apps/\(appID)/accessibilityDeclarations?limit=50")) {
        try await call("PATCH", "accessibilityDeclarations/\(ident(row))", body: [
            "data": [
                "type": "accessibilityDeclarations",
                "id": ident(row),
                "attributes": ["state": "PUBLISHED"],
            ],
        ])
    }
    print("Veroeffentlicht.")
}

// ---------------------------------------------------------------------------

let argumente = Array(CommandLine.arguments.dropFirst())
guard let befehl = argumente.first else {
    print("""
        Befehl fehlt. Möglich sind:
          show                 Was heute im Eintrag steht
          set-version <x.y>    Fassungsnummer setzen
          metadata             store/<locale>/* schreiben
          category <ID>        Hauptkategorie, z. B. UTILITIES
          screenshots          store/screenshots/* hochladen
        """)
    exit(2)
}

do {
    switch befehl {
    case "show": try await zeigeStand()
    case "set-version":
        guard argumente.count > 1 else { throw Fehler("Fassungsnummer fehlt.") }
        try await setzeFassung(argumente[1])
    case "metadata": try await setzeTexte()
    case "category":
        guard argumente.count > 1 else { throw Fehler("Kategorie fehlt.") }
        try await setzeKategorie(argumente[1])
    case "screenshots": try await ladeBilder()
    case "accessibility":
        try await setzeBedienungshilfen(veroeffentlichen: argumente.contains("--publish"))
    case "delete":
        guard argumente.count > 1 else { throw Fehler("Pfad fehlt.") }
        try await call("DELETE", argumente[1])
        print("Geloescht: \(argumente[1])")
    case "get":
        // Notausgang zum Nachsehen: `get apps/<id>/…`. Nuetzlich, um einen
        // Endpunkt zu pruefen, bevor man einen Befehl dafuer schreibt.
        guard argumente.count > 1 else { throw Fehler("Pfad fehlt.") }
        let json = try await call("GET", argumente[1])
        let daten = try JSONSerialization.data(
            withJSONObject: json, options: [.prettyPrinted, .sortedKeys]
        )
        print(String(data: daten, encoding: .utf8) ?? "")
    default: throw Fehler("Unbekannter Befehl: \(befehl)")
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
