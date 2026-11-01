// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ColorSync
import IOKit.graphics

struct ConfigurableDisplay: Identifiable {
    let id: CGDirectDisplayID
    let identity: String
    let name: String
    let isMain: Bool
    let isBuiltIn: Bool
    let isMirrored: Bool
    let current: DisplayModeSpecification
    let modes: [DisplayModeSpecification]
    let colorProfilePath: String?
    let customColorProfilePath: String?
}

struct DisplayColorProfile: Identifiable, Hashable {
    let path: String
    let name: String
    var id: String { path }
}

/// Existing modes are enumerated from the live display. Extended modes use a
/// checked CGS bridge; no new timings or model overrides are installed.
enum DisplayConfigurationDriver {
    static func specification(_ mode: CGDisplayMode) -> DisplayModeSpecification {
        DisplayModeSpecification(width: mode.width, height: mode.height,
                                 pixelWidth: mode.pixelWidth, pixelHeight: mode.pixelHeight,
                                 refreshRate: mode.refreshRate)
    }

    static func identity(_ id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }

    static func activeIDs() throws -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else {
            throw DisplayConfigurationIssue.unavailable
        }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else {
            throw DisplayConfigurationIssue.unavailable
        }
        return Array(ids.prefix(Int(count)))
    }

    static func modes(_ id: CGDirectDisplayID) -> [CGDisplayMode] {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        let all = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode] ?? []
        return all.filter {
            let flags = $0.ioFlags
            return $0.isUsableForDesktopGUI() && $0.width > 0 && $0.height > 0
                && flags & UInt32(kDisplayModeValidFlag) != 0
                && flags & UInt32(kDisplayModeSafeFlag) != 0
                && flags & UInt32(kDisplayModeInterlacedFlag) == 0
                && $0.refreshRate.isFinite && $0.refreshRate >= 0
        }
    }

    static func customProfile(_ id: CGDirectDisplayID) -> String? {
        guard let deviceClass = kColorSyncDisplayDeviceClass?.takeUnretainedValue(),
              let customKey = kColorSyncCustomProfiles?.takeUnretainedValue() as String?,
              let factoryKey = kColorSyncFactoryProfiles?.takeUnretainedValue() as String?,
              let defaultKey = kColorSyncDeviceDefaultProfileID?.takeUnretainedValue() as String?,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let info = ColorSyncDeviceCopyDeviceInfo(deviceClass, uuid)?
                .takeRetainedValue() as? [String: Any],
              let custom = info[customKey] as? [String: Any] else { return nil }
        let factory = info[factoryKey] as? [String: Any] ?? [:]
        let factoryIDs = factory.keys.filter { $0 != defaultKey }
        let defaultID = factory[defaultKey] as? String ?? (factoryIDs.count == 1 ? factoryIDs[0] : nil)
        let value = custom[defaultKey]
            ?? defaultID.flatMap { custom[$0] }
        return (value as? URL)?.path
    }

    static func currentProfile(_ id: CGDirectDisplayID) -> String? {
        guard let profile = ColorSyncProfileCreateWithDisplayID(id)?.takeRetainedValue(),
              let url = ColorSyncProfileGetURL(profile, nil)?.takeUnretainedValue() else { return nil }
        return (url as URL).path
    }

    static func profiles(including activePaths: [String]) -> [DisplayColorProfile] {
        let roots = ["/System/Library/ColorSync/Profiles", "/Library/ColorSync/Profiles",
                     NSHomeDirectory() + "/Library/ColorSync/Profiles"]
        var paths = Set(activePaths)
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { continue }
            for case let url as URL in enumerator where ["icc", "icm"].contains(url.pathExtension.lowercased()) {
                paths.insert(url.path)
            }
        }
        return paths.compactMap { path in
            guard let profile = rgbProfile(path) else { return nil }
            let name = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String?
            return DisplayColorProfile(path: path, name: name ?? URL(fileURLWithPath: path).lastPathComponent)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func rgbProfile(_ path: String) -> ColorSyncProfile? {
        guard FileManager.default.fileExists(atPath: path),
              let profile = ColorSyncProfileCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)?
                .takeRetainedValue(),
              let header = ColorSyncProfileCopyHeader(profile)?.takeRetainedValue() as Data?,
              header.count >= 20 else { return nil }
        // ColorSync returns the header in host byte order, unlike bytes in an ICC
        // file. Accept display-class RGB profiles, not CMYK or named-color lists.
        let signature = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 16, as: UInt32.self) }
        let profileClass = header.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 12, as: UInt32.self) }
        guard signature == 0x52474220, profileClass == 0x6d6e7472 else { return nil }
        return profile
    }

    static func displays() throws -> [ConfigurableDisplay] {
        try activeIDs().compactMap { id in
            guard let uuid = identity(id), let current = CGDisplayCopyDisplayMode(id) else { return nil }
            let name = NSScreen.screens.first {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
            }?.localizedName ?? "Display \(id)"
            let extended = ExtendedDisplayModes.snapshot(id)
            let currentSpecification = extended?.current.specification ?? specification(current)
            var choices = Set(extended?.modes.map(\.specification) ?? modes(id).map(specification))
            choices.insert(currentSpecification)
            return ConfigurableDisplay(id: id, identity: uuid, name: name,
                isMain: CGDisplayIsMain(id) != 0, isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                isMirrored: CGDisplayIsInMirrorSet(id) != 0,
                current: currentSpecification, modes: choices.sorted {
                    if $0.width != $1.width { return $0.width < $1.width }
                    if $0.height != $1.height { return $0.height < $1.height }
                    if $0.isHiDPI != $1.isHiDPI { return !$0.isHiDPI }
                    return $0.refreshRate > $1.refreshRate
                }, colorProfilePath: currentProfile(id), customColorProfilePath: customProfile(id))
        }
    }

    static func snapshot() throws -> [DisplayConfigurationRecord] {
        try displays().map { display in
            let origin = CGDisplayBounds(display.id).origin
            return DisplayConfigurationRecord(identity: display.identity, mode: display.current,
                x: Int32(origin.x), y: Int32(origin.y), isMain: display.isMain,
                customColorProfilePath: display.customColorProfilePath)
        }
    }

    static func apply(_ records: [DisplayConfigurationRecord], allowingMissing: Bool,
                      permanently: Bool) throws {
        let connected = try displays()
        guard Set(connected.map(\.identity)).count == connected.count else {
            throw DisplayConfigurationIssue.invalidConfiguration
        }
        let ids = Dictionary(uniqueKeysWithValues: connected.map { ($0.identity, $0.id) })
        let plan = allowingMissing ? try DisplayConfigurationPolicy.rollbackRecords(records,
            connected: Set(ids.keys), currentMain: connected.first(where: \.isMain)?.identity) : records
        try DisplayConfigurationPolicy.validate(plan)
        if !allowingMissing, Set(plan.map(\.identity)) != Set(ids.keys) {
            throw DisplayConfigurationIssue.unavailable
        }
        // Validate the whole plan before touching any screen or profile.
        enum ResolvedMode { case standard(CGDisplayMode), extended(Int32) }
        var resolved: [(CGDirectDisplayID, ResolvedMode, DisplayConfigurationRecord)] = []
        for record in plan {
            guard let id = ids[record.identity] else { throw DisplayConfigurationIssue.unavailable }
            guard CGDisplayIsInMirrorSet(id) == 0 else { throw DisplayConfigurationIssue.mirrored }
            let resolvedMode: ResolvedMode
            if let extended = ExtendedDisplayModes.snapshot(id),
               let mode = extended.modes.first(where: { $0.specification.matches(record.mode) }) {
                resolvedMode = .extended(mode.index)
            } else if let mode = modes(id).first(where: { specification($0).matches(record.mode) })
                ?? CGDisplayCopyDisplayMode(id).flatMap({ specification($0).matches(record.mode) ? $0 : nil }) {
                resolvedMode = .standard(mode)
            } else { throw DisplayConfigurationIssue.modeUnavailable }
            if let path = record.customColorProfilePath, rgbProfile(path) == nil {
                throw DisplayConfigurationIssue.profileUnavailable
            }
            resolved.append((id, resolvedMode, record))
        }
        var configuration: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configuration) == .success, let configuration else {
            throw DisplayConfigurationIssue.changeFailed
        }
        for (id, mode, record) in resolved {
            let result: CGError
            switch mode {
            case .standard(let mode): result = CGConfigureDisplayWithDisplayMode(configuration, id, mode, nil)
            case .extended(let index): result = ExtendedDisplayModes.configure(index, display: id, in: configuration)
            }
            guard result == .success,
                  CGConfigureDisplayOrigin(configuration, id, record.x, record.y) == .success else {
                CGCancelDisplayConfiguration(configuration)
                throw DisplayConfigurationIssue.changeFailed
            }
        }
        // WindowServer restores a preview even if the app crashes or is force quit.
        guard CGCompleteDisplayConfiguration(configuration, permanently ? .permanently : .forAppOnly) == .success
        else { throw DisplayConfigurationIssue.changeFailed }
        for (id, _, record) in resolved {
            if customProfile(id) == record.customColorProfilePath { continue }
            guard let deviceClass = kColorSyncDisplayDeviceClass?.takeUnretainedValue(),
                  let scopeKey = kColorSyncProfileUserScope?.takeUnretainedValue() as String?,
                  let defaultKey = kColorSyncDeviceDefaultProfileID?.takeUnretainedValue() as String?,
                  let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
                throw DisplayConfigurationIssue.unavailable
            }
            var profileInfo: [String: Any] = [
                scopeKey: kCFPreferencesCurrentUser as Any]
            profileInfo[defaultKey] = record.customColorProfilePath
                .map { URL(fileURLWithPath: $0) as Any } ?? NSNull()
            guard ColorSyncDeviceSetCustomProfiles(deviceClass, uuid, profileInfo as CFDictionary)
            else { throw DisplayConfigurationIssue.changeFailed }
        }
        // Report the actual state, not just a successful API return code.
        let actual = try displays()
        for (_, _, record) in resolved {
            guard let display = actual.first(where: { $0.identity == record.identity }),
                  display.current.matches(record.mode), display.isMain == record.isMain,
                  display.customColorProfilePath == record.customColorProfilePath else {
                throw DisplayConfigurationIssue.changeFailed
            }
        }
    }
}

final class DisplayConfigurationService: ObservableObject {
    @Published private(set) var displays: [ConfigurableDisplay] = []
    @Published private(set) var profiles: [DisplayColorProfile] = []
    @Published private(set) var saved: [SavedDisplayConfiguration] = []
    @Published private(set) var secondsRemaining = 0
    @Published private(set) var issue: DisplayConfigurationIssue?
    private let defaults: UserDefaults
    private var observer: NSObjectProtocol?
    private var confirmationTimer: Timer?
    private let transaction = DisplayConfigurationTransaction(apply: DisplayConfigurationDriver.apply)
    private static var recoveryChecked = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: DisplayConfigurationPolicy.savedConfigurationsKey),
           let values = try? JSONDecoder().decode([SavedDisplayConfiguration].self, from: data) { saved = values }
    }

    var isPending: Bool { transaction.isPending }

    /// Geometry previews are owned by WindowServer; ICC overrides need explicit
    /// recovery after a crash. Run once when the Displays feature starts.
    static func recoverIfNeeded(defaults: UserDefaults = .standard) {
        guard !recoveryChecked else { return }
        recoveryChecked = true
        guard let data = defaults.data(forKey: DisplayConfigurationPolicy.recoveryKey),
              let records = try? JSONDecoder().decode([DisplayConfigurationRecord].self, from: data) else { return }
        do {
            try DisplayConfigurationDriver.apply(records, allowingMissing: true, permanently: false)
            defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey)
        } catch { /* Retain the plan; the settings page offers an explicit retry. */ }
    }

    func start() {
        guard observer == nil else { return }
        if let data = defaults.data(forKey: DisplayConfigurationPolicy.recoveryKey),
           let records = try? JSONDecoder().decode([DisplayConfigurationRecord].self, from: data) {
            do {
                try DisplayConfigurationDriver.apply(records, allowingMissing: true, permanently: false)
                defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey)
            } catch { issue = .rollbackFailed }
        }
        refresh()
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            }
    }

    func stop() {
        if isPending { revert() }
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    deinit {
        confirmationTimer?.invalidate()
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func refresh() {
        do {
            displays = try DisplayConfigurationDriver.displays()
            profiles = DisplayConfigurationDriver.profiles(including: displays.compactMap(\.colorProfilePath))
        } catch { if issue == nil { issue = .unavailable } }
    }

    private func preview(_ records: [DisplayConfigurationRecord]) {
        do {
            guard !isPending else { throw DisplayConfigurationIssue.pending }
            issue = nil
            let original = try DisplayConfigurationDriver.snapshot()
            defaults.set(try JSONEncoder().encode(original), forKey: DisplayConfigurationPolicy.recoveryKey)
            try transaction.begin(from: original, to: records)
            secondsRemaining = DisplayConfigurationPolicy.confirmationSeconds
            confirmationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.secondsRemaining -= 1
                if self.secondsRemaining <= 0 { self.revert() }
            }
        } catch {
            issue = error as? DisplayConfigurationIssue ?? .changeFailed
            if !isPending { defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey) }
        }
        refresh()
    }

    func changeMode(_ mode: DisplayModeSpecification, for identity: String) {
        do {
            var records = try DisplayConfigurationDriver.snapshot()
            guard let index = records.firstIndex(where: { $0.identity == identity }) else {
                throw DisplayConfigurationIssue.unavailable
            }
            records[index].mode = mode
            preview(records)
        } catch { issue = error as? DisplayConfigurationIssue ?? .changeFailed }
    }

    func makeMain(_ identity: String) {
        do { preview(try DisplayConfigurationPolicy.makingMain(identity, in: DisplayConfigurationDriver.snapshot())) }
        catch {
            issue = error as? DisplayConfigurationIssue ?? .changeFailed
            if !isPending { defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey) }
        }
    }

    func changeProfile(_ path: String?, for identity: String) {
        do {
            var records = try DisplayConfigurationDriver.snapshot()
            guard let index = records.firstIndex(where: { $0.identity == identity }) else {
                throw DisplayConfigurationIssue.unavailable
            }
            records[index].customColorProfilePath = path
            preview(records)
        } catch { issue = error as? DisplayConfigurationIssue ?? .changeFailed }
    }

    func keep() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        do {
            try transaction.keep()
            defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey)
            issue = nil
        }
        catch {
            issue = error as? DisplayConfigurationIssue ?? .changeFailed
            if !isPending { defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey) }
        }
        secondsRemaining = 0
        refresh()
    }

    func revert() {
        confirmationTimer?.invalidate()
        confirmationTimer = nil
        do {
            if transaction.isPending {
                try transaction.rollback()
            } else if let data = defaults.data(forKey: DisplayConfigurationPolicy.recoveryKey) {
                let records = try JSONDecoder().decode([DisplayConfigurationRecord].self, from: data)
                try DisplayConfigurationDriver.apply(records, allowingMissing: true, permanently: false)
            }
            defaults.removeObject(forKey: DisplayConfigurationPolicy.recoveryKey)
            issue = nil
        }
        catch { issue = .rollbackFailed }
        secondsRemaining = 0
        refresh()
    }

    func save(name: String) {
        guard !isPending else { issue = .pending; return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { issue = .nameRequired; return }
        do {
            let snapshot = try DisplayConfigurationDriver.snapshot()
            try DisplayConfigurationPolicy.validate(snapshot)
            saved.append(SavedDisplayConfiguration(id: UUID(), name: trimmed, displays: snapshot))
            try persist()
            issue = nil
        } catch { issue = error as? DisplayConfigurationIssue ?? .invalidConfiguration }
    }

    func restore(_ configuration: SavedDisplayConfiguration) { preview(configuration.displays) }

    func remove(_ id: UUID) {
        guard !isPending else { return }
        saved.removeAll { $0.id == id }
        do { try persist() } catch { issue = .invalidConfiguration }
    }

    private func persist() throws {
        defaults.set(try JSONEncoder().encode(saved), forKey: DisplayConfigurationPolicy.savedConfigurationsKey)
    }
}
