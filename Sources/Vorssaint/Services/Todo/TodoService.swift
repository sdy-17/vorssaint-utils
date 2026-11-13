// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Carbon open shortcut and one-shot archive deadlines; no polling or capture.
final class TodoService: TodoModel {
    static let shared = TodoService()
    @Published private(set) var shortcutRegistrationFailed = false
    @Published private(set) var inputFocusRequest = UUID()
    private var window: NSWindow?
    private var archiveTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var clockObserver: NSObjectProtocol?
    private var isApplyingArchivePolicy = false
    // QuickToolHotkey ids: todo uses 90, above the capture tool block.
    private let hotkey = QuickToolHotkey(id: 90)

    override init(directoryURL: URL? = PrivateFileStore.containerURL) {
        super.init(directoryURL: directoryURL)
        hotkey.onPress = { [weak self] in
            guard !ShortcutCapture.isCapturing else { return }
            self?.open()
        }
    }

    func syncWithPreferences() {
        if !AppFeature.todo.isAvailable {
            window?.close()
            window = nil
        }
        syncHotkey()
        if AppFeature.todo.isAvailable { load() }
        else { cancelArchiveScheduling() }
    }

    deinit { cancelArchiveScheduling() }

    override func load() {
        super.load()
        refreshArchivePolicy()
    }

    override func didChangeItems() {
        refreshArchivePolicy()
    }

    private func cancelArchiveScheduling() {
        archiveTimer?.invalidate()
        archiveTimer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
        if let clockObserver { NotificationCenter.default.removeObserver(clockObserver) }
        clockObserver = nil
    }

    private func refreshArchivePolicy() {
        guard !isApplyingArchivePolicy else { return }
        archiveTimer?.invalidate()
        archiveTimer = nil
        let days = UserDefaults.standard.integer(forKey: DefaultsKey.todoAutoArchiveDays)
        guard AppFeature.todo.isAvailable, (1...3650).contains(days), !loadFailed else {
            cancelArchiveScheduling()
            return
        }
        if wakeObserver == nil {
            wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.refreshArchivePolicy() }
        }
        if clockObserver == nil {
            clockObserver = NotificationCenter.default.addObserver(
                forName: .NSSystemClockDidChange, object: nil, queue: .main
            ) { [weak self] _ in self?.refreshArchivePolicy() }
        }
        let now = Date()
        isApplyingArchivePolicy = true
        applyAutoArchive(days: days, now: now)
        isApplyingArchivePolicy = false
        // A failed write can leave an overdue task. Do not reschedule that
        // deadline immediately: retry only at the next explicit lifecycle event.
        guard let due = nextAutoArchiveDate(days: days), due > now else { return }
        let timer = Timer(fire: due, interval: 0, repeats: false) { [weak self] _ in
            // Timer belongs to the main run loop, including during event tracking.
            self?.refreshArchivePolicy()
        }
        archiveTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Shortcut recording releases this key through QuickToolHotkey.unregisterAll().
    /// Preference syncs during recording must not re-register it early.
    private func syncHotkey() {
        let enabled = AppFeature.todo.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.todoShortcutEnabled)
            && !ShortcutCapture.isCapturing
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.todoShortcut,
                                            fallback: .todoDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut,
                                                  storageKey: DefaultsKey.todoShortcut)
    }

    /// Prefer the editable island page, like Scratchpad; keep the window as a fallback.
    func open() {
        guard AppFeature.todo.isAvailable else { return }
        load()
        if NotchService.shared.showTodo() { return }
        show()
    }

    /// Explicit standalone window, also used when the island is unavailable or hidden.
    func show() {
        guard AppFeature.todo.isAvailable else { return }
        load()
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
                                 styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                 backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.minSize = NSSize(width: 440, height: 320)
            panel.contentView = NSHostingView(rootView: TodoView(service: self))
            panel.center()
            window = panel
        }
        window?.title = TodoStrings.current.title
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // A retained window does not re-run onAppear each time it is opened.
        inputFocusRequest = UUID()
    }

    func close() {
        // Keep the hosting view so an unsaved input draft survives reopening.
        window?.close()
    }
}
