import Foundation
import SwiftUI
import TorahInspectorCore

enum TorahInspectorPresentation {
    static func prefersHebrew(_ locale: Locale) -> Bool {
        let identifier = locale.identifier.lowercased()
        return identifier.hasPrefix("he") || identifier.hasPrefix("iw")
    }

    static func reference(canonical: String, hebrew: String?, locale: Locale) -> String {
        if canonical.hasPrefix("otzaria:") {
            if let hebrew, !hebrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return hebrew
            }
            let parts = canonical.split(separator: ":")
            if parts.count >= 4, let line = Int(parts.last!) {
                return "שורה \(line)"
            }
            return ""
        }
        return prefersHebrew(locale) ? (hebrew ?? canonical) : canonical
    }

    /// Resolves an immediately displayable route title without exposing the
    /// canonical English identifier while a Hebrew document is still loading.
    static func reference(
        selection: TorahInspectorSelection,
        loadedHebrewReference: String? = nil,
        locale: Locale
    ) -> String {
        if prefersHebrew(locale) {
            return firstNonempty(
                selection.displayMetadata?.hebrew,
                loadedHebrewReference,
                TorahStrings.text("Source", locale: locale)
            )
        }
        return firstNonempty(
            selection.displayMetadata?.english,
            selection.canonicalRef,
            TorahStrings.text("Source", locale: locale)
        )
    }

    static func linkedText(_ source: TorahLinkedSource, locale: Locale) -> String? {
        let preferred = prefersHebrew(locale) ? source.hebrewText : source.englishText
        let fallback = prefersHebrew(locale) ? source.englishText : source.hebrewText
        return preferred ?? fallback
    }

    static func topicTitle(_ topic: TorahLinkedTopic, locale: Locale) -> String {
        let preferred = prefersHebrew(locale) ? topic.titleHe : topic.titleEn
        let fallback = prefersHebrew(locale) ? topic.titleEn : topic.titleHe
        return preferred ?? fallback ?? topic.slug
    }

    static func workTitle(_ work: TorahWorkGroup, locale: Locale) -> String {
        let preferred = prefersHebrew(locale) ? work.hebrewTitle : work.title
        let fallback = prefersHebrew(locale) ? work.title : work.hebrewTitle
        return preferred ?? fallback ?? work.title
    }

    static func categoryTitle(_ category: TorahSourceCategory, locale: Locale) -> String {
        let key: String
        switch category {
        case .commentary: key = "Commentary"
        case .quotingCommentary: key = "Quoting Commentary"
        case .tanakh: key = "Tanakh"
        case .talmud: key = "Talmud"
        case .midrash: key = "Midrash"
        case .targum: key = "Targum"
        case .halakhah: key = "Halakhah"
        case .other: key = "Other"
        }
        return TorahStrings.text(key, locale: locale)
    }

    static func layoutDirection(for text: String) -> LayoutDirection {
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return .rightToLeft
            default:
                if CharacterSet.letters.contains(scalar) { return .leftToRight }
            }
        }
        return .leftToRight
    }

    private static func firstNonempty(_ values: String?...) -> String {
        values.lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }
}
