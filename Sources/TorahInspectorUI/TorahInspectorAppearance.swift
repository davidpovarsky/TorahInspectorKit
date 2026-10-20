import SwiftUI

public enum TorahInspectorTextRole: Sendable {
    case heading
    case body
    case sourceBody
    case caption
    case button
}

@MainActor
public struct TorahInspectorTheme {
    public var primaryText: Color
    public var secondaryText: Color
    public var accent: Color
    public var background: Color
    public var elevatedSurface: Color
    public var divider: Color
    private let textRenderer: (String, TorahInspectorTextRole) -> AnyView

    public init(
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
        background: Color,
        elevatedSurface: Color,
        divider: Color,
        textRenderer: @escaping (String, TorahInspectorTextRole) -> AnyView
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.accent = accent
        self.background = background
        self.elevatedSurface = elevatedSurface
        self.divider = divider
        self.textRenderer = textRenderer
    }

    public func text(_ value: String, role: TorahInspectorTextRole) -> AnyView {
        textRenderer(value, role)
    }

    public static let native = TorahInspectorTheme(
        primaryText: .primary,
        secondaryText: .secondary,
        accent: .accentColor,
        background: .torahSystemBackground,
        elevatedSurface: .torahSecondarySystemBackground,
        divider: .secondary.opacity(0.25)
    ) { value, role in
        AnyView(Text(value).font(role.font))
    }
}

private extension TorahInspectorTextRole {
    var font: Font {
        switch self {
        case .heading: .headline
        case .body: .body
        case .sourceBody: .system(size: 18)
        case .caption: .caption
        case .button: .body.weight(.medium)
        }
    }
}

enum TorahInspectorAppearance {
    static let referenceSymbol = "book.closed"
    static let topicSymbol = "tag"
}
