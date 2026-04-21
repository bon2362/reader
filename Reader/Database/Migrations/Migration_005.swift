import Foundation
import GRDB

enum Migration_005 {
    static let identifier = "005_books_format"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "books") { t in
            t.add(column: "format", .text).notNull().defaults(to: BookFormat.epub.rawValue)
        }
    }
}
