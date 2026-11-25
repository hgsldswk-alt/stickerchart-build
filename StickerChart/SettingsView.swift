import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IconRow(icon: "checkmark.seal.fill", color: Theme.grass) {
                        StatusPill(title: status).testID("settings.status")
                    }
                    if !model.state.entitlement.purchasedPro {
                        Button { open(.paywall) } label: {
                            IconRow(icon: "star.fill", color: Theme.accent) {
                                Text(L.t("settings.unlock")).font(.headline)
                            }
                        }
                        .testID("settings.unlock")
                    }
                } header: { sectionTitle("settings.purchase") }
                .listRowBackground(Theme.paper)

                Section {
                    if let c = model.current {
                        ShareLink(item: L.t("transfer.syncHint") + "\n" + Transfer.code(for: c, progress: true)) {
                            IconRow(icon: "arrow.triangle.2.circlepath", color: Theme.sky) {
                                Text(L.f("settings.syncChart", c.displayTitle)).font(.headline)
                            }
                        }.testID("settings.syncChart")
                        IconRow(icon: "info.circle.fill", color: Theme.accentSoft) {
                            Text(L.t("settings.syncNote")).font(.footnote).foregroundStyle(Theme.muted)
                        }
                        ShareLink(item: L.t("transfer.hint") + "\n" + Transfer.code(for: c)) {
                            IconRow(icon: "person.2.fill", color: Theme.grass) {
                                Text(L.f("settings.sendChart", c.displayTitle)).font(.headline)
                            }
                        }.testID("settings.sendChart")
                    }
                    ShareLink(item: L.t("settings.tellText") + " " + Launch.storeURL.absoluteString) {
                        IconRow(icon: "heart.fill", color: Theme.coral) {
                            Text(L.t("settings.tell")).font(.headline)
                        }
                    }
                } header: { sectionTitle("settings.share") } footer: { Text(L.t("settings.widgetNote")).font(.footnote).foregroundStyle(Theme.muted) }
                .listRowBackground(Theme.paper)

                if model.notificationsDenied {
                    Section {
                        IconRow(icon: "bell.slash.fill", color: Theme.coral) {
                            Text(L.t("settings.denied")).font(.footnote).testID("settings.denied")
                        }
                        Button {
                            if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                        } label: {
                            IconRow(icon: "gearshape.fill", color: Theme.accentSoft) {
                                Text(L.t("settings.openSettings")).font(.headline)
                            }
                        }
                    } header: { sectionTitle("settings.reminders") }
                    .listRowBackground(Theme.paper)
                }
                Section {
                    Link(destination: Launch.placeholderURL) {
                        IconRow(icon: "hand.raised.fill", color: Theme.sky) {
                            Text(L.t("settings.support")).font(.headline)
                        }
                    }
                } footer: {
                    Text(L.t("settings.privacy")).font(.footnote).foregroundStyle(Theme.muted)
                }
                .listRowBackground(Theme.paper)
            }
            .listSectionSpacing(22)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .tint(Theme.accentDeep)
            .navigationTitle(L.t("settings.title")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L.t("action.done")) { model.route = nil }.testID("settings.done") } }
        }
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(L.t(key)).font(.headline).foregroundStyle(Theme.muted).textCase(nil)
    }

    private var status: String {
        if model.state.entitlement.purchasedPro { return L.t("pay.owned") }
        if model.hasPro { return L.f("pay.until", Day(model.state.entitlement.trialEnd).label) }
        return L.f("pay.expired", Launch.freeLimit)
    }

    private func open(_ route: Route) {
        model.route = nil
        Task { try? await Task.sleep(for: .milliseconds(600)); model.route = route }
    }
}

struct PaywallView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var store: StoreModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            EmptyIllustration(icon: "star.fill")
                            Text(L.t("pay.title")).font(.largeTitle.bold())
                            Text(L.t("pay.once")).font(.subheadline).foregroundStyle(Theme.muted)
                            StatusPill(title: model.state.entitlement.purchasedPro ? L.t("pay.owned") : model.hasPro
                                       ? L.f("pay.until", Day(model.state.entitlement.trialEnd).label) : L.f("pay.expired", Launch.freeLimit),
                                       color: Theme.paper)
                                .testID("paywall.status")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        IconRow(icon: "square.stack.3d.up.fill", color: Theme.sky) {
                            Text(L.t("pay.unlimited")).font(.headline)
                        }
                        IconRow(icon: "lock.fill", color: Theme.grass) {
                            Text(L.t("pay.keep")).font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).card()
                    if !model.state.entitlement.purchasedPro {
                        if let product = store.pro {
                            PrimaryButton(title: L.f("pay.buy", product.displayPrice), id: "paywall.buy", icon: "lock.open.fill") {
                                Task { await store.buy(product, update: model.applyPurchase) }
                            }.disabled(store.busy)
                        } else if Launch.testing {
                            PrimaryButton(title: L.f("pay.buy", "US$2.99"), id: "paywall.buy", icon: "lock.open.fill") {}.disabled(true)
                        } else {
                            SecondaryButton(title: L.t("pay.load"), id: "paywall.load", icon: "arrow.clockwise") { Task { await store.load() } }
                        }
                        if model.state.entitlement.trialClaimedAt == nil, model.hasPro {
                            SecondaryButton(title: L.t("pay.claim"), id: "paywall.claim", icon: "star.fill") {
                                if let trial = store.trial { Task { await store.buy(trial, update: model.applyPurchase) } }
                                else { Task { await store.load() } }
                            }.disabled(store.busy)
                        }
                    }
                    SecondaryButton(title: L.t("pay.restore"), id: "paywall.restore", icon: "arrow.counterclockwise") { Task { await store.restore(model.applyPurchase) } }
                        .disabled(store.busy)
                    if store.busy { ProgressView() }
                    if let n = store.notice { Text(n).font(.footnote).foregroundStyle(Theme.muted).testID("paywall.notice") }
                }.padding(18)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { TextAction(title: L.t("action.close"), id: "paywall.close") { model.route = nil } } }
            .task { await store.load() }
        }
    }
}
