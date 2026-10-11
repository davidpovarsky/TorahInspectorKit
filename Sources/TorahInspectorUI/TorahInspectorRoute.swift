import Foundation
import TorahInspectorCore

public enum TorahInspectorRoute: Hashable, Sendable {
    case segment(TorahTextSegment)
    case source(TorahInspectorSelection)
}

/// Controls the initial view shown by ``TorahInspectorView``.
public enum TorahInspectorEntryMode: Sendable {
    /// Open the scrollable text reader for the whole section (default).
    case sourceReader
    /// Open relationships for the explicit section-or-segment selection.
    case relationships
    /// Compatibility spelling for callers that still enter with a segment.
    @available(*, deprecated, renamed: "relationships")
    case segmentRelationships
}

public enum TorahInspectorChrome: Sendable {
    case floatingPanel
    case embeddedSheet
}

public enum TorahStudyTool: String, CaseIterable, Identifiable, Hashable, Sendable {
    case commentaries
    case links
    case notes

    public var id: Self { self }

    public var localizedTitle: String {
        switch self {
        case .commentaries: TorahStrings.text("Commentaries")
        case .links: TorahStrings.text("Links")
        case .notes: TorahStrings.text("Notes")
        }
    }

    public func localizedTitle(locale: Locale) -> String {
        switch self {
        case .commentaries: TorahStrings.text("Commentaries", locale: locale)
        case .links: TorahStrings.text("Links", locale: locale)
        case .notes: TorahStrings.text("Notes", locale: locale)
        }
    }
}
