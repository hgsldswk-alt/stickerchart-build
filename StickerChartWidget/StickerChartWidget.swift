import AppIntents
import SwiftUI
import WidgetKit

struct Entry: TimelineEntry {
    let date: Date
    let today: Day
    let chart: Chart?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        var c = Chart()
        c.title = L.t("widget.sample")
        c.goal = 10
        for k in 1...4 { c.stickers.append(c.nextSticker(on: Day.today.adding(days: -k))) }
        return Entry(date: Date(), today: .today, chart: c)
    }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let e = entry()
        completion(e.chart == nil ? placeholder(in: context) : e)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let next = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400)).addingTimeInterval(30)
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> Entry {
        let state = Store.load() ?? AppState()
        return Entry(date: Date(), today: .today, chart: state.currentChart)
    }
}

struct WidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let c = entry.chart {
                HStack {
                    Text(c.displayTitle).font(.caption.weight(.bold)).lineLimit(1)
                    Spacer(minLength: 2)
                    Text("\(c.count)/\(c.goal)")
                        .font(.system(.caption2, design: .rounded, weight: .bold)).monospacedDigit()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentSoft, in: Capsule())
                }
                ChartGrid(chart: preview(c), spacing: family == .systemSmall ? 3 : 4, compact: true, columnsOverride: family == .systemSmall ? 5 : 10)
                Spacer(minLength: 0)
                if c.full {
                    Link(destination: Launch.openURL) { label(L.t("widget.full"), icon: "gift.fill") }
                } else if c.canStick(on: entry.today) {
                    Button(intent: StickIntent(chartID: c.id.uuidString)) { label(L.t("action.stick"), icon: "star.fill") }.buttonStyle(.plain)
                } else {
                    StatusPill(title: L.t("widget.doneToday"), color: Theme.accentSoft)
                        .frame(maxWidth: .infinity, minHeight: 28)
                }
            } else {
                VStack(spacing: 5) {
                    EmptyIllustration().scaleEffect(0.68).frame(height: 46)
                    Text(L.t("widget.empty")).font(.caption).foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                    Link(destination: Launch.openURL) { label(L.t("widget.open"), icon: "arrow.up.right") }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(Theme.ink)
        .containerBackground(Theme.background, for: .widget)
        .widgetURL(Launch.openURL)
    }

    private func preview(_ c: Chart) -> Chart {
        let size = family == .systemSmall ? 10 : 20
        guard c.goal > size else { return c }
        var p = c
        let start = min(max(0, c.count - size / 2), c.goal - size)
        p.stickers = Array(c.stickers.dropFirst(start))
        p.goal = size
        p.midAt = c.midAt.map { $0 - start }.flatMap { $0 >= 1 && $0 <= size ? $0 : nil }
        return p
    }

    private func label(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.caption.weight(.bold)).foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 28).background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
    }
}

@main
struct StickerChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Launch.widgetKind, provider: Provider()) { WidgetView(entry: $0) }
            .configurationDisplayName(L.t("widget.title"))
            .description(L.t("widget.desc"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}
