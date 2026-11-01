// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Production handoff logic runs with an ordinary reference in place of an
/// AppKit panel, so lifetime checks never create or manipulate desktop UI.
enum ScreenshotEditingSurfaceTests {
    final class NSPanel {}
    final class ScreenshotEditorController {}

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
    }
}
