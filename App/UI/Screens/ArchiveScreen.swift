import SwiftUI
import IDReaderCore

/// Die Liste der aufbewahrten Lesevorgaenge.
///
/// Die Zeit ordnet die Liste. Tagesgruppen als Versalzeile, die Uhrzeit in einer
/// eigenen Spalte, damit die Zeiten untereinander stehen, die Dokumentart in ihrer
/// eigenen Farbe ueber einem fetten Namen, die Nummer nichtproportional, und das
/// Echtheitszeichen am Ende der Zeile. Das Datum wiederholt sich nicht in jeder
/// Zeile, wo es fruehe ueber drei Zeilen brach.
///
/// Die Haken erscheinen nur waehrend der Auswahl - ein langer Druck oder „alle
/// auswaehlen" startet sie -, weil sie in jeder Zeile den Platz nahmen, den jetzt
/// die farbige Kachel hat.
struct ArchiveScreen: View {

    @Bindable var model: ReaderModel
    let retentionDays: Int
    let onBack: () -> Void
    let onExportSelected: () -> Void

    @State private var selecting = false
    @Environment(\.palette) private var palette

    private var strings: Strings { model.strings }

    var body: some View {
        VStack(spacing: 0) {
            header

            if model.records.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundStyle(palette.onSurfaceVariant)
                    Text(strings[.archiveEmpty])
                        .font(.subheadline)
                        .foregroundStyle(palette.onSurfaceVariant)
                    Spacer()
                }
            } else {
                List {
                    ForEach(groups, id: \.title) { group in
                        Section {
                            ForEach(group.records) { record in
                                row(record)
                            }
                        } header: {
                            Text(group.title.uppercased())
                                .font(AppType.groupLabel)
                                .tracking(0.8)
                                .foregroundStyle(palette.onSurfaceVariant)
                        }
                    }

                    Section {
                        Text(strings.format(.archiveRetentionHint, retentionDays))
                            .font(.footnote)
                            .foregroundStyle(palette.onSurfaceVariant)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            if selecting && !model.selectedIds.isEmpty {
                BottomActionBar {
                    HStack(spacing: 10) {
                        Button(role: .destructive) {
                            model.deleteSelected()
                            selecting = false
                        } label: {
                            Label(strings[.storedDelete], systemImage: "trash")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.error)
                        .overlay { Capsule().stroke(palette.error, lineWidth: 1) }

                        Button(action: onExportSelected) {
                            Text(strings.plural(.archiveExport, model.selectedIds.count))
                                .font(AppType.actionLarge)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(palette.onPrimary)
                        .background(palette.primary, in: .capsule)
                    }
                }
            }
        }
        .background(palette.background)
    }

    // -----------------------------------------------------------------------

    private var header: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(strings[.actionBack])

            Text(
                selecting && !model.selectedIds.isEmpty
                    ? strings.plural(.archiveSelected, model.selectedIds.count)
                    : strings.plural(.archiveTitle, model.records.count)
            )
            .font(AppType.screenTitle)
            .lineLimit(1)

            Spacer(minLength: 0)

            if !model.records.isEmpty {
                Button {
                    selecting = true
                    model.toggleSelectAll()
                } label: {
                    Text(strings[.archiveSelectAll]).font(AppType.actionSmall)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(palette.surfaceContainer)
        .foregroundStyle(palette.onSurface)
        .clipShape(.rect(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    private func row(_ record: StoredDocument) -> some View {
        let mode = DocumentMode.of(record.data)
        return Button {
            if selecting {
                model.toggleSelection(record.id)
            } else {
                model.openRecord(record)
            }
        } label: {
            HStack(spacing: 12) {
                if selecting {
                    Image(
                        systemName: model.selectedIds.contains(record.id)
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(
                        model.selectedIds.contains(record.id) ? palette.primary : palette.outline
                    )
                }

                Text(time(record))
                    .font(AppType.monoRowValue)
                    .foregroundStyle(palette.onSurfaceVariant)
                    // Eine eigene Spalte, damit die Zeiten untereinander stehen.
                    .frame(width: 46, alignment: .leading)

                DocumentTile(mode: mode)

                VStack(alignment: .leading, spacing: 2) {
                    Text(strings[mode.labelKey])
                        .font(AppType.microLabel)
                        .foregroundStyle(DocumentPalette.tint(mode, dark: palette.isDark).content)
                    Text(record.data.fullName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text(record.data.documentNumber)
                        .font(AppType.monoRowValue)
                        .foregroundStyle(palette.onSurfaceVariant)
                    if record.data.provenance == .chip {
                        revocationLine(record)
                    }
                }

                Spacer(minLength: 0)
                AuthenticityMark(status: record.data.authenticity.status, strings: strings)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
        .onLongPressGesture {
            selecting = true
            model.toggleSelection(record.id)
        }
        .swipeActions {
            Button(role: .destructive) {
                model.deleteRecord(record.id)
            } label: {
                Label(strings[.storedDelete], systemImage: "trash")
            }
        }
    }

    // -----------------------------------------------------------------------

    /// Eine Zeile zur Sperrpruefung, so knapp wie eine Archivzeile es zulaesst.
    ///
    /// Das Datum steht dabei, nicht bloss ein Haken: gefragt war, **wann** gegen
    /// die Sperrlisten geprueft wurde, und ein Haken ohne Datum beantwortet das
    /// nicht. Ausstehend bekommt kein Datum, sondern das Wort - es gibt keins.
    @ViewBuilder private func revocationLine(_ record: StoredDocument) -> some View {
        HStack(spacing: 4) {
            switch record.revocation?.outcome {
            case .revoked:
                Image(systemName: "xmark.seal")
                Text(strings[.revocationRevoked])
            case .notRevoked:
                Image(systemName: "checkmark.seal")
                Text(
                    strings.format(
                        .revocationCheckedAt,
                        checkDate(record.revocation?.checkedAt)
                    )
                )
            case .noListForIssuer:
                Image(systemName: "questionmark.circle")
                Text(strings[.revocationNoList])
            case nil:
                Image(systemName: "clock")
                Text(strings[.revocationPending])
            }
        }
        .font(AppType.microLabel)
        .lineLimit(2)
        .foregroundStyle(
            record.revocation?.outcome == .revoked ? palette.error : palette.onSurfaceVariant
        )
    }

    private func checkDate(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(
            .dateTime.day().month().year().locale(Locale(identifier: strings.resolved))
        )
    }

    private struct Group {
        let title: String
        let records: [StoredDocument]
    }

    /// Tagesgruppen, neueste zuerst. „Heute" und „Gestern" tragen ihren Namen, alles
    /// Aeltere sein Datum.
    private var groups: [Group] {
        let calendar = Calendar.current
        var order: [String] = []
        var byDay: [String: [StoredDocument]] = [:]

        for record in model.records {
            let title: String
            if calendar.isDateInToday(record.storedDate) {
                title = strings[.archiveGroupToday]
            } else if calendar.isDateInYesterday(record.storedDate) {
                title = strings[.archiveGroupYesterday]
            } else {
                title = record.storedDate.formatted(
                    .dateTime.day().month().year()
                        .locale(Locale(identifier: strings.resolved))
                )
            }
            if byDay[title] == nil { order.append(title) }
            byDay[title, default: []].append(record)
        }
        return order.map { Group(title: $0, records: byDay[$0] ?? []) }
    }

    private func time(_ record: StoredDocument) -> String {
        record.storedDate.formatted(
            .dateTime.hour().minute().locale(Locale(identifier: strings.resolved))
        )
    }
}
