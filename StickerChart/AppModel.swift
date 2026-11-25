import CoreImage
import StoreKit
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

enum Route: Identifiable, Equatable {
    case editor(UUID?), celebrate(UUID), wall, settings, paywall, milestone(String)
    var id: String {
        switch self {
        case .editor(let id): return "editor-\(id?.uuidString ?? "new")"
        case .celebrate(let id): return "celebrate-\(id)"
        case .wall: return "wall"
        case .settings: return "settings"
        case .paywall: return "paywall"
        case .milestone(let m): return "milestone-\(m)"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var state = AppState()
    @Published var route: Route?
    @Published var notice: String?
    @Published var notificationsDenied = false
    let purchases = StoreModel()
    private var loaded = false

    var today: Day { .today }
    var now: Date { Launch.testFlag("-expired") ? state.entitlement.firstOpen.addingTimeInterval(40 * 86_400) : Date() }
    var hasPro: Bool { state.entitlement.hasPro(at: now) }
    var current: Chart? { state.currentChart }

    func start() {
        guard !loaded else { return }
        loaded = true
        if Launch.testFlag("-reset") { Store.reset() }
        if let saved = Store.load() {
            state = saved
        } else {
            state = AppState()
            state.entitlement.firstOpen = Launch.testing ? Date() : TrialAnchor.firstOpen(Date())
            if Launch.testFlag("-demo") || Launch.testFlag("-demo-almost") { state = Demo.state(base: state, today: today) }
        }
        if Launch.testFlag("-paid") { state.entitlement.purchasedPro = true }
        markOpen()
        persist()
        purchases.start(applyPurchase)
        Task { await reschedule() }
        if Launch.testFlag("-paywall") { route = .paywall }
    }

    func reloadFromDisk() {
        guard loaded, route == nil, let saved = Store.load(), saved != state else { return }
        state = saved
    }

    func persist() {
        do { try Store.save(state) } catch { notice = ChartError.save.message }
        WidgetCenter.shared.reloadTimelines(ofKind: Launch.widgetKind)
    }

    func chart(_ id: UUID) -> Chart? { state.charts.first { $0.id == id } ?? state.wall.first { $0.id == id } }

    func select(_ id: UUID) {
        guard state.current != id else { return }
        state.current = id
        persist()
    }


    func stick() {
        guard let c = current else { return }
        if c.full { route = .celebrate(c.id); return }
        var next = state
        guard let result = next.stick(c.id, on: today) else { return }
        switch result {
        case .alreadyToday:
            notice = L.t("stick.today")
            return
        case .alreadyFull:
            route = .celebrate(c.id)
            return
        default: break
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { state = next }
        persist()
        if !Launch.testing { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        switch result {
        case .full:
            Task { try? await Task.sleep(for: .milliseconds(700)); route = .celebrate(c.id) }
        case .mid(let reward):
            notice = L.f("stick.mid", reward)
        default:
            if state.totalStuck >= 100, !state.milestonesShown.contains("hundred") {
                state.milestonesShown.append("hundred")
                persist()
                Task { try? await Task.sleep(for: .milliseconds(700)); if route == nil { route = .milestone("hundred") } }
            }
        }
        Task { await reschedule() }
    }

    func undo() {
        guard let c = current else { return }
        _ = state.undo(c.id)
        persist()
        Task { await reschedule() }
    }


    func requestNew() {
        guard state.canAdd(hasPro: hasPro) else { route = .paywall; notice = ChartError.limit.message; return }
        route = .editor(nil)
    }

    func addStarter(_ s: Starter) {
        guard state.canAdd(hasPro: hasPro) else { route = .paywall; return }
        withAnimation { state.add(s.chart()) }
        persist()
    }

    func save(_ chart: Chart) {
        var c = chart
        c.goal = min(max(c.goal, Chart.goalRange.lowerBound, c.count), Chart.goalRange.upperBound)
        if let m = c.midAt, m <= 0 || m >= c.goal { c.midAt = nil }
        let w = String(c.whoName.prefix(20)); c.who = w.isEmpty ? nil : w
        if let i = state.index(c.id) {
            state.charts[i] = c
        } else {
            guard state.canAdd(hasPro: hasPro) else { route = .paywall; return }
            state.add(c)
        }
        persist()
        Task { await reschedule() }
    }

    func delete(_ id: UUID) {
        state.delete(id)
        persist()
        Task { await reschedule() }
    }

    func redeem(_ id: UUID, again: Bool) {
        state.redeem(id, again: again)
        persist()
        Task { await reschedule() }
        askReviewIfReady()
    }

    func importCode(_ text: String) -> Chart? {
        do {
            let c = try Transfer.chart(from: text)
            if let n = state.mergeProgress(c), let m = state.charts.first(where: { $0.id == c.id }) {
                persist()
                notice = L.f("transfer.synced", n, m.goal)
                route = nil
                return nil
            }
            return c
        } catch {
            notice = (error as? ChartError ?? .badCode).message
            return nil
        }
    }


    func reschedule() async {
        notificationsDenied = await Reminders.sync(state, today: today)
    }


    func applyPurchase(_ pro: Bool?, _ trial: Date?) async throws {
        if let pro { state.entitlement.purchasedPro = pro }
        if let trial { state.entitlement.trialClaimedAt = min(state.entitlement.trialClaimedAt ?? trial, trial) }
        try Store.save(state)
        WidgetCenter.shared.reloadTimelines(ofKind: Launch.widgetKind)
    }


    private func markOpen() {
        let d = today.iso
        if !state.openDays.contains(d) { state.openDays = Array((state.openDays + [d]).suffix(10)) }
    }

    private func askReviewIfReady() {
        guard !state.reviewAsked, state.openDays.count >= 2, !Launch.testing || Launch.testFlag("-review") else { return }
        state.reviewAsked = true
        persist()
        if Launch.testing { notice = "review.requested"; return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        }
    }
}

enum Reminders {
    static func sync(_ state: AppState, today: Day) async -> Bool {
        if Launch.testFlag("-notifications-denied") { return state.charts.contains { $0.remindHour != nil } }
        guard !Launch.testing else { return false }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let wanted = state.charts.filter { $0.remindHour != nil && !$0.full }
        guard !wanted.isEmpty else { return false }
        var settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            settings = await center.notificationSettings()
        }
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return true }
        for chart in wanted {
            guard let hour = chart.remindHour else { continue }
            for offset in 0..<7 {
                let day = today.adding(days: offset)
                if chart.oncePerDay && chart.stuck(on: day) { continue }
                guard let date = day.local(hour: hour), date > Date() else { continue }
                let content = UNMutableNotificationContent()
                content.title = chart.displayTitle
                content.body = L.f("remind.body", chart.left)
                content.sound = .default
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "\(chart.id)-\(day.iso)", content: content, trigger: trigger))
            }
        }
        return false
    }
}

enum QR {
    static func image(_ text: String, size: CGFloat = 220) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: size / out.extent.width, y: size / out.extent.height))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum Demo {
    static func state(base: AppState, today: Day) -> AppState {
        var s = base
        func chart(_ title: String, goal: Int, reward: String, mid: Int?, midReward: String, count: Int, salt: Int, pack: Pack) -> Chart {
            var c = Chart()
            c.title = title; c.goal = goal; c.reward = reward; c.midAt = mid; c.midReward = midReward; c.salt = salt; c.pack = pack
            for k in stride(from: count, through: 1, by: -1) {
                c.stickers.append(c.nextSticker(on: today.adding(days: -k)))
            }
            return c
        }
        let almost = Launch.testFlag("-demo-almost")
        let walk = chart(L.t("demo.walk"), goal: 20, reward: L.t("demo.walk.reward"), mid: 15, midReward: L.t("demo.walk.mid"),
                         count: almost ? 19 : 13, salt: 7, pack: .mix)
        let sugar = chart(L.t("demo.sugar"), goal: 20, reward: L.t("demo.sugar.reward"), mid: nil, midReward: "", count: 7, salt: 3, pack: .stars)
        s.charts = [walk, sugar]
        s.current = walk.id
        s.totalStuck = walk.count + sugar.count + 40
        var sleep = chart(L.t("demo.sleep"), goal: 10, reward: L.t("demo.sleep.reward"), mid: nil, midReward: "", count: 10, salt: 11, pack: .flowers)
        sleep.completedOn = today.adding(days: -20)
        var teeth = chart(L.t("demo.teeth"), goal: 10, reward: L.t("demo.teeth.reward"), mid: nil, midReward: "", count: 10, salt: 5, pack: .hearts)
        teeth.completedOn = today.adding(days: -35)
        s.wall = [sleep, teeth]
        return s
    }
}
