// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import CoreGraphics

/// Production handoff logic runs with an ordinary reference in place of an
/// AppKit panel, so lifetime checks never create or manipulate desktop UI.
enum ScreenshotEditingSurfaceTests {
    final class NSPanel {
        var ignoresMouseEvents = false
        var visible = true
        var closeCount = 0
        var contentView: Int? = 1
        var delegate: Int? = 1
        let screenFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let displayID = 1
        var frozenImage: Int? = 1
        func releaseSelectionViews() {}
        func orderOut(_ sender: Any?) { visible = false }
        func close() { closeCount += 1; visible = false }
    }
    typealias NSWindow = NSPanel
    struct NSScreen {
        static let screens = [NSScreen()]
        let displayID = 1
        let visibleFrame = CGRect(x: 0, y: 0, width: 100, height: 100)
    }
    enum CATransaction { static func flush() {} }
    enum NSCursor {
        static let arrow = NSCursorToken()
        struct NSCursorToken { func set() {} }
    }
    enum NSEvent { static func removeMonitor(_ monitor: Any) {} }
    enum WindowActivationPolicy { static func release() {} }
    final class ScreenshotService {
        static let shared = ScreenshotService()
        var closeCount = 0
        func editorDidClose(_ editor: ScreenshotEditorController) { closeCount += 1 }
    }
    final class ScreenshotEditorController {
        typealias NSWindow = ScreenshotEditingSurfaceTests.NSWindow
        typealias WindowActivationPolicy = ScreenshotEditingSurfaceTests.WindowActivationPolicy
        typealias ScreenshotService = ScreenshotEditingSurfaceTests.ScreenshotService
        var window: NSWindow?
        var retainsActivation = false
        var monitorRemovalCount = 0
        var onRemoveMonitors: (() -> Void)?
        func removeEditorMonitors() {
            monitorRemovalCount += 1
            onRemoveMonitors?()
        }
    }
    typealias ScreenshotSelectionController = Session
    final class Session {
        typealias EditingSurface = ScreenshotEditingSurfaceTests.EditingSurface
        typealias NSScreen = ScreenshotEditingSurfaceTests.NSScreen
        typealias NSEvent = ScreenshotEditingSurfaceTests.NSEvent
        typealias NSCursor = ScreenshotEditingSurfaceTests.NSCursor
        typealias CATransaction = ScreenshotEditingSurfaceTests.CATransaction
        static var editingCursorOwners = 0
        static weak var activeSession: Session?
        static func refreshBackgroundCursor() {}
        struct EditingContext {
            let image: Int
            let screenFrame: CGRect
            let visibleFrame: CGRect
        }
        struct Capture {
            let anchorRect = CGRect(x: 10, y: 10, width: 20, height: 20)
            var editingContext: EditingContext?
            var editingSurface: EditingSurface?
        }
        enum Outcome { case cancelled, failed, captured(Capture) }
        final class Options { var onSelectionChange: (() -> Void)? }
        var screenCaptureOptions: Options? = Options()
        var finished = false
        var completion: ((Outcome) -> Void)?
        var panels: [NSPanel] = []
        var preparedEditors: [Int: ScreenshotEditorController] = [:]
        var keyMonitor: Any? = 1
        var globalKeyMonitor: Any? = 2
        var pendingCount = 0
        func markCapturePending() { pendingCount += 1 }
        func discardPreparedEditors() { preparedEditors.removeAll() }
    }

    static func run(_ suite: TestSuite) {
        var panel: NSPanel? = NSPanel()
        weak let observed = panel
        var prepared = 0
        let lease = EditingSurface(panel: panel!) { prepared += 1 }
        var editor: ScreenshotEditorController? = ScreenshotEditorController()
        lease.preparedEditor = editor
        editor = nil
        suite.expect(lease.preparedEditor == nil, "surface lease cannot retain a prepared editor cycle")
        var adopted = lease.claim()
        suite.expect(adopted === panel && lease.isClaimed && prepared == 1,
                     "editor claims the visible capture surface exactly once")
        suite.expect(lease.claim() == nil && prepared == 1,
                     "a reused capture cannot give two editors the same surface")
        panel = nil
        suite.expect(observed != nil, "adopting editor keeps its surface alive")
        adopted = nil
        suite.expect(observed == nil && lease.panel == nil,
                     "capture metadata does not retain a closed editor surface")
        var cancelled: NSPanel? = NSPanel()
        let abandoned = EditingSurface(panel: cancelled!) { prepared += 1 }
        cancelled = nil
        suite.expect(abandoned.claim() == nil && !abandoned.isClaimed && prepared == 1,
                     "expired unclaimed surface cannot be resurrected")
        let retainedPanel = NSPanel()
        let expired = EditingSurface(panel: retainedPanel) { prepared += 1 }
        expired.invalidate()
        suite.expect(expired.claim() == nil && prepared == 1,
                     "an unclaimed synchronous lease expires even when another owner retains its panel")
        cancellationAndReentry(suite)
        editorTeardown(suite)
    }

    private static func cancellationAndReentry(_ suite: TestSuite) {
        let session = Session()
        let panel = NSPanel()
        session.panels = [panel]
        var completions = 0
        var blockedDuringCompletion = false
        suite.expect(session.claimSession { _ in
            completions += 1
            blockedDuringCompletion = Session.isSessionOnScreen
            suite.expect(!panel.visible && panel.ignoresMouseEvents && panel.contentView == nil,
                         "cancel retires and clears the shield before invoking completion")
        }, "first selection acquires the capture surface")
        suite.expect(!session.claimSession { _ in completions += 100 },
                     "duplicate begin cannot replace the original callback")
        let competing = Session()
        var rejected = 0
        suite.expect(!competing.claimSession { _ in rejected += 1 } && rejected == 1,
                     "competing selection is cancelled without stealing ownership")
        session.cancel()
        session.cancel()
        suite.expect(completions == 1 && panel.closeCount == 1 && session.panels.isEmpty,
                     "repeated mouse/keyboard cancellation closes all panels and completes once")
        suite.expect(blockedDuringCompletion && !Session.isSessionOnScreen,
                     "selection ownership lasts through completion and is then released")
        suite.expect(competing.claimSession { _ in }, "capture can restart after cancellation")
        session.cancel()
        suite.expect(Session.activeSession === competing && Session.isSessionOnScreen,
                     "a late cancellation cannot clear a newer selection owner")
        competing.cancel()
        var abandoned: Session? = Session()
        _ = abandoned?.claimSession { _ in }
        abandoned = nil
        suite.expect(!Session.isSessionOnScreen,
                     "an abandoned selection cannot strand a separate global capture flag")

        let captured = Session()
        let adoptedPanel = NSPanel()
        let otherPanel = NSPanel()
        captured.panels = [adoptedPanel, otherPanel]
        var surface: EditingSurface?
        _ = captured.claimSession { outcome in
            if case .captured(let result) = outcome {
                surface = result.editingSurface
                _ = surface?.claim()
                Session.editingCursorOwners += 1
            }
        }
        captured.finish(.captured(Session.Capture()))
        suite.expect(adoptedPanel.visible && adoptedPanel.closeCount == 0 && !otherPanel.visible,
                     "handoff preserves only the claimed panel and retires the other display")
        suite.expect(Session.isSessionOnScreen && Session.activeSession == nil,
                     "the in-place editor continues blocking capture after selection completes")
        let next = Session()
        suite.expect(!next.claimSession { _ in }, "repeat capture cannot photograph an editor shield")
        Session.editingCursorOwners = 0
        suite.expect(next.claimSession { _ in }, "capture becomes available after editor release")
        next.cancel()
        let unclaimed = Session()
        let unclaimedPanel = NSPanel()
        unclaimed.panels = [unclaimedPanel]
        _ = unclaimed.claimSession { outcome in
            if case .captured(let result) = outcome { surface = result.editingSurface }
        }
        unclaimed.finish(.captured(Session.Capture()))
        suite.expect(surface?.claim() == nil && !unclaimedPanel.visible && unclaimedPanel.contentView == nil,
                     "delayed editor cannot resurrect an unclaimed retired screenshot panel")
    }

    private static func editorTeardown(_ suite: TestSuite) {
        let editor = ScreenshotEditorController()
        let panel = NSPanel()
        editor.window = panel
        editor.onRemoveMonitors = {
            suite.expect(!panel.visible && panel.contentView == nil && editor.window == nil,
                         "editor shield is hidden and cleared before capture ownership is released")
        }
        let before = ScreenshotService.shared.closeCount
        let event = Notification(name: Notification.Name("willClose"), object: panel)
        editor.windowWillClose(event)
        editor.windowWillClose(event)
        suite.expect(editor.monitorRemovalCount == 1 && ScreenshotService.shared.closeCount == before + 1,
                     "duplicate close notifications release monitors and notify service exactly once")
        let replacement = NSPanel()
        editor.window = replacement
        editor.windowWillClose(event)
        suite.expect(editor.window === replacement && replacement.visible && replacement.contentView != nil,
                     "stale native close notification cannot tear down a replacement editor window")
    }
}
