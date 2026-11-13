// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation

/// A projection of the existing store, never a second source of todo state.
struct NotchTodoSummary: Equatable {
    let items: [TodoItem]
    var count: Int { items.count }
    var headline: String {
        guard let first = items.first else { return "" }
        // Single-line even when an older/imported title contains line breaks.
        let title = first.title.split(whereSeparator: \.isNewline).joined(separator: " ")
        return "\(count) · \(title)"
    }
}

enum NotchTodoSupport {
    static func summary(_ items: [TodoItem]) -> NotchTodoSummary {
        NotchTodoSummary(items: items.filter { !$0.isCompleted })
    }

    /// Existing section visibility gates explicit inline opening, never ambient display.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        NotchSupport.isEnabled(in: defaults) && NotchSupport.modules(in: defaults).contains(.todo)
    }

    static func stripWing(_ summary: NotchTodoSummary, in geometry: NotchGeometry) -> CGFloat {
        let provisional = geometry.compactWatchGeometry(wing: NotchWatchSupport.stripWingRange.lowerBound)
        let size = NotchTimerSupport.stripTextSize(height: provisional.compactActivityContentHeight)
        let width = (summary.headline as NSString).size(withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .medium)
        ]).width.rounded(.up)
        let inset = provisional.compactActivityEdgeInset(boxHeight: size * 0.72, radius: 0)
        // Titles may be arbitrarily long. The existing watch geometry also
        // bounds this to the available menu-bar room on each display.
        return min(NotchWatchSupport.stripWingRange.upperBound,
                   max(NotchWatchSupport.stripWingRange.lowerBound, width + inset + NotchTimerSupport.stripCameraGap))
    }
}
