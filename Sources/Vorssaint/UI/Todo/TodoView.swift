// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

extension TodoColor {
    var tint: Color {
        switch self {
        case .blue: return .blue
        case .teal: return .teal
        case .green: return .green
        case .orange: return .orange
        case .pink: return .pink
        case .purple: return .purple
        }
    }
}

struct TodoView: View {
    @ObservedObject var service: TodoService
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.todoFilter) private var storedFilter = TodoFilter.all.rawValue
    @FocusState private var inputFocused: Bool
    @FocusState private var editingFocused: UUID?
    @State private var input = TodoInputState()
    private var editingID: UUID? {
        input.editingID
    }
    @State private var rowsHeight: CGFloat = 0

    private var text: TodoStrings { TodoStrings.current }
    private var filter: TodoFilter {
        TodoFilter(rawValue: storedFilter) ?? .all
    }
    private var visibleItems: [TodoItem] {
        service.items.filter { filter.includes($0) }
    }
    private var orphanedEditingID: UUID? {
        guard filter != .archived, let id = editingID,
              !visibleItems.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    var body: some View {
        VStack(spacing: 12) {
            if filter != .archived {
                HStack {
                    TextField(text.newItem, text: $input.newTitle)
                        .focused($inputFocused)
                        .onSubmit(add)
                    Button(text.add, action: add)
                        .disabled(TodoStore.normalizedTitle(input.newTitle).isEmpty || service.loadFailed)
                }
                .disabled(service.loadFailed)
            }
            Picker(text.filter, selection: $storedFilter) {
                Text(text.all).tag(TodoFilter.all.rawValue)
                Text(text.pending).tag(TodoFilter.pending.rawValue)
                Text(text.completed).tag(TodoFilter.completed.rawValue)
                Text(text.archived).tag(TodoFilter.archived.rawValue)
            }.pickerStyle(.segmented)
            if service.loadFailed {
                Text(text.loadFailed).foregroundStyle(.red)
                Button(text.retry) { service.load() }
            } else {
                if service.saveFailed { Text(text.saveFailed).foregroundStyle(.red) }
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            VStack(spacing: 0) {
                                ForEach(visibleItems) { item in
                                    row(item)
                                }
                                if let id = orphanedEditingID {
                                    // External archival/deletion must not hide an unsaved title.
                                    editFields(id).padding(.vertical, 8)
                                }
                            }
                            .background {
                                GeometryReader { rows in
                                    Color.clear.preference(key: TodoRowsHeightKey.self, value: rows.size.height)
                                }
                            }
                            // A separate target avoids interpreting row/button double-clicks
                            // as an insert, and remains reachable after a long list.
                            ZStack {
                                Color.clear
                                if visibleItems.isEmpty && orphanedEditingID == nil {
                                    Text(text.empty).foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: max(64, geometry.size.height - rowsHeight))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2, perform: beginAdd)
                            .allowsHitTesting(filter != .archived)
                            .accessibilityHidden(filter == .archived)
                            .accessibilityLabel(text.newItem)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { beginAdd() }
                        }
                    }
                    .onPreferenceChange(TodoRowsHeightKey.self) { rowsHeight = $0 }
                }
            }
        }
        .padding(16)
        .onChange(of: orphanedEditingID) { previous, _ in editingRowLocationChanged(from: previous) }
        .onChange(of: storedFilter) { _, _ in
            inputFocused = false
            editingFocused = nil
        }
        .task(id: service.inputFocusRequest) {
            inputFocused = false
            editingFocused = nil
            // A retained editor must resume its draft, not submit an old new-task draft.
            // Wait for the hosting view to attach to the now-key window.
            await Task.yield()
            guard !Task.isCancelled, !service.loadFailed, filter != .archived else { return }
            if let id = editingID { editingFocused = id } else { inputFocused = true }
        }
        .task(id: editingID) {
            guard let id = editingID, filter != .archived else { return }
            // Focus after SwiftUI has replaced the title with its editor.
            await Task.yield()
            guard !Task.isCancelled, editingID == id else { return }
            inputFocused = false
            editingFocused = id
        }
        .onExitCommand {
            if editingID != nil { cancelEdit() } else { service.close() }
        }
    }

    private func row(_ item: TodoItem) -> some View {
        HStack {
            Button { service.toggle(id: item.id) } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.color.tint)
            }
            .buttonStyle(.plain)
            .disabled(item.isArchived)
            .accessibilityLabel(item.isCompleted ? text.markPending : text.markCompleted)
            if !item.isArchived && editingID == item.id {
                editFields(item.id)
            } else {
                Text(item.title)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { beginEdit(item) }
                if !item.isArchived { Button(text.edit) { beginEdit(item) } }
            }
            if item.isArchived {
                Button(text.restore) { service.restore(id: item.id) }
            } else {
                if item.isCompleted {
                    Button { archive(item) } label: { Image(systemName: "archivebox") }
                        .accessibilityLabel(text.archive)
                }
                Button(role: .destructive) {
                    if service.delete(id: item.id), editingID == item.id { cancelEdit() }
                } label: {
                    Image(systemName: "trash")
                }.accessibilityLabel(text.delete)
            }
        }
        .padding(.vertical, 8)
    }

    private func editFields(_ id: UUID) -> some View {
        HStack {
            TextField(text.newItem, text: $input.editingTitle)
                .focused($editingFocused, equals: id)
                .onSubmit { saveEdit(id) }
            Button(text.save) { saveEdit(id) }
                .disabled(TodoStore.normalizedTitle(input.editingTitle).isEmpty)
            Button(text.cancel, action: cancelEdit)
        }
    }

    private func editingRowLocationChanged(from previous: UUID?) {
        guard previous != orphanedEditingID, editingID != nil,
              filter != .archived, !service.loadFailed else { return }
        // Only the editor moving between row and fallback warrants refocusing.
        DispatchQueue.main.async {
            guard let id = editingID, filter != .archived, !service.loadFailed else { return }
            editingFocused = id
        }
    }

    private func beginAdd() {
        guard !service.loadFailed, filter != .archived else { return }
        // Only enter input mode; never persist an empty task on a double-click.
        // Keep any existing new-task draft.
        cancelEdit()
    }

    private func add() {
        guard filter != .archived else { return }
        if input.add(using: service.add) {
            // A newly added pending task must not disappear behind Completed.
            if filter == .completed { storedFilter = TodoFilter.pending.rawValue }
            inputFocused = true
        }
    }

    private func beginEdit(_ item: TodoItem) {
        guard !service.loadFailed, !item.isArchived, filter != .archived,
              editingID != item.id else { return }
        inputFocused = false
        input.beginEditing(item)
    }

    private func cancelEdit() {
        editingFocused = nil
        input.beginAdding()
        inputFocused = true
    }

    private func archive(_ item: TodoItem) {
        guard !service.loadFailed, !item.isArchived, item.isCompleted else { return }
        if editingID == item.id, !service.update(id: item.id, title: input.editingTitle) { return }
        if service.archive(id: item.id), editingID == item.id { cancelEdit() }
    }

    private func saveEdit(_ id: UUID) {
        // Keep the editor and draft intact if persistence fails.
        guard editingID == id else { return }
        if input.saveEdit(using: service.update) { cancelEdit() }
    }
}

private struct TodoRowsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
