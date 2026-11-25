import XCTest

final class CoreTests: XCTestCase {
    private let today = Day(year: 2026, month: 11, day: 24)

    private func chart(goal: Int = 5, once: Bool = true) -> Chart {
        var c = Chart()
        c.title = "Walk"
        c.goal = goal
        c.reward = "Shoes"
        c.oncePerDay = once
        c.salt = 7
        return c
    }

    func testStickOncePerDayUndoAndFull() {
        var s = AppState()
        let c = chart(goal: 3)
        s.add(c)
        XCTAssertEqual(s.stick(c.id, on: today), .stuck)
        XCTAssertEqual(s.stick(c.id, on: today), .alreadyToday)
        XCTAssertEqual(s.currentChart?.count, 1)
        XCTAssertTrue(s.undo(c.id))
        XCTAssertEqual(s.currentChart?.count, 0)
        XCTAssertEqual(s.totalStuck, 0)
        XCTAssertFalse(s.undo(c.id))
        XCTAssertEqual(s.stick(c.id, on: today), .stuck)
        XCTAssertEqual(s.stick(c.id, on: today.adding(days: 1)), .stuck)
        XCTAssertEqual(s.stick(c.id, on: today.adding(days: 2)), .full)
        XCTAssertEqual(s.currentChart?.completedOn, today.adding(days: 2))
        XCTAssertEqual(s.stick(c.id, on: today.adding(days: 3)), .alreadyFull)
        XCTAssertEqual(s.totalStuck, 3)
        s.undo(c.id)
        XCTAssertNil(s.currentChart?.completedOn)
    }

    func testManyPerDayWhenOnceIsOff() {
        var s = AppState()
        let c = chart(goal: 8, once: false)
        s.add(c)
        for _ in 0..<3 { XCTAssertEqual(s.stick(c.id, on: today), .stuck) }
        XCTAssertEqual(s.currentChart?.count, 3)
    }

    func testMidRewardAndStreak() {
        var s = AppState()
        var c = chart(goal: 10)
        c.midAt = 2
        c.midReward = "Movie"
        s.add(c)
        XCTAssertEqual(s.stick(c.id, on: today.adding(days: -2)), .stuck)
        XCTAssertEqual(s.stick(c.id, on: today.adding(days: -1)), .mid("Movie"))
        XCTAssertEqual(s.currentChart?.streak(on: today), 2)
        XCTAssertEqual(s.stick(c.id, on: today), .stuck)
        XCTAssertEqual(s.currentChart?.streak(on: today), 3)
        XCTAssertEqual(s.currentChart?.streak(on: today.adding(days: 2)), 0)
    }

    func testRedeemMovesToWallAndAgainClones() {
        var s = AppState()
        let a = chart(goal: 3), b = chart(goal: 4)
        s.add(a); s.add(b)
        s.current = a.id
        s.redeem(a.id, again: false)
        XCTAssertEqual(s.wall.first?.id, a.id)
        XCTAssertEqual(s.charts.map(\.id), [b.id])
        XCTAssertEqual(s.current, b.id)
        _ = s.stick(b.id, on: today)
        s.redeem(b.id, again: true)
        XCTAssertEqual(s.wall.count, 2)
        XCTAssertEqual(s.charts.count, 1)
        XCTAssertNotEqual(s.charts[0].id, b.id)
        XCTAssertEqual(s.charts[0].title, "Walk")
        XCTAssertEqual(s.charts[0].goal, 4)
        XCTAssertEqual(s.charts[0].count, 0)
        XCTAssertEqual(s.current, s.charts[0].id)
    }

    func testDeleteKeepsCurrentValid() {
        var s = AppState()
        let a = chart(), b = chart()
        s.add(a); s.add(b)
        s.delete(b.id)
        XCTAssertEqual(s.current, a.id)
        s.delete(a.id)
        XCTAssertNil(s.current)
        XCTAssertNil(s.currentChart)
    }

    func testFreeLimit() {
        var s = AppState()
        XCTAssertTrue(s.canAdd(hasPro: false))
        s.add(chart()); s.add(chart())
        XCTAssertFalse(s.canAdd(hasPro: false))
        XCTAssertTrue(s.canAdd(hasPro: true))
    }

    func testTrialWindow() {
        var e = Entitlement()
        e.firstOpen = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(e.hasPro(at: e.firstOpen.addingTimeInterval(29 * 86_400)))
        XCTAssertFalse(e.hasPro(at: e.firstOpen.addingTimeInterval(31 * 86_400)))
        e.purchasedPro = true
        XCTAssertTrue(e.hasPro(at: e.firstOpen.addingTimeInterval(400 * 86_400)))
    }

    func testStickerPickIsStableAndFromPack() {
        var c = chart()
        c.pack = .hearts
        XCTAssertEqual(c.nextSticker(on: today), c.nextSticker(on: today))
        XCTAssertEqual(c.nextSticker(on: today).symbol, "heart.fill")
        c.pack = .mix
        for k in 0..<20 {
            let s = c.nextSticker(on: today.adding(days: k))
            XCTAssertTrue(Pack.mix.symbols.contains(s.symbol))
            XCTAssertTrue((0..<Palette.count).contains(s.color))
            c.stickers.append(s)
        }
        XCTAssertGreaterThanOrEqual(Set(c.stickers.map(\.symbol)).count, 3)
    }

    func testTransferRoundTripAndBadCode() throws {
        var c = chart(goal: 30)
        c.midAt = 10
        c.midReward = "Bubble tea"
        c.pack = .flowers
        c.stickers = [c.nextSticker(on: today)]
        let code = Transfer.code(for: c)
        XCTAssertTrue(code.hasPrefix("STK1:"))
        let back = try Transfer.chart(from: "hey try this " + code + " ok?")
        XCTAssertEqual(back.title, "Walk")
        XCTAssertEqual(back.goal, 30)
        XCTAssertEqual(back.midAt, 10)
        XCTAssertEqual(back.midReward, "Bubble tea")
        XCTAssertEqual(back.pack, .flowers)
        XCTAssertEqual(back.count, 0)
        XCTAssertNotEqual(back.id, c.id)
        XCTAssertThrowsError(try Transfer.chart(from: "STK1:@@@"))
        XCTAssertThrowsError(try Transfer.chart(from: "no code here"))
    }

    func testTransferClampsHostileValues() throws {
        let json = #"{"title":"X","goal":100000,"reward":"","midAt":-3,"midReward":"","oncePerDay":false,"pack":"nope"}"#
        let code = "STK1:" + Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let c = try Transfer.chart(from: code)
        XCTAssertEqual(c.goal, Chart.goalRange.upperBound)
        XCTAssertNil(c.midAt)
        XCTAssertEqual(c.pack, .mix)
        XCTAssertFalse(c.oncePerDay)
    }

    func testChartForSomeoneElse() throws {
        var c = chart()
        XCTAssertFalse(c.forOther)
        XCTAssertEqual(c.displayTitle, "Walk")
        c.who = "  Mia "
        XCTAssertTrue(c.forOther)
        XCTAssertEqual(c.displayTitle, "Mia · Walk")
        XCTAssertEqual(c.fresh().who, "  Mia ")
        c.stickers = [c.nextSticker(on: today)]
        let back = try Transfer.chart(from: Transfer.code(for: c))
        XCTAssertEqual(back.who, "Mia")
        XCTAssertEqual(back.count, 0)
        XCTAssertNotEqual(back.id, c.id)
    }

    func testSyncCodeCarriesProgressAndMerges() throws {
        var s = AppState()
        var mine = chart(goal: 10)
        s.add(mine)
        _ = s.stick(mine.id, on: today.adding(days: -2))
        _ = s.stick(mine.id, on: today.adding(days: -1))
        mine = s.charts[0]
        var theirs = try Transfer.chart(from: "here " + Transfer.code(for: mine, progress: true))
        XCTAssertEqual(theirs.id, mine.id)
        XCTAssertEqual(theirs.count, 2)
        theirs.stickers.append(theirs.nextSticker(on: today))
        let incoming = try Transfer.chart(from: Transfer.code(for: theirs, progress: true))
        XCTAssertEqual(s.mergeProgress(incoming), 3)
        XCTAssertEqual(s.charts[0].count, 3)
        XCTAssertEqual(s.mergeProgress(incoming), 3)
        var other = chart(); other.title = "Other"
        XCTAssertNil(s.mergeProgress(other))
        let json = #"{"title":"X","goal":5,"reward":"","midReward":"","oncePerDay":true,"pack":"mix","id":"\#(mine.id.uuidString)","st":["2026-11-24|not.a.symbol|1","bad"]}"#
        let code = "STK1:" + Data(json.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(try Transfer.chart(from: code).count, 0)
    }

    func testStateRoundTripsThroughJSON() throws {
        var s = AppState()
        var c = chart()
        c.remindHour = 21
        s.add(c)
        _ = s.stick(c.id, on: today)
        let data = try Store.encoder.encode(s)
        let back = try Store.decoder.decode(AppState.self, from: data)
        XCTAssertEqual(back.charts.first?.stickers, s.charts.first?.stickers)
        XCTAssertEqual(back.charts.first?.remindHour, 21)
        XCTAssertEqual(back.current, c.id)
    }

    func testDayParsing() {
        XCTAssertEqual(Day(iso: "2026-02-28")?.adding(days: 1), Day(year: 2026, month: 3, day: 1))
        XCTAssertNil(Day(iso: "2026-02-30"))
        XCTAssertNil(Day(iso: "junk"))
        XCTAssertEqual(today.days(until: today.adding(days: 10)), 10)
    }
}
