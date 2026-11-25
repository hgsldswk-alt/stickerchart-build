import Foundation

enum Store {
    static var root: URL {
        if Launch.testing {
            let t = FileManager.default.temporaryDirectory.appendingPathComponent("stickerchart-ui", isDirectory: true)
            try? FileManager.default.createDirectory(at: t, withIntermediateDirectories: true)
            return t
        }
        if let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Launch.group) { return g }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    static var stateURL: URL { root.appendingPathComponent("state.json") }

    static func load() -> AppState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? decoder.decode(AppState.self, from: data)
    }

    static func save(_ state: AppState) throws {
        if Launch.testFlag("-save-error") { throw ChartError.save }
        let data = try encoder.encode(state)
        try data.write(to: stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func reset() {
        try? FileManager.default.removeItem(at: stateURL)
    }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
