import Foundation
import GRDB

enum Migration_006 {
    static let identifier = "006_books_sync_metadata"

    static func migrate(_ db: Database) throws {
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN content_hash TEXT NOT NULL DEFAULT '';
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN sync_state TEXT NOT NULL DEFAULT 'localOnly';
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN remote_record_name TEXT;
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN updated_at DATETIME;
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN deleted_at DATETIME;
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN progress_updated_at DATETIME;
            """)
        try db.execute(sql: """
            ALTER TABLE books ADD COLUMN asset_updated_at DATETIME;
            """)
        try db.execute(sql: """
            UPDATE books
            SET updated_at = COALESCE(updated_at, added_at);
            """)
        try db.execute(sql: """
            CREATE INDEX idx_books_content_hash ON books(content_hash);
            """)
    }
}
