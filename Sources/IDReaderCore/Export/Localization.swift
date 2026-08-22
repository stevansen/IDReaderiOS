import Foundation

/// Jeder Text der App, unter dem Schluessel, unter dem er im Android-Original
/// stand.
///
/// Die Namen sind absichtlich unveraendert uebernommen. Solange beide Fassungen
/// gepflegt werden, ist eine geaenderte Formulierung damit in einem `grep` an
/// beiden Stellen zu finden; ein eigener, "schoenerer" Satz Namen haette diese
/// Bruecke gekostet, ohne etwas dafuer zu geben.
public enum StringKey: String, Sendable, CaseIterable {
    case appName = "app_name"

    // CAN-Eingabe
    case canHint = "can_hint"
    case canScan = "can_scan"
    case canScanWorking = "can_scan_working"
    case canScanTaken = "can_scan_taken"
    case canScanNotFound = "can_scan_not_found"
    case canScanWrongSide = "can_scan_wrong_side"
    case canScanAmbiguous = "can_scan_ambiguous"
    case canScanFailed = "can_scan_failed"
    case actionReadCard = "action_read_card"
    case actionReadCardFast = "action_read_card_fast"
    case actionMenu = "action_menu"
    case menuSettings = "menu_settings"
    case settingsLanguage = "settings_language"
    case settingsLanguageSystem = "settings_language_system"
    case settingsLanguageHint = "settings_language_hint"
    case settingsRetention = "settings_retention"
    case settingsRetainAll = "settings_retain_all"
    case settingsRetainAllHint = "settings_retain_all_hint"
    case settingsRetainAllWarningTitle = "settings_retain_all_warning_title"
    case settingsRetainAllWarningBody = "settings_retain_all_warning_body"
    case settingsRetainAllConfirm = "settings_retain_all_confirm"
    case revocationHeading = "revocation_heading"
    case revocationRevoked = "revocation_revoked"
    case revocationNotRevoked = "revocation_not_revoked"
    case revocationNoList = "revocation_no_list"
    case revocationPending = "revocation_pending"
    case revocationCheckedAt = "revocation_checked_at"
    case revocationListDate = "revocation_list_date"
    case revocationListStale = "revocation_list_stale"
    case revocationPendingHint = "revocation_pending_hint"
    case revocationScope = "revocation_scope"
    case settingsRevocation = "settings_revocation"
    case settingsRevocationUpdates = "settings_revocation_updates"
    case settingsRevocationUpdatesHint = "settings_revocation_updates_hint"
    case settingsRevocationRefresh = "settings_revocation_refresh"
    case settingsRevocationNoList = "settings_revocation_no_list"
    case settingsRevocationUpdated = "settings_revocation_updated"
    case settingsRevocationUnchanged = "settings_revocation_unchanged"
    case settingsRevocationUnreachable = "settings_revocation_unreachable"
    case settingsRevocationUnusable = "settings_revocation_unusable"
    case settingsRevocationNoSource = "settings_revocation_no_source"
    case languageDe = "language_de"
    case languageIt = "language_it"
    case languageEn = "language_en"
    case menuVersion = "menu_version"
    case actionClearAll = "action_clear_all"
    case actionBackspace = "action_backspace"

    // Lesevorgang
    case readingTitle = "reading_title"
    case readingInstruction = "reading_instruction"
    case readingTitlePassport = "reading_title_passport"
    case readingInstructionPassport = "reading_instruction_passport"
    case phaseConnect = "phase_connect"
    case phaseSecure = "phase_secure"
    case phaseData = "phase_data"
    case phaseVerify = "phase_verify"
    case actionCancel = "action_cancel"

    // Ergebnis
    case resultDocumentType = "result_document_type"
    case resultDocumentTypePassport = "result_document_type_passport"
    case resultDocumentTypeLicence = "result_document_type_licence"
    case resultValidUntil = "result_valid_until"
    case labelSurname = "label_surname"
    case labelGivenNames = "label_given_names"
    case labelDateOfBirth = "label_date_of_birth"
    case labelDocumentNumber = "label_document_number"
    case labelNationality = "label_nationality"
    case labelGender = "label_gender"
    case labelDateOfExpiry = "label_date_of_expiry"
    case labelPlaceOfBirth = "label_place_of_birth"
    case labelResidence = "label_residence"
    case labelCodiceFiscale = "label_codice_fiscale"
    case labelIssuingAuthority = "label_issuing_authority"
    case labelIssuingState = "label_issuing_state"
    case labelOtherNames = "label_other_names"
    case labelTitle = "label_title"
    case labelProfession = "label_profession"
    case labelPersonalSummary = "label_personal_summary"
    case labelTelephone = "label_telephone"
    case labelOtherDocuments = "label_other_documents"
    case labelCustody = "label_custody"
    case labelTaxExit = "label_tax_exit"
    case labelEndorsements = "label_endorsements"
    case labelDateOfIssue = "label_date_of_issue"
    case labelCategories = "label_categories"
    case labelLicenceNumber = "label_licence_number"
    case labelProvenance = "label_provenance"
    case valueProvenancePhoto = "value_provenance_photo"
    case valueMissing = "value_missing"
    case valueNotRetained = "value_not_retained"
    case retentionMinimisedHint = "retention_minimised_hint"
    case genderMale = "gender_male"
    case genderFemale = "gender_female"
    case genderUnknown = "gender_unknown"
    case resultRetentionHint = "result_retention_hint"
    case actionDone = "action_done"

    // Archiv
    case storedDelete = "stored_delete"
    case storedCopyNotice = "stored_copy_notice"
    case actionReadAgain = "action_read_again"
    case archiveSelectAll = "archive_select_all"
    case actionBackToPhoto = "action_back_to_photo"
    case archiveGroupToday = "archive_group_today"
    case archiveGroupYesterday = "archive_group_yesterday"
    case authenticityUnverifiedShort = "authenticity_unverified_short"
    case archiveEmpty = "archive_empty"
    case archiveRetentionHint = "archive_retention_hint"
    case exportScannedAt = "export_scanned_at"
    case exportCreatedAt = "export_created_at"

    // Erster Start
    case noticeTitle = "notice_title"
    case noticeLead = "notice_lead"
    case noticeLocalTitle = "notice_local_title"
    case noticeLocalText = "notice_local_text"
    case noticePersonTitle = "notice_person_title"
    case noticePersonText = "notice_person_text"
    case noticeDecisionTitle = "notice_decision_title"
    case noticeDecisionText = "notice_decision_text"
    case actionUnderstood = "action_understood"

    // Teilen
    case actionShare = "action_share"
    case actionCopy = "action_copy"
    case shareTitle = "share_title"
    case shareStepScopeTitle = "share_step_scope_title"
    case shareStepScopeSubtitle = "share_step_scope_subtitle"
    case shareStepWhereTitle = "share_step_where_title"
    case shareStepWhereSubtitle = "share_step_where_subtitle"
    case shareScopeLine = "share_scope_line"
    case shareScopePersonDocument = "share_scope_person_document"
    case shareScopeNoPhoto = "share_scope_no_photo"
    case shareWording = "share_wording"
    case shareShowText = "share_show_text"
    case shareHideText = "share_hide_text"
    case actionOtherApp = "action_other_app"
    case shareFormatReadable = "share_format_readable"
    case shareFormatJson = "share_format_json"
    case shareChooserTitle = "share_chooser_title"
    case shareSubject = "share_subject"
    case shareClipLabel = "share_clip_label"
    case shareCopied = "share_copied"
    case shareEmailLabel = "share_email_label"
    case actionSendEmail = "action_send_email"
    case shareNoMailApp = "share_no_mail_app"

    // Exporttext
    case exportSectionPerson = "export_section_person"
    case exportSectionDocument = "export_section_document"
    case exportSectionExtra = "export_section_extra"
    case exportSectionExtraDocument = "export_section_extra_document"
    case exportLabelResult = "export_label_result"
    case exportNoPhoto = "export_no_photo"
    case exportPhotoAttached = "export_photo_attached"
    case exportNoticePhoto = "export_notice_photo"

    // Echtheit
    case authenticityVerified = "authenticity_verified"
    case authenticityFailed = "authenticity_failed"
    case authenticityNotChecked = "authenticity_not_checked"
    case authenticityDetailsTitle = "authenticity_details_title"
    case authenticityCheckHashes = "authenticity_check_hashes"
    case authenticityCheckSignature = "authenticity_check_signature"
    case authenticityCheckChain = "authenticity_check_chain"
    case authenticityCheckChip = "authenticity_check_chip"
    case authenticityCheckChipDetail = "authenticity_check_chip_detail"
    case authenticitySigner = "authenticity_signer"
    case authenticityExplainer = "authenticity_explainer"
    case authenticityFailSod = "authenticity_fail_sod"
    case authenticityFailHash = "authenticity_fail_hash"
    case authenticityFailSignature = "authenticity_fail_signature"
    case authenticityFailAnchor = "authenticity_fail_anchor"
    case authenticityFailChain = "authenticity_fail_chain"
    case authenticityFailChip = "authenticity_fail_chip"
    case authenticityFailError = "authenticity_fail_error"

    // Fehler
    case errorTitle = "error_title"
    case errorWrongCan = "error_wrong_can"
    case errorWrongMrzKey = "error_wrong_mrz_key"
    case errorConnectionLost = "error_connection_lost"
    case errorExtendedLength = "error_extended_length"
    case errorUnsupportedTag = "error_unsupported_tag"
    case errorNoPace = "error_no_pace"
    case errorPaceUnavailable = "error_pace_unavailable"
    case errorUnknown = "error_unknown"
    /// „Protokoll kopieren (%d Zeilen)" - der Knopf auf dem Fehlerblatt.
    case errorCopyLog = "error_copy_log"
    case actionRetry = "action_retry"
    case actionBack = "action_back"

    // NFC
    case nfcDisabledTitle = "nfc_disabled_title"
    case nfcDisabledMessage = "nfc_disabled_message"
    case actionOpenNfcSettings = "action_open_nfc_settings"
    case noNfcTitle = "no_nfc_title"
    case noNfcMessage = "no_nfc_message"

    // Barrierefreiheit
    case cdPhoto = "cd_photo"
    case cdDigitFilled = "cd_digit_filled"
    case cdDigitEmpty = "cd_digit_empty"

    // Dokumentarten und Pass
    case modeIdentityCard = "mode_identity_card"
    case modePassport = "mode_passport"
    case modeLicence = "mode_licence"
    case passportTitle = "passport_title"
    case passportDocumentNumber = "passport_document_number"
    case passportDateOfBirth = "passport_date_of_birth"
    case passportDateOfExpiry = "passport_date_of_expiry"
    case passportDatePlaceholder = "passport_date_placeholder"
    case passportScan = "passport_scan"
    case passportScanWorking = "passport_scan_working"
    case passportScanNotFound = "passport_scan_not_found"
    case passportScanFailed = "passport_scan_failed"
    case passportScanConfirmed = "passport_scan_confirmed"
    case actionReadPassport = "action_read_passport"

    // Fahrerlaubnis
    case licenceScan = "licence_scan"
    case licenceStepPhotoDone = "licence_step_photo_done"
    case licenceScanAgain = "licence_scan_again"
    case licenceScanWorking = "licence_scan_working"
    case licenceScanNotFound = "licence_scan_not_found"
    case licenceNumberOdd = "licence_number_odd"
    case licenceSave = "licence_save"
    case licenceStepPhotoTitle = "licence_step_photo_title"
    case licenceStepPhotoSubtitle = "licence_step_photo_subtitle"
    case licenceStepCheckTitle = "licence_step_check_title"

    // Zwei Schritte
    case stepKeyCardTitle = "step_key_card_title"
    case stepKeyPassSubtitle = "step_key_pass_subtitle"
    case scanCaptionCan = "scan_caption_can"
    case scanCaptionMrz = "scan_caption_mrz"
    case keyFromPhoto = "key_from_photo"
    case keyTyped = "key_typed"
    case keyMissing = "key_missing"
    case actionChange = "action_change"
    case actionEnterByHand = "action_enter_by_hand"
    case manualDivider = "manual_divider"
    case canLabel = "can_label"
    case stepTapCard = "step_tap_card"
    case stepTapPassport = "step_tap_passport"
    case readWithoutPhoto = "read_without_photo"
}

/// Zaehlangaben.
///
/// Von Hand und nicht als `.stringsdict`: der Katalog braucht fuer Englisch,
/// Deutsch und Italienisch dieselben zwei Formen, und zwei Formen sind eine
/// Verzweigung. Ein Stringsdict waere dreimal derselbe Baum in XML, den kein
/// Test erreicht.
public enum PluralKey: String, Sendable, CaseIterable {
    case archiveTitle = "archive_title"
    case archiveOpen = "archive_open"
    case archiveSelected = "archive_selected"
    case archiveExport = "archive_export"
    case shareTitleMany = "share_title_many"
    case exportCollectionHeader = "export_collection_header"
    case shareFieldCount = "share_field_count"
    case revocationPendingCount = "revocation_pending_count"
}

/// Die Sprache, in der die App antwortet.
///
/// ``system`` ist absichtlich der Vorgabewert und nicht etwa Deutsch: wer nichts
/// einstellt, soll die Sprache bekommen, die er auf dem Geraet eingestellt hat -
/// auch dann, wenn er sie spaeter aendert.
public enum AppLanguage: String, Sendable, CaseIterable, Identifiable {
    case system
    case de
    case it
    case en

    public var id: String { rawValue }

    /// BCP-47-Kuerzel, oder nil fuer die Systemsprache.
    public var tag: String? { self == .system ? nil : rawValue }

    public init(tag: String?) {
        self = AppLanguage(rawValue: tag ?? "system") ?? .system
    }

    public var labelKey: StringKey {
        switch self {
        case .system: .settingsLanguageSystem
        case .de: .languageDe
        case .it: .languageIt
        case .en: .languageEn
        }
    }
}

/// Nachschlagewerk fuer Texte in einer festgelegten Sprache.
///
/// Warum ein eigenes Objekt und nicht `String(localized:)`: die App kann ihre
/// Sprache unabhaengig vom System einstellen, und dieselben Zeichenketten
/// bauen den Ausgabetext, der die App verlaesst. Beides braucht einen
/// **benannten** Katalog statt der Prozesssprache. Das Android-Original loeste
/// dasselbe Problem mit einem eigenen Context; hier ist es ein `Bundle` aus dem
/// passenden `.lproj`.
public struct Strings: Sendable {

    public let language: AppLanguage

    /// Die tatsaechlich verwendete Sprache - bei ``AppLanguage/system`` die des
    /// Geraets, sofern sie im Katalog steht, sonst Englisch.
    public let resolved: String

    private let table: [String: String]

    public init(language: AppLanguage) {
        self.language = language
        let wanted = language.tag ?? Strings.preferredSystemLanguage()
        self.resolved = Strings.available.contains(wanted) ? wanted : "en"
        self.table = Strings.loadTable(for: resolved)
    }

    /// Die drei Sprachen, die der Katalog fuehrt.
    public static let available: Set<String> = ["en", "de", "it"]

    /// Ob die deutsche Haelfte zweisprachiger Orts- und Adressangaben genommen
    /// wird.
    ///
    /// Bewusst an der App-Sprache und nicht an `Locale.current`: so entscheidet
    /// genau derselbe Mechanismus, der auch die Texte auswaehlt - einschliesslich
    /// der in der App eingestellten Sprache.
    public var prefersGerman: Bool { resolved == "de" }

    public func callAsFunction(_ key: StringKey) -> String { self[key] }

    public subscript(_ key: StringKey) -> String {
        table[key.rawValue] ?? Strings.fallback(key)
    }

    /// Ein Text mit Platzhaltern. Die Kataloge benutzen `%@` fuer Zeichenketten
    /// und `%d` fuer Zahlen, wie in einer `.strings`-Datei ueblich.
    public func format(_ key: StringKey, _ arguments: CVarArg...) -> String {
        String(format: self[key], arguments: arguments)
    }

    /// Eine Zaehlangabe. Englisch, Deutsch und Italienisch brauchen dieselben
    /// zwei Formen.
    public func plural(_ key: PluralKey, _ count: Int) -> String {
        let suffix = count == 1 ? "one" : "other"
        let pattern = table["\(key.rawValue)_\(suffix)"] ?? "%d"
        return String(format: pattern, count)
    }

    // -----------------------------------------------------------------------
    // Laden
    // -----------------------------------------------------------------------

    private static func preferredSystemLanguage() -> String {
        for identifier in Locale.preferredLanguages {
            let code = String(identifier.prefix(2)).lowercased()
            if available.contains(code) { return code }
        }
        return "en"
    }

    private static func loadTable(for language: String) -> [String: String] {
        // Ueber den Pfad und nicht ueber `Bundle.module.localizedString`: das
        // waehlt nach der Prozesssprache, und genau die soll hier nicht
        // entscheiden.
        guard let path = Bundle.module.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: language
        ), let table = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return [:]
        }
        return table
    }

    /// Wenn ein Schluessel im Katalog fehlt, steht sein Name da.
    ///
    /// Nicht ein leerer Text: ein leeres Feld in einem Einsatzbericht sieht wie
    /// eine Angabe aus, die das Dokument nicht fuehrt. Der Schluesselname sieht
    /// wie ein Fehler aus, und das ist er auch.
    private static func fallback(_ key: StringKey) -> String { key.rawValue }
}
