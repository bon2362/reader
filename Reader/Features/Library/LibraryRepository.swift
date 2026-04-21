import Foundation
import GRDB

protocol LibraryRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Book]
    func fetch(id: String) async throws -> Book?
    func fetchByContentHash(_ contentHash: String) async throws -> Book?
    func fetchBooksPendingSync() async throws -> [Book]
    func insert(_ book: Book) async throws
    func update(_ book: Book) async throws
    func delete(id: String) async throws
    func updateReadingProgress(id: String, lastCFI: String, currentPage: Int, totalPages: Int) async throws
    func updateChapterPageCountsCache(id: String, counts: [Int]) async throws
    func updateSyncMetadata(
        id: String,
        remoteRecordName: String?,
        syncState: String,
        updatedAt: Date,
        deletedAt: Date?,
        progressUpdatedAt: Date?,
        assetUpdatedAt: Date?
    ) async throws
    func markBookSynced(
        id: String,
        remoteRecordName: String,
        updatedAt: Date,
        assetUpdatedAt: Date?,
        deletedAt: Date?
    ) async throws
    func applyRemoteBookUpsert(_ remoteBook: SyncedBookRecord) async throws
    func applyRemoteBookTombstone(_ remoteBook: SyncedBookRecord) async throws
    func updateProgressFromSync(_ progress: SyncedProgressRecord) async throws
}

final class LibraryRepository: LibraryRepositoryProtocol {
    private let writer: any DatabaseWriter

    init(database: DatabaseManager) {
        self.writer = database.writer
    }

    func fetchAll() async throws -> [Book] {
        try await writer.read { db in
            try Book
                .filter(Book.Columns.deletedAt == nil)
                .order(Book.Columns.addedAt.desc)
                .fetchAll(db)
        }
    }

    func fetch(id: String) async throws -> Book? {
        try await writer.read { db in
            try Book.fetchOne(db, key: id)
        }
    }

    func fetchByContentHash(_ contentHash: String) async throws -> Book? {
        guard !contentHash.isEmpty else { return nil }
        return try await writer.read { db in
            try Book
                .filter(Book.Columns.contentHash == contentHash)
                .fetchOne(db)
        }
    }

    func fetchBooksPendingSync() async throws -> [Book] {
        try await writer.read { db in
            try Book
                .filter(
                    Book.Columns.syncState != Book.SyncState.synced.rawValue ||
                    Book.Columns.remoteRecordName == nil
                )
                .fetchAll(db)
        }
    }

    func insert(_ book: Book) async throws {
        try await writer.write { db in
            try book.insert(db)
        }
    }

    func update(_ book: Book) async throws {
        try await writer.write { db in
            try book.update(db)
        }
    }

    func delete(id: String) async throws {
        try await writer.write { db in
            let now = Date()
            try db.execute(
                sql: """
                UPDATE highlights
                SET deleted_at = ?, updated_at = ?, sync_state = ?
                WHERE book_id = ? AND deleted_at IS NULL
                """,
                arguments: [now, now, Highlight.SyncState.pendingDelete.rawValue, id]
            )
            try db.execute(
                sql: "DELETE FROM text_notes WHERE book_id = ?",
                arguments: [id]
            )
            try db.execute(
                sql: "DELETE FROM page_notes WHERE book_id = ?",
                arguments: [id]
            )
            try db.execute(
                sql: """
                UPDATE books
                SET deleted_at = ?, sync_state = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [now, Book.SyncState.pendingDelete.rawValue, now, id]
            )
        }
    }

    func updateChapterPageCountsCache(id: String, counts: [Int]) async throws {
        let json = Book.encodeChapterPageCounts(counts)
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE books SET chapter_page_counts = ? WHERE id = ?",
                arguments: [json, id]
            )
        }
    }

    func updateReadingProgress(id: String, lastCFI: String, currentPage: Int, totalPages: Int) async throws {
        let progressUpdatedAt = Date()
        try await writer.write { db in
            try db.execute(
                sql: """
                UPDATE books
                SET last_cfi = ?, current_page = ?, total_pages = ?, last_opened_at = ?, progress_updated_at = ?, sync_state = ?, updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    lastCFI,
                    currentPage,
                    totalPages,
                    progressUpdatedAt,
                    progressUpdatedAt,
                    Book.SyncState.pendingUpload.rawValue,
                    progressUpdatedAt,
                    id
                ]
            )
        }
    }

    func updateSyncMetadata(
        id: String,
        remoteRecordName: String?,
        syncState: String,
        updatedAt: Date,
        deletedAt: Date?,
        progressUpdatedAt: Date?,
        assetUpdatedAt: Date?
    ) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                UPDATE books
                SET remote_record_name = ?,
                    sync_state = ?,
                    updated_at = ?,
                    deleted_at = ?,
                    progress_updated_at = ?,
                    asset_updated_at = ?
                WHERE id = ?
                """,
                arguments: [
                    remoteRecordName,
                    syncState,
                    updatedAt,
                    deletedAt,
                    progressUpdatedAt,
                    assetUpdatedAt,
                    id
                ]
            )
        }
    }

    func markBookSynced(
        id: String,
        remoteRecordName: String,
        updatedAt: Date,
        assetUpdatedAt: Date?,
        deletedAt: Date?
    ) async throws {
        let existing = try await fetch(id: id)
        try await updateSyncMetadata(
            id: id,
            remoteRecordName: remoteRecordName,
            syncState: deletedAt == nil ? Book.SyncState.synced.rawValue : Book.SyncState.pendingDelete.rawValue,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            progressUpdatedAt: existing?.progressUpdatedAt,
            assetUpdatedAt: assetUpdatedAt ?? existing?.assetUpdatedAt
        )
    }

    func applyRemoteBookUpsert(_ remoteBook: SyncedBookRecord) async throws {
        try await writer.write { db in
            let existing = try Book
                .filter(
                    Book.Columns.id == remoteBook.bookID ||
                    Book.Columns.remoteRecordName == remoteBook.remoteRecordName ||
                    Book.Columns.contentHash == remoteBook.contentHash
                )
                .fetchOne(db)

            var merged = existing ?? Book(
                id: remoteBook.bookID,
                title: remoteBook.title,
                author: remoteBook.author,
                filePath: "",
                format: remoteBook.format,
                contentHash: remoteBook.contentHash,
                syncState: Book.SyncState.synced.rawValue,
                remoteRecordName: remoteBook.remoteRecordName,
                updatedAt: remoteBook.updatedAt
            )

            merged.id = remoteBook.bookID
            merged.title = remoteBook.title
            merged.author = remoteBook.author
            merged.format = remoteBook.format
            merged.contentHash = remoteBook.contentHash
            merged.remoteRecordName = remoteBook.remoteRecordName
            merged.updatedAt = remoteBook.updatedAt
            merged.deletedAt = remoteBook.deletedAt
            merged.syncState = Book.SyncState.synced.rawValue

            if existing == nil {
                try merged.insert(db)
            } else {
                try merged.update(db)
            }
        }
    }

    func applyRemoteBookTombstone(_ remoteBook: SyncedBookRecord) async throws {
        try await writer.write { db in
            guard var existing = try Book
                .filter(
                    Book.Columns.id == remoteBook.bookID ||
                    Book.Columns.remoteRecordName == remoteBook.remoteRecordName ||
                    Book.Columns.contentHash == remoteBook.contentHash
                )
                .fetchOne(db) else {
                return
            }

            existing.deletedAt = remoteBook.deletedAt ?? remoteBook.updatedAt
            existing.updatedAt = remoteBook.updatedAt
            existing.remoteRecordName = remoteBook.remoteRecordName
            existing.syncState = Book.SyncState.pendingDelete.rawValue
            try existing.update(db)
        }
    }

    func updateProgressFromSync(_ progress: SyncedProgressRecord) async throws {
        try await writer.write { db in
            try db.execute(
                sql: """
                UPDATE books
                SET last_cfi = ?, current_page = ?, total_pages = ?, progress_updated_at = ?, updated_at = ?, sync_state = ?
                WHERE id = ?
                """,
                arguments: [
                    progress.lastReadAnchor,
                    progress.currentPage,
                    progress.totalPages,
                    progress.progressUpdatedAt,
                    progress.progressUpdatedAt,
                    Book.SyncState.synced.rawValue,
                    progress.bookID
                ]
            )
        }
    }
}
