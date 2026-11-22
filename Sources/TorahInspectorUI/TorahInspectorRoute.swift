import Foundation
import TorahInspectorCore

public enum TorahInspectorRoute: Hashable, Sendable {
    case search
    case segment(TorahTextSegment)
    case source(TorahInspectorSelection)
    case fullSource(TorahInspectorSelection)
}

public struct TorahStudyToolID: RawRepresentable, Hashable, Identifiable, Sendable {
    public let rawValue: String
    public var id: String { rawValue }

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let commentaries = Self(rawValue: "commentaries")
    public static let links = Self(rawValue: "links")
    public static let notes = Self(rawValue: "notes")
    public static let relatedDocuments = Self(rawValue: "relatedDocuments")

    public func localizedTitle(locale: Locale) -> String {
        switch self {
        case .commentaries: TorahStrings.text("Commentaries", locale: locale)
        case .links: TorahStrings.text("Links", locale: locale)
        case .notes: TorahStrings.text("Notes", locale: locale)
        case .relatedDocuments: TorahStrings.text("In Documents", locale: locale)
        default: rawValue
        }
    }
}

@MainActor
public struct TorahInspectorConfiguration {
    public var availableTools: [TorahStudyToolID]
    public var allowsInlineFullSourceNavigation: Bool
    public var theme: TorahInspectorTheme

    public init(
        availableTools: [TorahStudyToolID] = [.commentaries, .links, .notes],
        allowsInlineFullSourceNavigation: Bool = false,
        theme: TorahInspectorTheme = .native
    ) {
        self.availableTools = availableTools.isEmpty ? [.commentaries] : availableTools
        self.allowsInlineFullSourceNavigation = allowsInlineFullSourceNavigation
        self.theme = theme
    }

    public static let legacy = Self()
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
    public var toolID: TorahStudyToolID { TorahStudyToolID(rawValue: rawValue) }

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
