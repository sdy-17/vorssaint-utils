// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Production routing and editor actions are extracted verbatim by the generator.
/// No native window, global shortcut, input monitor or user store is involved.
enum NotchTodoTests {
    enum NotchTodoSupport {
        static var enabled = true
        static func isEnabled() -> Bool { enabled }
    }
    class RouteState {
        var acceptsUserInteraction = true
        var captureControls: Int?
        var heldDrag = false
        var expanded = false
        var selected = NotchModule.controls
        var showingSections = false, showingAppPanel = false
        var todoFocusSerial = 0
        var opened: [NotchModule] = []
        var canOpen = true
        func open(_ module: NotchModule) {
            guard canOpen else { return }
            opened.append(module)
            expanded = true
            selected = module
            showingSections = false
            showingAppPanel = false
        }
    }
    final class DraftOwner {
        var todoInput = TodoInputState()
        var panelIsKey = true, expanded = true
        var canBecomeKey = true
        var selected = NotchModule.todo
        var showingSections = false, showingAppPanel = false
        func ensurePanelKeyForTyping() {
            if canBecomeKey { panelIsKey = true }
        }
    }
    final class Model {
        var items: [TodoItem] = []
        var loadFailed = false
        var failsSave = false
        var failsArchive = false
        var writes = 0
        func add(_ title: String) -> Bool {
            guard !TodoStore.normalizedTitle(title).isEmpty, !failsSave else { return false }
            writes += 1
            items.append(TodoItem(title: title))
            return true
        }
        func update(id: UUID, title: String) -> Bool {
            guard !TodoStore.normalizedTitle(title).isEmpty, !failsSave,
                  let i = items.firstIndex(where: { $0.id == id }) else { return false }
            writes += 1
            items[i].title = title
            return true
        }
        func toggle(id: UUID) -> Bool {
            guard !failsSave, let i = items.firstIndex(where: { $0.id == id }) else { return false }
            writes += 1
            items[i].isCompleted.toggle()
            return true
        }
        func archive(id: UUID) -> Bool {
            guard !failsSave, !failsArchive, let i = items.firstIndex(where: { $0.id == id }),
                  items[i].isCompleted, !items[i].isArchived else { return false }
            writes += 1
            items[i].archivedAt = Date()
            return true
        }
        func restore(id: UUID) -> Bool {
            guard !failsSave, let i = items.firstIndex(where: { $0.id == id }),
                  items[i].isArchived else { return false }
            writes += 1
            items[i].archivedAt = nil
            return true
        }
        func delete(id: UUID) -> Bool {
            guard !failsSave else { return false }
            writes += 1
            items.removeAll { $0.id == id }
            return true
        }
    }
    class EditorState {
        let service = DraftOwner()
        let todos = Model()
        var preview = false
        var showingArchived = false
        var inputFocused: NotchTodoFocusTarget?
        var scrollSerial = 0
        var scrollMode = NotchTodoScrollMode.none
        var queuedFocus: [() -> Void] = []
        var editing: Bool { service.todoInput.editingID != nil }
        func enqueueFocus(_ action: @escaping () -> Void) { queuedFocus.append(action) }
        func attachRows() {
            let callbacks = queuedFocus
            queuedFocus.removeAll()
            callbacks.forEach { $0() }
        }
    }

    class WindowEditorState {
        let service = Model()
        var input = TodoInputState()
        var storedFilter = TodoFilter.all.rawValue
        var inputFocused = false
        var editingFocused: UUID?
        var queuedFocus: [() -> Void] = []
        func enqueueFocus(_ action: @escaping () -> Void) { queuedFocus.append(action) }
        func attachRows() {
            let callbacks = queuedFocus
            queuedFocus.removeAll()
            callbacks.forEach { $0() }
        }
    }

    static func windowDrafts(_ suite: TestSuite) {
        let editor = WindowEditor()
        let item = TodoItem(title: "completed window row", isCompleted: true)
        let other = TodoItem(title: "unrelated window row")
        editor.service.items = [item, other]
        editor.input.newTitle = "independent window draft"
        editor.beginEdit(item)
        editor.input.editingTitle = "keep unsaved window title"
        editor.beginEdit(item)
        suite.expect(editor.input.editingTitle == "keep unsaved window title",
                     "repeated double-click/AX edit on the same window row never resets its draft")
        let originalLocation = editor.orphanedEditingID
        _ = editor.service.archive(id: item.id)
        editor.editingRowLocationChanged(from: originalLocation)
        editor.attachRows()
        suite.expect(editor.orphanedEditingID == item.id && editor.editingFocused == item.id
                     && editor.input.editingTitle == "keep unsaved window title",
                     "external archival moves the window draft into a reachable fallback editor")
        editor.editingFocused = nil
        editor.service.items.append(TodoItem(title: "another unrelated row"))
        editor.editingRowLocationChanged(from: editor.orphanedEditingID)
        editor.attachRows()
        suite.expect(editor.editingFocused == nil,
                     "unrelated window item changes do not refocus the editor or disturb IME")
        editor.storedFilter = TodoFilter.archived.rawValue
        suite.expect(editor.orphanedEditingID == nil && editor.input.editingTitle == "keep unsaved window title",
                     "archived window mode suspends the draft and mounts no editor")
        editor.beginEdit(other)
        suite.expect(editor.editingID == item.id, "archived mode cannot replace a suspended window edit")
        editor.storedFilter = TodoFilter.all.rawValue
        suite.expect(editor.orphanedEditingID == item.id,
                     "returning to all restores access to a suspended archived-item draft")
        editor.service.failsSave = true
        editor.saveEdit(item.id)
        suite.expect(editor.editingID == item.id && editor.input.editingTitle == "keep unsaved window title",
                     "failed fallback title save retains the editor and unsaved text")
        editor.service.failsSave = false
        editor.saveEdit(item.id)
        suite.expect(editor.editingID == nil && editor.service.items[0].isArchived
                     && editor.service.items[0].title == "keep unsaved window title"
                     && editor.input.newTitle == "independent window draft",
                     "saving the fallback updates its title without restoring or deleting the archived item")
        _ = editor.service.restore(id: item.id)
        editor.beginEdit(item)
        editor.input.editingTitle = "draft hidden by pending filter"
        editor.storedFilter = TodoFilter.pending.rawValue
        suite.expect(editor.orphanedEditingID == item.id, "a filter-hidden completed edit retains an accessible fallback")
        editor.service.items.removeAll { $0.id == item.id }
        editor.saveEdit(item.id)
        suite.expect(editor.editingID == item.id && editor.input.editingTitle == "draft hidden by pending filter",
                     "externally deleted window items retain their draft when saving fails")
    }

    static func run(_ suite: TestSuite) {
        windowDrafts(suite)
        defer { NotchTodoSupport.enabled = true }
        let route = Route()
        suite.expect(route.showTodo() && route.expanded && route.selected == .todo && route.opened == [.todo],
                     "Todo opens the inline island page directly, not its floating window")
        suite.expect(route.showTodo() && route.expanded && route.todoFocusSerial == 2,
                     "reopening Todo restores focus without toggling the island closed")
        for unavailable in 0..<4 {
            let route = Route()
            if unavailable == 0 { route.acceptsUserInteraction = false }
            if unavailable == 1 { NotchTodoSupport.enabled = false }
            if unavailable == 2 { route.captureControls = 1 }
            if unavailable == 3 { route.heldDrag = true }
            suite.expect(!route.showTodo() && route.opened.isEmpty && route.todoFocusSerial == 0,
                         "unavailable Todo route never redirects focus or interrupts capture/drag (\(unavailable))")
            NotchTodoSupport.enabled = true
        }
        let failedOpen = Route()
        failedOpen.canOpen = false
        suite.expect(!failedOpen.showTodo() && failedOpen.todoFocusSerial == 0,
                     "a failed island opening permits the explicit service fallback")

        let empty = Editor()
        empty.beginAdd()
        empty.submit()
        empty.attachRows()
        suite.expect(empty.todos.writes == 0 && empty.todos.items.isEmpty && empty.inputFocused == .new
                     && empty.scrollMode == .bottom,
                     "blank or Return on an empty bottom draft creates no task")
        suite.expect(NotchTodoFocusTarget.blankHeight(viewport: 240, rows: 42) == 198
                     && NotchTodoFocusTarget.blankHeight(viewport: 100, rows: 60) == 40
                     && NotchTodoFocusTarget.blankHeight(viewport: 100, rows: 900) == 40,
                     "blank hit target fills unused list height and remains reachable after small/long lists")

        let editor = Editor()
        editor.service.todoInput.newTitle = "new draft"
        editor.beginAdd()
        suite.expect(editor.todos.writes == 0 && editor.service.todoInput.newTitle == "new draft",
                     "single-clicking blank space only focuses a bottom draft and never persists a placeholder")
        editor.todos.failsSave = true
        editor.submit()
        suite.expect(editor.service.todoInput.newTitle == "new draft" && editor.todos.items.isEmpty,
                     "failed inline add keeps the draft and never manufactures a task")
        editor.todos.failsSave = false
        editor.submit()
        suite.expect(editor.service.todoInput.newTitle.isEmpty && editor.todos.items.count == 1,
                     "successful inline add clears only the persisted new-task draft")
        guard let item = editor.todos.items.first else { return }
        let stable = Editor()
        let other = TodoItem(title: "another row")
        stable.todos.items = [item, other]
        stable.beginEdit(item)
        stable.attachRows()
        suite.expect(stable.inputFocused == .item(item.id) && stable.scrollSerial == 0,
                     "double-click editing a visible existing row does not scroll it to the bottom")
        stable.service.todoInput.editingTitle = "composing A"
        let previousOrphan = stable.orphanedEditingID
        stable.todos.items[1].title = "B changed height elsewhere"
        stable.editingRowLocationChanged(from: previousOrphan)
        stable.rowsHeightChanged()
        suite.expect(stable.inputFocused == .item(item.id) && stable.queuedFocus.isEmpty
                     && stable.scrollSerial == 0 && stable.service.todoInput.editingTitle == "composing A",
                     "B updates during A editing neither nil the focused row nor enqueue focus/scroll, preserving IME")
        stable.requestFocus()
        stable.attachRows()
        suite.expect(stable.inputFocused == .item(item.id) && stable.scrollMode == .visible && stable.scrollSerial == 1,
                     "reopening a normal UUID editor requests minimum visibility, not bottom alignment")
        stable.beginAdd()
        stable.attachRows()
        let newScroll = stable.scrollSerial
        stable.rowsHeightChanged()
        suite.expect(stable.inputFocused == .new && stable.scrollMode == .bottom && stable.scrollSerial == newScroll + 1,
                     "new bottom drafts still scroll into view after layout changes")

        editor.service.todoInput.newTitle = "separate new draft"
        editor.beginEdit(item)
        editor.service.todoInput.editingTitle = "edited draft"
        editor.beginEdit(item)
        editor.requestFocus()
        editor.attachRows()
        suite.expect(editor.inputFocused == .item(item.id) && editor.scrollSerial > 0
                     && editor.service.todoInput.editingTitle == "edited draft",
                     "reopening and repeated row focus resume the same UUID draft and request scrolling")
        editor.service.panelIsKey = false
        editor.inputFocused = nil
        editor.requestFocus()
        editor.attachRows()
        suite.expect(editor.inputFocused == .item(item.id) && editor.service.todoInput.editingTitle == "edited draft",
                     "a lost key panel is reclaimed so the next todo can still be typed")
        editor.service.canBecomeKey = false
        editor.service.panelIsKey = false
        editor.inputFocused = nil
        editor.requestFocus()
        editor.attachRows()
        suite.expect(editor.inputFocused == nil && editor.service.todoInput.editingTitle == "edited draft",
                     "a panel that cannot take the keyboard keeps the draft for a later focus")
        editor.service.canBecomeKey = true
        editor.service.panelIsKey = true
        editor.todos.failsSave = true
        editor.submit()
        suite.expect(editor.service.todoInput.editingID == item.id
                     && editor.service.todoInput.editingTitle == "edited draft" && editor.todos.items[0].title == item.title,
                     "failed inline edit retains its identity/title and leaves the persisted item unchanged")
        editor.delete(item)
        suite.expect(editor.service.todoInput.editingID == item.id && editor.todos.items.count == 1,
                     "failed delete keeps both the item and its active edit draft")
        editor.todos.failsSave = false
        editor.submit()
        suite.expect(!editor.editing && editor.todos.items[0].title == "edited draft"
                     && editor.service.todoInput.newTitle == "separate new draft",
                     "successful edit exits editing without overwriting the separate new-task draft")
        editor.beginEdit(editor.todos.items[0])
        editor.delete(editor.todos.items[0])
        suite.expect(editor.todos.items.isEmpty && !editor.editing
                     && editor.service.todoInput.newTitle == "separate new draft",
                     "successful delete exits only the deleted row's edit")
        let completed = Editor()
        completed.todos.items = [item]
        completed.service.todoInput.newTitle = "independent new draft"
        completed.beginEdit(item)
        completed.service.todoInput.editingTitle = "pending completion draft"
        completed.todos.failsSave = true
        completed.toggle(item)
        suite.expect(completed.editing && completed.service.todoInput.editingTitle == "pending completion draft",
                     "failed completion retains its row edit")
        completed.todos.failsSave = false
        completed.toggle(item)
        completed.attachRows()
        suite.expect(completed.editing && completed.inputFocused == .item(item.id)
                     && completed.visibleItems.map(\.id) == [item.id]
                     && completed.service.todoInput.editingTitle == "pending completion draft"
                     && completed.service.todoInput.newTitle == "independent new draft",
                     "completion remains in the original row and preserves its active edit and separate new draft")
        let completedItem = completed.todos.items[0]
        completed.todos.failsSave = true
        completed.archive(completedItem)
        suite.expect(completed.editing && !completed.todos.items[0].isArchived
                     && completed.service.todoInput.editingTitle == "pending completion draft",
                     "failed archive keeps the completed row and its unsaved title")
        completed.todos.failsSave = false
        completed.todos.failsArchive = true
        completed.archive(completedItem)
        suite.expect(completed.editing && !completed.todos.items[0].isArchived
                     && completed.service.todoInput.editingTitle == "pending completion draft",
                     "archive failure after a successful title save still preserves the active draft")
        completed.todos.failsArchive = false
        completed.archive(completedItem)
        completed.attachRows()
        suite.expect(!completed.editing && completed.visibleItems.isEmpty
                     && completed.todos.items.count == 1 && completed.todos.items[0].isArchived
                     && completed.todos.items[0].title == "pending completion draft",
                     "archival saves an active edit before hiding the row, without deleting it")
        completed.setArchivedMode(true)
        let writesBeforeArchivedInput = completed.todos.writes
        completed.beginAdd()
        completed.beginEdit(completed.todos.items[0])
        completed.submit()
        completed.delete(completed.todos.items[0])
        completed.toggle(completed.todos.items[0])
        completed.requestFocus()
        completed.attachRows()
        suite.expect(completed.visibleItems.map(\.id) == [item.id]
                     && completed.todos.writes == writesBeforeArchivedInput && completed.inputFocused == nil
                     && completed.service.todoInput.newTitle == "independent new draft",
                     "archived mode shows saved archives but has no new/edit input and preserves the new draft")
        completed.todos.failsSave = true
        completed.restore(completed.todos.items[0])
        suite.expect(completed.visibleItems.count == 1, "failed restore keeps the archived row visible")
        completed.todos.failsSave = false
        completed.restore(completed.todos.items[0])
        suite.expect(completed.visibleItems.isEmpty && completed.todos.items.count == 1,
                     "restore removes only archived membership and never deletes the item")
        completed.setArchivedMode(false)
        completed.attachRows()
        suite.expect(completed.visibleItems.map(\.id) == [item.id] && completed.inputFocused == .new,
                     "returning to all shows restored completed items and resumes the bottom draft")

        let mixed = Editor()
        mixed.todos.items = [item, TodoItem(title: "finished", isCompleted: true), other]
        suite.expect(mixed.visibleItems.map(\.id) == mixed.todos.items.map(\.id),
                     "default island list contains pending and completed together in stable stored order")
        mixed.beginEdit(item)
        mixed.attachRows()
        mixed.service.todoInput.editingTitle = "IME draft survives browsing archives"
        mixed.setArchivedMode(true)
        mixed.attachRows()
        mixed.setArchivedMode(false)
        mixed.attachRows()
        suite.expect(mixed.editing && mixed.inputFocused == .item(item.id)
                     && mixed.service.todoInput.editingTitle == "IME draft survives browsing archives",
                     "archive browsing suspends and resumes an existing editor without dropping its draft")

        let external = Editor()
        external.todos.items = [item]
        external.beginEdit(item)
        external.service.todoInput.editingTitle = "external deletion draft"
        external.attachRows()
        let formerLocation = external.orphanedEditingID
        external.todos.items = []
        external.editingRowLocationChanged(from: formerLocation)
        external.attachRows()
        suite.expect(external.orphanedEditingID == item.id && external.inputFocused == .item(item.id)
                     && external.scrollMode == .bottom && external.service.todoInput.editingTitle == "external deletion draft",
                     "an externally missing row retains a mounted orphan draft rather than an invisible caret or lost title")
        let orphanLocation = external.orphanedEditingID
        external.todos.items = [item]
        external.editingRowLocationChanged(from: orphanLocation)
        external.attachRows()
        suite.expect(external.orphanedEditingID == nil && external.inputFocused == .item(item.id)
                     && external.scrollMode == .visible && external.service.todoInput.editingTitle == "external deletion draft",
                     "an orphan returning to its normal row recovers minimum visibility and retains its draft")
        external.service.todoInput.newTitle = "cancel keeps new draft"
        external.beginAdd()
        external.attachRows()
        suite.expect(!external.editing && external.inputFocused == .new
                     && external.service.todoInput.newTitle == "cancel keeps new draft" && external.todos.writes == 0,
                     "explicit cancel returns to new input without writing or overwriting the separate draft")

        let detached = Editor()
        detached.requestFocus()
        detached.service.expanded = false
        detached.attachRows()
        suite.expect(detached.inputFocused == nil && detached.scrollSerial == 0,
                     "a queued focus request cannot revive a collapsed page")

        for blocked in 0..<2 {
            let editor = Editor()
            editor.preview = blocked == 0
            editor.todos.loadFailed = blocked == 1
            editor.service.todoInput.newTitle = "keep me"
            editor.beginEdit(item)
            editor.beginAdd()
            editor.submit()
            editor.delete(item)
            editor.toggle(item)
            editor.requestFocus()
            editor.attachRows()
            suite.expect(editor.todos.writes == 0 && !editor.editing && editor.inputFocused == nil
                         && editor.service.todoInput.newTitle == "keep me",
                         "preview/load failure rejects inline mutations and keeps drafts (\(blocked))")
        }
    }
}
