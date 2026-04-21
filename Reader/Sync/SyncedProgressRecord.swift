import Foundation

struct SyncedProgressRecord: Equatable, Sendable {
    var bookID: String
    var lastReadAnchor: String
    var currentPage: Int
    var totalPages: Int
    var progressUpdatedAt: Date
}
