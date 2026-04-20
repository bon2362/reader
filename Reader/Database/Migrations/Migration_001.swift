import Foundation
import GRDB

enum Migration_001 {
    static let identifier = "001_initial_schema"

    static func migrate(_ db: Database) throws {
        try db.create(table: "books") { t in
            t.primaryKey("id", .text).notNull()
            t.column("title", .text).notNull()
            t.column("author", .text)
            t.column("cover_path", .text)
            t.column("file_path", .text).notNull()
            t.column("file_bookmark", .blob)
            t.column("added_at", .datetime).notNull()
            t.column("last_opened_at", .datetime)
            t.column("last_cfi", .text)
            t.column("total_pages", .integer)
            t.column("current_page", .integer)
        }

        try db.create(table: "highlights") { t in
            t.primaryKey("id", .text).notNull()
            t.column("book_id", .text).notNull()
                .references("books", onDelete: .cascade)
            t.column("cfi_start", .text).notNull()
            t.column("cfi_end", .text).notNull()
            t.column("color", .text).notNull()
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        try db.create(index: "idx_highlights_book", on: "highlights", columns: ["book_id"])

        try db.create(table: "text_notes") { t in
            t.primaryKey("id", .text).notNull()
            t.column("book_id", .text).notNull()
                .references("books", onDelete: .cascade)
            t.column("highlight_id", .text)
                .references("highlights", onDelete: .setNull)
            t.column("cfi_anchor", .text).notNull()
            t.column("body", .text).notNull()
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        try db.create(index: "idx_text_notes_book", on: "text_notes", columns: ["book_id"])

        try db.create(table: "page_notes") { t in
            t.primaryKey("id", .text).notNull()
            t.column("book_id", .text).notNull()
                .references("books", onDelete: .cascade)
            t.column("spine_index", .integer).notNull()
            t.column("body", .text).notNull()
            t.column("created_at", .datetime).notNull()
            t.column("updated_at", .datetime).notNull()
        }
        try db.create(index: "idx_page_notes_book", on: "page_notes", columns: ["book_id"])
    }
}
