// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Standalone behavior tests: no display API is called and no screen is changed.
enum DisplayConfigurationTests {
    static func run(_ suite: TestSuite) {
        do { try checks(suite) }
        catch { suite.expect(false, "Unexpected display test failure: \(error)") }
    }

    private static func checks(_ suite: TestSuite) throws {
        func check(_ value: @autoclosure () -> Bool, _ message: String) {
            suite.expect(value(), message)
        }
        let low = DisplayModeSpecification(width: 1920, height: 1080,
            pixelWidth: 1920, pixelHeight: 1080, refreshRate: 144)
        let high = DisplayModeSpecification(width: 1920, height: 1080,
            pixelWidth: 3840, pixelHeight: 2160, refreshRate: 144)
        let slow = DisplayModeSpecification(width: 1920, height: 1080,
            pixelWidth: 3840, pixelHeight: 2160, refreshRate: 60)
        check(!low.matches(high), "Same logical size must not silently substitute LoDPI for HiDPI")
        check(high.isHiDPI && !low.isHiDPI, "HiDPI requires a larger backing buffer")
        check(DisplayConfigurationPolicy.preferredMode(in: [slow, high], sizeID: high.sizeID,
            keeping: 144) == high, "Changing resolution preserves a supported 144 Hz rate")
        let a = DisplayConfigurationRecord(identity: "internal", mode: high, x: 0, y: 0,
            isMain: true, customColorProfilePath: nil)
        let b = DisplayConfigurationRecord(identity: "external", mode: high, x: 1920, y: -200,
            isMain: false, customColorProfilePath: "/profiles/calibrated.icc")
        let before = [a, b]
        let after = try DisplayConfigurationPolicy.makingMain("external", in: before)
        check(after[1].isMain && after[1].x == 0 && after[1].y == 0, "Selected main display has origin zero")
        check(after[0].x == -1920 && after[0].y == 200, "Primary change preserves the screens' relative positions")
        check(after[1].customColorProfilePath == b.customColorProfilePath, "Primary change preserves color calibration")
        try DisplayConfigurationPolicy.validate(after)
        let unplugged = try DisplayConfigurationPolicy.rollbackRecords(before,
            connected: ["external"], currentMain: "external")
        check(unplugged.count == 1 && unplugged[0].isMain && unplugged[0].x == 0,
              "Rollback still works after the original primary display is unplugged")
        do {
            try DisplayConfigurationPolicy.validate([a, a])
            check(false, "Duplicate display identities must be refused")
        } catch DisplayConfigurationIssue.invalidConfiguration { check(true, "Duplicate identities refused") }
        var calls: [([DisplayConfigurationRecord], Bool, Bool)] = []
        let transaction = DisplayConfigurationTransaction { calls.append(($0, $1, $2)) }
        try transaction.begin(from: before, to: after)
        check(transaction.isPending && calls.count == 1 && !calls[0].2,
              "Preview is temporary and waits for confirmation")
        do {
            try transaction.begin(from: before, to: after)
            check(false, "A second preview must not overwrite the rollback plan")
        } catch DisplayConfigurationIssue.pending { check(true, "Concurrent preview refused") }
        try transaction.rollback()
        check(!transaction.isPending && calls.last!.0 == before && calls.last!.1,
              "Timeout and cancel restore the original snapshot, tolerating unplugged displays")
        try transaction.begin(from: before, to: after)
        try transaction.keep()
        check(!transaction.isPending && calls.last!.0 == after && calls.last!.2,
              "Only Keep commits the accepted configuration permanently")
        var attempts = 0
        let failing = DisplayConfigurationTransaction { _, recovering, _ in
            attempts += 1
            if !recovering { throw DisplayConfigurationIssue.profileUnavailable }
        }
        do {
            try failing.begin(from: before, to: after)
            check(false, "An application failure must be reported")
        } catch DisplayConfigurationIssue.profileUnavailable { check(true, "Application failure reported") }
        check(attempts == 2 && !failing.isPending, "Partial color-profile failures restore geometry and profiles")
        var canRecover = false
        let recoveryFailure = DisplayConfigurationTransaction { _, recovering, _ in
            if !recovering || !canRecover { throw DisplayConfigurationIssue.changeFailed }
        }
        do {
            try recoveryFailure.begin(from: before, to: after)
            check(false, "Failed rollback must be reported")
        } catch DisplayConfigurationIssue.rollbackFailed { check(true, "Rollback failure reported") }
        check(recoveryFailure.isPending, "A failed restore retains the recovery plan for Retry")
        canRecover = true
        try recoveryFailure.rollback()
        check(!recoveryFailure.isPending, "Retry can recover after the display becomes available")
        var restoredPermanently = false
        let commitFailure = DisplayConfigurationTransaction { _, recovering, permanent in
            if permanent && !recovering { throw DisplayConfigurationIssue.changeFailed }
            if recovering { restoredPermanently = permanent }
        }
        try commitFailure.begin(from: before, to: after)
        do {
            try commitFailure.keep()
            check(false, "A failed permanent commit must be reported")
        } catch DisplayConfigurationIssue.changeFailed { check(true, "Commit failure reported") }
        check(restoredPermanently && !commitFailure.isPending,
              "A failed permanent commit also restores the persisted configuration")
        let saved = SavedDisplayConfiguration(id: UUID(), name: "Desk", displays: after)
        let data = try JSONEncoder().encode(saved)
        let decoded = try JSONDecoder().decode(SavedDisplayConfiguration.self, from: data)
        check(decoded == saved, "Saved configurations preserve stable identity, HiDPI, rate, layout and ICC selection")
        var raw = Data(repeating: 0, count: 212)
        func put<T>(_ value: T, at offset: Int) {
            var value = value
            withUnsafeBytes(of: &value) { raw.replaceSubrange(offset..<(offset + $0.count), with: $0) }
        }
        put(UInt32(0x200001), at: 4)
        put(UInt32(1920), at: 8); put(UInt32(1080), at: 12); put(UInt32(8), at: 16)
        put(UInt32(144 * 65536), at: 188); put(Float(2), at: 208)
        let extended = ExtendedDisplayModes.decode(raw, index: 101)
        check(extended?.specification.isHiDPI == true && extended?.specification.pixelWidth == 3840,
              "Extended scaled modes retain their backing size and HiDPI identity")
        check(extended?.specification.refreshRate == 144 && extended?.specification.colorDepth == 8,
              "Extended mode preserves refresh rate and color depth")
        put(UInt32((59.94 * 65536).rounded()), at: 188)
        check(abs(ExtendedDisplayModes.decode(raw, index: 1)!.specification.refreshRate - 59.94) < 0.001,
              "Fractional refresh rates must not be truncated to integer Hz")
        put(UInt32(0x200000), at: 4)
        check(ExtendedDisplayModes.decode(raw, index: 1) == nil, "Invalid modes must not be offered")
        put(UInt32(0x200001), at: 4); put(Float.nan, at: 208)
        check(ExtendedDisplayModes.decode(raw, index: 1) == nil, "Unknown or corrupt ABIs must fail closed")
        for language in AppLanguage.allCases {
            let values = DisplayConfigurationStrings.values(language)
            check(values.count == DisplayConfigurationText.allCases.count,
                  "Every display label is localized in \(language.rawValue)")
            check(values.allSatisfy { !$0.isEmpty }, "Display translations are nonempty in \(language.rawValue)")
        }
    }
}
