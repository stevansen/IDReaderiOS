import Foundation

/// Liest die Felder einer italienischen Fahrerlaubnis aus erkanntem Text.
///
/// Grundlage ist die Nummerierung aus Anhang I der Richtlinie 2006/126/EG: die
/// Angaben auf der Vorderseite tragen gedruckte Nummern - 1 Nachname, 2 Vorname,
/// 3 Geburtsdatum und -ort, 4a Ausstellungsdatum, 4b Ablaufdatum, 4c ausstellende
/// Stelle, 5 Nummer des Dokuments, 9 Klassen. Feld 7 ist die Unterschrift und
/// traegt keinen Text.
///
/// Zwei Dinge unterscheiden diese Auswertung grundlegend von den beiden anderen:
///
/// - **Es gibt nichts zu pruefen.** Die Karte hat keinen Chip, keine
///   maschinenlesbare Zone, keinen Strichcode. Der abschliessende Buchstabe der
///   Nummer ist zwar amtlich ein Pruefzeichen (Rundschreiben des MIT vom
///   18.10.2011), aber sein Verfahren ist nie veroeffentlicht worden. Es gibt
///   folglich keine Pruefziffer, an der eine Erkennung scheitern koennte.
/// - **Ein Lesefehler faellt nicht auf.** Bei der CAN zeigt sich ein Irrtum
///   spaetestens, wenn der Chip sich nicht oeffnet. Hier oeffnet sich nichts. An
///   echten Aufnahmen gemessen: aus dem B in der Nummer wurde eine 8, und nichts
///   an der Zeichenkette verriet das.
///
/// Daraus folgt der Massstab, an dem dieser Typ gebaut ist: **ein falscher Wert
/// ist schlimmer als ein leeres Feld.** Ein leeres Feld sieht der Benutzer und
/// fuellt es. Ein plausibel gefuelltes sieht er nur, wenn er genau hinschaut.
///
/// ## Wie gelesen wird
///
/// Die naheliegende Bauart - Etikett gefunden, also ist der Rest der Zeile der
/// Wert - traegt hier nicht. An acht vermessenen Aufnahmen (siehe
/// `LicenceScanCorpus` im Testziel) zeigte sich:
///
/// - Die Erkennung liefert die Bloecke in einer Reihenfolge, die mit dem Aufbau
///   der Karte nichts zu tun hat. Der Wert stand mal hinter dem Etikett, mal eine
///   Zeile darunter, mal eine Zeile **darueber**.
/// - Etiketten kommen zerlesen an: aus `4b.` wurde `40.`, `4o.`, `G0.`; aus `2.`
///   wurde eine nackte `2` ohne Punkt.
/// - Die Karte ist mit mehrsprachigem Kleindruck bedeckt, der als Buchstabensalat
///   durchkommt. Eine Aufnahme bestand fast nur daraus.
///
/// Deshalb sucht diese Auswertung nicht **an einer Stelle**, sondern waehlt unter
/// mehreren Kandidaten den aus, der **die Form des gesuchten Feldes hat**. Ein
/// Ablaufdatum muss ein vierstelliges Jahr tragen, eine Dokumentnummer zehn
/// Zeichen aus Buchstaben und Ziffern, ein Name Grossbuchstaben. Was nicht passt,
/// wird verworfen, auch wenn es unmittelbar hinter dem Etikett steht.
public enum LicenceScan {

    /// Die Felder der Vorderseite, so gut sie sich lesen liessen.
    ///
    /// Jedes Feld einzeln optional: die Erkennung verliert regelmaessig einzelne
    /// Zeilen, und ein fehlendes Ablaufdatum darf nicht die uebrigen acht
    /// Angaben mitnehmen.
    public struct Fields: Sendable, Equatable {
        public var surname: String?
        public var givenNames: String?
        public var dateOfBirth: String?
        public var placeOfBirth: String?
        public var dateOfIssue: String?
        public var dateOfExpiry: String?
        public var issuingAuthority: String?
        public var number: String?
        public var categories: String?

        public init(
            surname: String? = nil,
            givenNames: String? = nil,
            dateOfBirth: String? = nil,
            placeOfBirth: String? = nil,
            dateOfIssue: String? = nil,
            dateOfExpiry: String? = nil,
            issuingAuthority: String? = nil,
            number: String? = nil,
            categories: String? = nil
        ) {
            self.surname = surname
            self.givenNames = givenNames
            self.dateOfBirth = dateOfBirth
            self.placeOfBirth = placeOfBirth
            self.dateOfIssue = dateOfIssue
            self.dateOfExpiry = dateOfExpiry
            self.issuingAuthority = issuingAuthority
            self.number = number
            self.categories = categories
        }

        /// Ob ueberhaupt etwas gefunden wurde.
        public var isEmpty: Bool {
            [surname, givenNames, dateOfBirth, placeOfBirth,
             dateOfIssue, dateOfExpiry, issuingAuthority, number, categories]
                .allSatisfy { ($0 ?? "").trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }

    /// Wertet erkannten Text aus.
    public static func read(_ recognisedText: String) -> Fields {
        let page = Page(lines: recognisedText.nonEmptyTrimmedLines)

        // Alle Felder gemeinsam, ringweise von innen nach aussen. Die Reihenfolge
        // in dieser Aufzaehlung entscheidet nur bei gleichem Abstand.
        let found = page.assign([
            (fieldSurname, asName),
            (fieldGivenNames, asName),
            (fieldBirth, asBirthText),
            (fieldIssue, asFullDate),
            (fieldExpiry, asFullDate),
            (fieldAuthority, asAuthority),
            (fieldNumber, asNumber),
            (fieldCategories, asCategories),
        ])

        let surname = found[fieldSurname]
        let birth = page.completeBirth(found[fieldBirth].flatMap(asBirth))
        let (issue, expiry) = page.issueAndExpiry(found[fieldIssue], found[fieldExpiry])

        return Fields(
            surname: surname,
            givenNames: found[fieldGivenNames] ?? page.rescueGivenNames(surname: surname),
            dateOfBirth: bornBefore(birth: birth?.date, issue: issue),
            placeOfBirth: birth?.place,
            dateOfIssue: issue,
            dateOfExpiry: expiry,
            issuingAuthority: found[fieldAuthority],
            number: found[fieldNumber] ?? page.rescueNumber(),
            categories: found[fieldCategories]
        )
    }

    // -----------------------------------------------------------------------
    // Die Seite
    // -----------------------------------------------------------------------

    /// Der erkannte Text mit seinen Etiketten, und was davon schon vergeben ist.
    ///
    /// Die Buchfuehrung ueber das Vergebene ist kein Beiwerk. Ohne sie holt sich
    /// das zweite Feld den Wert des ersten: gemessen an einer Aufnahme, auf der
    /// die nackten Etiketten `2` und `3` untereinander standen und darueber
    /// `1. RAAB` - der Vorname waere der Nachname geworden.
    private final class Page {
        /// Zeichenweise, weil die Zuteilung mit Spaltenbereichen arbeitet.
        let lines: [[Character]]
        /// Etiketten je Zeile, in der Reihenfolge ihres Auftretens.
        private let labels: [[Label]]
        /// Bereits vergebene Textstuecke, als Zeile und Spaltenbereich.
        private var claimed: [Claim] = []

        init(lines: [String]) {
            self.lines = lines.map(Array.init)
            self.labels = lines.map(LicenceScan.labelsIn)
        }

        /// Verteilt die Werte auf die Felder, ringweise von innen nach aussen.
        ///
        /// Erst bekommt **jedes** Feld die Zeile unmittelbar bei seinem Etikett,
        /// dann jedes die uebernaechste, und so fort. Der naheliegende Aufbau -
        /// ein Feld sucht seinen Umkreis vollstaendig ab, dann das naechste - ist
        /// falsch: das zuerst behandelte Feld greift sich dann einen Wert vier
        /// Zeilen entfernt, obwohl er unmittelbar neben dem Etikett eines anderen
        /// steht. Gemessen an einer verschobenen Fassung der Aufnahme B4
        /// tauschten so Nachname und Vorname die Plaetze - zwei richtige Namen in
        /// den falschen Feldern, und nichts an ihnen sieht falsch aus.
        ///
        /// Innerhalb eines Rings zaehlt die Reihenfolge der Aufzaehlung, und nach
        /// vorn wird weiter gesucht als zurueck: dort steht der Wert oefter.
        ///
        /// Diese Verteilung traegt **nur zusammen mit** den strengen Pruefungen
        /// in den `as…`-Funktionen. Fuer sich genommen macht sie es schlimmer:
        /// sie nimmt einem Feld den Wert weg, den ein anderes dann verschluckt.
        func assign(_ fields: [(String, (String) -> String?)]) -> [String: String] {
            var result: [String: String] = [:]
            for radius in 0...lookAhead {
                for (field, accept) in fields {
                    if result[field] != nil { continue }
                    if radius > 0 && sameLineOnly.contains(field) { continue }
                    if let value = atRadius(field: field, radius: radius, accept: accept) {
                        result[field] = value
                    }
                }
            }
            return result
        }

        /// Was fuer `field` im Abstand `radius` von seinem Etikett steht.
        private func atRadius(
            field: String,
            radius: Int,
            accept: (String) -> String?
        ) -> String? {
            for (index, inLine) in labels.enumerated() {
                for (position, entry) in inLine.enumerated() {
                    guard entry.key == field else { continue }

                    if radius == 0 {
                        // Hinter dem Etikett, bis zum naechsten Etikett derselben
                        // Zeile: auf der Karte teilen sich 4a und 4c eine Zeile.
                        let end = position + 1 < inLine.count
                            ? inLine[position + 1].start
                            : lines[index].count
                        if let value = take(line: index, from: entry.end, to: end, accept: accept) {
                            return value
                        }
                        continue
                    }

                    let ahead = index + radius
                    if ahead < lines.count, let value = takeLine(ahead, accept) { return value }
                    let behind = index - radius
                    if radius <= lookBehind, behind >= 0, let value = takeLine(behind, accept) {
                        return value
                    }
                }
            }
            return nil
        }

        /// Eine ganze Zeile als Kandidat - genauer: ihr Anfang bis zum ersten
        /// Etikett, und wenn sie mit einem Etikett beginnt, gar nichts.
        ///
        /// Der zweite Fall ist der, an dem eine frueherere Fassung scheiterte:
        /// stand `4a.` allein auf einer Zeile und darunter
        /// `08/06/2015 4c. MIT-UCO`, wurde die ganze Zeile als etikettiert
        /// uebersprungen und das Ausstellungsdatum weit entfernt gesucht -
        /// gefunden wurde das Geburtsdatum.
        private func takeLine(_ index: Int, _ accept: (String) -> String?) -> String? {
            let inLine = labels[index]
            guard let first = inLine.first else {
                return take(line: index, from: 0, to: lines[index].count, accept: accept)
            }
            if let value = take(line: index, from: 0, to: first.start, accept: accept) {
                return value
            }
            // Hinter dem Etikett steht der Wert dieses Etiketts, nicht unserer.
            return nil
        }

        private func take(
            line: Int,
            from: Int,
            to: Int,
            accept: (String) -> String?
        ) -> String? {
            guard from < to else { return nil }
            if claimed.contains(where: { $0.line == line && $0.from < to && from < $0.to }) {
                return nil
            }

            let text = String(lines[line][from..<to]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            guard let accepted = accept(text) else { return nil }
            claimed.append(Claim(line: line, from: from, to: to))
            return accepted
        }

        /// Zeilen, die noch kein Feld fuer sich beansprucht hat.
        private func unclaimed() -> [String] {
            lines.enumerated()
                .filter { index, _ in !claimed.contains { $0.line == index } }
                .map { String($0.element) }
        }

        /// Ergaenzt, was am Geburtsfeld noch fehlt.
        ///
        /// Feld 3 traegt zwei Angaben, und die Erkennung reisst sie regelmaessig
        /// auseinander: mal fehlt die `3.` ganz, mal steht das Datum bei ihr und
        /// der Ort drei Zeilen weiter. Beide Haelften duerfen sich deshalb auch
        /// einzeln finden lassen.
        ///
        /// Ohne Etikett gilt jeweils nur, was fuer sich allein eindeutig ist: ein
        /// kurzes Datum, das eine Zeile fuer sich hat, und eine Ortsangabe mit
        /// Provinzkuerzel in Klammern. Der Kleindruck der Karte enthaelt weder
        /// das eine noch das andere.
        func completeBirth(_ found: Birth?) -> Birth? {
            // Jede Haelfte fuer sich. Frueher hing die Rettung an einem
            // Gesamttreffer, und ein halber - Datum gefunden, Ort nicht -
            // schaltete sie fuer beide ab. Ein Etiketttreffer war damit
            // schlechter als gar keiner.
            let free = unclaimed()
            let fromOneLine = free.lazy
                .compactMap { birthLine.firstMatch($0)?.value }
                .compactMap(LicenceScan.asBirth)
                .first

            let date = found?.date
                ?? fromOneLine?.date
                ?? free.first(where: { shortDateLine.matches($0) }).flatMap(LicenceScan.asDate)
            // Nicht `place`: der Name gehoert schon dem Muster, und ein
            // verdecktes Muster waere hier ein stiller Fehler.
            let birthPlace = found?.place
                ?? fromOneLine?.place
                ?? free.first(where: { place.matches($0) }).flatMap(LicenceScan.asPlace)

            if date == nil && birthPlace == nil { return nil }
            return Birth(date: date, place: birthPlace)
        }

        /// Der Vorname ohne Etikett, unmittelbar unter dem Nachnamen.
        ///
        /// Nur diese eine Stelle, und nur wenn im ganzen Text keine `2` steht.
        /// Auf der Karte sind die beiden Namen uebereinander gedruckt, und wenn
        /// die Erkennung das Etikett verliert, bleibt die Nachbarschaft. Weiter
        /// zu suchen waere Raten: ein zweiter Name in Versalien steht auf dieser
        /// Karte nicht herum, aber ein zerlesenes Wort schon.
        func rescueGivenNames(surname: String?) -> String? {
            guard let surname else { return nil }
            if labels.contains(where: { $0.contains { $0.key == fieldGivenNames } }) { return nil }

            let surnameLine = lines.firstIndex { String($0).contains(surname) } ?? -1
            let below = surnameLine + 1
            guard surnameLine >= 0, below < lines.count else { return nil }
            guard labels[below].isEmpty else { return nil }
            return take(line: below, from: 0, to: lines[below].count, accept: LicenceScan.asName)
        }

        /// Die Nummer ohne Etikett.
        ///
        /// Nur wenn eine Zeile fuer sich allein die Bauform der Nummer hat: zehn
        /// Zeichen, keine Leerstellen, Grossbuchstaben und Ziffern gemischt. Der
        /// Kleindruck der Karte enthaelt nichts dergleichen - er ist gemischt
        /// geschrieben und traegt Leerzeichen.
        func rescueNumber() -> String? {
            unclaimed().lazy
                .filter { numberLine.matches($0) }
                .compactMap(LicenceScan.asNumber)
                .first
        }

        /// Ausstellungs- und Ablaufdatum ueber ihre Reihenfolge zueinander.
        ///
        /// Die Etiketten 4a und 4b werden am haeufigsten zerlesen - `40.`, `4o.`,
        /// `G0.`, oder das `4` faellt ganz weg. Sie sind aber auch die einzigen
        /// beiden Angaben mit vierstelligem Jahr, und das Ausstellungsdatum liegt
        /// zwangslaeufig vor dem Ablaufdatum.
        ///
        /// Also: stehen im ganzen Text genau zwei solche Datumsangaben, ist die
        /// fruehere die Ausstellung und die spaetere der Ablauf. Genau zwei - bei
        /// dreien koennte eine davon ein vierstellig gedrucktes Geburtsdatum
        /// sein, und dann wird lieber nichts zugeordnet.
        func issueAndExpiry(_ gefunden: String?, _ abgelaufen: String?) -> (String?, String?) {
            // Erst pruefen, dann ergaenzen. Frueher stand die Reihenfolgepruefung
            // hinter einem Kurzschluss - sind beide da, gib beide zurueck - und
            // war damit genau in dem Fall unerreichbar, fuer den sie gedacht war.
            var issue = gefunden
            var expiry = abgelaufen
            if let i = issue, let e = expiry {
                if LicenceScan.sortKey(i) < LicenceScan.sortKey(e) { return (i, e) }
                issue = nil
                expiry = nil
            }

            var seen: [String] = []
            for line in lines {
                for match in fullDate.allMatches(LicenceScan.repairDigits(String(line))) {
                    if let date = LicenceScan.asFullDate(match.value), !seen.contains(date) {
                        seen.append(date)
                    }
                }
            }
            guard seen.count == 2 else { return (issue, expiry) }

            let sorted = seen.sorted { LicenceScan.sortKey($0) < LicenceScan.sortKey($1) }
            let earlier = sorted[0]
            let later = sorted[1]

            // Ein bereits gefundenes Datum bleibt, was es ist. Ergaenzt wird nur
            // das fehlende, und nur wenn die Reihenfolge dazu passt.
            if let issue { return (issue, later == issue ? nil : later) }
            if let expiry { return (earlier == expiry ? nil : earlier, expiry) }
            return (earlier, later)
        }
    }

    /// Haelt das Geburtsdatum vor dem Ausstellungsdatum.
    ///
    /// Das zweistellige Jahr braucht eine Jahrhundertgrenze, und die stand hier
    /// als feste Zahl - was bedeutet, dass sie mit den Jahren falsch wird und
    /// dass ein `29` heute zu 2029 wird, einem Datum in der Zukunft. Die Karte
    /// beantwortet das selbst: niemand wird nach der Ausstellung seiner
    /// Fahrerlaubnis geboren. Liegt das Datum danach, gehoert es ins vorige
    /// Jahrhundert; hilft auch das nicht, ist es falsch zugeordnet und faellt weg.
    ///
    /// Ohne Ausstellungsdatum bleibt es bei der festen Grenze - eine schlechtere
    /// Auskunft als gar keine ist es nicht.
    private static func bornBefore(birth: String?, issue: String?) -> String? {
        guard let birth else { return nil }
        guard let issue else { return birth }
        if sortKey(birth) < sortKey(issue) { return birth }

        let head = String(birth.prefix(6))
        guard let year = Int(String(birth.dropFirst(6))) else { return nil }
        let century = head + String(year - 100)
        return sortKey(century) < sortKey(issue) ? century : nil
    }

    /// TT.MM.JJJJ so umgestellt, dass sich Datumsangaben vergleichen lassen.
    private static func sortKey(_ date: String) -> String {
        let c = Array(date)
        guard c.count >= 10 else { return date }
        return String(c[6...]) + String(c[3..<5]) + String(c[0..<2])
    }

    private struct Label {
        let key: String
        let start: Int
        let end: Int
    }

    private struct Claim {
        let line: Int
        let from: Int
        let to: Int
    }

    /// Datum und Ort, wie Feld 3 sie zusammen fuehrt.
    fileprivate struct Birth {
        let date: String?
        let place: String?
    }

    /// Die Etiketten einer Zeile.
    ///
    /// Zwei Formen werden erkannt: die gedruckte mit Satzzeichen (`4a.`, und weil
    /// die Erkennung den Punkt gelegentlich als Komma oder Doppelpunkt liest,
    /// auch die), und die nackte Ziffer, die allein auf einer Zeile steht. Die
    /// zweite Form ist noetig, weil der Punkt regelmaessig verlorengeht; sie ist
    /// nur zulaessig, wenn die Zeile aus nichts anderem besteht, sonst wuerde
    /// jede Hausnummer im Kleindruck zum Etikett.
    ///
    /// Angenommen wird ausserdem nur, was es auf der Karte gibt. Eine `11.`
    /// gehoert nicht zum Satz und ist damit kein Etikett, sondern Text.
    private static func labelsIn(_ line: String) -> [Label] {
        let characters = Array(line)

        if bareLabel.matches(line), let match = bareLabel.firstMatch(line),
           let key = match[1]?.lowercased(), knownLabels.contains(key) {
            return [Label(key: key, start: 0, end: characters.count)]
        }

        return label.allMatches(line).compactMap { match in
            guard let key = match[1]?.lowercased(), knownLabels.contains(key) else { return nil }
            let start = line.distance(from: line.startIndex, to: match.range.lowerBound)
            let end = line.distance(from: line.startIndex, to: match.range.upperBound)
            return Label(key: key, start: start, end: end)
        }
    }

    // -----------------------------------------------------------------------
    // Was ein Feld annimmt
    // -----------------------------------------------------------------------

    /// Namen stehen auf der Karte in Grossbuchstaben.
    ///
    /// Das ist die ganze Pruefung, und sie traegt erstaunlich weit: der
    /// Kleindruck der Karte ist gemischt geschrieben, und was die Erkennung aus
    /// ihm macht - `chein`, `dove`, `cence` - faellt damit weg. Ohne diese
    /// Bedingung wurde an einer Aufnahme `chein` zum Geburtsort.
    ///
    /// Die Aufdrucke der Karte selbst sind ebenfalls in Versalien und muessen
    /// ausgeschlossen werden. Die Liste dafuer enthaelt nur Woerter, die als
    /// Namensbestandteil nicht vorkommen. `DI` und `GUIDA` standen frueher darin
    /// und schlossen damit **DI STEFANO**, **DI MARZIO** und jeden anderen Namen
    /// mit italienischem Namenszusatz aus - der Nachname fiel weg, und das Feld
    /// nahm sich stattdessen den Vornamen. `PATENTE DI GUIDA` wird ohnehin schon
    /// an `PATENTE` erkannt.
    static func asName(_ text: String) -> String? {
        // Ziffern schliessen den Kandidaten aus, statt herausgefiltert zu werden.
        // Herausfiltern machte aus der Dokumentnummer `U1X830164P` den Namen
        // `UXP` und aus einer zerlesenen Datumszeile den Namen `G O`.
        if text.contains(where: \.isNumber) { return nil }

        let kept = String(normaliseApostrophes(text).filter {
            $0.isLetter || $0 == " " || $0 == "-" || $0 == "'"
        }).trimmingCharacters(in: .whitespaces)
        let letters = whitespace.replacingAll(in: kept, with: " ")

        guard letters.count >= 2 else { return nil }
        guard letters == letters.uppercased() else { return nil }
        if letters.split(separator: " ").contains(where: { cardWords.contains(String($0)) }) {
            return nil
        }
        // MIT-UCO ist die ausstellende Stelle, kein Name.
        if authority.matches(letters) { return nil }
        // Eine Ortsangabe ist kein Name. Auf einer Aufnahme stand der Geburtsort
        // ohne Etikett direkt unter der `1.`.
        if place.containsMatch(text) { return nil }
        return letters
    }

    /// Feld 3 traegt Datum und Ort, getrennt nur durch Leerraum.
    ///
    /// Angenommen wird der Kandidat, sobald eines von beidem erkennbar ist -
    /// fehlt das Datum, ist der Ort allein immer noch die richtige Angabe.
    fileprivate static func asBirth(_ text: String) -> Birth? {
        // Nur ein zweistelliges Jahr. Die Karte druckt das Geburtsdatum
        // zweistellig und Ausstellung wie Ablauf vierstellig - genau daran haengt
        // die Trennung. Ohne diese Bedingung nahm Feld 3 das Ausstellungsdatum,
        // sobald seine eigene Zeile fehlte, und lieferte ein Geburtsjahr 2015.
        let repaired = repairDigits(text)
        if let match = shortDate.firstMatch(repaired) {
            let characters = Array(text)
            let from = repaired.distance(from: repaired.startIndex, to: match.range.lowerBound)
            let to = repaired.distance(from: repaired.startIndex, to: match.range.upperBound)
            let rest = (String(characters[0..<from]) + String(characters[to...]))
                .trimmingCharacters(in: CharacterSet(charactersIn: " ,."))
            return Birth(date: asDate(match.value), place: asPlace(rest))
        }
        guard let place = asPlace(text) else { return nil }
        return Birth(date: nil, place: place)
    }

    /// Ein Ortsname, gegebenenfalls mit Provinzkuerzel.
    ///
    /// Ziffern werden hier zu Buchstaben zurueckgedreht - gemessen wurde
    /// `BOLZANO-80ZEN (BZ)`. Italienische Ortsnamen enthalten keine Ziffern, also
    /// ist jede Ziffer hier ein Lesefehler und die Rueckdrehung keine Wette.
    /// Umgekehrt waere sie eine: in der Dokumentnummer stehen Ziffern und
    /// Buchstaben nebeneinander, und dort wird deshalb nichts angetastet.
    static func asPlace(_ text: String) -> String? {
        let repaired = String(text.map { letterRepairs[$0] ?? $0 })
        let filtered = String(repaired.filter { $0.isLetter || " -'()".contains($0) })
        let cleaned = whitespace.replacingAll(in: filtered, with: " ")
            .trimmingCharacters(in: .whitespaces)

        guard cleaned.count >= 3 else { return nil }
        guard cleaned == cleaned.uppercased() else { return nil }
        let parts = cleaned.split(whereSeparator: { $0 == " " || $0 == "-" })
        if parts.contains(where: { cardWords.contains(String($0)) }) { return nil }
        // Das Kuerzel in Klammern ist die eigentliche Bedingung: es steht auf
        // allen vermessenen Karten, und ohne es genuegte jede Folge von drei
        // Grossbuchstaben. Damit wurde der Vorname zum Geburtsort und `JEC` aus
        // dem Kleindruck ebenfalls. Bei Geburt im Ausland steht dort das
        // Laenderkuerzel, die Klammer bleibt also auch dann.
        guard place.containsMatch(cleaned) else { return nil }
        return cleaned
    }

    /// Ein Datum mit vierstelligem Jahr.
    ///
    /// Die Bedingung ist der Kern der Trennung von Feld 3: Ausstellung und Ablauf
    /// sind auf der Karte vierstellig gedruckt, das Geburtsdatum zweistellig.
    /// Ohne sie wanderte an einer Aufnahme das Geburtsdatum ins Ausstellungsdatum
    /// - ein Wert, dem man nicht ansieht, dass er falsch ist.
    static func asFullDate(_ text: String) -> String? {
        fullDate.firstMatch(repairDigits(text)).flatMap { asDate($0.value) }
    }

    /// Feld 3 als unveraenderter Kandidat, sofern es sich als solches lesen
    /// laesst.
    ///
    /// Die Verteilung arbeitet mit Zeichenketten; Datum und Ort werden erst
    /// danach auseinandergenommen. So bleibt die Zuteilung von der Auswertung
    /// getrennt, und beide sind fuer sich zu lesen.
    static func asBirthText(_ text: String) -> String? {
        asBirth(text) != nil ? text : nil
    }

    /// TT/MM/JJ oder TT/MM/JJJJ wird zu TT.MM.JJJJ - dieselbe Schreibweise, die
    /// die App bei Karte und Pass zeigt.
    ///
    /// Zweistellige Jahre stehen nur im Geburtsdatum. Ein Jahr oberhalb des
    /// laufenden liegt im vergangenen Jahrhundert; dieselbe Annahme wie beim
    /// Lesen der MRZ.
    static func asDate(_ text: String) -> String? {
        guard let match = date.firstMatch(repairDigits(text)),
              let day = match[1], let month = match[2], let year = match[3],
              let dayValue = Int(day), let monthValue = Int(month), let yearValue = Int(year)
        else { return nil }
        guard (1...31).contains(dayValue), (1...12).contains(monthValue) else { return nil }

        let fullYear: String
        if year.count == 4 {
            fullYear = year
        } else if yearValue > currentTwoDigitYear {
            fullYear = "19" + year
        } else {
            fullYear = "20" + year
        }
        return "\(day).\(month).\(fullYear)"
    }

    /// Die ausstellende Stelle: MIT-UCO auf den neuen Karten, MC-<Provinz> auf
    /// den aelteren.
    ///
    /// Der Bindestrich ist die Bedingung. Ohne ihn wuerde jedes Wort in Versalien
    /// angenommen, und davon steht auf der Karte reichlich herum.
    static func asAuthority(_ text: String) -> String? {
        let cleaned = String(text.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" })
        return authority.matches(cleaned) ? cleaned : nil
    }

    /// Die Nummer: zehn Zeichen aus Buchstaben und Ziffern.
    ///
    /// Die Laenge ist die eigentliche Pruefung. Ohne sie landete an einer
    /// Aufnahme das Geburtsdatum im Nummernfeld - als `020965`, was in einem
    /// Bericht niemandem auffaellt.
    ///
    /// Verlesene Zeichen werden hier **nicht** zurueckgedreht. Buchstaben und
    /// Ziffern stehen in dieser Nummer nebeneinander; gemessen wurde `U1974B315M`
    /// einmal als `U19748315M`, und beide Lesarten sind zulaessig. Eine
    /// Rueckdrehung waere kein Ausbessern, sondern Raten - und die Karte hat
    /// keine Pruefziffer, an der sich das Ergebnis messen liesse.
    static func asNumber(_ text: String) -> String? {
        // Ein einziges gedrucktes Wort, nicht aus Satzzeichen zusammengesetzt.
        // Vorher wurde alles Nichtalphanumerische weggeworfen, und aus der
        // zerlesenen Zeile `G0. 07/O4/2031` entstand `G007O42031`: zehn Zeichen,
        // zwei Buchstaben, acht Ziffern - eine erfundene Dokumentnummer, die jede
        // Pruefung bestand und der man nichts ansieht.
        let cleaned = text.trimmingCharacters(in: .whitespaces).uppercased()
        guard numberLine.matches(cleaned) else { return nil }
        guard cleaned.filter(\.isLetter).count >= 2 else { return nil }
        guard cleaned.filter(\.isNumber).count >= 4 else { return nil }
        return cleaned
    }

    /// Feld 9 nennt die Klassen.
    ///
    /// Zerlegt wird gegen den geschlossenen Satz aus Anhang I, laengste Marke
    /// zuerst - sonst wird aus `AM` ein `A` und ein uebrig gebliebenes `M`. Die
    /// Erkennung liefert die Klassen mal getrennt (`A B`), mal zusammengezogen
    /// (`AB`); beides muss dasselbe ergeben.
    ///
    /// Angenommen wird nur, was sich **restlos** zerlegen laesst. Diese Bedingung
    /// ist der Schutz: ohne sie liefert jedes Wort im Kleindruck, das ein A oder
    /// B enthaelt, eine erfundene Fahrerlaubnis - und eine Klasse, die niemand
    /// hat, ist schlimmer als eine fehlende Angabe.
    static func asCategories(_ text: String) -> String? {
        // Nicht gross schreiben, sondern gross verlangen. Die Klassen stehen auf
        // der Karte in Versalien; der Kleindruck nicht. Wer hier `uppercased()`
        // aufruft, bevor er prueft, macht aus einem einzelnen `a` aus dem
        // Kleindruck die Fahrerlaubnis der Klasse A.
        guard text == text.uppercased() else { return nil }
        // `A1` und `B1` kommen regelmaessig als `AI` und `BI` an. In einem Satz
        // ohne den Buchstaben I ist die Rueckdrehung eindeutig - und ohne sie
        // faellt wegen der Alles-oder-nichts-Regel gleich das ganze Feld weg.
        var compact = String(repairDigits(text).filter {
            !$0.isWhitespace && $0 != "," && $0 != "/"
        })
        while compact.hasSuffix(".") { compact.removeLast() }
        guard !compact.isEmpty else { return nil }

        var found: [String] = []
        var rest = Substring(compact)
        while !rest.isEmpty {
            guard let match = categories.first(where: { rest.hasPrefix($0) }) else { return nil }
            found.append(match)
            rest = rest.dropFirst(match.count)
        }

        var distinct: [String] = []
        for entry in found where !distinct.contains(entry) { distinct.append(entry) }
        let joined = distinct.joined(separator: " ")
        return joined.isEmpty ? nil : joined
    }

    /// In Ziffernfeldern verlesene Buchstaben zurueckdrehen.
    ///
    /// Nur dort, wo ausschliesslich Ziffern stehen duerfen. In einem Namen oder in
    /// der Dokumentnummer waere dieselbe Ersetzung Unfug.
    private static func repairDigits(_ value: String) -> String {
        String(value.map { digitRepairs[$0] ?? $0 })
    }

    /// Typografische Apostrophe auf den geraden zurueckfuehren.
    ///
    /// Die Erkennung liefert bei `D'ANGELO` regelmaessig das typografische
    /// Zeichen. Wurde es weggefiltert, hiess der Mann `DANGELO` - kein falsches
    /// Feld, aber ein falscher Name.
    private static func normaliseApostrophes(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{02BC}", with: "'")
            .replacingOccurrences(of: "\u{00B4}", with: "'")
    }

    // -----------------------------------------------------------------------
    // Muster
    // -----------------------------------------------------------------------

    private static let fieldSurname = "1"
    private static let fieldGivenNames = "2"
    private static let fieldBirth = "3"
    private static let fieldIssue = "4a"
    private static let fieldExpiry = "4b"
    private static let fieldAuthority = "4c"
    private static let fieldNumber = "5"
    private static let fieldCategories = "9"

    /// Feld 7 ist die Unterschrift: als Etikett bekannt, aber ohne Wert.
    private static let knownLabels: Set<String> = ["1", "2", "3", "4a", "4b", "4c", "5", "7", "9"]

    /// Felder, deren Wert nur auf der Zeile des Etiketts gilt.
    ///
    /// Bisher nur die Klassen. Auf sieben der acht vermessenen Aufnahmen stehen
    /// sie hinter ihrer `9.`, auf der achten fehlt das Etikett ganz - der Umkreis
    /// hat also nie eine richtige Klasse beigetragen. Er war aber der einzige
    /// Weg, auf dem der Kleindruck der Karte das Feld erreichen konnte.
    private static let sameLineOnly: Set<String> = [fieldCategories]

    /// Ein gedrucktes Etikett mit Satzzeichen.
    private static let label = Pattern("(?<![0-9A-Za-z])(\\d{1,2}[a-dA-D]?)\\s*[.,:]\\s*")

    /// Eine nackte Ziffer, die allein auf ihrer Zeile steht.
    private static let bareLabel = Pattern("(\\d{1,2}[a-dA-D]?)\\s*[.,:]?")

    private static let date = Pattern("(\\d{2})[/.\\-](\\d{2})[/.\\-](\\d{4}|\\d{2})")
    private static let fullDate = Pattern("\\d{2}[/.\\-]\\d{2}[/.\\-]\\d{4}")

    /// Zweistelliges Jahr - so steht das Geburtsdatum auf der Karte.
    private static let shortDate = Pattern("\\d{2}[/.\\-]\\d{2}[/.\\-]\\d{2}(?!\\d)")

    /// Ortsangabe mit Provinzkuerzel, etwa BOLZANO-BOZEN (BZ).
    private static let place = Pattern("[A-ZÄÖÜ'\\- ]{3,}\\s*\\([A-Z]{2}\\)")

    /// Ein kurzes Datum, das eine Zeile fuer sich allein hat.
    private static let shortDateLine = Pattern("\\d{2}[/.\\-]\\d{2}[/.\\-]\\d{2}")

    /// Geburtszeile ohne Etikett: kurzes Datum, dahinter der Ort.
    private static let birthLine = Pattern(
        "\\d{2}[/.\\-]\\d{2}[/.\\-]\\d{2}\\s+[A-Z0-9ÄÖÜ'\\- ]{3,}\\s*\\([A-Z]{2}\\)"
    )

    /// Eine Zeile, die fuer sich allein die Bauform der Nummer hat.
    private static let numberLine = Pattern("[A-Z0-9]{10}")

    /// MIT-UCO, oder MC- gefolgt vom Provinzkuerzel.
    private static let authority = Pattern("[A-Z]{2,4}-[A-Z0-9]{2,4}")

    private static let whitespace = Pattern("\\s+")

    /// Die Klassen nach Anhang I, laengste zuerst.
    ///
    /// Die Reihenfolge ist Teil des Verfahrens und keine Formsache: `AM` muss vor
    /// `A` stehen, sonst zerfaellt es.
    private static let categories = [
        "AM", "A1", "A2", "B1", "BE", "C1E", "CE", "C1", "D1E", "DE", "D1",
        "A", "B", "C", "D",
    ]

    /// Was auf jeder Karte steht und deshalb kein Name sein kann.
    ///
    /// Beide Amtssprachen und die deutsche Fassung, die auf der Suedtiroler Karte
    /// mitgedruckt ist.
    private static let cardWords: Set<String> = [
        "PATENTE", "REPUBBLICA", "ITALIANA", "ITALIANE",
        "FÜHRERSCHEIN", "FUHRERSCHEIN", "REPUBLIK", "ITALIEN",
    ]

    /// Was die Erkennung in Ziffernfeldern fuer eine Ziffer haelt.
    private static let digitRepairs: [Character: Character] = [
        "O": "0", "o": "0", "I": "1", "l": "1",
    ]

    /// Was sie umgekehrt in reinen Buchstabenfeldern fuer einen Buchstaben haelt.
    private static let letterRepairs: [Character: Character] = [
        "0": "O", "8": "B", "1": "I", "5": "S",
    ]

    /// Wie weit hinter einem Etikett nach seinem Wert gesucht wird.
    private static let lookAhead = 4

    /// Und wie weit davor. Kuerzer, weil der Wert dort seltener steht.
    private static let lookBehind = 2

    /// Zweistellige Jahre oberhalb dieses Werts liegen im vergangenen
    /// Jahrhundert. Bewusst eine Konstante und kein Systemdatum: das Ergebnis
    /// soll nicht davon abhaengen, wann die App laeuft.
    private static let currentTwoDigitYear = 30
}
