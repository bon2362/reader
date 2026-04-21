import CloudKit
import Foundation
import Testing
@testable import Reader

@Suite("CloudKitHighlightMapper")
struct CloudKitHighlightMapperTests {

    @Test func mapsHighlightToRecordAndBack() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_700_001_000)
        let highlight = Highlight(
            id: "highlight-1",
            bookId: "book-1",
            cfiStart: "pdf:3|10-20",
            cfiEnd: "pdf:3|10-20",
            color: .green,
            selectedText: "sample",
            updatedAt: updatedAt,
            remoteRecordName: "remote-highlight-1",
            syncState: Highlight.SyncState.synced.rawValue
        )

        let record = CloudKitHighlightMapper.makeRecord(from: highlight)
        let restored = try CloudKitHighlightMapper.makeSyncedHighlightRecord(from: record)

        #expect(record.recordType == CloudKitHighlightMapper.recordType)
        #expect(record.recordID.recordName == "remote-highlight-1")
        #expect(restored.highlightID == "highlight-1")
        #expect(restored.bookID == "book-1")
        #expect(restored.anchor == "pdf:3|10-20")
        #expect(restored.color == .green)
        #expect(restored.selectedText == "sample")
        #expect(restored.updatedAt == updatedAt)
    }

    @Test func throwsWhenColorIsInvalid() {
        let record = CKRecord(
            recordType: CloudKitHighlightMapper.recordType,
            recordID: CKRecord.ID(recordName: "broken-highlight")
        )
        record[CloudKitHighlightMapper.Field.highlightID] = "highlight-2"
        record[CloudKitHighlightMapper.Field.bookID] = "book-2"
        record[CloudKitHighlightMapper.Field.anchor] = "pdf:1"
        record[CloudKitHighlightMapper.Field.color] = "orange"
        record[CloudKitHighlightMapper.Field.updatedAt] = Date()

        #expect(throws: CloudKitHighlightMapperError.invalidField(CloudKitHighlightMapper.Field.color)) {
            _ = try CloudKitHighlightMapper.makeSyncedHighlightRecord(from: record)
        }
    }
}
