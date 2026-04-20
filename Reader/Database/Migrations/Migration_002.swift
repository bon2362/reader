import Foundation
import GRDB

enum Migration_002 {
    static let identifier = "002_highlight_selected_text"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "highlights") { t in
            t.add(column: "selected_text", .text).notNull().defaults(to: "")
        }
    }
}
