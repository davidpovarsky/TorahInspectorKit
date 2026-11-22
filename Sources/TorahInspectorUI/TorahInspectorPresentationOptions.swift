import SwiftUI

/// Optional host chrome preferences. Defaults preserve every existing consumer.
public struct TorahInspectorPresentationOptions: Equatable, Sendable {
    public var showsStudyToolsTitle: Bool
    public var showsSelectedSegmentTitle: Bool
    public var usesMinimalChrome: Bool

    public init(showsStudyToolsTitle: Bool = true, showsSelectedSegmentTitle: Bool = true, usesMinimalChrome: Bool = false) {
        self.showsStudyToolsTitle = showsStudyToolsTitle
        self.showsSelectedSegmentTitle = showsSelectedSegmentTitle
        self.usesMinimalChrome = usesMinimalChrome
    }
}

private struct TorahInspectorPresentationOptionsKey: EnvironmentKey {
    static let defaultValue = TorahInspectorPresentationOptions()
}

extension EnvironmentValues {
    var torahInspectorPresentationOptions: TorahInspectorPresentationOptions {
        get { self[TorahInspectorPresentationOptionsKey.self] }
        set { self[TorahInspectorPresentationOptionsKey.self] = newValue }
    }
}

// Existing legacy entry points retain their header and selected-segment card.
// Configured tool-ID entry points keep the native navigation presentation.
private struct TorahInspectorLegacyDetailLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var torahInspectorUsesLegacyDetailLayout: Bool {
        get { self[TorahInspectorLegacyDetailLayoutKey.self] }
        set { self[TorahInspectorLegacyDetailLayoutKey.self] = newValue }
    }
}
