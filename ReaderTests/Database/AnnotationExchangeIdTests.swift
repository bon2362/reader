import Foundation
import GRDB
import Testing
@testable import Reader

@Suite("Annotation Exchange ID")
struct AnnotationExchangeIdTests {

    @Test func highlightGeneratesExchangeIdByDefault() {
        let highlight = Highlight(
            bookId: "book",
            cfiStart: "start",
            cfiEnd: "end",
            color: .yellow
        )

        #expect(highlight.exchangeId?.isEmpty == false)
    }

    @Test func textNoteGeneratesExchangeIdByDefault() {
        let note = TextNote(
            bookId: "book",
            cfiAnchor: "anchor",
            body: "body"
        )

        #expect(note.exchangeId?.isEmpty == false)
    }

    @Test func pageNoteGeneratesExchangeIdByDefault() {
        let note = PageNote(
            bookId: "book",
            spineIndex: 1,
            body: "body"
        )

        #expect(note.exchangeId?.isEmpty == false)
    }

    @Test func modelsKeepExplicitExchangeId() {
        let expected = "exchange-id"

        let highlight = Highlight(
            bookId: "book",
            cfiStart: "start",
            cfiEnd: "end",
            color: .yellow,
            exchangeId: expected
        )
        let textNote = TextNote(
            bookId: "book",
            cfiAnchor: "anchor",
            body: "body",
            exchangeId: expected
        )
        let pageNote = PageNote(
            bookId: "book",
            spineIndex: 1,
            body: "body",
            exchangeId: expected
        )

        #expect(highlight.exchangeId == expected)
        #expect(textNote.exchangeId == expected)
        #expect(pageNote.exchangeId == expected)
    }

    @Test func migrationAllowsReadingLegacyRowsWithNullExchangeId() throws {
        let dbQueue = try DatabaseQueue()

        var migrator = DatabaseMigrator()
        migrator.registerMigration(Migration_001.identifier, migrate: Migration_001.migrate)
        migrator.registerMigration(Migration_002.identifier, migrate: Migration_002.migrate)
        migrator.registerMigration(Migration_003.identifier, migrate: Migration_003.migrate)
        migrator.registerMigration(Migration_004.identifier, migrate: Migration_004.migrate)
        migrator.registerMigration(Migration_005.identifier, migrate: Migration_005.migrate)
        try migrator.migrate(dbQueue)

        let createdAt = Date(timeIntervalSince1970: 1)
        let updatedAt = Date(timeIntervalSince1970: 2)

        try dbQueue.write { db in
            try db.execute(
                sql: """
                INSERT INTO books (id, title, author, file_path, added_at, format)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: ["book-1", "Title", "Author", "/tmp/book.epub", createdAt, BookFormat.epub.rawValue]
            )
            try db.execute(
                sql: """
                INSERT INTO highlights (id, book_id, cfi_start, cfi_end, color, selected_text, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["highlight-1", "book-1", "start", "end", HighlightColor.yellow.rawValue, "selection", createdAt, updatedAt]
            )
            try db.execute(
                sql: """
                INSERT INTO text_notes (id, book_id, highlight_id, cfi_anchor, body, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["text-note-1", "book-1", "highlight-1", "anchor", "body", createdAt, updatedAt]
            )
            try db.execute(
                sql: """
                INSERT INTO page_notes (id, book_id, spine_index, page_in_chapter, body, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: ["page-note-1", "book-1", 3, 0, "body", createdAt, updatedAt]
            )
        }

        migrator.registerMigration(Migration_006.identifier, migrate: Migration_006.migrate)
        try migrator.migrate(dbQueue)

        let records = try dbQueue.read { db in
            (
                try Highlight.fetchOne(db, key: "highlight-1"),
                try TextNote.fetchOne(db, key: "text-note-1"),
                try PageNote.fetchOne(db, key: "page-note-1")
            )
        }

        #expect(records.0?.exchangeId == nil)
        #expect(records.1?.exchangeId == nil)
        #expect(records.2?.exchangeId == nil)
    }
}
