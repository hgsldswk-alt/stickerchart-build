import AppIntents
import WidgetKit

struct StickIntent: AppIntent {
    static var title: LocalizedStringResource = "Stick a sticker"
    static var isDiscoverable = false

    @Parameter(title: "Chart") var chartID: String

    init() {}
    init(chartID: String) { self.chartID = chartID }

    func perform() async throws -> some IntentResult {
        guard var state = Store.load(), let id = UUID(uuidString: chartID) else { return .result() }
        if state.stick(id, on: .today) != nil {
            try? Store.save(state)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
