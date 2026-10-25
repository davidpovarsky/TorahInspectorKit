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
                XCTAssertTrue(app.buttons["torah-inspector-peek-close"].exists)
                XCTAssertFalse(app.buttons["torah-inspector-search-entry-peek"].exists)
                XCTAssertFalse(app.buttons["torah-inspector-peek-insert"].exists)
                app.descendants(matching: .any)["torah-inspector-peek-tools"].tap()
                XCTAssertTrue(
                    app.descendants(matching: .any)["torah-inspector-sheet-medium"].waitForExistence(timeout: 5),
                    "Tapping the selected Peek tool must expand the native sheet to medium"
                )
            }

            if detent != "peek" {
                XCTAssertTrue(app.buttons["torah-inspector-close"].exists)
                XCTAssertFalse(app.buttons["torah-inspector-search-entry"].exists)
            }

            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = String(format: "%02d-torah-inspector-%@-hebrew-rtl", index + 1, detent)
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }

    func testHostSearchUsesTheExistingStackAndPreservesSearchState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--detent", "medium", "--search-enabled"]
        app.launch()

        let search = app.buttons["torah-inspector-search-entry"]
        XCTAssertTrue(search.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["torah-inspector-close"].exists)
        search.tap()

        XCTAssertTrue(app.descendants(matching: .any)["demo-search-destination"].waitForExistence(timeout: 5))
        let field = app.descendants(matching: .any)["demo-search-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("בראשית")
        app.buttons["demo-search-result-b"].tap()

        XCTAssertTrue(app.staticTexts["וְאֵלֶּה שְׁמוֹת בְּנֵי יִשְׂרָאֵל"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "בראשית")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["בְּרֵאשִׁית בָּרָא אֱלֹהִים אֵת הַשָּׁמַיִם וְאֵת הָאָרֶץ׃"].exists)
    }

    func testPeekSearchPromotesTheSameSheetBeforeShowingSearch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--detent", "peek", "--search-enabled"]
        app.launch()

        let peekSearch = app.buttons["torah-inspector-search-entry-peek"]
        XCTAssertTrue(peekSearch.waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["torah-inspector-peek-close"].exists)
        peekSearch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["torah-inspector-sheet-large"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["demo-search-destination"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["demo-search-field"].exists)
    }
}
