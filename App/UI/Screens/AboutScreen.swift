import SwiftUI
import IDReaderCore

/// Wer die App gemacht hat, unter welcher Lizenz sie steht, und was fremd ist.
///
/// ## Warum es diesen Bildschirm gibt
///
/// Nicht aus Höflichkeit. Die App steht unter der Apache-Lizenz 2.0, und
/// Abschnitt 4(d) verlangt, dass die `NOTICE`-Angaben **beim Empfänger** ankommen.
/// „In der Quelltextform oder in der Dokumentation" genügt dafür, und beides liegt
/// im öffentlichen Repository — aber ein Ort in der App ist der ehrlichere: wer
/// die App aus dem Store lädt, hat das Repository nicht vor sich.
///
/// Dasselbe gilt für die fremden Bestandteile: MIT und Apache-2.0 verlangen beide,
/// dass ihr Vermerk mitreist. Ein Verweis auf eine Adresse im Netz ist dafür die
/// schwächere Form.
///
/// ## Was hier bewusst nicht steht
///
/// Keine E-Mail-Adresse. Wer die Entwickler erreichen will, findet den Weg über
/// das Repository; eine Adresse in einer App, die Ausweise liest, ist eine
/// Adresse, die in jedem Bericht landen kann.
struct AboutScreen: View {

    let strings: Strings
    let onBack: () -> Void

    @Environment(\.palette) private var palette

    /// Die Adresse steht an einer Stelle im Programm und nicht dreimal in den
    /// Sprachdateien - sie ist kein Text, der übersetzt wird.
    private let repository = "https://github.com/stevansen/IDReaderiOS"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel(strings[.actionBack])

                Text(strings[.aboutTitle])
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(palette.surfaceContainerHigh)
            .clipShape(.rect(cornerRadius: 20))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView {
                VStack(spacing: 12) {
                    karte(strings[.aboutAuthorsTitle], strings[.aboutAuthorsText])
                    karte(strings[.aboutLicenceTitle], strings[.aboutLicenceText])
                    karte(strings[.aboutThirdPartyTitle], strings[.aboutThirdPartyText])

                    // Der Verweis auf den Quelltext ist kein Zierrat: dort stehen
                    // die vollstaendigen Lizenztexte, und die kann kein Bildschirm
                    // ersetzen.
                    Link(destination: URL(string: repository)!) {
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text(strings[.aboutRepository])
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right.square")
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.surfaceContainer, in: .rect(cornerRadius: 14))
                    }
                    .accessibilityElement(children: .combine)

                    Text(strings.format(.menuVersion, "\(AppInfo.version) (\(AppInfo.build))"))
                        .font(.footnote)
                        .foregroundStyle(palette.onSurfaceVariant)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(palette.background)
        .foregroundStyle(palette.onSurface)
    }

    private func karte(_ titel: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).font(AppType.cardHeading)
            Text(text)
                .font(.footnote)
                .foregroundStyle(palette.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceContainerLowest, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(palette.outlineVariant, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
