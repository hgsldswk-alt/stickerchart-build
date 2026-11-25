import SwiftUI

private func hex(_ v: UInt32) -> Color {
    Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
}

enum Theme {
    static let accent = hex(0xECD865)
    static let accentDeep = hex(0x866013)
    static let accentSoft = hex(0xFCF6D9)
    static let coral = hex(0xF08A6C)
    static let sky = hex(0x6EB6E6)
    static let grass = hex(0x8CC774)
    static let background = hex(0xFBF8F3)
    static let paper = Color.white
    static let cellBack = hex(0xFFFDF9)
    static let midBack = hex(0xFFF6EC)
    static let midLine = hex(0xEBC9A6)
    static let ink = hex(0x3A2E26)
    static let muted = hex(0x66574B)
    static let line = hex(0xEADFD0)
    static let frame = hex(0xD9CCB9)
    static let heroGradient = LinearGradient(colors: [accent, accentSoft], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let stickers: [Color] = [accent, coral, grass, sky, accentSoft]
    static func sticker(_ i: Int) -> Color { stickers[((i % stickers.count) + stickers.count) % stickers.count] }
}

extension View {
    func testID(_ id: String) -> some View { accessibilityIdentifier(id) }

    func card(_ radius: CGFloat = 20, inset: CGFloat = 14) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius)
        return padding(inset)
            .background {
                shape.fill(Theme.paper).shadow(color: Theme.ink.opacity(0.07), radius: 12, x: 0, y: 4)
            }
            .overlay { shape.strokeBorder(Theme.line).allowsHitTesting(false) }
    }
}

struct HeroCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Theme.heroGradient)
                    .shadow(color: Theme.ink.opacity(0.07), radius: 12, x: 0, y: 4)
            }
            .foregroundStyle(Theme.ink)
    }
}

struct IconBadge: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .accessibilityHidden(true)
    }
}

struct IconTile: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            IconBadge(symbol: icon, color: color, size: 30)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .foregroundStyle(Theme.ink)
        .card(16, inset: 0)
        .contentShape(Rectangle())
    }
}

struct IconRow<Content: View>: View {
    let icon: String
    let color: Color
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            IconBadge(symbol: icon, color: color)
            content
        }
        .foregroundStyle(Theme.ink)
    }
}

struct StatusPill: View {
    let title: String
    var color: Color = Theme.accentSoft

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

struct StickerStamp: View {
    let symbol: String
    let color: Color
    var compact = false

    var body: some View {
        Circle().fill(color)
            .overlay {
                Circle().strokeBorder(.white, lineWidth: compact ? 1 : 2)
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Theme.ink)
                    .padding(compact ? 4 : 8)
            }
            .shadow(color: Theme.ink.opacity(0.16), radius: compact ? 1 : 2, x: 0, y: compact ? 1 : 2)
            .accessibilityHidden(true)
    }
}

struct EmptyIllustration: View {
    var icon = "star.fill"

    var body: some View {
        HStack(alignment: .bottom, spacing: -3) {
            StickerStamp(symbol: "heart.fill", color: Theme.coral)
                .frame(width: 35, height: 35)
                .rotationEffect(.degrees(-13))
            StickerStamp(symbol: icon, color: Theme.accent)
                .frame(width: 58, height: 58)
                .padding(.bottom, 8)
                .zIndex(1)
            StickerStamp(symbol: "sparkles", color: Theme.sky)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(11))
                .padding(.bottom, 2)
        }
        .accessibilityHidden(true)
    }
}

struct ProgressRing: View {
    let count: Int
    let goal: Int
    private var fraction: CGFloat { min(1, CGFloat(count) / CGFloat(max(1, goal))) }

    var body: some View {
        ZStack {
            Circle().strokeBorder(Theme.ink.opacity(0.12), lineWidth: 6)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accentDeep, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .padding(3)
                .rotationEffect(.degrees(-90))
            Text("\(count)/\(goal)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 8)
        }
        .frame(width: 70, height: 70)
        .background(Theme.paper, in: Circle())
        .foregroundStyle(Theme.ink)
        .accessibilityHidden(true)
    }
}

struct ChartGrid: View {
    let chart: Chart
    var spacing: CGFloat = 9
    var highlightNext = true
    var compact = false
    var columnsOverride: Int?
    var tapCell: ((Int) -> Void)?

    private var columns: Int { columnsOverride ?? (chart.goal <= 30 ? 5 : 8) }

    var body: some View {
        let rows = (chart.goal + columns - 1) / columns
        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { c in
                        let i = r * columns + c
                        if i < chart.goal {
                            cell(i).frame(maxWidth: .infinity)
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ i: Int) -> some View {
        let radius: CGFloat = compact ? 5 : 12
        let shape = RoundedRectangle(cornerRadius: radius)
        let isNext = highlightNext && i == chart.count && !chart.full
        let rewardIcon: String? = i + 1 == chart.midAt ? "gift.fill" : i + 1 == chart.goal ? "trophy.fill" : nil
        let base = shape
            .fill(i < chart.count ? .clear : rewardIcon == nil ? (isNext ? Theme.accentSoft : Theme.cellBack) : Theme.midBack)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if i < chart.count {
                    let s = chart.stickers[i]
                    StickerStamp(symbol: s.symbol, color: Theme.sticker(s.color), compact: compact)
                        .padding(compact ? 1 : 3)
                        .rotationEffect(.degrees(Double((i * 37) % 17) - 8))
                } else if let rewardIcon {
                    shape.strokeBorder(isNext ? Theme.accentDeep : Theme.midLine, lineWidth: isNext ? 2 : 1)
                    if !compact {
                        Image(systemName: rewardIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accentDeep)
                    }
                } else if isNext {
                    shape.strokeBorder(Theme.accentDeep, lineWidth: compact ? 1.5 : 2)
                } else {
                    shape.strokeBorder(Theme.frame, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
        if let tapCell, i == chart.count {
            Button { tapCell(i) } label: { base.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityLabel(L.t("action.stick"))
                .testID("cell.\(i)")
        } else {
            base.accessibilityElement(children: .ignore)
                .accessibilityLabel(i < chart.count ? L.t("cell.stuck") : L.t("cell.empty"))
                .testID("cell.\(i)")
        }
    }
}

struct ActionLabel: View {
    let title: String
    var icon: String?
    var primary = true
    @Environment(\.isEnabled) private var enabled

    var body: some View {
        HStack(spacing: 8) {
            if let icon { Image(systemName: icon).accessibilityHidden(true) }
            Text(title).multilineTextAlignment(.center)
        }
        .font(.headline)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: primary ? 52 : 48)
        .foregroundStyle(enabled ? (primary ? Theme.ink : Theme.accentDeep) : Theme.muted)
        .background(enabled ? (primary ? Theme.accent : Theme.accentSoft) : Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            if !enabled {
                RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line).allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
    }
}

struct PrimaryButton: View {
    let title: String
    let id: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) { ActionLabel(title: title, icon: icon) }
            .buttonStyle(.plain).testID(id)
    }
}

struct SecondaryButton: View {
    let title: String
    let id: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) { ActionLabel(title: title, icon: icon, primary: false) }
            .buttonStyle(.plain).testID(id)
    }
}

struct TextAction: View {
    var title: String
    var id: String
    var icon: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).accessibilityHidden(true) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                if icon != nil { Capsule().fill(Theme.accentSoft).padding(.vertical, 5) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Theme.accentDeep).testID(id)
    }
}
