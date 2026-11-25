import SwiftUI
import UIKit

struct CelebrateView: View {
    @EnvironmentObject private var model: AppModel
    let id: UUID
    @State private var sharing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let c = model.chart(id) {
                    VStack(spacing: 20) {
                        HeroCard {
                            VStack(spacing: 12) {
                                HStack(alignment: .bottom, spacing: -3) {
                                    ForEach(Array(c.stickers.suffix(3).enumerated()), id: \.offset) { index, sticker in
                                        let size: CGFloat = [35, 58, 40][index]
                                        StickerStamp(symbol: sticker.symbol, color: Theme.sticker(sticker.color))
                                            .frame(width: size, height: size)
                                            .rotationEffect(.degrees([-13, 0, 11][index]))
                                            .padding(.bottom, [0, 8, 2][index])
                                            .zIndex(index == 1 ? 1 : 0)
                                    }
                                }
                                .accessibilityHidden(true)
                                Text(c.forOther ? L.f("celebrate.titleWho", c.whoName, c.goal) : L.f("celebrate.title", c.goal))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .testID("celebrate.title")
                                StatusPill(title: L.f("celebrate.reward", reward(c)), color: Theme.paper)
                                    .multilineTextAlignment(.center)
                                if let first = c.stickers.first?.day {
                                    Text(L.f("celebrate.span", first.label, max(1, first.days(until: c.completedOn ?? model.today) + 1)))
                                        .font(.subheadline).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        PrimaryButton(title: L.t("celebrate.redeem"), id: "celebrate.redeem", icon: "checkmark") {
                            model.route = nil
                            model.redeem(id, again: false)
                        }
                        VStack(spacing: 10) {
                            SecondaryButton(title: L.t("celebrate.share"), id: "celebrate.share", icon: "square.and.arrow.up") { sharing = true }
                            SecondaryButton(title: L.t("celebrate.again"), id: "celebrate.again", icon: "arrow.clockwise") {
                                model.route = nil
                                model.redeem(id, again: true)
                            }
                        }
                        Text(c.forOther ? L.f("celebrate.noteWho", c.whoName) : L.t("celebrate.note")).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { TextAction(title: L.t("action.close"), id: "celebrate.close") { model.route = nil } } }
            .navigationDestination(isPresented: $sharing) {
                if let c = model.chart(id) { ShareCardView(chart: c) }
            }
        }
        .presentationDetents([.large])
    }

    private func reward(_ c: Chart) -> String { c.rewardText }
}

struct ShareCardView: View {
    let chart: Chart
    @State private var image: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ShareCard(chart: chart).testID("share.card")
                if let image {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(chart.displayTitle, image: Image(uiImage: image))) {
                        ActionLabel(title: L.t("share.image"), icon: "square.and.arrow.up")
                    }.testID("share.image")
                }
                ShareLink(item: L.t("transfer.hint") + "\n" + Transfer.code(for: chart)) {
                    ActionLabel(title: L.t("share.code"), icon: "person.2", primary: false)
                }.testID("share.code")
                Text(L.t("share.codeNote")).font(.footnote).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            }
            .padding(18)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L.t("share.title")).navigationBarTitleDisplayMode(.inline)
        .task {
            let r = ImageRenderer(content: ShareCard(chart: chart).frame(width: 360))
            r.scale = 3
            image = r.uiImage
        }
    }
}

struct ShareCard: View {
    let chart: Chart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmptyIllustration(icon: "rosette")
            if chart.forOther && chart.full {
                Label(L.f("share.forWho", chart.whoName), systemImage: "rosette")
                    .font(.title3.weight(.heavy)).foregroundStyle(Theme.accentDeep).testID("share.forWho")
            }
            HStack {
                Text(chart.displayTitle).font(.title2.bold()).lineLimit(2)
                Spacer(minLength: 8)
                Text("\(chart.count)/\(chart.goal)")
                    .font(.system(.headline, design: .rounded, weight: .bold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accentSoft, in: Capsule())
            }
            ChartGrid(chart: chart, spacing: 5, highlightNext: false)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chart.full ? L.f("share.rewardDone", rewardText) : L.f("share.rewardGoal", rewardText))
                        .font(.subheadline.weight(.bold))
                    Text(L.t("app.name") + " " + Launch.hashtag).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                if let qr = QR.image(Launch.storeURL.absoluteString) {
                    Image(uiImage: qr).interpolation(.none).resizable().frame(width: 58, height: 58)
                        .padding(4).background(.white).accessibilityHidden(true)
                }
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20).fill(Theme.paper)
                .shadow(color: Theme.ink.opacity(0.07), radius: 12, x: 0, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.heroGradient, lineWidth: 3).allowsHitTesting(false)
        }
    }

    private var rewardText: String { chart.rewardText }
}

struct WallView: View {
    @EnvironmentObject private var model: AppModel
    @State private var picked: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L.f("wall.count", model.state.wall.count, model.state.totalStuck))
                        .font(.headline).foregroundStyle(Theme.muted).testID("wall.count")
                    if model.state.wall.isEmpty {
                        VStack(spacing: 14) {
                            EmptyIllustration(icon: "rosette")
                            Text(L.t("wall.empty")).font(.body).foregroundStyle(Theme.muted)
                                .multilineTextAlignment(.center).testID("wall.empty")
                            PrimaryButton(title: L.t("action.done"), id: "wall.empty.done", icon: "checkmark") {
                                model.route = nil
                            }
                        }
                        .frame(maxWidth: .infinity).card()
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(Array(model.state.wall.enumerated()), id: \.element.id) { i, c in
                                Button { picked = c.id } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        IconRow(icon: "rosette", color: Theme.sticker(i)) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(c.displayTitle).font(.subheadline.weight(.semibold)).lineLimit(2)
                                                if let d = c.completedOn { Text(d.label).font(.caption2).foregroundStyle(Theme.muted) }
                                            }
                                        }
                                        StatusPill(title: "\(c.count)/\(c.goal)", color: Theme.accentSoft)
                                        ChartGrid(chart: c, spacing: 3, highlightNext: false, compact: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).card(16).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).testID("wall.item.\(i)")
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(L.t("wall.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("action.done")) { model.route = nil }.testID("wall.done") } }
            .navigationDestination(item: $picked) { id in
                if let c = model.chart(id) { ShareCardView(chart: c) }
            }
        }
    }
}

struct MilestoneView: View {
    @EnvironmentObject private var model: AppModel
    let kind: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HeroCard {
                    VStack(spacing: 10) {
                        EmptyIllustration(icon: "medal.fill")
                        Text(L.f("milestone.hundred", model.state.totalStuck))
                            .font(.system(.title, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                            .testID("milestone.title")
                        Text(L.t("milestone.note")).font(.subheadline).foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                ShareLink(item: L.f("milestone.share", model.state.totalStuck, Launch.hashtag) + "\n" + Launch.storeURL.absoluteString) {
                    ActionLabel(title: L.t("milestone.tell"), icon: "square.and.arrow.up")
                }.testID("milestone.share")
                SecondaryButton(title: L.t("action.close"), id: "milestone.close") { model.route = nil }
            }
            .padding(20)
        }
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}
