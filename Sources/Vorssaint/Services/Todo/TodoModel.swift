// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Combine

/// Draft-only interaction state. Beginning input never writes a placeholder task.
struct TodoInputState {
    var newTitle = ""
    private(set) var editingID: UUID?
    var editingTitle = ""

    mutating func beginEditing(_ item: TodoItem) {
        editingID = item.id
        editingTitle = item.title
    }

    mutating func beginAdding() {
        editingID = nil
        editingTitle = ""
    }

    mutating func add(using save: (String) -> Bool) -> Bool {
        guard save(newTitle) else { return false }
        newTitle = ""
        return true
    }

    mutating func saveEdit(using save: (UUID, String) -> Bool) -> Bool {
        guard let id = editingID, save(id, editingTitle) else { return false }
        beginAdding()
        return true
    }
}

/// Persistence-backed task mutations shared by the native service and tests.
class TodoModel: ObservableObject {
    @Published private(set) var items: [TodoItem] = []
    @Published private(set) var loadFailed = false
    @Published private(set) var saveFailed = false
    private var store: TodoStore
    private var hasLoaded = false
    private var clock: () -> Date = Date.init
    private var migrationStartedAt: Date?

    /// A second initializer keeps the service's existing override source-compatible.
    convenience init(directoryURL: URL?, now: @escaping () -> Date) {
        self.init(directoryURL: directoryURL)
        clock = now
    }

    /// Service lifecycle hook, intentionally independent of UI and preferences.
    func didChangeItems() {}

    init(directoryURL: URL? = PrivateFileStore.containerURL) {
        store = TodoStore(directoryURL: directoryURL)
    }

    func load() {
        guard !hasLoaded || loadFailed else { return }
        do {
            let loaded = try store.load()
            hasLoaded = true
            loadFailed = false
            migrationStartedAt = clock()
            if store.needsMigration {
                // Keep the readable legacy tasks if migration cannot be saved. In
                // particular, never publish a made-up completion age on failure.
                let migrated = fillingMissingCompletionDates(loaded)
                do {
                    try store.save(migrated)
                    items = migrated
                    saveFailed = false
                } catch {
                    items = loaded
                    saveFailed = true
                }
            } else {
                items = loaded
                saveFailed = false
            }
        } catch { loadFailed = true }
    }

    @discardableResult
    func add(_ title: String) -> Bool {
        let title = TodoStore.normalizedTitle(title)
        guard !title.isEmpty else { return false }
        var index = store.nextColorIndex
        // Deleting a tail can expose this cursor's color again.
        if items.last?.color == TodoColor.allCases[index] {
            index = (index + 1) % TodoColor.allCases.count
        }
        return commit(items + [TodoItem(title: title, color: TodoColor.allCases[index])],
                      nextColorIndex: (index + 1) % TodoColor.allCases.count)
    }

    @discardableResult
    func update(id: UUID, title: String) -> Bool {
        let title = TodoStore.normalizedTitle(title)
        guard !title.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return false }
        var next = items
        next[index].title = title
        return commit(next)
    }

    @discardableResult
    func toggle(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return false }
        var next = items
        next[index].isCompleted.toggle()
        next[index].completedAt = next[index].isCompleted ? clock() : nil
        next[index].archivedAt = nil
        return commit(next)
    }

    @discardableResult
    func delete(id: UUID) -> Bool {
        guard items.contains(where: { $0.id == id }) else { return false }
        return commit(items.filter { $0.id != id })
    }

    @discardableResult
    func archive(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }),
              items[index].isCompleted, !items[index].isArchived else { return false }
        var next = items
        next[index].archivedAt = clock()
        return commit(next)
    }

    @discardableResult
    func restore(id: UUID) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].isArchived else { return false }
        var next = items
        next[index].archivedAt = nil
        next[index].completedAt = clock()
        return commit(next)
    }

    /// Days are elapsed 24-hour periods, not local calendar midnights.
    @discardableResult
    func applyAutoArchive(days: Int, now: Date = Date()) -> Bool {
        guard (1...3650).contains(days) else { return false }
        let interval = TimeInterval(days) * 86_400
        var next = items
        for index in next.indices {
            if next[index].isCompleted, !next[index].isArchived,
               let completedAt = next[index].completedAt,
               completedAt.addingTimeInterval(interval) <= now {
                next[index].archivedAt = now
            }
        }
        guard next != items else { return false }
        return commit(next)
    }

    func nextAutoArchiveDate(days: Int) -> Date? {
        guard (1...3650).contains(days) else { return nil }
        return items.compactMap { item -> Date? in
            guard item.isCompleted, !item.isArchived, let completedAt = item.completedAt else { return nil }
            return completedAt.addingTimeInterval(TimeInterval(days) * 86_400)
        }.min()
    }

    private func fillingMissingCompletionDates(_ source: [TodoItem]) -> [TodoItem] {
        source.map { item in
            var item = item
            if item.isCompleted && item.completedAt == nil {
                item.completedAt = migrationStartedAt ?? clock()
            }
            return item
        }
    }

    private func commit(_ next: [TodoItem], nextColorIndex: Int? = nil) -> Bool {
        guard hasLoaded, !loadFailed else { return false }
        let next = fillingMissingCompletionDates(next)
        do {
            try store.save(next, nextColorIndex: nextColorIndex)
            items = next
            saveFailed = false
            didChangeItems()
            return true
        } catch {
            saveFailed = true
            return false
        }
    }

}
