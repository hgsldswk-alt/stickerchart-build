import SwiftUI

@main
struct StickerChartApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
                .onAppear { model.start() }
                .onChange(of: phase) { _, p in
                    if p == .active { model.reloadFromDisk(); Task { await model.reschedule() } }
                }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HomeView()
            .tint(Theme.accentDeep)
            .foregroundStyle(Theme.ink)
            .sheet(item: $model.route) { route in
                sheet(route).environmentObject(model)
            }
            .overlay(alignment: .top) {
                if let n = model.notice {
                    Text(n).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule()).padding(.top, 6).padding(.horizontal, 16)
                        .testID("app.notice")
                        .task(id: n) { try? await Task.sleep(for: .seconds(3)); if model.notice == n { model.notice = nil } }
                }
            }
    }

    @ViewBuilder private func sheet(_ route: Route) -> some View {
        switch route {
        case .editor(let id): EditorView(id: id)
        case .celebrate(let id): CelebrateView(id: id)
        case .wall: WallView()
        case .settings: SettingsView()
        case .paywall: PaywallView(store: model.purchases)
        case .milestone(let kind): MilestoneView(kind: kind)
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if model.state.charts.isEmpty {
                StarterView()
            } else {
                TabView(selection: Binding(get: { model.current?.id ?? UUID() }, set: { model.select($0) })) {
                    ForEach(model.state.charts) { c in
                        ChartPage(chart: c).tag(c.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                if model.state.charts.count > 1 { dots }
                bottom
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 8) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())]) {
                Button { model.route = .wall } label: {
                    IconTile(title: L.t("wall.title"), icon: "rosette", color: Theme.sky)
                }.buttonStyle(.plain).testID("home.wall")
                Button { model.requestNew() } label: {
                    IconTile(title: L.t("home.new"), icon: "plus", color: Theme.coral)
                }.buttonStyle(.plain).testID("home.new")
            }
            Button { model.route = .settings } label: {
                IconBadge(symbol: "gearshape.fill", color: Theme.accentSoft, size: 30)
                    .frame(width: 44, height: 44)
                    .card(16, inset: 0)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L.t("settings.title")).testID("home.settings")
        }
        .padding(.horizontal, 18)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(model.state.charts) { c in
                Circle().fill(c.id == model.current?.id ? Theme.accent : Theme.frame).frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 6).accessibilityHidden(true)
    }

    @ViewBuilder private var bottom: some View {
        if let c = model.current {
            VStack(spacing: 4) {
                if c.full {
                    PrimaryButton(title: L.t("home.redeem"), id: "home.stick", icon: "gift.fill") { model.stick() }
                } else {
                    PrimaryButton(title: c.canStick(on: model.today) ? L.t("action.stick") : L.t("home.doneToday"),
                                  id: "home.stick", icon: "star.fill") { model.stick() }
                        .disabled(!c.canStick(on: model.today))
                }
                HStack {
                    StatusPill(title: status(c), color: c.full ? Theme.grass : Theme.accentSoft).testID("home.status")
                    Spacer()
                    if c.count > 0 { TextAction(title: L.t("action.undo"), id: "home.undo", icon: "arrow.uturn.backward") { model.undo() } }
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 18).padding(.bottom, 6)
        }
    }

    private func status(_ c: Chart) -> String {
        if c.full { return L.t("home.fullStatus") }
        let n = c.stickers.filter { $0.day == model.today }.count
        if n == 0 { return L.t("home.notYet") }
        return c.oncePerDay ? L.t("home.stuckToday") : L.f("home.stuckCount", n)
    }
}

struct ChartPage: View {
    @EnvironmentObject private var model: AppModel
    let chart: Chart

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chart.displayTitle).font(.title2.bold()).testID("chart.title")
                                    .accessibilityAction(named: L.t("chart.editHint")) { model.route = .editor(chart.id) }
                                Text(subtitle).font(.subheadline).foregroundStyle(Theme.ink).testID("chart.count")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { model.route = .editor(chart.id) }
                            ProgressRing(count: chart.count, goal: chart.goal)
                        }
                        Text(chart.full ? L.t("chart.ready") : L.f("chart.remaining", chart.left))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        RewardBanner(chart: chart)
                    }
                }
                ChartGrid(chart: chart, tapCell: chart.canStick(on: model.today) ? { (_: Int) in model.stick() } : nil).card()
            }
            .padding(.horizontal, 18).padding(.top, 6).padding(.bottom, 12)
        }
    }

    private var subtitle: String {
        let streak = chart.streak(on: model.today)
        let base = L.f("chart.progress", chart.count, chart.goal)
        return streak >= 2 ? base + " · " + L.f("chart.streak", streak) : base
    }
}

struct RewardBanner: View {
    let chart: Chart

    var body: some View {
        IconRow(icon: chart.full ? "trophy.fill" : "gift.fill", color: chart.full ? Theme.grass : Theme.coral) {
            VStack(alignment: .leading, spacing: 2) {
                Text(main).font(.subheadline.weight(.semibold))
                if let mid { Text(mid).font(.caption).foregroundStyle(Theme.muted) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(Theme.paper.opacity(0.76), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine).testID("chart.reward")
    }

    private var reward: String { chart.rewardText }

    private var main: String {
        if chart.full { return L.f("chart.rewardReady", reward) }
        if let m = chart.midAt, chart.count + 1 == m, !chart.midReward.isEmpty { return L.f("chart.midNext", chart.midReward) }
        return L.f("chart.rewardAt", chart.goal, reward)
    }

    private var mid: String? {
        guard let m = chart.midAt, chart.count < m, chart.count + 1 != m, !chart.midReward.isEmpty else { return nil }
        return L.f("chart.midAt", m, chart.midReward)
    }
}

struct StarterView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeroCard {
                    VStack(alignment: .leading, spacing: 10) {
                        EmptyIllustration()
                        Text(L.t("starter.title")).font(.title2.bold())
                        Text(L.t("starter.subtitle")).font(.subheadline)
                        PrimaryButton(title: L.t("starter.custom"), id: "starter.custom", icon: "plus") {
                            model.requestNew()
                        }
                    }
                }

                VStack(spacing: 10) {
                    ForEach(Starter.allCases) { s in
                        Button { model.addStarter(s) } label: {
                            IconRow(icon: s.icon, color: starterColor(s)) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(L.t("starter." + s.rawValue)).font(.headline)
                                    Text(L.t("starter." + s.rawValue + ".reward"))
                                        .font(.subheadline).foregroundStyle(Theme.muted)
                                    StatusPill(title: L.f("starter.stickerCount", s == .teeth ? 10 : 20))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "plus.circle.fill").font(.title3)
                                    .foregroundStyle(Theme.accentDeep).accessibilityHidden(true)
                            }
                            .card(16).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).testID("starter." + s.rawValue)
                    }
                    Text(L.t("starter.note")).font(.footnote).foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
        }
    }

    private func starterColor(_ starter: Starter) -> Color {
        switch starter {
        case .walk, .teeth: Theme.grass
        case .sugar, .read: Theme.coral
        case .sleep: Theme.sky
        }
    }
}
