import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum TorahPlatformClipboard {
    static func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([text as NSString])
        #endif
    }
}

extension Color {
    static var torahSecondarySystemBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color.secondary.opacity(0.08)
        #endif
    }
}

extension View {
    @ViewBuilder
    func torahInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
