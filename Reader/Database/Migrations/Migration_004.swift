import Foundation
import GRDB

enum Migration_004 {
    static let identifier = "004_books_chapter_page_counts"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "books") { t in
            t.add(column: "chapter_page_counts", .text)
        }
    }
}
