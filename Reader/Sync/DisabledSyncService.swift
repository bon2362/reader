import Foundation

struct DisabledSyncService: SyncServiceProtocol {
    func fetchBooks() async throws -> [SyncedBookRecord] { [] }
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
    func fetchProgressRecords() async throws -> [SyncedProgressRecord] { [] }
    func saveProgress(_ progress: SyncedProgressRecord) async throws -> SyncedProgressRecord { progress }
    func fetchHighlights() async throws -> [SyncedHighlightRecord] { [] }
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
