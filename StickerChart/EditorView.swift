import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var model: AppModel
    let id: UUID?
    @State private var draft = Chart()
    @State private var loaded = false
    @State private var code = ""
    @State private var confirmDelete = false
    @FocusState private var codeFocused: Bool

    private var isNew: Bool { id == nil }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    Section {
                        IconRow(icon: "pencil", color: Theme.accent) {
                            TextField(L.t("editor.titlePrompt"), text: $draft.title).font(.headline).testID("editor.title")
                        }
                        .id("top")
                        IconRow(icon: draft.forOther ? "person.fill" : "person", color: Theme.sky) {
                            TextField(L.t("editor.whoPrompt"), text: Binding(get: { draft.who ?? "" }, set: { draft.who = $0 }))
                                .testID("editor.who")
                        }
                        HStack(spacing: 6) {
                            IconRow(icon: "square.grid.2x2.fill", color: Theme.grass) {
                                Text(L.t("editor.goal"))
                            }
                            Spacer(minLength: 0)
                            ForEach([10, 20, 30], id: \.self) { n in
                                Button { draft.goal = max(n, draft.count) } label: {
                                    Text("\(n)").font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .frame(minWidth: 38, minHeight: 36)
                                        .foregroundStyle(Theme.ink)
                                        .background(draft.goal == n ? Theme.accent : Theme.accentSoft, in: Capsule())
                                        .overlay {
                                            Capsule().strokeBorder(draft.goal == n ? Theme.accentDeep : Theme.line)
                                                .allowsHitTesting(false)
                                        }
                                }.buttonStyle(.plain).testID("editor.goal.\(n)")
                            }
                        }
                        Stepper(value: $draft.goal, in: max(Chart.goalRange.lowerBound, draft.count)...Chart.goalRange.upperBound) {
                            IconRow(icon: "slider.horizontal.3", color: Theme.accentSoft) {
                                Text(L.f("editor.goalCustom", draft.goal))
                            }
                        }
                        .testID("editor.goalStepper")
                        IconRow(icon: "trophy.fill", color: Theme.coral) {
                            TextField(L.t("editor.rewardPrompt"), text: $draft.reward).testID("editor.reward")
                        }
                    } header: { sectionTitle("editor.section.chart") } footer: {
                        Text(L.t("editor.whoNote")).foregroundStyle(Theme.muted)
                    }
                    .listRowBackground(Theme.paper)

                    Section {
                        Toggle(isOn: Binding(get: { draft.midAt != nil },
                                             set: { draft.midAt = $0 ? max(1, min(draft.goal / 2, draft.goal - 1)) : nil })) {
                            IconRow(icon: "gift.fill", color: Theme.coral) {
                                Text(L.t("editor.mid"))
                            }
                        }
                        .testID("editor.mid")
                        if let m = draft.midAt {
                            Stepper(value: Binding(get: { m }, set: { draft.midAt = $0 }), in: 1...max(1, draft.goal - 1)) {
                                IconRow(icon: "flag.fill", color: Theme.accentSoft) {
                                    Text(L.f("editor.midAt", m))
                                }
                            }
                            IconRow(icon: "gift", color: Theme.coral) {
                                TextField(L.t("editor.midPrompt"), text: $draft.midReward).testID("editor.midReward")
                            }
                        }
                    } footer: { Text(L.t("editor.midNote")).foregroundStyle(Theme.muted) }
                    .listRowBackground(Theme.paper)

                    Section {
                        Toggle(isOn: $draft.oncePerDay) {
                            IconRow(icon: "calendar", color: Theme.grass) {
                                Text(L.t("editor.once"))
                            }
                        }
                        .testID("editor.once")
                        Toggle(isOn: Binding(get: { draft.remindHour != nil }, set: { draft.remindHour = $0 ? 21 : nil })) {
                            IconRow(icon: "bell.fill", color: Theme.sky) {
                                Text(L.t("editor.remind"))
                            }
                        }
                        .testID("editor.remind")
                        if let h = draft.remindHour {
                            Stepper(value: Binding(get: { h }, set: { draft.remindHour = $0 }), in: 6...23) {
                                IconRow(icon: "clock.fill", color: Theme.sky) {
                                    Text(L.f("editor.remindAt", h))
                                }
                            }
                        }
                    } footer: { Text(L.t("editor.onceNote")).foregroundStyle(Theme.muted) }
                    .listRowBackground(Theme.paper)

                    Section {
                        HStack(spacing: 8) {
                            ForEach(Pack.allCases) { p in
                                Button { draft.pack = p } label: {
                                    StickerStamp(symbol: p.cover, color: Theme.sticker(Pack.allCases.firstIndex(of: p) ?? 0), compact: true)
                                        .frame(width: 26, height: 26)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .background(draft.pack == p ? Theme.accentSoft : Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(draft.pack == p ? Theme.accentDeep : Theme.line,
                                                              lineWidth: draft.pack == p ? 2 : 1)
                                                .allowsHitTesting(false)
                                        }
                                }
                                .buttonStyle(.plain).accessibilityLabel(L.t("pack." + p.rawValue)).testID("editor.pack." + p.rawValue)
                            }
                        }
                    } header: { sectionTitle("editor.pack") }
                    .listRowBackground(Theme.paper)

                    if isNew {
                        Section {
                            HStack(alignment: .top, spacing: 8) {
                                IconBadge(symbol: "doc.on.clipboard", color: Theme.sky)
                                TextField(L.t("editor.codePrompt"), text: $code, axis: .vertical)
                                    .lineLimit(3, reservesSpace: true)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($codeFocused)
                                    .testID("editor.code")
                                Button {
                                    if let imported = model.importCode(code) {
                                        draft = imported
                                        code = ""
                                        model.notice = L.t("editor.imported")
                                    }
                                    codeFocused = false
                                    if model.route == .editor(id) {
                                        Task { @MainActor in
                                            withAnimation { proxy.scrollTo("top", anchor: .top) }
                                        }
                                    }
                                } label: {
                                    Text(L.t("editor.import")).font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .frame(minWidth: 44, minHeight: 44)
                                        .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .testID("editor.import")
                            }
                        } header: { sectionTitle("editor.codeHeader") }
                        .listRowBackground(Theme.paper)
                    } else {
                        Section {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                IconRow(icon: "trash.fill", color: Theme.coral) {
                                    Text(L.t("editor.delete")).font(.headline).foregroundStyle(.red)
                                }
                            }
                            .testID("editor.delete")
                        }
                        .listRowBackground(Theme.paper)
                    }
                }
                .listSectionSpacing(22)
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background)
            .tint(Theme.accentDeep)
            .navigationTitle(isNew ? L.t("editor.newTitle") : L.t("editor.editTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t("action.cancel")) { model.route = nil }.testID("editor.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.t("action.done")) {
                        model.save(draft)
                        if model.route == .editor(id) { model.route = nil }
                    }
                    .fontWeight(.bold).testID("editor.done")
                }
            }
            .alert(L.t("editor.deleteConfirm"), isPresented: $confirmDelete) {
                Button(L.t("action.cancel"), role: .cancel) {}
                Button(L.t("editor.delete"), role: .destructive) {
                    if let id { model.delete(id) }
                    model.route = nil
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let id, let c = model.chart(id) { draft = c }
            }
        }
    }
    private func sectionTitle(_ key: String) -> some View {
        Text(L.t(key)).font(.headline).foregroundStyle(Theme.muted).textCase(nil)
    }
}
