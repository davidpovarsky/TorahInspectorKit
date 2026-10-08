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
    /// Jump directly to the segment-level relationships view.
    /// Requires ``TorahInspectorSelection/preferredSegmentRef`` to be non-nil;
    /// falls back to ``sourceReader`` otherwise.
    case segmentRelationships
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
