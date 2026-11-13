// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Combine
import Carbon.HIToolbox

enum TodoFeatureTests {
    static func runArchiveModels(_ suite: TestSuite) {
        let manager = FileManager.default
        let day: TimeInterval = 86_400
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        func fixture(_ check: (URL) throws -> Void) {
            let directory = manager.temporaryDirectory.appendingPathComponent("todo-archive-tests-" + UUID().uuidString)
            defer { try? manager.removeItem(at: directory) }
            do {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                try check(directory)
            } catch { suite.expect(false, "todo archive fixture completes: \(error)") }
        }

        fixture { directory in
            var now = start
            let model = TodoModel(directoryURL: directory, now: { now })
            model.load()
            suite.expect(model.add("First") && model.add("Second"), "todo creates ordered archive fixture")
            let first = model.items[0].id
            let second = model.items[1].id
            suite.expect(model.items.map(\.title) == ["First", "Second"], "todo new tasks append at the bottom")
            suite.expect(!model.archive(id: first) && !model.restore(id: first), "todo pending tasks cannot be archived or restored")
            suite.expect(model.toggle(id: first) && model.items[0].completedAt == start, "todo completion records the injected time")
            suite.expect(TodoFilter.all.includes(model.items[0]) && TodoFilter.all.includes(model.items[1]),
                         "todo all shows both completed and pending tasks")
            suite.expect(!model.applyAutoArchive(days: 1, now: start.addingTimeInterval(day - 0.001)),
                         "todo does not archive before the exact elapsed-day threshold")
            suite.expect(model.nextAutoArchiveDate(days: 1) == start.addingTimeInterval(day), "todo exposes the next exact deadline")
            suite.expect(model.applyAutoArchive(days: 1, now: start.addingTimeInterval(day)), "todo archives at the exact threshold")
            suite.expect(model.items[0].archivedAt == start.addingTimeInterval(day)
                         && !model.items[1].isArchived, "todo auto archive affects only due completed tasks")
            suite.expect(TodoFilter.archived.includes(model.items[0])
                         && [TodoFilter.all, .pending, .completed].allSatisfy { !$0.includes(model.items[0]) },
                         "todo only the archive filter includes archived tasks")
            suite.expect(!model.applyAutoArchive(days: 1, now: start.addingTimeInterval(day * 2)), "todo archiving is idempotent")
            now = start.addingTimeInterval(day * 3)
            suite.expect(model.restore(id: first) && model.items[0].isCompleted && !model.items[0].isArchived
                         && model.items[0].completedAt == now, "todo restore keeps completion and restarts the archive clock")
            suite.expect(!model.applyAutoArchive(days: 1, now: now), "todo restored tasks are not immediately rearchived")
            suite.expect(model.toggle(id: first) && model.items[0].completedAt == nil,
                         "todo uncomplete removes the completion timestamp")
            suite.expect(!model.applyAutoArchive(days: 1, now: now.addingTimeInterval(day * 10)), "todo uncompleted tasks never age into archive")
            suite.expect(model.toggle(id: first) && model.archive(id: first), "todo completed tasks support manual archive")
            suite.expect(!model.archive(id: first), "todo manual archive is not repeated")
            suite.expect(model.toggle(id: first) && !model.items[0].isCompleted && !model.items[0].isArchived
                         && model.items[0].completedAt == nil, "todo uncomplete also restores an archived task")
            suite.expect(!model.archive(id: UUID()) && !model.restore(id: UUID()), "todo unknown archive IDs do not mutate")
            suite.expect(model.toggle(id: second), "todo prepares no-expiry task")
            let snapshot = model.items
            suite.expect(!model.applyAutoArchive(days: 0, now: now.addingTimeInterval(day * 100_000))
                         && !model.applyAutoArchive(days: -1, now: now)
                         && !model.applyAutoArchive(days: 3651, now: now) && model.items == snapshot,
                         "todo zero means no expiry and out-of-range policies never archive")
            suite.expect(model.nextAutoArchiveDate(days: 0) == nil, "todo disabled policy has no timer deadline")
            suite.expect(!model.applyAutoArchive(days: 1, now: start.addingTimeInterval(-day)),
                         "todo backward clock changes never archive future completions")
            suite.expect(!model.applyAutoArchive(days: 3650, now: now.addingTimeInterval(day * 3650 - 0.001))
                         && model.applyAutoArchive(days: 3650, now: now.addingTimeInterval(day * 3650)),
                         "todo maximum supported policy respects the same exact threshold")
            let restarted = TodoModel(directoryURL: directory)
            restarted.load()
            suite.expect(restarted.items == model.items, "todo completion archive timestamps and order survive restart")
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory, now: { start })
            model.load()
            for index in 0..<8 { suite.expect(model.add("Task \(index)"), "todo palette fixture saves") }
            let initial = model.items
            suite.expect(Array(initial.prefix(6)).map(\.color) == TodoColor.allCases,
                         "todo new tasks cycle through all six fixed palette colors")
            suite.expect(zip(initial, initial.dropFirst()).allSatisfy { $0.color != $1.color },
                         "todo adjacent new tasks always have different colors")
            let restarted = TodoModel(directoryURL: directory, now: { start })
            restarted.load()
            suite.expect(restarted.items == initial, "todo palette colors remain stable across restart")
            let deletedColor = restarted.items.last!.color
            suite.expect(restarted.delete(id: restarted.items.last!.id) && restarted.add("After restart"), "todo palette continues after deletion")
            suite.expect(restarted.items.last!.color != deletedColor && restarted.items.last!.color == .green,
                         "todo persisted palette cursor survives restart and deletion")
            suite.expect(restarted.update(id: initial[0].id, title: "Renamed") && restarted.toggle(id: initial[0].id)
                         && restarted.archive(id: initial[0].id) && restarted.restore(id: initial[0].id)
                         && restarted.items[0].color == initial[0].color, "todo edits completion and archive preserve assigned colors")
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory)
            model.load()
            for index in 0..<6 { suite.expect(model.add("Tail \(index)"), "todo deleted-tail palette fixture saves") }
            for item in model.items.dropFirst() { suite.expect(model.delete(id: item.id), "todo palette fixture deletes tail") }
            suite.expect(model.add("After removed tail") && model.items[0].color != model.items[1].color,
                         "todo palette skips an exposed tail color after deletions")
        }

        fixture { directory in
            let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            let legacy = try JSONSerialization.data(withJSONObject: ["version": 1, "items": [
                ["id": id.uuidString, "title": "Legacy completed", "isCompleted": true]
            ]])
            let url = directory.appendingPathComponent("todos.json")
            try legacy.write(to: url)
            let firstDecode = try JSONDecoder().decode(TodoStore.Document.self, from: legacy)
            let secondDecode = try JSONDecoder().decode(TodoStore.Document.self, from: legacy)
            suite.expect(firstDecode.items == secondDecode.items && firstDecode.items[0].color == .green
                         && firstDecode.items[0].completedAt == nil,
                         "todo old version-one items decode with deterministic colors and no invented age")
            let model = TodoModel(directoryURL: directory, now: { start })
            model.load()
            suite.expect(!model.loadFailed && !model.saveFailed && model.items[0].id == id
                         && model.items[0].completedAt == start && !model.items[0].isArchived,
                         "todo legacy completion starts aging at this load only after successful migration")
            let saved = try JSONDecoder().decode(TodoStore.Document.self, from: Data(contentsOf: url))
            suite.expect(saved.items == model.items && saved.nextColorIndex != nil, "todo migration persists dates colors and palette cursor")
            let restarted = TodoModel(directoryURL: directory, now: { start.addingTimeInterval(day * 10) })
            restarted.load()
            suite.expect(restarted.items == model.items, "todo migration never resets an already-persisted completion date")
            suite.expect(!model.applyAutoArchive(days: 1, now: start), "todo migration does not immediately hide legacy completed tasks")
        }

        fixture { directory in
            let url = directory.appendingPathComponent("todos.json")
            let old = TodoItem(title: "Legacy write failure", isCompleted: true)
            let bytes = try JSONEncoder().encode(TodoStore.Document(items: [old]))
            try bytes.write(to: url)
            try manager.setAttributes([.immutable: true], ofItemAtPath: url.path)
            defer { try? manager.setAttributes([.immutable: false], ofItemAtPath: url.path) }
            let model = TodoModel(directoryURL: directory, now: { start })
            model.load()
            suite.expect(!model.loadFailed && model.saveFailed && model.items == [old],
                         "todo migration write failure retains readable tasks without publishing timestamps")
            suite.expect(try Data(contentsOf: url) == bytes, "todo failed migration preserves original document bytes")
            suite.expect(!model.applyAutoArchive(days: 1, now: start.addingTimeInterval(day * 100))
                         && !model.items[0].isArchived, "todo failed migration cannot immediately auto-hide tasks")
            try manager.setAttributes([.immutable: false], ofItemAtPath: url.path)
            suite.expect(model.update(id: old.id, title: "Recovered") && model.items[0].completedAt == start,
                         "todo next successful mutation safely persists deferred migration")
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory, now: { start })
            model.load()
            suite.expect(model.add("Keep") && model.toggle(id: model.items[0].id), "todo archive write failure fixture is saved")
            let saved = model.items
            let url = directory.appendingPathComponent("todos.json")
            try manager.removeItem(at: url)
            try manager.createDirectory(at: url, withIntermediateDirectories: false)
            var publishes = 0
            let observation = model.$items.sink { _ in publishes += 1 }
            suite.expect(!model.applyAutoArchive(days: 1, now: start.addingTimeInterval(day)) && model.saveFailed,
                         "todo automatic archive reports disk failure")
            suite.expect(!model.archive(id: saved[0].id) && !model.toggle(id: saved[0].id)
                         && !model.add("Not saved") && model.items == saved && publishes == 1,
                         "todo failed writes never publish archive completion or new tasks")
            observation.cancel()
            try manager.removeItem(at: url)
            suite.expect(model.archive(id: saved[0].id), "todo manual archive recovers after write repair")
            let archived = model.items
            try manager.removeItem(at: url)
            try manager.createDirectory(at: url, withIntermediateDirectories: false)
            suite.expect(!model.restore(id: saved[0].id) && model.items == archived, "todo failed restore retains the saved archive")
            try manager.removeItem(at: url)
            suite.expect(model.restore(id: saved[0].id) && model.add("Retry"), "todo restore and add recover after write repair")
            suite.expect(model.items.last!.color == .teal, "todo failed additions do not consume the palette cursor")
        }
    }

    static func run(_ suite: TestSuite) {
        runArchiveModels(suite)
        let manager = FileManager.default
        func fixture(_ check: (URL) throws -> Void) {
            let directory = manager.temporaryDirectory.appendingPathComponent("todo-tests-" + UUID().uuidString)
            defer { try? manager.removeItem(at: directory) }
            do {
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                try check(directory)
            } catch { suite.expect(false, "todo fixture completes: \(error)") }
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory)
            suite.expect(!model.add("Before load"), "todo mutations require a successful initial read")
            model.load()
            suite.expect(model.items.isEmpty && !model.loadFailed, "todo missing file starts empty")
            suite.expect(!model.add("  \n "), "todo rejects blank titles")
            suite.expect(model.add("  First task  "), "todo creates tasks")
            let id = model.items[0].id
            suite.expect(model.items[0].title == "First task", "todo normalizes titles")
            suite.expect(!model.update(id: id, title: " "), "todo rejects blank edits")
            suite.expect(model.update(id: id, title: "  Edited task\n"), "todo edits a task")
            suite.expect(model.items[0].id == id && model.items[0].title == "Edited task",
                         "todo edits preserve identity")
            suite.expect(model.toggle(id: id) && model.items[0].isCompleted, "todo completes tasks")
            suite.expect(TodoFilter.completed.includes(model.items[0]) && !TodoFilter.pending.includes(model.items[0]),
                         "todo completed filter excludes pending")
            let restarted = TodoModel(directoryURL: directory)
            restarted.load()
            suite.expect(restarted.items == model.items, "todo edited title and completion survive a new model")
            suite.expect(restarted.toggle(id: id) && !restarted.items[0].isCompleted, "todo reopens completed tasks")
            suite.expect(TodoFilter.all.includes(restarted.items[0]) && TodoFilter.pending.includes(restarted.items[0])
                         && !TodoFilter.completed.includes(restarted.items[0]), "todo all and pending filters")
            suite.expect(!restarted.update(id: UUID(), title: "Missing") && !restarted.toggle(id: UUID())
                         && !restarted.delete(id: UUID()), "todo unknown task IDs do not mutate")
            let url = directory.appendingPathComponent("todos.json")
            let permissions = try manager.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
            suite.expect(permissions?.intValue == 0o600, "todo content is owner-only")
            suite.expect(restarted.delete(id: id) && restarted.items.isEmpty, "todo deletes tasks")
            var store = TodoStore(directoryURL: directory)
            suite.expect(try store.load().isEmpty, "todo deletion survives reopening")
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory)
            model.load()
            suite.expect(model.add("Original"), "todo input fixture starts with a saved item")
            let original = model.items[0]
            var input = TodoInputState()
            input.newTitle = "New draft"
            input.beginEditing(original)
            suite.expect(input.editingID == original.id && input.editingTitle == original.title,
                         "todo edit starts with the selected title and identity")
            input.editingTitle = "Uncommitted edit"
            input.beginAdding()
            suite.expect(input.editingID == nil && input.editingTitle.isEmpty && input.newTitle == "New draft",
                         "todo blank-area input cancels editing without losing the new-task draft")
            suite.expect(model.items == [original], "todo entering input never creates a placeholder or saves a cancelled edit")
            input.beginEditing(original)
            input.editingTitle = " "
            suite.expect(!input.saveEdit(using: model.update) && input.editingID == original.id && input.editingTitle == " ",
                         "todo rejected edits keep the editor and entered text")
            input.editingTitle = "Renamed"
            suite.expect(input.saveEdit(using: model.update) && input.editingID == nil
                         && model.items[0].title == "Renamed" && input.newTitle == "New draft",
                         "todo submit saves the selected item and leaves the new-task draft intact")
            suite.expect(input.add(using: model.add) && input.newTitle.isEmpty && model.items.count == 2,
                         "todo new input creates one task only on successful submit")
            input.newTitle = "  "
            suite.expect(!input.add(using: model.add) && input.newTitle == "  " && model.items.count == 2,
                         "todo blank submit does not insert or clear the draft")
        }

        let duplicateID = UUID()
        let invalidDocuments = [
            Data("{broken".utf8), Data(),
            try! JSONEncoder().encode(TodoStore.Document(version: 2, items: [])),
            try! JSONEncoder().encode(TodoStore.Document(items: [TodoItem(title: " ")])),
            try! JSONEncoder().encode(TodoStore.Document(items: [TodoItem(id: duplicateID, title: "a"),
                                                               TodoItem(id: duplicateID, title: "b")]))
        ]
        for damaged in invalidDocuments {
            fixture { directory in
                let url = directory.appendingPathComponent("todos.json")
                try damaged.write(to: url)
                let model = TodoModel(directoryURL: directory)
                model.load()
                suite.expect(model.loadFailed && !model.add("Do not overwrite"), "todo failed reads block mutations")
                suite.expect(try Data(contentsOf: url) == damaged, "todo failed reads preserve original bytes")
                try JSONEncoder().encode(TodoStore.Document(items: [])).write(to: url)
                model.load()
                suite.expect(!model.loadFailed && model.add("Recovered"), "todo explicit retry recovers after repair")
            }
        }

        fixture { directory in
            let model = TodoModel(directoryURL: directory)
            model.load()
            suite.expect(model.add("Saved task"), "todo write failure fixture starts saved")
            let saved = model.items
            let url = directory.appendingPathComponent("todos.json")
            // A directory in the destination prevents an atomic file replacement deterministically.
            try manager.removeItem(at: url)
            try manager.createDirectory(at: url, withIntermediateDirectories: false)
            var input = TodoInputState()
            input.beginEditing(saved[0])
            input.editingTitle = "Unsaved"
            suite.expect(!input.saveEdit(using: model.update) && model.saveFailed
                         && input.editingID == saved[0].id && input.editingTitle == "Unsaved",
                         "todo failed writes retain the editor and draft for retry")
            suite.expect(model.items == saved && !model.delete(id: saved[0].id),
                         "todo failed writes retain the previously published tasks")
        }

        let keys = SettingsBackupSupport.exportKeys()
        suite.expect(keys.contains(DefaultsKey.todoFilter) && keys.contains(DefaultsKey.todoAutoArchiveDays)
                     && keys.contains(DefaultsKey.panelUtilityTodo)
                     && keys.contains(AppFeature.todo.availabilityKey), "todo preferences participate in settings backups")
        suite.expect(!keys.contains("todos.json") && !keys.contains("todoItems"), "todo content is not settings backup data")
        suite.expect(AppFeature.todo.group == .tools && AppFeature.todo.permissions.isEmpty
                     && AppFeature.todo.enabledKeys.isEmpty, "todo is an on-demand tool without permissions")
        suite.expect(AppFeature.todo.settingsDestination == FeatureSettingsDestination(.quickTools, sectionAnchor: .todo),
                     "todo feature hub opens its quick tools section")

        let role = GlobalShortcutRole.todo
        suite.expect(role.storageKey == DefaultsKey.todoShortcut
                     && role.defaultShortcut == .todoDefault
                     && role.requiredEnableKeys == [DefaultsKey.todoShortcutEnabled]
                     && role.feature == .todo,
                     "todo global shortcut role follows the feature and its own toggle")
        suite.expect(role.defaultShortcut.keyCode == Int64(kVK_ANSI_Y)
                     && role.defaultShortcut.modifiers == [.control, .option, .command]
                     && !GlobalShortcutRole.allCases.contains { $0 != .todo && $0.defaultShortcut == .todoDefault },
                     "todo default shortcut is unique on the control-option-command layer")
        suite.expect(!GlobalShortcutRole.activeRoles(isOn: { $0 == DefaultsKey.panelUtilityTodo },
                                                 isAvailable: { _ in true }).contains(role),
                     "todo shortcut stays off until its own toggle is on")
        suite.expect(GlobalShortcutRole.activeRoles(isOn: { $0 == DefaultsKey.todoShortcutEnabled },
                                                isAvailable: { _ in true }).contains(role),
                     "todo shortcut works even when its menu-panel entry is hidden")
        suite.expect(!GlobalShortcutRole.activeRoles(isOn: { _ in true },
                                                    isAvailable: { $0 != .todo }).contains(role),
                     "uninstalled todo never holds a global shortcut")
        suite.expect(GlobalShortcutRole.featuresToSilenceWhileRecording.contains(.todo),
                     "todo participates in shortcut recording suspension and restoration")
        suite.expect(keys.contains(DefaultsKey.todoShortcut) && keys.contains(DefaultsKey.todoShortcutEnabled),
                     "todo shortcut preferences travel in settings backups")
    }
}
