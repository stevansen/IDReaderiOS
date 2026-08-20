import SwiftUI
import IDReaderCore

/// Die Fahrerlaubnis: kein Chip, keine Pruefung, das Foto ist die Quelle.
///
/// Alle Felder sind frei bearbeitbar, und das ist keine Bequemlichkeit, sondern
/// die einzige Absicherung, die diese Dokumentart hat. Die Texterkennung kann
/// sich verlesen, und niemand kann ihr widersprechen - es gibt keine Pruefziffer
/// und keinen Chip, der sich verweigert. Die einzige Instanz, die einen Lesefehler
/// bemerkt, ist der Mensch mit dem Dokument in der Hand. Also gehoert ihm das
/// letzte Wort, und die Maske ist eine Vorlage zum Gegenlesen, kein Ergebnis.
struct LicenceScreen: View {

    @Bindable var model: ReaderModel
    let onScanRequested: () -> Void

    @Environment(\.palette) private var palette
    private var strings: Strings { model.strings }

    /// Ob schon fotografiert wurde. Vor der ersten Aufnahme sind alle Felder leer,
    /// und dann ist Schritt 2 noch nicht an der Reihe.
    private var hasPhoto: Bool { !model.licenceInput.number.isEmpty || anyFieldFilled }

    private var anyFieldFilled: Bool {
        let i = model.licenceInput
        return !(i.surname + i.givenNames + i.dateOfBirth + i.placeOfBirth
            + i.dateOfIssue + i.dateOfExpiry + i.categories).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    StepCard(
                        number: 1,
                        title: strings[hasPhoto ? .licenceStepPhotoDone : .licenceStepPhotoTitle],
                        subtitle: strings[.licenceStepPhotoSubtitle],
                        wideSubtitle: true
                    ) {
                        if !hasPhoto {
                            DocumentGraphic(mode: .drivingLicence)
                                .frame(maxWidth: 300)
                                .frame(maxWidth: .infinity)
                        }
                        PrimaryActionButton(
                            title: strings[title],
                            systemImage: "camera.fill",
                            busy: model.scanState == .working,
                            action: onScanRequested
                        )
                        if model.scanState == .notFound || model.scanState == .failed {
                            Text(strings[.licenceScanNotFound])
                                .font(.footnote)
                                .foregroundStyle(palette.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    StepCard(
                        number: 2,
                        title: strings[.licenceStepCheckTitle],
                        badgeActive: hasPhoto,
                        contentSpacing: 9
                    ) {
                        field(strings[.labelSurname], $model.licenceInput.surname)
                        field(strings[.labelGivenNames], $model.licenceInput.givenNames)
                        field(strings[.labelDateOfBirth], $model.licenceInput.dateOfBirth)
                        field(strings[.labelPlaceOfBirth], $model.licenceInput.placeOfBirth)
                        field(strings[.labelDateOfIssue], $model.licenceInput.dateOfIssue)
                        field(strings[.labelDateOfExpiry], $model.licenceInput.dateOfExpiry)
                        field(
                            strings[.labelLicenceNumber],
                            $model.licenceInput.number,
                            mono: true
                        )
                        field(strings[.labelCategories], $model.licenceInput.categories)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            BottomActionBar(
                notice: {
                    // Der Hinweis steht hier und nicht am Feld: er gilt fuer den
                    // ganzen Datensatz, den man gleich speichert.
                    if model.licenceInput.numberLooksOdd {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(strings[.licenceNumberOdd]).font(.footnote)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(palette.errorContainer, in: .rect(cornerRadius: 12))
                        .foregroundStyle(palette.onErrorContainer)
                    }
                },
                action: {
                    Button(action: model.saveLicence) {
                        Text(strings[.licenceSave])
                            .font(AppType.actionLarge)
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(
                        model.licenceInput.isComplete ? palette.onPrimary
                                                      : palette.onSurfaceVariant
                    )
                    .background(
                        model.licenceInput.isComplete ? palette.primary
                                                      : palette.surfaceContainerHigh,
                        in: .capsule
                    )
                    .disabled(!model.licenceInput.isComplete)
                }
            )
        }
    }

    private var title: StringKey {
        if model.scanState == .working { return .licenceScanWorking }
        return hasPhoto ? .licenceScanAgain : .licenceScan
    }

    private func field(_ label: String, _ text: Binding<String>, mono: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.onSurfaceVariant)
            TextField("", text: text)
                .font(mono ? AppType.monoField : .body)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(palette.surfaceContainer, in: .rect(cornerRadius: 8))
        }
    }
}
