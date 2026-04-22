import Foundation
import GRDB

enum Migration_006 {
    static let identifier = "006_annotation_exchange_id"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "highlights") { table in
            table.add(column: "exchange_id", .text)
        }

        try db.alter(table: "text_notes") { table in
            table.add(column: "exchange_id", .text)
        }

        try db.alter(table: "page_notes") { table in
            table.add(column: "exchange_id", .text)
        }
    }
}
