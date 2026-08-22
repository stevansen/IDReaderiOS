import SwiftUI
import IDReaderCore

/// Das Ergebnis, als Dokument gedacht.
///
/// Lichtbild, Name, Geburtsdatum und Gueltigkeit im getoenten Kopfbereich mit dem
/// Echtheitszeichen; darunter die MRZ-Felder als Kacheln und die DG11-Felder als
/// Liste. Die zwei Gruppen tragen keine Ueberschriften: die Beschriftungen an
/// jedem Feld sagen schon, was sie sind, und die Ueberschriften kosten je eine
/// Zeile, die das Layout anderswo braucht.
struct ResultScreen: View {

    let document: StoredDocument
    /// Ob der Datensatz gerade von der Karte kommt. Bei false stammt er aus dem
    /// Archiv - und eine aufbewahrte Kopie kann veraltet sein.
    let fresh: Bool
    let retentionDays: Int
    /// Ob die Einstellung „Alle Felder aufbewahren" an ist.
    ///
    /// Steht hier, weil der Hinweis unter den Feldern eine **Zusage** ist und
    /// keine Beschreibung: er sagt, was mit dem Wohnsitz gleich passiert. Ohne
    /// diesen Wert sagte er es unabhaengig davon, was wirklich passiert - und
    /// stand bei eingeschaltetem Schalter genau falsch da.
    let retainsAllFields: Bool
    let strings: Strings
    let onDone: () -> Void
    let onReread: () -> Void
    let onShare: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var authenticityShown = false

    private var data: DocumentData { document.data }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    header
                    if !fresh {
                        storedCopyNotice
                    }
                    if data.provenance == .photo {
                        photoProvenanceNotice
                    }
                    tiles
                    extras
                    if fresh && data.provenance == .chip {
                        retentionModeNotice
                    }
                    if data.provenance == .chip {
                        revocationCard
                    }
                    retentionNotice
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            BottomActionBar {
                HStack(spacing: 10) {
                    Button(action: onShare) {
                        Label(strings[.actionShare], systemImage: "square.and.arrow.up")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .overlay { Capsule().stroke(palette.outline, lineWidth: 1) }

                    Button(action: onDone) {
                        Text(strings[.actionDone])
                            .font(AppType.actionLarge)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(palette.onPrimary)
                    .background(palette.primary, in: .capsule)
                }
            }
        }
        .sheet(isPresented: $authenticityShown) {
            AuthenticitySheet(authenticity: data.authenticity, strings: strings)
        }
    }

    // -----------------------------------------------------------------------

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                photo
                VStack(alignment: .leading, spacing: 4) {
                    Text(strings[DocumentType.of(data).titleKey])
                        .font(AppType.microLabel)
                        .opacity(0.85)
                    Text(data.fullName)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(data.dateOfBirth).font(.subheadline)
                    if let place = BilingualText.pick(
                        data.placeOfBirth,
                        preferGerman: strings.prefersGerman
                    ) {
                        Text(place).font(.footnote).opacity(0.85)
                    }
                    Text(strings.format(.resultValidUntil, data.dateOfExpiry))
                        .font(.footnote)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
                seal
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.primary)
        .foregroundStyle(palette.onPrimary)
        .clipShape(.rect(cornerRadius: 20))
    }

    /// Das Siegel im Kopfbereich hat eigene Farben.
    ///
    /// Der Kopfbereich traegt ``DocumentPalette/primary`` - im hellen Theme
    /// dunkelblau, im dunklen hellblau. Ein Gruenton, der auf dem einen lesbar ist,
    /// verschwindet auf dem anderen.
    @ViewBuilder private var seal: some View {
        switch data.authenticity.status {
        case .verified:
            Button { authenticityShown = true } label: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.sealVerified)
            }
            .accessibilityLabel(strings[.authenticityVerified])
        case .failed, .notChecked:
            Button { authenticityShown = true } label: {
                Image(systemName: "xmark.seal.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(palette.sealFailed)
            }
            .accessibilityLabel(strings[.authenticityFailed])
        case .unverifiable:
            // Kein Siegel. Nicht ein graues, nicht ein durchgestrichenes: ein
            // durchgestrichenes liest sich als „Pruefung nicht bestanden", waehrend
            // es hier nie eine Pruefung gab. Der Vorbehalt steht stattdessen in
            // Worten, unter dem Kopfbereich.
            EmptyView()
        }
    }

    @ViewBuilder private var photo: some View {
        if let jpeg = data.photo?.jpegData, let image = UIImage(data: jpeg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 100)
                .clipShape(.rect(cornerRadius: 8))
                .accessibilityLabel(strings[.cdPhoto])
        } else if let photo = data.photo {
            // Kein Bild, aber ein Format: dann steht das Format da. „Hier war ein
            // Bild, das ich nicht lesen kann" ist eine Auskunft, ein leerer Rahmen
            // waere eine falsche.
            VStack(spacing: 4) {
                Image(systemName: "photo.badge.exclamationmark")
                Text(photo.mimeType).font(.system(.caption2, design: .monospaced))
            }
            .frame(width: 78, height: 100)
            .background(palette.onPrimary.opacity(0.12), in: .rect(cornerRadius: 8))
        }
    }

    private var storedCopyNotice: some View {
        notice(
            symbol: "clock.arrow.circlepath",
            text: strings.format(.storedCopyNotice, formattedTimestamp),
            container: palette.tertiaryContainer,
            content: palette.onTertiaryContainer
        ) {
            Button(action: onReread) {
                Text(strings[.actionReadAgain]).font(AppType.actionSmall)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    /// Der Vorbehalt bei einem Datensatz aus einem Foto.
    ///
    /// In Worten, mit rotem Zeichen, und **an derselben Stelle**, an der bei einem
    /// Chip-Datensatz das Siegel steht. Verwechseln soll man die zwei nicht.
    private var photoProvenanceNotice: some View {
        notice(
            symbol: "exclamationmark.circle.fill",
            text: strings[.valueProvenancePhoto],
            container: palette.errorContainer,
            content: palette.onErrorContainer
        ) { EmptyView() }
    }

    /// Was mit den vier Feldern gleich passiert - und zwar in beiden Faellen.
    ///
    /// Steht nur beim frisch gelesenen Datensatz, und dort ist er noetig: bei der
    /// Vorgabe hat wer die Anschrift braucht genau diesen Augenblick, um sie
    /// abzuschreiben. Beim Blick aus dem Archiv waere der Hinweis zu spaet und
    /// deshalb nur Ballast - dort sagen die Felder selbst, was mit ihnen war.
    ///
    /// Ist „Alle Felder aufbewahren" an, bleiben sie, und dann ist **das** die
    /// Auskunft, die hierher gehoert. Vorher stand hier ein fester Text, und der
    /// war in diesem Fall das Gegenteil der Wahrheit: er versprach eine
    /// Datenminimierung, die gerade nicht lief.
    private var retentionModeNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: retainsAllFields ? "tray.and.arrow.down" : "eye.slash")
                .font(.footnote)
                .padding(.top, 2)
            Text(strings[retainsAllFields ? .retentionAllHint : .retentionMinimisedHint])
                .font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.tertiaryContainer, in: .rect(cornerRadius: 14))
        .foregroundStyle(palette.onTertiaryContainer)
    }

    /// Was die Sperrpruefung ergeben hat, und wann.
    ///
    /// ## Warum drei Zeilen und nicht ein Siegel
    ///
    /// Ein Zeichen waere zu wenig. „Geprueft" allein sagt nichts: eine Pruefung
    /// von heute gegen eine Liste von vor zwei Jahren ist etwas anderes als eine
    /// von vor zwei Wochen gegen die Liste von damals. Also stehen beide Daten da,
    /// und die Bewertung bleibt bei dem, der hinsieht.
    ///
    /// Und darunter, immer, der Satz, was hier ueberhaupt geprueft wird. Wer
    /// „Sperrliste" liest, denkt zuerst an einen als gestohlen gemeldeten Ausweis;
    /// geprueft wird das Signierzertifikat. Diesen Irrtum stehen zu lassen waere
    /// schlimmer, als die Pruefung ganz weggelassen zu haben.
    @ViewBuilder private var revocationCard: some View {
        let check = document.revocation
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: revocationSymbol).font(.footnote)
                Text(strings[.revocationHeading]).font(AppType.cardHeading)
                Spacer(minLength: 0)
            }
            Text(revocationVerdict).font(.subheadline)

            if let check {
                Text(strings.format(.revocationCheckedAt, formatted(check.checkedAt)))
                    .font(.footnote)
                    .foregroundStyle(palette.onSurfaceVariant)
                if check.outcome != .noListForIssuer {
                    Text(strings.format(.revocationListDate, formatted(check.listIssuedAt)))
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                }
                if check.usedStaleList(at: Date()) {
                    Text(strings[.revocationListStale])
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            } else if document.signer != nil {
                Text(strings[.revocationPendingHint])
                    .font(.footnote)
                    .foregroundStyle(palette.onSurfaceVariant)
            }

            Text(strings[.revocationScope])
                .font(.caption)
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(palette.outlineVariant, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private var revocationVerdict: String {
        guard let check = document.revocation else {
            return strings[.revocationPending]
        }
        switch check.outcome {
        case .revoked: return strings[.revocationRevoked]
        case .notRevoked: return strings[.revocationNotRevoked]
        case .noListForIssuer: return strings[.revocationNoList]
        }
    }

    private var revocationSymbol: String {
        switch document.revocation?.outcome {
        case .revoked: "xmark.seal"
        case .notRevoked: "checkmark.seal"
        default: "clock"
        }
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private var retentionNotice: some View {
        Text(strings.format(.resultRetentionHint, retentionDays))
            .font(.footnote)
            .foregroundStyle(palette.onSurfaceVariant)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }

    private func notice<Trailing: View>(
        symbol: String,
        text: String,
        container: Color,
        content: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        // Bei den Bedienungshilfen-Groessen steht der Knopf **unter** dem Satz.
        // Daneben blieb dem Satz eine Spalte von zwei Woertern Breite, und
        // „Gespeicherte Fassung vom … - nicht neu gelesen" endete unter der
        // Knopfleiste. Am Simulator gesehen.
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).padding(.top, 2)
                Text(text).font(.footnote)
                Spacer(minLength: 0)
                if !typeSize.isAccessibilitySize {
                    trailing()
                }
            }
            if typeSize.isAccessibilitySize {
                trailing()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(container, in: .rect(cornerRadius: 14))
        .foregroundStyle(content)
    }

    // -----------------------------------------------------------------------

    /// Die MRZ-Felder als Kacheln.
    private var tiles: some View {
        LazyVGrid(columns: [GridItem(spacing: 10), GridItem(spacing: 10)], spacing: 10) {
            tile(strings[.labelDocumentNumber], data.documentNumber, mono: true)
            tile(strings[.labelNationality], data.nationality)
            tile(strings[.labelGender], strings[genderKey])
            tile(strings[.labelDateOfExpiry], data.dateOfExpiry, mono: true)
            if let issue = data.dateOfIssue {
                tile(strings[.labelDateOfIssue], issue, mono: true)
            }
            if let cf = data.codiceFiscale {
                tile(strings[.labelCodiceFiscale], cf, mono: true)
            } else if data.wasDropped(.codiceFiscale) {
                // Die Kachel bleibt stehen und sagt, warum sie leer ist. Ohne sie
                // saehe es aus, als habe die Karte keine Steuernummer gefuehrt.
                tile(strings[.labelCodiceFiscale], strings[.valueNotRetained])
            }
            if let categories = data.categories {
                tile(strings[.labelCategories], categories)
            }
        }
    }

    private func tile(_ label: String, _ value: String, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.onSurfaceVariant)
            Text(value.isEmpty ? strings[.valueMissing] : value)
                .font(mono ? AppType.monoRowValue : .subheadline)
                .foregroundStyle(value.isEmpty ? palette.onSurfaceVariant : palette.onSurface)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceContainer, in: .rect(cornerRadius: 12))
        // Ein Element, nicht zwei. Sonst hoert die Vorlesefunktion beim ersten
        // Wischen „Geburtsdatum" und beim zweiten „07.04.1968" - man muss sich
        // die Bezeichnung merken, waehrend man zum Wert wischt, und bei
        // sechzehn Kacheln ist das keine Auskunft mehr.
        .accessibilityElement(children: .combine)
    }

    /// Die uebrigen Angaben, sofern das Dokument sie fuehrt. Auf den allermeisten
    /// Dokumenten ist hier nichts gesetzt, und ein Abschnitt aus neun Zeilen
    /// „nicht im Dokument" waere Ballast.
    /// „Nicht im Dokument" und „gelesen, nicht gespeichert" sind zwei
    /// verschiedene Auskuenfte. Eine Zeile, die fehlt, liest sich als die erste -
    /// also muss die zweite dastehen, wenn sie zutrifft.
    ///
    /// Kein verschachtelter Hilfsausdruck im `ViewBuilder`: der versucht, jede
    /// Anweisung als Ansicht zu lesen, und ein `return` darin schaltet ihn ab.
    private func orNotRetained(_ value: String?, _ field: MinimisedField) -> String {
        if let value, !value.isEmpty { return value }
        return data.wasDropped(field) ? strings[.valueNotRetained] : ""
    }

    @ViewBuilder private var extras: some View {
        let rows: [(String, String)] = [
            (strings[.labelResidence],
             orNotRetained(
                BilingualText.pick(data.residence, preferGerman: strings.prefersGerman),
                .residence
             )),
            (strings[.labelIssuingAuthority],
             BilingualText.pick(data.issuingAuthority, preferGerman: strings.prefersGerman) ?? ""),
            (strings[.labelIssuingState], data.issuingState ?? ""),
            (strings[.labelOtherNames], data.otherNames ?? ""),
            (strings[.labelTitle], data.title ?? ""),
            (strings[.labelProfession], orNotRetained(data.profession, .profession)),
            (strings[.labelPersonalSummary], data.personalSummary ?? ""),
            (strings[.labelTelephone], orNotRetained(data.telephone, .telephone)),
            (strings[.labelOtherDocuments], data.otherValidDocuments ?? ""),
            (strings[.labelCustody], data.custodyInformation ?? ""),
            (strings[.labelEndorsements], data.endorsements ?? ""),
            (strings[.labelTaxExit], data.taxOrExitRequirements ?? ""),
        ].filter { !$0.1.isEmpty }

        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { Divider().overlay(palette.outlineVariant) }
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.0)
                            .font(.footnote)
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(width: 120, alignment: .leading)
                        Text(row.1).font(.subheadline)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
            }
            .background(palette.surfaceContainer, in: .rect(cornerRadius: 12))
        }
    }

    private var genderKey: StringKey {
        switch data.gender {
        case .male: .genderMale
        case .female: .genderFemale
        case .unknown: .genderUnknown
        }
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: document.storedDate)
    }
}

/// Einzelheiten der Echtheitspruefung.
///
/// Bewusst ein eigenes Blatt und keine aufklappbare Stelle im Ergebnisschirm: der
/// soll ohne Scrollen auskommen, und diese Angaben braucht man nur, wenn man
/// nachsehen will.
struct AuthenticitySheet: View {

    let authenticity: Authenticity
    let strings: Strings

    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(strings[.authenticityDetailsTitle]).font(.title2.weight(.semibold))

                VStack(spacing: 0) {
                    checkRow(
                        strings[.authenticityCheckHashes],
                        detail: dataGroupDetail,
                        passed: authenticity.dataGroupsIntact
                    )
                    Divider().overlay(palette.outlineVariant)
                    checkRow(
                        strings[.authenticityCheckSignature],
                        detail: authenticity.digestAlgorithm,
                        passed: authenticity.signatureValid
                    )
                    Divider().overlay(palette.outlineVariant)
                    checkRow(
                        strings[.authenticityCheckChain],
                        detail: authenticity.trustAnchorName,
                        passed: authenticity.chainTrusted
                    )
                    // Nur zeigen, wenn die Karte eine Chip-Authentisierung
                    // anbietet - sonst waere eine rote Zeile fuer etwas da, das
                    // dieses Dokument gar nicht kann.
                    if authenticity.chipAuthenticationExpected {
                        Divider().overlay(palette.outlineVariant)
                        checkRow(
                            strings[.authenticityCheckChip],
                            detail: strings[.authenticityCheckChipDetail],
                            passed: authenticity.chipAuthenticated
                        )
                    }
                }
                .background(palette.surfaceContainer, in: .rect(cornerRadius: 12))

                if let failure = authenticity.failure {
                    Text(strings[failureKey(failure)])
                        .font(.subheadline)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.errorContainer, in: .rect(cornerRadius: 12))
                        .foregroundStyle(palette.onErrorContainer)
                }

                if let signer = authenticity.signerName {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strings[.authenticitySigner])
                            .font(.caption)
                            .foregroundStyle(palette.onSurfaceVariant)
                        Text(signer).font(.subheadline)
                    }
                }

                Text(strings[.authenticityExplainer])
                    .font(.footnote)
                    .foregroundStyle(palette.onSurfaceVariant)
            }
            .padding(24)
        }
        .background(palette.surface)
    }

    /// Eine Zeile des Echtheitsblatts - Zeichen, Bezeichnung und Begruendung
    /// gehoeren zusammen und werden als ein Element vorgelesen.
    private func checkRow(_ label: String, detail: String?, passed: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: passed ? "checkmark.seal.fill" : "xmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(passed ? palette.verified : palette.error)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private var dataGroupDetail: String {
        if authenticity.checkedDataGroups.isEmpty { return strings[.authenticityNotChecked] }
        let groups = authenticity.mismatchedDataGroups.isEmpty
            ? authenticity.checkedDataGroups
            : authenticity.mismatchedDataGroups
        return groups.map { "DG\($0)" }.joined(separator: ", ")
    }

    private func failureKey(_ failure: AuthenticityFailure) -> StringKey {
        switch failure {
        case .sodUnavailable: .authenticityFailSod
        case .dataGroupMismatch: .authenticityFailHash
        case .signatureInvalid: .authenticityFailSignature
        case .noTrustAnchor: .authenticityFailAnchor
        case .chainInvalid: .authenticityFailChain
        case .chipNotAuthentic: .authenticityFailChip
        case .error: .authenticityFailError
        }
    }
}
