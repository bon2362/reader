import Foundation
import GRDB

protocol LibraryRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Book]
    func fetch(id: String) async throws -> Book?
    func insert(_ book: Book) async throws
    func update(_ book: Book) async throws
    func delete(id: String) async throws
    func updateReadingProgress(id: String, lastCFI: String, currentPage: Int, totalPages: Int) async throws
    func updateChapterPageCountsCache(id: String, counts: [Int]) async throws
}

final class LibraryRepository: LibraryRepositoryProtocol {
    private let writer: any DatabaseWriter

    init(database: DatabaseManager) {
        self.writer = database.writer
    }

    func fetchAll() async throws -> [Book] {
        try await writer.read { db in
            try Book.order(Book.Columns.addedAt.desc).fetchAll(db)
        }
    }

    func fetch(id: String) async throws -> Book? {
        try await writer.read { db in
            try Book.fetchOne(db, key: id)
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
            _ = try Book.deleteOne(db, key: id)
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
        try await writer.write { db in
            try db.execute(
                sql: """
                UPDATE books
                SET last_cfi = ?, current_page = ?, total_pages = ?, last_opened_at = ?
                WHERE id = ?
                """,
                arguments: [lastCFI, currentPage, totalPages, Date(), id]
            )
        }
    }
}
