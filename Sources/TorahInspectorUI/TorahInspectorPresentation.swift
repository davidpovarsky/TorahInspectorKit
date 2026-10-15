import Foundation
import TorahInspectorCore

enum TorahInspectorPresentation {
    static func prefersHebrew(_ locale: Locale) -> Bool {
        let identifier = locale.identifier.lowercased()
        return identifier.hasPrefix("he") || identifier.hasPrefix("iw")
    }

    static func reference(canonical: String, hebrew: String?, locale: Locale) -> String {
        if let hebrew, !hebrew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hebrew
        }
        if canonical.hasPrefix("otzaria:") {
            let parts = canonical.split(separator: ":")
            if parts.count >= 4, let line = Int(parts.last!) {
                return "שורה \(line)"
            }
            return ""
        }
        return canonical
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
}
