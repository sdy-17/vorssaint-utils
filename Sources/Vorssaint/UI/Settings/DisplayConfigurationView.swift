// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Lives inside the existing Displays feature: no second brightness service,
/// no helper, and no display polling while this settings page is closed.
struct DisplayConfigurationView: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var service = DisplayConfigurationService()
    @State private var configurationName = ""
    private func text(_ key: DisplayConfigurationText) -> String {
        DisplayConfigurationStrings.text(key, l10n.language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(text(.title)).font(.headline)
                Text(text(.caption)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if service.isPending {
                SettingsCard {
                    SettingsRow(symbol: "clock.arrow.circlepath", title: text(.keep),
                        caption: String(format: text(.confirmation), service.secondsRemaining)) {
                        EmptyView()
                    }
                    HStack {
                        Button(text(.revert), action: service.revert)
                        Button(text(.keep), action: service.keep).buttonStyle(.borderedProminent)
                    }
                    .padding(.leading, settingsRowTextInset)
                }
                .accessibilityElement(children: .contain)
            }
            if let issue = service.issue {
                SettingsCard {
                    Text(text(issue == .rollbackFailed ? .rollbackFailed : issue == .mirrored ? .mirrored : .failed))
                        .font(.caption).foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    if (service.isPending && service.secondsRemaining == 0) || issue == .rollbackFailed {
                        Button(text(.revert), action: service.revert)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 20) {
                if service.displays.isEmpty {
                    SettingsCard { Text(text(.noDisplays)).foregroundStyle(.secondary) }
                }
                ForEach(service.displays) { display in
                    SettingsCard {
                        DisplayModeControls(display: display, service: service, language: l10n.language)
                            .id(display.identity)
                    }
                }
                SettingsCard(title: text(.saved)) {
                    HStack {
                        TextField(text(.name), text: $configurationName)
                            .textFieldStyle(.roundedBorder)
                        Button(text(.save)) {
                            service.save(name: configurationName)
                            if service.issue == nil { configurationName = "" }
                        }
                        .disabled(configurationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                  || service.displays.isEmpty)
                    }
                    ForEach(service.saved) { configuration in
                        Divider()
                        SettingsRow(symbol: "display.2", title: configuration.name,
                            caption: configuration.displays.map { $0.mode.label }.joined(separator: " · ")) {
                            Button(text(.restore)) { service.restore(configuration) }
                                .controlSize(.small)
                            Button { service.remove(configuration.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help(text(.delete))
                            .accessibilityLabel(text(.delete) + " " + configuration.name)
                        }
                    }
                }
            }
            .disabled(service.isPending)
        }
        .onAppear { service.start() }
        .onDisappear { service.stop() }
    }
}

private struct DisplayModeControls: View {
    let display: ConfigurableDisplay
    @ObservedObject var service: DisplayConfigurationService
    let language: AppLanguage
    @State private var draft: DisplayModeSpecification

    init(display: ConfigurableDisplay, service: DisplayConfigurationService, language: AppLanguage) {
        self.display = display
        self.service = service
        self.language = language
        _draft = State(initialValue: display.current)
    }

    private func text(_ key: DisplayConfigurationText) -> String {
        DisplayConfigurationStrings.text(key, language)
    }
    private var choices: [DisplayModeSpecification] {
        display.modes.filter { $0.isHiDPI == draft.isHiDPI }
    }
    private var sizes: [DisplayModeSpecification] {
        var seen = Set<String>()
        return choices.filter { seen.insert($0.sizeID).inserted }
    }
    private var rates: [Double] {
        Array(Set(choices.filter { $0.sizeID == draft.sizeID }.map(\.refreshRate))).sorted(by: >)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsRow(symbol: display.isBuiltIn ? "laptopcomputer" : "display", title: display.name,
                badge: display.isMain ? text(.main) : nil, caption: display.current.label) {
                if !display.isMain {
                    Button(text(.makeMain)) { service.makeMain(display.identity) }
                        .controlSize(.small)
                        .disabled(display.isMirrored)
                }
            }
            Divider()
            if display.isMirrored {
                Text(text(.mirrored)).font(.caption).foregroundStyle(.secondary)
            } else {
                SettingsRow(symbol: "sparkles", title: "HiDPI",
                    caption: "\(text(.rendered)): \(draft.pixelWidth) × \(draft.pixelHeight)") {
                    Toggle("HiDPI", isOn: Binding(get: { draft.isHiDPI }, set: { enabled in
                        let candidates = display.modes.filter { $0.isHiDPI == enabled }
                        if let closest = candidates.min(by: {
                            let a = abs($0.width - draft.width) + abs($0.height - draft.height)
                            let b = abs($1.width - draft.width) + abs($1.height - draft.height)
                            return a == b ? abs($0.refreshRate - draft.refreshRate) < abs($1.refreshRate - draft.refreshRate) : a < b
                        }) { draft = closest }
                    }))
                    .labelsHidden()
                    .disabled(!display.modes.contains { $0.isHiDPI != draft.isHiDPI })
                }
                SettingsMenuRow(symbol: "aspectratio", title: text(.resolution),
                    selection: Binding(get: { draft.sizeID }, set: { size in
                        if let mode = DisplayConfigurationPolicy.preferredMode(in: display.modes,
                            sizeID: size, keeping: draft.refreshRate) { draft = mode }
                    })) {
                    ForEach(sizes, id: \.sizeID) { mode in
                        Text("\(mode.width) × \(mode.height)").tag(mode.sizeID)
                    }
                }
                SettingsMenuRow(symbol: "arrow.triangle.2.circlepath", title: text(.rate),
                    selection: Binding(get: { draft.refreshRate }, set: { rate in
                        if let mode = choices.first(where: { $0.sizeID == draft.sizeID && $0.refreshRate == rate }) {
                            draft = mode
                        }
                    })) {
                    ForEach(rates, id: \.self) { rate in
                        Text(rate > 0 ? String(format: "%.2f Hz", rate) : "—").tag(rate)
                    }
                }
                if draft.refreshRate > 0 && draft.refreshRate < display.current.refreshRate - 0.1 {
                    Text(text(.lowerRate)).font(.caption).foregroundStyle(.orange)
                        .padding(.leading, settingsRowTextInset)
                }
                HStack {
                    Spacer()
                    Button(text(.apply)) { service.changeMode(draft, for: display.identity) }
                        .disabled(draft.matches(display.current))
                }
                Divider()
                SettingsMenuRow(symbol: "paintpalette", title: text(.profile), selection: Binding(
                    get: { display.customColorProfilePath ?? "" },
                    set: { service.changeProfile($0.isEmpty ? nil : $0, for: display.identity) })) {
                    Text(text(.factory)).tag("")
                    ForEach(service.profiles) { profile in
                        Text(profile.name).tag(profile.path)
                    }
                }
            }
        }
        .onAppear { draft = display.current }
        .onChange(of: display.current) { _, current in draft = current }
    }
}
