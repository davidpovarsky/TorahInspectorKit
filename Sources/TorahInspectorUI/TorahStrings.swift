import Foundation
import TorahInspectorCore

public enum TorahStrings {
    public static var close: String { text("Close") }
    public static var insertIntoDocument: String { text("Insert into document") }
    public static var openInNewTab: String { text("Open in new tab") }
    public static var copy: String { text("Copy") }
    public static var viewDetails: String { text("View details") }
    public static var couldNotLoadRelatedSources: String { text("Could not load related sources") }
    public static var retry: String { text("Retry") }
    public static var studyTools: String { text("Study Tools") }
    public static var selectedSegment: String { text("Selected Segment") }
    public static var addNote: String { text("Add Note") }

    public static func message(for error: Error) -> String {
        guard let torah = error as? TorahError else { return text("Could not load source") }
        switch torah {
        case .invalidReference: return text("The reference is not valid.")
        case .referenceTooBroad: return text("Choose a more specific source.")
        case .noText: return text("No text is available for this source.")
        case .missingProvider: return text("No Torah provider is available.")
        case .noResults: return text("No results")
        case .malformedResponse, .network: return text("Could not load source")
        case .storage: return text("Torah storage is unavailable.")
        }
    }

    public static func text(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: .module)
    }

    public static func text(_ key: String, locale: Locale) -> String {
        let rawLanguage = locale.identifier
            .split(whereSeparator: { $0 == "_" || $0 == "-" })
            .first
            .map(String.init)?
            .lowercased() ?? "en"
        let language = rawLanguage == "iw" ? "he" : rawLanguage
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return NSLocalizedString(key, bundle: .module, comment: "")
        }
        return NSLocalizedString(key, bundle: localizedBundle, comment: "")
    }
}
