// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TodoColor: String, Codable, CaseIterable {
    case blue, teal, green, orange, pink, purple

    /// UUID text and fixed arithmetic, never Swift's process-randomized Hasher.
    static func legacyColor(for id: UUID) -> TodoColor {
        let hash = id.uuidString.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}

struct TodoItem: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var completedAt: Date?
    var archivedAt: Date?
    var color: TodoColor
    var isArchived: Bool { archivedAt != nil }

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         completedAt: Date? = nil, archivedAt: Date? = nil, color: TodoColor? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.archivedAt = archivedAt
        self.color = color ?? TodoColor.legacyColor(for: id)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, completedAt, archivedAt, color
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        isCompleted = try values.decode(Bool.self, forKey: .isCompleted)
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        archivedAt = try values.decodeIfPresent(Date.self, forKey: .archivedAt)
        color = try values.decodeIfPresent(TodoColor.self, forKey: .color) ?? TodoColor.legacyColor(for: id)
    }
}

enum TodoFilter: String, CaseIterable {
    case all, pending, completed, archived

    func includes(_ item: TodoItem) -> Bool {
        switch self {
        case .all: return !item.isArchived
        case .pending: return !item.isArchived && !item.isCompleted
        case .completed: return !item.isArchived && item.isCompleted
        case .archived: return item.isArchived
        }
    }
}

/// Versioned private user content, deliberately outside the settings backup.
/// A failed read never authorizes a write over the unread document.
struct TodoStore {
    struct Document: Codable {
        var version = 1
        var items: [TodoItem]
        var nextColorIndex: Int? = nil
    }

    enum StoreError: Error { case unavailable, invalidDocument, writeFailed }
    let directoryURL: URL?
    private(set) var canSave = false
    private(set) var nextColorIndex = 0
    private(set) var needsMigration = false

    init(directoryURL: URL?) { self.directoryURL = directoryURL }

    var fileURL: URL? { directoryURL?.appendingPathComponent("todos.json") }

    mutating func load() throws -> [TodoItem] {
        canSave = false
        guard let fileURL else { throw StoreError.unavailable }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain
            && error.code == NSFileReadNoSuchFileError {
            canSave = true
            nextColorIndex = 0
            needsMigration = false
            return []
        }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.version == 1, Self.isValid(document.items),
              document.nextColorIndex.map({ TodoColor.allCases.indices.contains($0) }) ?? true else {
            throw StoreError.invalidDocument
        }
        nextColorIndex = document.nextColorIndex ?? document.items.last.map {
            (TodoColor.allCases.firstIndex(of: $0.color)! + 1) % TodoColor.allCases.count
        } ?? 0
        needsMigration = document.nextColorIndex == nil
            || document.items.contains { $0.isCompleted && $0.completedAt == nil }
        canSave = true
        return document.items
    }

    mutating func save(_ items: [TodoItem], nextColorIndex: Int? = nil) throws {
        guard canSave, let directoryURL, let fileURL else { throw StoreError.unavailable }
        let colorIndex = nextColorIndex ?? self.nextColorIndex
        guard Self.isValid(items), TodoColor.allCases.indices.contains(colorIndex) else {
            throw StoreError.invalidDocument
        }
        let data = try JSONEncoder().encode(Document(items: items, nextColorIndex: colorIndex))
        guard PrivateFileStore.createDirectory(at: directoryURL, container: directoryURL),
              PrivateFileStore.write(data, to: fileURL) else { throw StoreError.writeFailed }
        self.nextColorIndex = colorIndex
        needsMigration = false
    }

    static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValid(_ items: [TodoItem]) -> Bool {
        Set(items.map(\.id)).count == items.count
            && items.allSatisfy { !normalizedTitle($0.title).isEmpty
                && (!$0.isArchived || $0.isCompleted) }
    }
}
