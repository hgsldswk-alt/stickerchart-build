import Foundation

enum Transfer {
    static let prefix = "STK1:"

    struct Payload: Codable, Equatable {
        var title: String
        var goal: Int
        var reward: String
        var midAt: Int?
        var midReward: String
        var oncePerDay: Bool
        var pack: String
        var who: String? = nil
        var id: String? = nil
        var st: [String]? = nil
    }

    static func code(for chart: Chart, progress: Bool = false) -> String {
        var p = Payload(title: chart.title, goal: chart.goal, reward: chart.reward, midAt: chart.midAt,
                        midReward: chart.midReward, oncePerDay: chart.oncePerDay, pack: chart.pack.rawValue,
                        who: chart.forOther ? chart.whoName : nil)
        if progress {
            p.id = chart.id.uuidString
            p.st = chart.stickers.map { "\($0.day.iso)|\($0.symbol)|\($0.color)" }
        }
        let data = (try? JSONEncoder().encode(p)) ?? Data()
        return prefix + data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func chart(from text: String) throws -> Chart {
        guard let r = text.range(of: prefix) else { throw ChartError.badCode }
        var body = String(text[r.upperBound...].prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
        guard !body.isEmpty, body.count < 20_000 else { throw ChartError.badCode }
        body = body.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while body.count % 4 != 0 { body += "=" }
        guard let data = Data(base64Encoded: body), let p = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw ChartError.badCode
        }
        var c = Chart()
        c.title = String(p.title.prefix(40))
        c.goal = min(max(p.goal, Chart.goalRange.lowerBound), Chart.goalRange.upperBound)
        c.reward = String(p.reward.prefix(60))
        c.midAt = p.midAt.flatMap { $0 > 0 && $0 < c.goal ? $0 : nil }
        c.midReward = String(p.midReward.prefix(60))
        c.oncePerDay = p.oncePerDay
        c.pack = Pack(rawValue: p.pack) ?? .mix
        c.who = p.who.map { String($0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20)) }.flatMap { $0.isEmpty ? nil : $0 }
        if let raw = p.id, let id = UUID(uuidString: raw) {
            c.id = id
            c.stickers = Array((p.st ?? []).compactMap(sticker).sorted { $0.day < $1.day }.prefix(c.goal))
            if c.full { c.completedOn = c.stickers.last?.day }
        }
        guard !c.title.trimmingCharacters(in: .whitespaces).isEmpty else { throw ChartError.badCode }
        return c
    }

    private static func sticker(_ s: String) -> Sticker? {
        let parts = s.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let d = parts[0].split(separator: "-").compactMap { Int($0) }
        guard d.count == 3, (2000...2100).contains(d[0]), (1...12).contains(d[1]), (1...31).contains(d[2]),
              let color = Int(parts[2]), Pack.allCases.contains(where: { $0.symbols.contains(String(parts[1])) }) else { return nil }
        return Sticker(day: Day(year: d[0], month: d[1], day: d[2]), symbol: String(parts[1]), color: abs(color) % Palette.count)
    }
}
