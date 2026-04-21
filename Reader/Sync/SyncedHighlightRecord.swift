import Foundation

struct SyncedHighlightRecord: Equatable, Sendable {
    var highlightID: String
    var bookID: String
    var anchor: String
    var color: HighlightColor
    var selectedText: String
    var remoteRecordName: String
    var updatedAt: Date
    var deletedAt: Date?
}
