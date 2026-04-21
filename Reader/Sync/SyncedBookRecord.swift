import Foundation

struct SyncedBookRecord: Equatable, Sendable {
    var bookID: String
    var contentHash: String
    var title: String
    var author: String?
    var format: BookFormat
    var remoteRecordName: String
    var updatedAt: Date
    var deletedAt: Date?
    var assetChecksum: String
}
