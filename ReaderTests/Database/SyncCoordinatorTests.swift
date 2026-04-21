import Foundation
import Testing
@testable import Reader

@Suite("SyncCoordinator")
struct SyncCoordinatorTests {

    @Test func keepsRemoteProgressPendingWhileBookIsActive() async throws {
        let db = try DatabaseManager.inMemory()
        let library = LibraryRepository(database: db)
        let annotations = AnnotationRepository(database: db)
        let book = Book(
            id: "book-1",
            title: "Book",
            filePath: "",
            lastCFI: "pdf:1",
            totalPages: 10,
            currentPage: 2,
            format: .pdf,
            progressUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        try await library.insert(book)

        let remoteProgress = SyncedProgressRecord(
            bookID: "book-1",
            lastReadAnchor: "pdf:7",
            currentPage: 8,
            totalPages: 10,
            progressUpdatedAt: Date(timeIntervalSince1970: 200)
        )

        let sync = SyncCoordinator(
            libraryRepository: library,
            annotationRepository: annotations,
            syncService: FakeSyncService(progressRecords: [remoteProgress])
        )

        await sync.beginReading(bookID: "book-1")
        await sync.syncOnLaunch()

        let stored = try await library.fetch(id: "book-1")
        let pending = await sync.pendingRemoteProgress(for: "book-1")

        #expect(stored?.lastCFI == "pdf:1")
        #expect(stored?.currentPage == 2)
        #expect(pending?.lastReadAnchor == "pdf:7")
        #expect(pending?.currentPage == 8)
    }

    @Test func appliesRemoteProgressWhenBookIsInactive() async throws {
        let db = try DatabaseManager.inMemory()
        let library = LibraryRepository(database: db)
        let annotations = AnnotationRepository(database: db)
        let book = Book(
            id: "book-2",
            title: "Book",
            filePath: "",
            lastCFI: "pdf:1",
            totalPages: 10,
            currentPage: 2,
            format: .pdf,
            progressUpdatedAt: Date(timeIntervalSince1970: 100)
        )
        try await library.insert(book)

        let remoteProgress = SyncedProgressRecord(
            bookID: "book-2",
            lastReadAnchor: "pdf:4",
            currentPage: 5,
            totalPages: 10,
            progressUpdatedAt: Date(timeIntervalSince1970: 200)
        )

        let sync = SyncCoordinator(
            libraryRepository: library,
            annotationRepository: annotations,
            syncService: FakeSyncService(progressRecords: [remoteProgress])
        )

        await sync.syncOnLaunch()

        let stored = try await library.fetch(id: "book-2")
        #expect(stored?.lastCFI == "pdf:4")
        #expect(stored?.currentPage == 5)
    }
}

private struct FakeSyncService: SyncServiceProtocol {
    var books: [SyncedBookRecord] = []
    var progressRecords: [SyncedProgressRecord] = []
    var highlights: [SyncedHighlightRecord] = []

    func fetchBooks() async throws -> [SyncedBookRecord] { books }
    func saveBook(_ book: Book, assetURL: URL?) async throws -> SyncedBookRecord {
        SyncedBookRecord(
            bookID: book.id,
            contentHash: book.contentHash,
            title: book.title,
            author: book.author,
            format: book.format,
            remoteRecordName: book.remoteRecordName ?? book.id,
            updatedAt: book.updatedAt,
            deletedAt: book.deletedAt,
            assetChecksum: book.contentHash
        )
    }
    func fetchProgressRecords() async throws -> [SyncedProgressRecord] { progressRecords }
    func saveProgress(_ progress: SyncedProgressRecord) async throws -> SyncedProgressRecord { progress }
    func fetchHighlights() async throws -> [SyncedHighlightRecord] { highlights }
    func saveHighlight(_ highlight: Highlight) async throws -> SyncedHighlightRecord {
        SyncedHighlightRecord(
            highlightID: highlight.id,
            bookID: highlight.bookId,
            anchor: highlight.cfiStart,
            color: highlight.color,
            selectedText: highlight.selectedText,
            remoteRecordName: highlight.remoteRecordName ?? highlight.id,
            updatedAt: highlight.updatedAt,
            deletedAt: highlight.deletedAt
        )
    }
    func downloadBookAsset(recordName: String) async throws -> URL? { nil }
}
