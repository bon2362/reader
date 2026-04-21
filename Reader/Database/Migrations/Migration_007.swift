import Foundation
import GRDB

enum Migration_007 {
    static let identifier = "007_highlights_sync_metadata"

    static func migrate(_ db: Database) throws {
        try db.execute(sql: """
            ALTER TABLE highlights ADD COLUMN deleted_at DATETIME;
            """)
        try db.execute(sql: """
            ALTER TABLE highlights ADD COLUMN remote_record_name TEXT;
            """)
        try db.execute(sql: """
            ALTER TABLE highlights ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'localOnly';
            """)
        try db.execute(sql: """
            CREATE INDEX idx_highlights_remote_record_name ON highlights(remote_record_name);
            """)
    }
}
