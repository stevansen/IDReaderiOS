import SwiftUI
import IDReaderCore

/// Der Hinweis beim ersten Start.
///
/// ## Was er ist, und was er ausdruecklich nicht ist
///
/// Er ist **keine Einwilligung**. Wer die App bedient, ist nicht die betroffene
/// Person, sondern derjenige, der ueber die Verarbeitung entscheidet - seine
/// Zustimmung koennte gar nichts legitimieren. Deshalb steht auf dem Knopf „Alles
/// klar" und nicht „Zustimmen", und deshalb gibt es kein Kaestchen zum Anhaken.
/// Ein Einwilligungsdialog an dieser Stelle waere schlimmer als kein Hinweis: er
/// erzeugte den Anschein einer Rechtsgrundlage, die es nicht gibt.
///
/// Er ist auch **nicht die Unterrichtung der betroffenen Person**. Die schuldet
/// ihr der Bediener vor Ort, und die App kann sie ihm nicht abnehmen. Genau das
/// sagt der zweite Punkt.
///
/// Die App wird an jeden ausgegeben, der sie laedt - nicht nur an Behoerden.
/// Welche Rechtsgrundlage jemand hat, weiss sie also nicht, und deshalb nennt der
/// Text keine Vorschrift: er benennt die Verantwortung.
///
/// ## Warum er freundlich klingt
///
/// Eine erste Fassung sagte dreimal, was die App *nicht* fuer den Benutzer tut.
/// Sachlich richtig und trotzdem falsch: der erste Bildschirm einer App, der
/// belehrt, kostet die Lust daran, und wer die Lust verliert, liest den dritten
/// Satz nicht mehr - also genau den, auf den es ankommt.
///
/// Deshalb steht die gute Nachricht zuerst, die Bitte in der Mitte, und die
/// Verantwortung zuletzt. Weggelassen ist nichts.
///
/// ## Warum er eine Fassungsnummer hat
///
/// Der Bediener bestaetigt eine bestimmte Fassung, und die wird mit Zeitpunkt
/// vermerkt. Aendert sich der Text inhaltlich, steigt
/// ``AppSettings/noticeVersion`` und der Hinweis erscheint erneut.
struct FirstRunNotice: View {

    let strings: Strings
    let retentionDays: Int
    let onAcknowledge: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                // Drei Karten und nicht eine mit drei Absaetzen: die Maske daneben
                // ist aus Karten gebaut, und drei kurze lesen sich leichter als ein
                // Block, den man als Ganzes vor sich hat.
                VStack(spacing: 10) {
                    card(
                        symbol: "lock.fill",
                        title: strings[.noticeLocalTitle],
                        text: strings.format(.noticeLocalText, retentionDays)
                    )
                    card(
                        symbol: "person.fill",
                        title: strings[.noticePersonTitle],
                        text: strings[.noticePersonText]
                    )
                    card(
                        // Das Dokument der App selbst und kein Sinnbild fuer
                        // „entscheiden": worum es geht, ist das Dokument in der Hand.
                        symbol: "person.text.rectangle",
                        title: strings[.noticeDecisionTitle],
                        text: strings[.noticeDecisionText]
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }

            BottomActionBar {
                Button(action: onAcknowledge) {
                    Text(strings[.actionUnderstood])
                        .font(AppType.actionLarge)
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.onPrimary)
                .background(palette.primary, in: .capsule)
            }
        }
        .background(palette.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                Image(systemName: "person.text.rectangle.fill").font(.system(size: 24))
                Text(strings[.appName]).font(AppType.actionLarge)
            }
            .padding(.bottom, 8)

            Text(strings[.noticeTitle]).font(AppType.screenTitle)
            Text(strings[.noticeLead]).font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.primaryContainer)
        .foregroundStyle(palette.onPrimaryContainer)
        .clipShape(.rect(bottomLeadingRadius: 26, bottomTrailingRadius: 26))
    }

    /// Ein Punkt des Hinweises als eigene Karte.
    ///
    /// Aufbau wie eine Schrittkarte: runde Marke links, Ueberschrift, Satz
    /// darunter. Nur traegt die Marke ein Zeichen und keine Ziffer - es sind drei
    /// Hinweise und keine drei Schritte, und eine Nummer wuerde eine Reihenfolge
    /// behaupten, die es nicht gibt.
    private func card(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(palette.primary)
                .frame(width: 34, height: 34)
                .background(palette.primaryContainer, in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppType.cardHeading)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(palette.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(palette.outlineVariant, lineWidth: 1)
        }
        .foregroundStyle(palette.onSurface)
    }
}

/// Einstellungen.
///
/// Derzeit steht hier eine Sache, und deshalb ist der Bildschirm auch nur eine
/// Karte lang. Er bekommt trotzdem einen eigenen Platz: eine Sprache waehlt man
/// selten, aber wenn, dann sucht man sie unter „Einstellungen" und nirgends
/// sonst.
///
/// Die Sprachnamen stehen in ihrer eigenen Sprache - „Deutsch", nicht „German".
/// Wer die App gerade auf Italienisch vor sich hat und Deutsch sucht, sucht nach
/// „Deutsch". Uebersetzte Sprachnamen sind genau dort unbrauchbar, wo man sie
/// braucht.
struct SettingsScreen: View {

    @Bindable var model: ReaderModel
    let onBack: () -> Void

    @Environment(\.palette) private var palette
    @State private var warningShown = false
    private var strings: Strings { model.strings }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(strings[.actionBack])
                Text(strings[.menuSettings]).font(AppType.screenTitle).lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(palette.surfaceContainer)
            .foregroundStyle(palette.onSurface)
            .clipShape(.rect(bottomLeadingRadius: 26, bottomTrailingRadius: 26))

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(strings[.settingsLanguage])
                            .font(AppType.cardHeading)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 4)

                        ForEach(AppLanguage.allCases) { language in
                            Button {
                                model.language = language
                            } label: {
                                HStack(spacing: 8) {
                                    Image(
                                        systemName: model.language == language
                                            ? "largecircle.fill.circle" : "circle"
                                    )
                                    .foregroundStyle(
                                        model.language == language
                                            ? palette.primary : palette.outline
                                    )
                                    Text(strings[language.labelKey]).font(.body)
                                    Spacer(minLength: 0)
                                }
                                // Die ganze Zeile ist das Bedienelement, nicht nur
                                // der Ring: nach einem 20-Punkt-Kreis zu zielen ist
                                // unnoetig, wenn die Zeile daneben ohnehin leer ist.
                                .frame(minHeight: 52)
                                .padding(.horizontal, 12)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(
                                model.language == language ? .isSelected : []
                            )
                        }

                        Divider()
                            .overlay(palette.outlineVariant)
                            .padding(.horizontal, 16)

                        Text(strings[.settingsLanguageHint])
                            .font(.footnote)
                            .foregroundStyle(palette.onSurfaceVariant)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                    }
                    .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(palette.outlineVariant, lineWidth: 1)
                    }

                    retentionCard

                    revocationCard

                    Text(strings.format(.menuVersion, "\(AppInfo.version) (\(AppInfo.build))"))
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(palette.background)
        .foregroundStyle(palette.onSurface)
        .alert(strings[.settingsRetainAllWarningTitle], isPresented: $warningShown) {
            Button(strings[.actionCancel], role: .cancel) {}
            Button(strings[.settingsRetainAllConfirm]) {
                model.retainsAllFields = true
            }
        } message: {
            Text(strings[.settingsRetainAllWarningBody])
        }
    }

    /// Die Sperrlisten.
    ///
    /// Der einzige Schalter der App, der Netzverkehr betrifft, und deshalb der
    /// einzige, der erklaert werden muss statt nur benannt: was hinausgeht, wann,
    /// und was nicht. „Jetzt holen" bleibt bedienbar, auch wenn die Auffrischung
    /// aus ist - eine ausdrueckliche Anforderung ist die eine Einwilligung, die es
    /// hier gibt, und wer sie erteilt, soll sie nicht erst ueber einen Schalter
    /// erteilen muessen.
    @ViewBuilder private var revocationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(strings[.settingsRevocation])
                .font(AppType.cardHeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Toggle(isOn: Binding(
                get: { model.revocationUpdatesEnabled },
                set: { model.revocationUpdatesEnabled = $0 }
            )) {
                Text(strings[.settingsRevocationUpdates]).font(.body)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)

            Divider()
                .overlay(palette.outlineVariant)
                .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Text(revocationState)
                    .font(.footnote)
                    .foregroundStyle(palette.onSurfaceVariant)
                Spacer(minLength: 0)
                Button {
                    model.refreshRevocation(force: true)
                } label: {
                    if model.revocationRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(strings[.settingsRevocationRefresh]).font(AppType.actionSmall)
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.revocationRefreshing)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .foregroundStyle(palette.onSecondaryContainer)
                .background(palette.secondaryContainer, in: .capsule)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Text(strings[.settingsRevocationUpdatesHint])
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Text(strings[.revocationScope])
                .font(.caption)
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.outlineVariant, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    /// Ein Satz zum Stand: erst die Meldung des letzten Versuchs, sonst das
    /// Datum der vorliegenden Liste, sonst dass keine da ist. Dazu, wenn welche
    /// offen sind, wie viele.
    private var revocationState: String {
        var parts: [String] = []
        switch model.revocationNotice {
        case .updated(let date):
            parts.append(strings.format(.settingsRevocationUpdated, formatted(date)))
        case .unchanged:
            parts.append(strings[.settingsRevocationUnchanged])
        case .unreachable:
            parts.append(strings[.settingsRevocationUnreachable])
        case .unusable:
            parts.append(strings[.settingsRevocationUnusable])
        case .noSource:
            parts.append(strings[.settingsRevocationNoSource])
        case nil:
            if let issued = model.newestRevocationList {
                parts.append(strings.format(.revocationListDate, formatted(issued)))
            } else {
                parts.append(strings[.settingsRevocationNoList])
            }
        }
        let pending = model.pendingRevocationCount
        if pending > 0 {
            parts.append(strings.plural(.revocationPendingCount, pending))
        }
        return parts.joined(separator: " ")
    }

    private func formatted(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    /// Die Aufbewahrung.
    ///
    /// Ein Schalter, der den Datenschutz **schwaecht**, und deshalb einer, der
    /// nicht einfach umgeht: beim Einschalten kommt eine Rueckfrage, die den Grund
    /// verlangt. Beim Ausschalten nicht - zurueck zur Vorgabe braucht niemand eine
    /// Begruendung.
    @ViewBuilder private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(strings[.settingsRetention])
                .font(AppType.cardHeading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 4)

            Toggle(isOn: Binding(
                get: { model.retainsAllFields },
                set: { wanted in
                    if wanted {
                        // Nicht sofort setzen: erst die Frage nach dem Grund.
                        warningShown = true
                    } else {
                        model.retainsAllFields = false
                    }
                }
            )) {
                Text(strings[.settingsRetainAll]).font(.body)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)

            Divider()
                .overlay(palette.outlineVariant)
                .padding(.horizontal, 16)

            Text(strings[.settingsRetainAllHint])
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 12)
        }
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
        .overlay {
            // Der Rahmen ist Zierrat und soll keine Beruehrung annehmen. Er tat
            // es hier nicht, aber ueber einem Schalter will man sich darauf
            // nicht verlassen.
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.outlineVariant, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
