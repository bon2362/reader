import Foundation
import GRDB

protocol AnnotationRepositoryProtocol: Sendable {
    // Highlights
    func fetchHighlights(bookId: String) async throws -> [Highlight]
    func fetchHighlight(bookId: String, exchangeId: String) async throws -> Highlight?
    func insertHighlight(_ h: Highlight) async throws
    func updateHighlight(_ h: Highlight) async throws
    func deleteHighlight(id: String) async throws

    // Text notes
    func fetchTextNotes(bookId: String) async throws -> [TextNote]
    func fetchTextNote(bookId: String, exchangeId: String) async throws -> TextNote?
    func insertTextNote(_ n: TextNote) async throws
    func updateTextNote(_ n: TextNote) async throws
    func deleteTextNote(id: String) async throws

    // Page notes (sticky)
    func fetchPageNotes(bookId: String) async throws -> [PageNote]
    func fetchPageNote(bookId: String, exchangeId: String) async throws -> PageNote?
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
                .filter(Highlight.Columns.bookId == bookId)
                .order(Highlight.Columns.createdAt)
                .fetchAll(db)
        }
    }

    func fetchHighlight(bookId: String, exchangeId: String) async throws -> Highlight? {
        try await writer.read { db in
            try Highlight
                .filter(Highlight.Columns.bookId == bookId)
                .filter(Highlight.Columns.exchangeId == exchangeId)
                .fetchOne(db)
        }
    }

    func insertHighlight(_ h: Highlight) async throws {
        try await writer.write { db in try h.insert(db) }
    }

    func updateHighlight(_ h: Highlight) async throws {
        try await writer.write { db in
            var copy = h; copy.updatedAt = Date()
            try copy.update(db)
        }
    }

    func deleteHighlight(id: String) async throws {
        try await writer.write { db in _ = try Highlight.deleteOne(db, key: id) }
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

    func fetchTextNote(bookId: String, exchangeId: String) async throws -> TextNote? {
        try await writer.read { db in
            try TextNote
                .filter(TextNote.Columns.bookId == bookId)
                .filter(TextNote.Columns.exchangeId == exchangeId)
                .fetchOne(db)
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

    func fetchPageNote(bookId: String, exchangeId: String) async throws -> PageNote? {
        try await writer.read { db in
            try PageNote
                .filter(PageNote.Columns.bookId == bookId)
                .filter(PageNote.Columns.exchangeId == exchangeId)
                .fetchOne(db)
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
