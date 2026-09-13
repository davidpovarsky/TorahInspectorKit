import Foundation
import TorahInspectorCore

enum TorahInspectorPresentation {
    static func prefersHebrew(_ locale: Locale) -> Bool {
        let identifier = locale.identifier.lowercased()
        return identifier.hasPrefix("he") || identifier.hasPrefix("iw")
    }

    static func reference(canonical: String, hebrew: String?, locale: Locale) -> String {
        prefersHebrew(locale) ? (hebrew ?? canonical) : canonical
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
}
