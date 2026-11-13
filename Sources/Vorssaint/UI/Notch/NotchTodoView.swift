// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A row identity is also the scroll identity: new input must never steal an edit's caret.
enum NotchTodoFocusTarget: Hashable {
    case item(UUID)
    case new

    static func current(_ input: TodoInputState) -> Self {
        input.editingID.map(Self.item) ?? .new
    }

    static func blankHeight(viewport: CGFloat, rows: CGFloat) -> CGFloat {
        max(40, viewport - rows)
    }
}

enum NotchTodoScrollMode {
    case none, visible, bottom

    func resolved(for target: NotchTodoFocusTarget, orphan: UUID?) -> Self {
        guard self != .none else { return .none }
        return target == .new || orphan != nil ? .bottom : self
    }
}

private struct NotchTodoRowsHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Drafts live with the island service, never in a transient row or view.
struct NotchTodoView: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    @ObservedObject private var todos = TodoService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var preview
    @FocusState private var inputFocused: NotchTodoFocusTarget?
    @State private var rowsHeight: CGFloat = 0
    @State private var scrollSerial = 0
    @State private var scrollMode = NotchTodoScrollMode.none
    @State private var showingArchived = false

    private var text: TodoStrings { FeatureStrings.todo(l10n.language) }
    private var visibleItems: [TodoItem] {
        todos.items.filter { (showingArchived ? TodoFilter.archived : .all).includes($0) }
    }
    private var editing: Bool { service.todoInput.editingID != nil }
    private var focusTarget: NotchTodoFocusTarget {
        .current(service.todoInput)
    }
    private var orphanedEditingID: UUID? {
        guard let id = service.todoInput.editingID,
              !visibleItems.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(showingArchived ? text.archived : text.all, systemImage: "checklist")
                Text(visibleItems.count.formatted()).monospacedDigit().foregroundStyle(.secondary)
                Spacer()
                Button { setArchivedMode(!showingArchived) } label: {
                    Image(systemName: showingArchived ? "list.bullet" : "archivebox")
                }
                .help(showingArchived ? text.all : text.archived)
                .accessibilityLabel(showingArchived ? text.all : text.archived)
                .accessibilityIdentifier("notch.todo.archiveFilter")
                .disabled(preview)
                Button(action: service.openTodoPanel) { Image(systemName: "arrow.up.right.square") }
                    .help(text.open).accessibilityLabel(text.open).disabled(preview)
            }
            .font(.system(size: 12, weight: .medium))
            if todos.saveFailed {
                Text(text.saveFailed).font(.system(size: 11)).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("notch.todo.saveFailed")
            }
            if todos.loadFailed {
                NotchEmptyView(symbol: "exclamationmark.triangle", message: text.loadFailed)
                Button(text.retry) { todos.load(); requestFocus() }.disabled(preview)
            } else {
                GeometryReader { viewport in
                    ScrollViewReader { scroll in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                // Eager rows ensure a restored offscreen editor is mounted before focus.
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(visibleItems) { item in row(item).id(NotchTodoFocusTarget.item(item.id)) }
                                    if !showingArchived {
                                        if let id = service.todoInput.editingID {
                                            // External archival/deletion must not silently discard a draft.
                                            if orphanedEditingID == id {
                                                editor(.item(id)).id(NotchTodoFocusTarget.item(id))
                                            }
                                        } else {
                                            editor(.new).id(NotchTodoFocusTarget.new)
                                        }
                                    }
                                }
                                .background {
                                    GeometryReader { rows in
                                        Color.clear.preference(key: NotchTodoRowsHeightKey.self, value: rows.size.height)
                                    }
                                }
                                // Separate from every row/control, fills short lists and remains
                                // reachable beyond long lists. A single click only opens a draft.
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .frame(height: NotchTodoFocusTarget.blankHeight(viewport: viewport.size.height, rows: rowsHeight))
                                    .contentShape(Rectangle())
                                    .onTapGesture(perform: beginAdd)
                                    .allowsHitTesting(!showingArchived)
                                    .accessibilityHidden(showingArchived)
                                    .accessibilityLabel(text.newItem)
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityAction { beginAdd() }
                                    .accessibilityIdentifier("notch.todo.blank")
                            }
                        }
                        .onPreferenceChange(NotchTodoRowsHeightKey.self) { rowsHeight = $0 }
                        .onChange(of: scrollSerial) { _, _ in
                            scroll.scrollTo(focusTarget, anchor: scrollMode == .bottom ? .bottom : nil)
                        }
                        .onChange(of: rowsHeight) { _, _ in rowsHeightChanged() }
                        .onChange(of: viewport.size.height) { _, _ in
                            if inputFocused != nil {
                                queueScroll(NotchTodoScrollMode.visible.resolved(for: focusTarget, orphan: orphanedEditingID))
                            }
                        }
                    }
                }
                .disabled(preview)
            }
        }
        .buttonStyle(.plain)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .onAppear {
            if !preview && NotchTodoSupport.isEnabled() { todos.load(); requestFocus() }
        }
        .onChange(of: service.todoFocusSerial) { _, _ in requestFocus() }
        .onChange(of: orphanedEditingID) { previous, _ in editingRowLocationChanged(from: previous) }
        .onChange(of: service.panelIsKey) { _, key in
            if key { requestFocus() } else { inputFocused = nil }
        }
        .onDisappear { inputFocused = nil }
        .accessibilityIdentifier("notch.todo.page")
    }

    private func editor(_ target: NotchTodoFocusTarget, item: TodoItem? = nil) -> some View {
        HStack(spacing: 8) {
            if let item {
                Button { toggle(item) } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(item.color.tint).frame(width: 20, height: 20)
                }
                .accessibilityLabel(item.isCompleted ? text.markPending : text.markCompleted).accessibilityValue(item.title)
            } else {
                Image(systemName: "circle").foregroundStyle(.secondary).frame(width: 20, height: 20)
            }
            TextField(target == .new ? text.newItem : text.edit, text: Binding(
                get: { target == .new ? service.todoInput.newTitle : service.todoInput.editingTitle },
                set: { if target == .new { service.todoInput.newTitle = $0 } else { service.todoInput.editingTitle = $0 } }))
                .textFieldStyle(.plain)
                .focused($inputFocused, equals: target)
                .onSubmit(submit)
                .accessibilityIdentifier(target == .new ? "notch.todo.input.new" : "notch.todo.input.edit")
            if target != .new { Button(text.cancel, action: beginAdd) }
            if let item {
                if item.isCompleted {
                    Button { archive(item) } label: { Image(systemName: "archivebox") }
                        .accessibilityLabel(text.archive)
                }
                Button(role: .destructive) { delete(item) } label: { Image(systemName: "trash") }
                    .accessibilityLabel(text.delete)
            }
        }
        .font(.system(size: 12)).padding(9)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .disabled(preview || todos.loadFailed)
    }

    private func row(_ item: TodoItem) -> some View {
        Group {
            if !showingArchived && service.todoInput.editingID == item.id {
                editor(.item(item.id), item: item)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Button { toggle(item) } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.color.tint).frame(width: 20, height: 20)
                    }
                    .disabled(showingArchived)
                    .accessibilityLabel(item.isCompleted ? text.markPending : text.markCompleted).accessibilityValue(item.title)
                    Text(item.title).lineLimit(3).multilineTextAlignment(.leading)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { beginEdit(item) }
                        .accessibilityAction(named: Text(text.edit)) { beginEdit(item) }
                    if showingArchived {
                        Button { restore(item) } label: { Image(systemName: "arrow.uturn.backward") }
                            .accessibilityLabel(text.restore)
                    } else {
                        Button { beginEdit(item) } label: { Image(systemName: "pencil") }
                            .accessibilityLabel(text.edit)
                        if item.isCompleted {
                            Button { archive(item) } label: { Image(systemName: "archivebox") }
                                .accessibilityLabel(text.archive)
                        }
                        Button(role: .destructive) { delete(item) } label: { Image(systemName: "trash") }
                            .accessibilityLabel(text.delete)
                    }
                }
                .font(.system(size: 12)).padding(9)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func submit() {
        guard !preview, !todos.loadFailed, !showingArchived else { return }
        if editing { _ = service.todoInput.saveEdit(using: todos.update) }
        else { _ = service.todoInput.add(using: todos.add) }
        requestFocus()
    }

    private func beginEdit(_ item: TodoItem) {
        guard !preview, !todos.loadFailed, !showingArchived else { return }
        // Repeated focus/open requests on the same row must preserve its unsaved title.
        if service.todoInput.editingID != item.id { service.todoInput.beginEditing(item) }
        requestFocus(scroll: .none)
    }

    private func beginAdd() {
        guard !preview, !todos.loadFailed, !showingArchived else { return }
        service.todoInput.beginAdding()
        requestFocus()
    }

    private func toggle(_ item: TodoItem) {
        guard !preview, !todos.loadFailed else { return }
        guard !showingArchived else { return }
        // Completion stays in this row and must not discard an in-progress edit.
        _ = todos.toggle(id: item.id)
    }

    private func delete(_ item: TodoItem) {
        guard !preview, !todos.loadFailed, !showingArchived else { return }
        if todos.delete(id: item.id), service.todoInput.editingID == item.id { beginAdd() }
    }

    private func archive(_ item: TodoItem) {
        guard !preview, !todos.loadFailed, !showingArchived, item.isCompleted else { return }
        // Persist the active title first; never clear its draft until archival succeeds.
        if service.todoInput.editingID == item.id,
           !todos.update(id: item.id, title: service.todoInput.editingTitle) { return }
        if todos.archive(id: item.id), service.todoInput.editingID == item.id { beginAdd() }
    }

    private func restore(_ item: TodoItem) {
        guard !preview, !todos.loadFailed, showingArchived else { return }
        _ = todos.restore(id: item.id)
    }

    private func setArchivedMode(_ archived: Bool) {
        guard !preview else { return }
        inputFocused = nil
        showingArchived = archived
        // Switching lists suspends, rather than clears, an existing edit/new draft.
        if !archived { requestFocus() }
    }

    private func editingRowLocationChanged(from previous: UUID?) {
        // Unrelated model updates must not resign the field editor or interrupt IME.
        guard let id = service.todoInput.editingID, previous != orphanedEditingID,
              previous == id || orphanedEditingID == id else { return }
        requestFocus()
    }

    private func rowsHeightChanged() {
        // Existing row edits must not jump when another row's title/height changes.
        guard inputFocused == .new else { return }
        queueScroll(.bottom)
    }

    private func queueScroll(_ mode: NotchTodoScrollMode) {
        guard mode != .none else { return }
        scrollMode = mode
        scrollSerial += 1
    }

    private func requestFocus(scroll: NotchTodoScrollMode = .visible) {
        // Recheck after the new row attaches; the async pass reclaims the key
        // panel so shortcut-opened islands can still type.
        guard !preview, !todos.loadFailed, !showingArchived else { return }
        inputFocused = nil
        DispatchQueue.main.async {
            // Reclaim the key panel first: a shortcut-opened island can lose
            // key status before this pass, which used to orphan the draft.
            service.ensurePanelKeyForTyping()
            guard !preview, !todos.loadFailed, !showingArchived, service.panelIsKey,
                  service.expanded, service.selected == .todo,
                  !service.showingSections, !service.showingAppPanel else { return }
            inputFocused = focusTarget
            queueScroll(scroll.resolved(for: focusTarget, orphan: orphanedEditingID))
        }
    }
}

struct NotchTodoStrip: View {
    @ObservedObject var service: NotchService
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var todos = TodoService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let summary = NotchTodoSupport.summary(todos.items)
        let geometry = displayGeometry ?? service.compactActivityGeometry
        let height = geometry.compactActivityContentHeight
        let wing = geometry.compactActivityWingWidth
        let iconSize = NotchTimerSupport.stripIconSize(height: height)
        let textSize = NotchTimerSupport.stripTextSize(height: height)
        Button(action: service.openTodo) {
            HStack(spacing: 0) {
                Image(systemName: "checklist")
                    .font(.system(size: iconSize, weight: .medium))
                    .padding(.leading, geometry.compactActivityEdgeInset(boxHeight: iconSize, radius: iconSize / 2))
                    .frame(width: wing, alignment: .leading)
                    .opacity(wing >= 28 ? 1 : 0)
                Color.clear.frame(width: geometry.compactActivityCameraGap)
                Text(summary.headline)
                    .font(.system(size: textSize, weight: .medium)).monospacedDigit()
                    .lineLimit(1).truncationMode(.tail)
                    .padding(.trailing, geometry.compactActivityEdgeInset(boxHeight: textSize * 0.72, radius: 0))
                    .frame(width: wing, alignment: .trailing).clipped()
            }
            .foregroundStyle(.cyan)
            .frame(height: height)
            .padding(.horizontal, geometry.compactActivityHorizontalPadding)
            .padding(.top, geometry.compactActivityTopPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FeatureStrings.todo(l10n.language).title)
        .accessibilityValue(summary.headline)
        .accessibilityHint(FeatureStrings.todo(l10n.language).open)
        .accessibilityIdentifier("notch.todo.strip")
    }
}

struct NotchCapsuleTodoStrip: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    var displayGeometry: NotchGeometry? = nil
    @ObservedObject private var todos = TodoService.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        let geometry = displayGeometry ?? service.geometry
        let layout = NotchCapsuleLayout.self
        let summary = NotchTodoSupport.summary(todos.items)
        Button(action: service.openTodo) {
            HStack(spacing: layout.spacing) {
                Image(systemName: "checklist")
                    .font(.system(size: layout.symbolSize, weight: .medium))
                    .frame(width: layout.symbolWidth)
                Text(summary.headline)
                    .font(Font(layout.levelFont as CTFont))
                    .lineLimit(1).truncationMode(.tail)
            }
            .foregroundStyle(.cyan)
            .padding(.horizontal, layout.side(geometry) + layout.endPadding)
            .frame(width: size.width, height: geometry.stripHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FeatureStrings.todo(l10n.language).title)
        .accessibilityValue(summary.headline)
        .accessibilityHint(FeatureStrings.todo(l10n.language).open)
        .accessibilityIdentifier("notch.todo.capsule")
    }
}
