import XCTest

@MainActor
final class TorahInspectorSheetDemoUITests: XCTestCase {
    func testThreeNativeDetentsInHebrewRTL() throws {
        for (index, detent) in ["peek", "medium", "large"].enumerated() {
            let app = XCUIApplication()
            app.launchArguments = ["--detent", detent]
            app.launch()

            let identifier = "torah-inspector-sheet-\(detent)"
            XCTAssertTrue(
                app.descendants(matching: .any)[identifier].waitForExistence(timeout: 30),
                "The native Torah sheet must appear at the \(detent) detent"
            )

            if detent == "peek" {
                XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-peek-tools"].exists)
                XCTAssertTrue(app.buttons["torah-inspector-expand-medium"].exists)
                XCTAssertFalse(app.buttons["torah-inspector-peek-insert"].exists)
            }

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = String(format: "%02d-torah-inspector-%@-hebrew-rtl", index + 1, detent)
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }
}
