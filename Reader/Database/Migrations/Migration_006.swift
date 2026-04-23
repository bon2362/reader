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

enum Migration_007 {
    static let identifier = "007_text_notes_selected_text"

    static func migrate(_ db: Database) throws {
        try db.alter(table: "text_notes") { table in
            table.add(column: "selected_text", .text)
        }

        try db.execute(sql: """
            UPDATE text_notes
            SET selected_text = (
                SELECT highlights.selected_text
                FROM highlights
                WHERE highlights.id = text_notes.highlight_id
            )
            WHERE highlight_id IS NOT NULL
        """)
    }
}
