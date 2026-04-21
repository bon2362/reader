import Testing
import Foundation
@testable import Reader

@Suite("LibraryRepository")
struct LibraryRepositoryTests {

    private func makeRepo() throws -> LibraryRepository {
        let db = try DatabaseManager.inMemory()
        return LibraryRepository(database: db)
    }

    @Test func insertAndFetchAll() async throws {
        let repo = try makeRepo()
        let book = Book(title: "Test", filePath: "/tmp/test.epub")
        try await repo.insert(book)

        let all = try await repo.fetchAll()
        #expect(all.count == 1)
        #expect(all[0].title == "Test")
    }

    @Test func fetchByID() async throws {
        let repo = try makeRepo()
        let book = Book(title: "Swift", author: "Apple", filePath: "/tmp/swift.epub")
        try await repo.insert(book)

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.title == "Swift")
        #expect(fetched?.author == "Apple")
    }

    @Test func fetchByIDReturnsNilWhenMissing() async throws {
        let repo = try makeRepo()
        let fetched = try await repo.fetch(id: "non-existent")
        #expect(fetched == nil)
    }

    @Test func updateBook() async throws {
        let repo = try makeRepo()
        var book = Book(title: "Old Title", filePath: "/tmp/b.epub")
        try await repo.insert(book)

        book.title = "New Title"
        try await repo.update(book)

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.title == "New Title")
    }

    @Test func deleteBook() async throws {
        let repo = try makeRepo()
        let book = Book(title: "ToDelete", filePath: "/tmp/d.epub")
        try await repo.insert(book)

        try await repo.delete(id: book.id)

        let all = try await repo.fetchAll()
        #expect(all.isEmpty)
    }

    @Test func updateReadingProgress() async throws {
        let repo = try makeRepo()
        let book = Book(title: "Progress", filePath: "/tmp/p.epub")
        try await repo.insert(book)

        try await repo.updateReadingProgress(
            id: book.id, lastCFI: "epubcfi(/6/4)", currentPage: 47, totalPages: 312
        )

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.lastCFI == "epubcfi(/6/4)")
        #expect(fetched?.currentPage == 47)
        #expect(fetched?.totalPages == 312)
        #expect(fetched?.lastOpenedAt != nil)
    }

    @Test func progressCalculation() {
        let book = Book(
            title: "Prog", filePath: "/x",
            totalPages: 100, currentPage: 25
        )
        #expect(book.progress == 0.25)
    }

    @Test func progressZeroWhenNoTotalPages() {
        let book = Book(title: "Prog", filePath: "/x")
        #expect(book.progress == 0)
    }

    @Test func progressCappedAtOne() {
        let book = Book(
            title: "Prog", filePath: "/x",
            totalPages: 100, currentPage: 200
        )
        #expect(book.progress == 1.0)
    }

    @Test func fetchAllOrderedByAddedAtDesc() async throws {
        let repo = try makeRepo()
        let older = Book(title: "Older", filePath: "/o", addedAt: Date(timeIntervalSince1970: 1000))
        let newer = Book(title: "Newer", filePath: "/n", addedAt: Date(timeIntervalSince1970: 2000))
        try await repo.insert(older)
        try await repo.insert(newer)

        let all = try await repo.fetchAll()
        #expect(all[0].title == "Newer")
        #expect(all[1].title == "Older")
    }

    @Test func persistsBookFormat() async throws {
        let repo = try makeRepo()
        let book = Book(title: "PDF", filePath: "/tmp/test.pdf", format: .pdf)
        try await repo.insert(book)

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.format == .pdf)
    }

    @Test func persistsSyncMetadata() async throws {
        let repo = try makeRepo()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let book = Book(
            title: "Synced",
            filePath: "/tmp/synced.pdf",
            format: .pdf,
            contentHash: "hash-1",
            syncState: Book.SyncState.pendingUpload.rawValue,
            remoteRecordName: "book-record",
            updatedAt: timestamp,
            deletedAt: nil,
            progressUpdatedAt: timestamp.addingTimeInterval(5),
            assetUpdatedAt: timestamp.addingTimeInterval(10)
        )
        try await repo.insert(book)

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.contentHash == "hash-1")
        #expect(fetched?.syncState == Book.SyncState.pendingUpload.rawValue)
        #expect(fetched?.remoteRecordName == "book-record")
        #expect(fetched?.updatedAt == timestamp)
        #expect(fetched?.progressUpdatedAt == timestamp.addingTimeInterval(5))
        #expect(fetched?.assetUpdatedAt == timestamp.addingTimeInterval(10))
    }

    @Test func fetchesBookByContentHash() async throws {
        let repo = try makeRepo()
        let book = Book(title: "By Hash", filePath: "/tmp/hash.pdf", contentHash: "same-hash")
        try await repo.insert(book)

        let fetched = try await repo.fetchByContentHash("same-hash")
        #expect(fetched?.id == book.id)
    }

    @Test func updatesSyncMetadata() async throws {
        let repo = try makeRepo()
        let book = Book(title: "Pending", filePath: "/tmp/pending.pdf")
        try await repo.insert(book)

        let updatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let deletedAt = updatedAt.addingTimeInterval(60)
        try await repo.updateSyncMetadata(
            id: book.id,
            remoteRecordName: "remote-1",
            syncState: Book.SyncState.synced.rawValue,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            progressUpdatedAt: updatedAt.addingTimeInterval(10),
            assetUpdatedAt: updatedAt.addingTimeInterval(20)
        )

        let fetched = try await repo.fetch(id: book.id)
        #expect(fetched?.remoteRecordName == "remote-1")
        #expect(fetched?.syncState == Book.SyncState.synced.rawValue)
        #expect(fetched?.updatedAt == updatedAt)
        #expect(fetched?.deletedAt == deletedAt)
        #expect(fetched?.progressUpdatedAt == updatedAt.addingTimeInterval(10))
        #expect(fetched?.assetUpdatedAt == updatedAt.addingTimeInterval(20))
    }
}
