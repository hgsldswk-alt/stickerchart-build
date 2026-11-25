import XCTest

final class FlowUITests: XCTestCase {
    private let app = XCUIApplication()
    private let readCode = "STK1:eyJ0aXRsZSI6IlJlYWQgMTAgcGFnZXMiLCJnb2FsIjoxMCwicmV3YXJkIjoiQSBuZXcgYm9vayIsIm1pZEF0Ijo1LCJtaWRSZXdhcmQiOiJUZWEiLCJvbmNlUGVyRGF5Ijp0cnVlLCJwYWNrIjoic3RhcnMifQ"

    override func setUp() {
        continueAfterFailure = false
        executionTimeAllowance = 900
    }

    func testStarterThenStickInOneTapAndUndo() {
        launch()
        tap("starter.walk")
        let count = wait("chart.count")
        XCTAssertTrue(count.label.hasPrefix("0 "), count.label)
        tap("home.stick")
        XCTAssertTrue(waitLabel("chart.count", prefix: "1 "), element("chart.count").label)
        XCTAssertFalse(element("home.stick").isEnabled)
        tap("home.undo")
        XCTAssertTrue(waitLabel("chart.count", prefix: "0 "), element("chart.count").label)
        XCTAssertTrue(element("home.stick").isEnabled)
    }

    func testTapNextCellSticks() {
        launch(["-demo"])
        XCTAssertTrue(wait("chart.count").label.hasPrefix("13 "))
        tap("cell.13")
        XCTAssertTrue(waitLabel("chart.count", prefix: "14 "), element("chart.count").label)
    }

    func testFillChartCelebrateShareRedeemAndWall() {
        launch(["-demo-almost"])
        tap("home.stick")
        XCTAssertTrue(wait("celebrate.title", timeout: 12).exists)
        tap("celebrate.share")
        XCTAssertTrue(wait("share.card", timeout: 15).exists)
        XCTAssertTrue(wait("share.code").exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        tap("celebrate.redeem")
        XCTAssertTrue(app.staticTexts["No sugary drinks"].waitForExistence(timeout: 8))
        tap("home.wall")
        XCTAssertTrue(wait("wall.count").label.hasPrefix("3 "), element("wall.count").label)
        tap("wall.item.0")
        XCTAssertTrue(wait("share.card", timeout: 15).exists)
    }

    func testFreeLimitAndNewChartFromCode() {
        launch(["-demo", "-expired"])
        tap("home.new")
        XCTAssertTrue(wait("paywall.status").exists)

        launch(["-demo", "-paid"])
        tap("home.new")
        let field = wait("editor.code", slide: true)
        field.tap()
        field.typeText(readCode)
        tapImport()
        let title = element("editor.title")
        for _ in 0..<5 where !(title.waitForExistence(timeout: 2) && title.isHittable) {
            let form = app.collectionViews.firstMatch
            (form.exists ? form : app).swipeDown()
        }
        if !title.exists { print(app.debugDescription) }
        XCTAssertTrue(title.exists, "editor.title")
        XCTAssertEqual(title.value as? String, "Read 10 pages")
        tap("editor.done")
        XCTAssertTrue(app.staticTexts["Read 10 pages"].waitForExistence(timeout: 8))
    }

    func testBadCodeShowsNotice() {
        launch(["-demo", "-paid"])
        tap("home.new")
        let field = wait("editor.code", slide: true)
        field.tap()
        field.typeText("STK1:@@@")
        tapImport()
        XCTAssertTrue(wait("app.notice").exists)
        let v = wait("editor.title").value as? String ?? ""
        XCTAssertTrue(v.isEmpty || v == "What are you sticking with?", v)
    }

    func testChartForSomeoneElse() {
        launch(["-demo", "-paid"])
        tap("home.new")
        let title = wait("editor.title")
        title.tap()
        title.typeText("Brush teeth")
        let who = wait("editor.who")
        who.tap()
        who.typeText("Mia")
        tap("editor.done")
        XCTAssertTrue(app.staticTexts["Mia · Brush teeth"].waitForExistence(timeout: 8))
        shot("paid-02-who-home")
        tap("home.settings")
        XCTAssertTrue(wait("settings.syncChart", slide: true).exists)
        shot("paid-03-who-sync")
    }

    func testStoreScreenshots() {
        for language in ["en", "zh-Hans", "zh-Hant"] {
            launch(["-demo"], language: language)
            XCTAssertTrue(wait("home.stick").exists)
            shot("store-\(language)-01-home")
            tap("home.stick")
            Thread.sleep(forTimeInterval: 1.2)
            shot("store-\(language)-02-stuck")

            launch(["-demo-almost"], language: language)
            tap("home.stick")
            XCTAssertTrue(wait("celebrate.title", timeout: 12).exists)
            Thread.sleep(forTimeInterval: 0.8)
            shot("store-\(language)-03-celebrate")
            tap("celebrate.share")
            XCTAssertTrue(wait("share.card", timeout: 15).exists)
            Thread.sleep(forTimeInterval: 1.0)
            shot("store-\(language)-04-share")

            launch(["-demo"], language: language)
            tap("home.wall")
            XCTAssertTrue(wait("wall.item.0").exists)
            shot("store-\(language)-05-wall")
        }
        launch(["-demo", "-paywall"])
        XCTAssertTrue(wait("paywall.status").exists)
        shot("paid-01-paywall")
    }


    private func launch(_ flags: [String] = [], language: String = "en") {
        if app.state != .notRunning { app.terminate() }
        let locale = language == "zh-Hans" ? "zh_CN" : language == "zh-Hant" ? "zh_TW" : "en_US"
        app.launchArguments = ["-ui-testing", "-reset", "-today", "2026-11-24", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + flags
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitLabel(_ id: String, prefix: String, timeout: TimeInterval = 6) -> Bool {
        let item = element(id)
        let ok = NSPredicate { _, _ in item.exists && item.label.hasPrefix(prefix) }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ok, object: nil)], timeout: timeout) == .completed
    }

    @discardableResult
    private func wait(_ id: String, timeout: TimeInterval = 8, slide: Bool = false, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let item = element(id)
        _ = item.waitForExistence(timeout: slide ? min(timeout, 3) : timeout)
        if slide {
            for _ in 0..<8 {
                if item.exists && item.isHittable { break }
                let form = app.collectionViews.firstMatch
                (form.exists ? form : app).swipeUp()
                Thread.sleep(forTimeInterval: 1.2)
            }
        }
        XCTAssertTrue(item.exists, id, file: file, line: line)
        return item
    }

    private func tapImport(file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons.matching(identifier: "editor.import").firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8), "editor.import", file: file, line: line)
        let enabled = NSPredicate { _, _ in button.isEnabled }
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: enabled, object: nil)], timeout: 5)
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func tap(_ id: String, slide: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let item = wait(id, slide: slide, file: file, line: line)
        let ready = NSPredicate { _, _ in item.exists && item.isHittable && item.isEnabled }
        if XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 8) == .completed {
            item.tap()
            return
        }
        XCTAssertTrue(item.exists && item.isEnabled, id, file: file, line: line)
        item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
