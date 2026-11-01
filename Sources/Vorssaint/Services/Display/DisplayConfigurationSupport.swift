// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Persist geometry, never WindowServer's transient display/mode numbers.
struct DisplayModeSpecification: Codable, Hashable {
    let width: Int
    let height: Int
    let pixelWidth: Int
    let pixelHeight: Int
    let refreshRate: Double
    var colorDepth: UInt32? = nil

    var isHiDPI: Bool { pixelWidth > width && pixelHeight > height }
    var sizeID: String { "\(width)x\(height):\(pixelWidth)x\(pixelHeight)" }
    var rateLabel: String {
        refreshRate > 0 ? String(format: "%.2f Hz", refreshRate) : "—"
    }
    var label: String { "\(width) × \(height)\(isHiDPI ? " HiDPI" : "") · \(rateLabel)" }

    func matches(_ other: Self) -> Bool {
        sizeID == other.sizeID && abs(refreshRate - other.refreshRate) < 0.1
            && (other.colorDepth == nil || colorDepth == other.colorDepth)
    }
}

struct DisplayConfigurationRecord: Codable, Equatable {
    let identity: String
    var mode: DisplayModeSpecification
    var x: Int32
    var y: Int32
    var isMain: Bool
    /// nil means the factory profile, not an arbitrary guessed ICC file.
    var customColorProfilePath: String?
}

struct SavedDisplayConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let displays: [DisplayConfigurationRecord]
}

enum DisplayConfigurationIssue: String, Error {
    case unavailable, modeUnavailable, profileUnavailable, changeFailed, rollbackFailed
    case mirrored, nameRequired, pending, invalidConfiguration
}

enum DisplayConfigurationPolicy {
    static let savedConfigurationsKey = "displaySavedConfigurations"
    static let recoveryKey = "displayConfigurationPendingRecovery"
    static let confirmationSeconds = 15

    /// Making a screen primary translates the whole desktop, preserving adjacency.
    static func makingMain(_ identity: String, in records: [DisplayConfigurationRecord]) throws
        -> [DisplayConfigurationRecord] {
        guard let target = records.first(where: { $0.identity == identity }) else {
            throw DisplayConfigurationIssue.unavailable
        }
        return try records.map { record in
            var changed = record
            let x = Int64(record.x) - Int64(target.x)
            let y = Int64(record.y) - Int64(target.y)
            guard let nx = Int32(exactly: x), let ny = Int32(exactly: y) else {
                throw DisplayConfigurationIssue.invalidConfiguration
            }
            changed.x = nx
            changed.y = ny
            changed.isMain = record.identity == identity
            return changed
        }
    }

    static func validate(_ records: [DisplayConfigurationRecord]) throws {
        guard !records.isEmpty, Set(records.map(\.identity)).count == records.count,
              records.allSatisfy({ !$0.identity.isEmpty && $0.mode.width > 0 && $0.mode.height > 0
                  && $0.mode.pixelWidth >= $0.mode.width && $0.mode.pixelHeight >= $0.mode.height
                  && $0.mode.refreshRate.isFinite && $0.mode.refreshRate >= 0 }),
              records.filter(\.isMain).count == 1,
              records.first(where: \.isMain).map({ $0.x == 0 && $0.y == 0 }) == true else {
            throw DisplayConfigurationIssue.invalidConfiguration
        }
    }

    /// An unplugged monitor must not prevent restoration of the remaining screens.
    static func rollbackRecords(_ records: [DisplayConfigurationRecord], connected: Set<String>,
                                currentMain: String?) throws -> [DisplayConfigurationRecord] {
        let remaining = records.filter { connected.contains($0.identity) }
        guard !remaining.isEmpty else { throw DisplayConfigurationIssue.unavailable }
        if remaining.contains(where: \.isMain) { return remaining }
        let primary = remaining.first(where: { $0.identity == currentMain }) ?? remaining[0]
        return try makingMain(primary.identity, in: remaining)
    }

    static func preferredMode(in modes: [DisplayModeSpecification], sizeID: String,
                              keeping rate: Double) -> DisplayModeSpecification? {
        modes.filter { $0.sizeID == sizeID }.min {
            let a = abs($0.refreshRate - rate), b = abs($1.refreshRate - rate)
            return a == b ? $0.refreshRate > $1.refreshRate : a < b
        }
    }
}

/// One preview at a time. Injected I/O lets failures and hot-unplug recovery be tested
/// without changing a real screen. Both the timeout and Cancel use this same path.
final class DisplayConfigurationTransaction {
    typealias Apply = ([DisplayConfigurationRecord], Bool, Bool) throws -> Void
    private(set) var original: [DisplayConfigurationRecord]?
    private(set) var proposed: [DisplayConfigurationRecord]?
    private let apply: Apply
    private var commitAttempted = false

    init(apply: @escaping Apply) { self.apply = apply }
    var isPending: Bool { original != nil }

    func begin(from old: [DisplayConfigurationRecord], to new: [DisplayConfigurationRecord]) throws {
        guard !isPending else { throw DisplayConfigurationIssue.pending }
        try DisplayConfigurationPolicy.validate(old)
        try DisplayConfigurationPolicy.validate(new)
        // Retain the recovery plan even if applying the new color profile fails
        // after the WindowServer transaction has already completed.
        original = old
        proposed = new
        commitAttempted = false
        do { try apply(new, false, false) }
        catch {
            do { try rollback() }
            catch { throw DisplayConfigurationIssue.rollbackFailed }
            throw error
        }
    }

    func keep() throws {
        guard let proposed else { return }
        commitAttempted = true
        do { try apply(proposed, false, true) }
        catch {
            do { try rollback() }
            catch { throw DisplayConfigurationIssue.rollbackFailed }
            throw error
        }
        original = nil
        self.proposed = nil
        commitAttempted = false
    }

    func rollback() throws {
        guard let original else { return }
        try apply(original, true, commitAttempted)
        self.original = nil
        proposed = nil
        commitAttempted = false
    }
}
