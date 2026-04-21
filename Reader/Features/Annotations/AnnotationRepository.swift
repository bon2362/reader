import Foundation
import GRDB

protocol AnnotationRepositoryProtocol: Sendable {
    // Highlights
    func fetchHighlights(bookId: String) async throws -> [Highlight]
    func fetchHighlight(id: String, includeDeleted: Bool) async throws -> Highlight?
    func fetchHighlightsPendingSync() async throws -> [Highlight]
    func insertHighlight(_ h: Highlight) async throws
    func updateHighlight(_ h: Highlight) async throws
    func deleteHighlight(id: String) async throws
    func markHighlightSynced(id: String, remoteRecordName: String, updatedAt: Date, deletedAt: Date?) async throws
    func applyRemoteHighlightUpsert(_ highlight: SyncedHighlightRecord) async throws
    func applyRemoteHighlightTombstone(_ highlight: SyncedHighlightRecord) async throws

    // Text notes
    func fetchTextNotes(bookId: String) async throws -> [TextNote]
    func insertTextNote(_ n: TextNote) async throws
    func updateTextNote(_ n: TextNote) async throws
    func deleteTextNote(id: String) async throws

    // Page notes (sticky)
    func fetchPageNotes(bookId: String) async throws -> [PageNote]
    func insertPageNote(_ n: PageNote) async throws
    func updatePageNote(_ n: PageNote) async throws
    func deletePageNote(id: String) async throws
}

final class AnnotationRepository: AnnotationRepositoryProtocol {
    private let writer: any DatabaseWriter

    init(database: DatabaseManager) {
        self.writer = database.writer
    }

    // MARK: - Highlights

    func fetchHighlights(bookId: String) async throws -> [Highlight] {
        try await writer.read { db in
            try Highlight
                .filter(Highlight.Columns.bookId == bookId && Highlight.Columns.deletedAt == nil)
                .order(Highlight.Columns.createdAt)
                .fetchAll(db)
        }
    }

    func fetchHighlight(id: String, includeDeleted: Bool = false) async throws -> Highlight? {
        try await writer.read { db in
            let request = Highlight.filter(Highlight.Columns.id == id)
            if includeDeleted {
                return try request.fetchOne(db)
            }
            return try request
                .filter(Highlight.Columns.deletedAt == nil)
                .fetchOne(db)
        }
    }

    func fetchHighlightsPendingSync() async throws -> [Highlight] {
        try await writer.read { db in
            try Highlight
                .filter(
                    Highlight.Columns.syncState != Highlight.SyncState.synced.rawValue ||
                    Highlight.Columns.remoteRecordName == nil
                )
                .fetchAll(db)
        }
    }

    func insertHighlight(_ h: Highlight) async throws {
        try await writer.write { db in
            var copy = h
            copy.syncState = Highlight.SyncState.pendingUpload.rawValue
            copy.deletedAt = nil
            try copy.insert(db)
        }
    }

    func updateHighlight(_ h: Highlight) async throws {
        try await writer.write { db in
            var copy = h
            copy.updatedAt = Date()
            copy.syncState = Highlight.SyncState.pendingUpload.rawValue
            try copy.update(db)
        }
    }

    func deleteHighlight(id: String) async throws {
        try await writer.write { db in
            let now = Date()
            try db.execute(
                sql: """
                UPDATE text_notes
                SET highlight_id = NULL, updated_at = ?
                WHERE highlight_id = ?
                """,
                arguments: [now, id]
            )
            try db.execute(
                sql: """
                UPDATE highlights
                SET deleted_at = ?, updated_at = ?, sync_state = ?
                WHERE id = ?
                """,
                arguments: [now, now, Highlight.SyncState.pendingDelete.rawValue, id]
            )
        }
    }

    func markHighlightSynced(id: String, remoteRecordName: String, updatedAt: Date, deletedAt: Date?) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                UPDATE highlights
                SET remote_record_name = ?, updated_at = ?, deleted_at = ?, sync_state = ?
                WHERE id = ?
                """,
                arguments: [
                    remoteRecordName,
                    updatedAt,
                    deletedAt,
                    deletedAt == nil ? Highlight.SyncState.synced.rawValue : Highlight.SyncState.pendingDelete.rawValue,
                    id
                ]
            )
        }
    }

    func applyRemoteHighlightUpsert(_ highlight: SyncedHighlightRecord) async throws {
        try await writer.write { db in
            let existing = try Highlight
                .filter(
                    Highlight.Columns.id == highlight.highlightID ||
                    Highlight.Columns.remoteRecordName == highlight.remoteRecordName
                )
                .fetchOne(db)

            let createdAt = existing?.createdAt ?? highlight.updatedAt
            var merged = existing ?? Highlight(
                id: highlight.highlightID,
                bookId: highlight.bookID,
                cfiStart: highlight.anchor,
                cfiEnd: highlight.anchor,
                color: highlight.color,
                selectedText: highlight.selectedText,
                createdAt: createdAt,
                updatedAt: highlight.updatedAt,
                deletedAt: nil,
                remoteRecordName: highlight.remoteRecordName,
                syncState: Highlight.SyncState.synced.rawValue
            )

            guard highlight.updatedAt >= merged.updatedAt else { return }

            merged.id = highlight.highlightID
            merged.bookId = highlight.bookID
            merged.cfiStart = highlight.anchor
            merged.cfiEnd = highlight.anchor
            merged.color = highlight.color
            merged.selectedText = highlight.selectedText
            merged.updatedAt = highlight.updatedAt
            merged.deletedAt = highlight.deletedAt
            merged.remoteRecordName = highlight.remoteRecordName
            merged.syncState = Highlight.SyncState.synced.rawValue

            if existing == nil {
                try merged.insert(db)
            } else {
                try merged.update(db)
            }
        }
    }

    func applyRemoteHighlightTombstone(_ highlight: SyncedHighlightRecord) async throws {
        try await writer.write { db in
            guard var existing = try Highlight
                .filter(
                    Highlight.Columns.id == highlight.highlightID ||
                    Highlight.Columns.remoteRecordName == highlight.remoteRecordName
                )
                .fetchOne(db) else {
                return
            }

            let tombstoneDate = highlight.deletedAt ?? highlight.updatedAt
            guard tombstoneDate >= existing.updatedAt else { return }

            existing.deletedAt = tombstoneDate
            existing.updatedAt = highlight.updatedAt
            existing.remoteRecordName = highlight.remoteRecordName
            existing.syncState = Highlight.SyncState.pendingDelete.rawValue
            try existing.update(db)
        }
    }

    // MARK: - Text Notes

    func fetchTextNotes(bookId: String) async throws -> [TextNote] {
        try await writer.read { db in
            try TextNote
                .filter(TextNote.Columns.bookId == bookId)
                .order(TextNote.Columns.createdAt)
                .fetchAll(db)
        }
    }

    func insertTextNote(_ n: TextNote) async throws {
        try await writer.write { db in try n.insert(db) }
    }

    func updateTextNote(_ n: TextNote) async throws {
        try await writer.write { db in
            var copy = n; copy.updatedAt = Date()
            try copy.update(db)
        }
    }

    func deleteTextNote(id: String) async throws {
        try await writer.write { db in _ = try TextNote.deleteOne(db, key: id) }
    }

    // MARK: - Page Notes

    func fetchPageNotes(bookId: String) async throws -> [PageNote] {
        try await writer.read { db in
            try PageNote
                .filter(PageNote.Columns.bookId == bookId)
                .order(PageNote.Columns.spineIndex)
                .fetchAll(db)
        }
    }

    func insertPageNote(_ n: PageNote) async throws {
        try await writer.write { db in try n.insert(db) }
    }

    func updatePageNote(_ n: PageNote) async throws {
        try await writer.write { db in
            var copy = n; copy.updatedAt = Date()
            try copy.update(db)
        }
    }

    func deletePageNote(id: String) async throws {
        try await writer.write { db in _ = try PageNote.deleteOne(db, key: id) }
    }
}
