import Foundation

protocol SyncServiceProtocol: Sendable {
    func fetchBooks() async throws -> [SyncedBookRecord]
    func saveBook(_ book: Book, assetURL: URL?) async throws -> SyncedBookRecord
    func fetchProgressRecords() async throws -> [SyncedProgressRecord]
    func saveProgress(_ progress: SyncedProgressRecord) async throws -> SyncedProgressRecord
    func fetchHighlights() async throws -> [SyncedHighlightRecord]
    func saveHighlight(_ highlight: Highlight) async throws -> SyncedHighlightRecord
    func downloadBookAsset(recordName: String) async throws -> URL?
}
