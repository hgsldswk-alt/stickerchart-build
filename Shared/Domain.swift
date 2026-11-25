import Foundation

struct Day: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    var utcDate: Date { Self.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))! }

    func local(hour: Int, calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))
    }

    func adding(days: Int) -> Day {
        Day(Self.calendar.date(byAdding: .day, value: days, to: utcDate)!, calendar: Self.calendar)
    }

    func days(until other: Day) -> Int {
        Self.calendar.dateComponents([.day], from: utcDate, to: other.utcDate).day ?? 0
    }

    static func < (a: Day, b: Day) -> Bool { (a.year, a.month, a.day) < (b.year, b.month, b.day) }

    static var today: Day {
        if Launch.testing, let i = Launch.arguments.firstIndex(of: "-today"), i + 1 < Launch.arguments.count,
           let d = Day(iso: Launch.arguments[i + 1]) { return d }
        return Day(Date())
    }

    init?(iso: String) {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1900...2200).contains(p[0]), (1...12).contains(p[1]), (1...31).contains(p[2]) else { return nil }
        let d = Day(year: p[0], month: p[1], day: p[2])
        guard Day(d.utcDate, calendar: Self.calendar) == d else { return nil }
        self = d
    }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var label: String { utcDate.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: TimeZone(identifier: "UTC")!)) }
}

enum Pack: String, Codable, CaseIterable, Identifiable {
    case stars, hearts, flowers, medals, mix
    var id: String { rawValue }

    var symbols: [String] {
        switch self {
        case .stars: return ["star.fill"]
        case .hearts: return ["heart.fill"]
        case .flowers: return ["camera.macro"]
        case .medals: return ["medal.fill"]
        case .mix: return ["star.fill", "heart.fill", "camera.macro", "medal.fill", "sun.max.fill", "leaf.fill", "moon.fill", "cloud.fill"]
        }
    }

    var cover: String { self == .mix ? "square.grid.2x2.fill" : symbols[0] }
}

struct Sticker: Codable, Equatable {
    var day: Day
    var symbol: String
    var color: Int
}

struct Chart: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = ""
    var goal = 20
    var reward = ""
    var midAt: Int?
    var midReward = ""
    var oncePerDay = true
    var pack = Pack.mix
    var stickers: [Sticker] = []
    var salt = Int.random(in: 0..<10_000)
    var created = Date()
    var completedOn: Day?
    var remindHour: Int?
    var who: String?

    static let goalRange = 3...100

    var count: Int { stickers.count }
    var full: Bool { count >= goal }
    var left: Int { max(0, goal - count) }
    var whoName: String { (who ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
    var forOther: Bool { !whoName.isEmpty }
    var baseTitle: String { title.trimmingCharacters(in: .whitespaces).isEmpty ? L.t("chart.untitled") : title }
    var displayTitle: String { forOther ? whoName + " · " + baseTitle : baseTitle }
    var rewardText: String {
        let r = reward.trimmingCharacters(in: .whitespaces)
        return r.isEmpty ? L.t(forOther ? "chart.rewardDefaultOther" : "chart.rewardDefault") : r
    }

    func stuck(on day: Day) -> Bool { stickers.contains { $0.day == day } }
    func canStick(on day: Day) -> Bool { !full && (!oncePerDay || !stuck(on: day)) }

    func streak(on today: Day) -> Int {
        let days = Set(stickers.map(\.day))
        var d = days.contains(today) ? today : today.adding(days: -1)
        var n = 0
        while days.contains(d) { n += 1; d = d.adding(days: -1) }
        return n
    }

    func nextSticker(on day: Day) -> Sticker {
        let seed = (count &+ 1) &* 2_654_435_761 &+ salt &* 40_503
        let symbols = pack.symbols
        let symbol = symbols[abs(seed / 7) % symbols.count]
        return Sticker(day: day, symbol: symbol, color: abs(seed / 13) % Palette.count)
    }

    func fresh() -> Chart {
        var c = Chart()
        c.title = title; c.goal = goal; c.reward = reward; c.midAt = midAt; c.midReward = midReward
        c.oncePerDay = oncePerDay; c.pack = pack; c.remindHour = remindHour; c.who = who
        return c
    }
}

enum Palette { static let count = 5 }

enum StickResult: Equatable {
    case stuck
    case mid(String)
    case full
    case alreadyToday
    case alreadyFull
}

enum Starter: String, CaseIterable, Identifiable {
    case walk, sugar, sleep, read, teeth
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .walk: return "figure.walk"
        case .sugar: return "cup.and.saucer.fill"
        case .sleep: return "bed.double.fill"
        case .read: return "book.fill"
        case .teeth: return "mouth.fill"
        }
    }

    func chart() -> Chart {
        var c = Chart()
        c.title = L.t("starter." + rawValue)
        c.reward = L.t("starter." + rawValue + ".reward")
        c.goal = self == .teeth ? 10 : 20
        c.pack = self == .teeth ? .stars : .mix
        return c
    }
}

struct Entitlement: Codable, Equatable {
    var firstOpen = Date()
    var trialClaimedAt: Date?
    var purchasedPro = false

    var trialStart: Date { min(firstOpen, trialClaimedAt ?? firstOpen) }
    var trialEnd: Date { trialStart.addingTimeInterval(30 * 86_400) }
    func hasPro(at now: Date) -> Bool {
        Launch.freePeriod || purchasedPro || (now >= trialStart && now < trialEnd)
    }
}

struct AppState: Codable, Equatable {
    var charts: [Chart] = []
    var wall: [Chart] = []
    var current: UUID?
    var entitlement = Entitlement()
    var totalStuck = 0
    var openDays: [String] = []
    var reviewAsked = false
    var milestonesShown: [String] = []

    var currentChart: Chart? { charts.first { $0.id == current } ?? charts.first }
    func index(_ id: UUID) -> Int? { charts.firstIndex { $0.id == id } }

    func canAdd(hasPro: Bool) -> Bool { hasPro || charts.count < Launch.freeLimit }

    mutating func add(_ chart: Chart) {
        charts.append(chart)
        current = chart.id
    }

    mutating func stick(_ id: UUID, on day: Day) -> StickResult? {
        guard let i = index(id) else { return nil }
        if charts[i].full { return .alreadyFull }
        if !charts[i].canStick(on: day) { return .alreadyToday }
        charts[i].stickers.append(charts[i].nextSticker(on: day))
        totalStuck += 1
        if charts[i].full {
            charts[i].completedOn = day
            return .full
        }
        if let m = charts[i].midAt, m == charts[i].count, !charts[i].midReward.trimmingCharacters(in: .whitespaces).isEmpty {
            return .mid(charts[i].midReward)
        }
        return .stuck
    }

    @discardableResult
    mutating func undo(_ id: UUID) -> Bool {
        guard let i = index(id), !charts[i].stickers.isEmpty else { return false }
        charts[i].stickers.removeLast()
        charts[i].completedOn = nil
        totalStuck = max(0, totalStuck - 1)
        return true
    }

    mutating func redeem(_ id: UUID, again: Bool) {
        guard let i = index(id) else { return }
        let done = charts.remove(at: i)
        wall.insert(done, at: 0)
        if again {
            let next = done.fresh()
            charts.insert(next, at: min(i, charts.count))
            current = next.id
        } else {
            current = charts.indices.contains(i) ? charts[i].id : charts.last?.id
        }
    }

    @discardableResult
    mutating func mergeProgress(_ other: Chart) -> Int? {
        guard let i = index(other.id) else { return nil }
        var mine = charts[i]
        let days = Set(mine.stickers.map(\.day)).union(other.stickers.map(\.day))
        var merged: [Sticker] = []
        for d in days.sorted() {
            let a = mine.stickers.filter { $0.day == d }, b = other.stickers.filter { $0.day == d }
            merged += b.count > a.count ? b : a
        }
        let before = mine.count
        mine.stickers = Array(merged.prefix(mine.goal))
        if mine.full, mine.completedOn == nil { mine.completedOn = mine.stickers.last?.day }
        charts[i] = mine
        totalStuck += max(0, mine.count - before)
        current = mine.id
        return mine.count
    }

    mutating func delete(_ id: UUID) {
        guard let i = index(id) else { return }
        charts.remove(at: i)
        current = charts.indices.contains(i) ? charts[i].id : charts.last?.id
    }
}

enum ChartError: Error, Equatable {
    case save, store, badCode, limit

    var message: String {
        switch self {
        case .save: return L.t("error.save")
        case .store: return L.t("error.store")
        case .badCode: return L.t("error.badCode")
        case .limit: return L.f("error.limit", Launch.freeLimit)
        }
    }
}
