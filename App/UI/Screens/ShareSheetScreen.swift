import SwiftUI
import IDReaderCore

/// Der Weg nach draussen.
///
/// Zwei Schritte wie die Eingabemasken. Schritt 1 rechnet ab, was die App
/// verlaesst: jeder Datensatz mit seiner Art, seiner Feldzahl und seinem
/// Echtheitszeichen, dann der Umfang als zwei Aussagen, dann der Wortlaut hinter
/// einer einzigen Zeile weggeklappt. Schritt 2 ist der Ausgang.
///
/// Die Schalter, die hier einmal standen - fuer die DG11-Felder und das
/// Pruefergebnis -, sind weg. Sie verlangten eine Entscheidung, die im Einsatz
/// niemand treffen will, und was hinausgeht, wird jetzt **gesagt** statt
/// eingestellt.
///
/// Das Lichtbild geht **nur per Mail** mit, und nur mit der lesbaren Fassung: dort
/// ist der Empfaenger benannt und die Nachricht adressiert, was von der
/// Zwischenablage und von einem Teilen-Dialog mit nachtraeglich gewaehltem Ziel
/// nicht gilt.
struct ShareSheetScreen: View {

    let documents: [StoredDocument]
    @Bindable var model: ReaderModel
    let onDismiss: () -> Void

    @State private var wordingShown = false
    @State private var systemShareItem: String?
    @State private var mailDraft: MailDraft?
    @State private var copiedNotice = false
    @Environment(\.palette) private var palette

    private var strings: Strings { model.strings }
    private var export: DocumentExport { DocumentExport(strings: strings) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    scopeCard
                    whereCard
                }
                .padding(16)
            }
            .background(palette.background)
            .navigationTitle(
                documents.count > 1
                    ? strings.plural(.shareTitleMany, documents.count)
                    : strings[.shareTitle]
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings[.actionCancel], action: onDismiss)
                }
            }
            .overlay(alignment: .bottom) {
                if copiedNotice {
                    Text(strings[.shareCopied])
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(palette.surfaceContainerHigh, in: .capsule)
                        .padding(.bottom, 24)
                        .transition(.opacity)
                }
            }
        }
        .sheet(item: $systemShareItem) { text in
            SystemShareSheet(items: [text])
        }
        .sheet(item: $mailDraft) { draft in
            MailComposer(draft: draft) { onDismiss() }
        }
    }

    // -----------------------------------------------------------------------

    private var scopeCard: some View {
        StepCard(
            number: 1,
            title: strings[.shareStepScopeTitle],
            subtitle: strings[.shareStepScopeSubtitle],
            wideSubtitle: true
        ) {
            ForEach(documents) { document in
                let record = export.structure(document)
                let mode = DocumentMode.of(document.data)
                HStack(spacing: 10) {
                    DocumentTile(mode: mode)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(document.data.fullName)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(strings.format(
                            .shareScopeLine,
                            strings[mode.labelKey],
                            strings.plural(.shareFieldCount, record.fieldCount)
                        ))
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                    }
                    Spacer(minLength: 0)
                    AuthenticityMark(status: document.data.authenticity.status, strings: strings)
                }
            }

            Divider().overlay(palette.outlineVariant)

            // Der Umfang als zwei Aussagen, nicht als zwei Schalter.
            VStack(alignment: .leading, spacing: 4) {
                statement(strings[.shareScopePersonDocument])
                statement(strings[.shareScopeNoPhoto])
            }

            Divider().overlay(palette.outlineVariant)

            Picker(strings[.shareWording], selection: Binding(
                get: { model.exportFormat },
                set: { model.exportFormat = $0 }
            )) {
                ForEach(ExportFormat.allCases) { format in
                    Text(strings[format.labelKey]).tag(format)
                }
            }
            .pickerStyle(.segmented)

            DisclosureGroup(
                isExpanded: $wordingShown,
                content: {
                    // Die Vorschau ist eine echte zweispaltige Tabelle und kein
                    // vorformatierter Text. Beides entsteht aus demselben
                    // `ExportRecord`, damit die Vorschau nicht etwas anderes zeigt
                    // als das, was hinausgeht.
                    if model.exportFormat == .readable {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(documents) { document in
                                preview(export.structure(document))
                            }
                        }
                        .padding(.top, 8)
                    } else {
                        Text(export.build(documents, format: .json))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                },
                label: {
                    Text(strings[wordingShown ? .shareHideText : .shareShowText])
                        .font(AppType.actionSmall)
                }
            )
        }
    }

    private func statement(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark").font(.system(size: 11))
            Text(text).font(.footnote)
        }
        .foregroundStyle(palette.onSurfaceVariant)
    }

    private func preview(_ record: ExportRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.title).font(.subheadline.weight(.semibold))
            Text(record.subtitle)
                .font(.caption)
                .foregroundStyle(palette.onSurfaceVariant)
            if let notice = record.notice {
                Text(notice)
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(palette.errorContainer, in: .rect(cornerRadius: 8))
                    .foregroundStyle(palette.onErrorContainer)
            }
            ForEach(record.sections) { section in
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.primary)
                    .padding(.top, 4)
                ForEach(section.rows) { row in
                    HStack(alignment: .top, spacing: 8) {
                        Text(row.label)
                            .font(.caption)
                            .foregroundStyle(palette.onSurfaceVariant)
                            .frame(width: 120, alignment: .leading)
                        Text(row.value).font(.caption)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(10)
        .background(palette.surfaceContainer, in: .rect(cornerRadius: 10))
    }

    // -----------------------------------------------------------------------

    private var whereCard: some View {
        StepCard(
            number: 2,
            title: strings[.shareStepWhereTitle],
            subtitle: strings[.shareStepWhereSubtitle],
            wideSubtitle: true
        ) {
            HStack(spacing: 6) {
                TextField(
                    strings[.shareEmailLabel],
                    text: Binding(get: { model.shareEmail }, set: { model.shareEmail = $0 })
                )
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(palette.surfaceContainer, in: .rect(cornerRadius: 10))
            }

            Button {
                mailDraft = ExportActions.mailDraft(
                    documents: documents,
                    to: model.shareEmail,
                    format: model.exportFormat,
                    strings: strings
                )
            } label: {
                Label(strings[.actionSendEmail], systemImage: "envelope.fill")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain)
            .foregroundStyle(palette.onPrimary)
            .background(
                AppSettings.looksLikeEmail(model.shareEmail)
                    ? palette.primary : palette.surfaceContainerHigh,
                in: .capsule
            )
            .disabled(!AppSettings.looksLikeEmail(model.shareEmail) || !MailComposer.canSendMail)

            HStack(spacing: 10) {
                Button {
                    ExportActions.copyToClipboard(
                        export.build(documents, format: model.exportFormat)
                    )
                    withAnimation { copiedNotice = true }
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { copiedNotice = false }
                    }
                } label: {
                    Label(strings[.actionCopy], systemImage: "doc.on.doc")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .overlay { Capsule().stroke(palette.outline, lineWidth: 1) }

                Button {
                    systemShareItem = export.build(documents, format: model.exportFormat)
                } label: {
                    Label(strings[.actionOtherApp], systemImage: "square.and.arrow.up")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
                .overlay { Capsule().stroke(palette.outline, lineWidth: 1) }
            }
        }
    }
}

/// `sheet(item:)` mit einer Zeichenkette als Kennung.
extension String: @retroactive Identifiable {
    public var id: String { self }
}
