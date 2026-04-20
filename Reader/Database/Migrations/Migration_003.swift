import Foundation
import GRDB

enum Migration_003 {
    static let identifier = "003_page_notes_page_in_chapter"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "page_notes") { t in
            t.add(column: "page_in_chapter", .integer).notNull().defaults(to: 0)
        }
    }
}
