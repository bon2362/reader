import CloudKit
import Foundation
import Testing
@testable import Reader

@Suite("CloudKitBookMapper")
struct CloudKitBookMapperTests {

    @Test func mapsBookToRecordAndBack() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_123)
        let deletedAt = updatedAt.addingTimeInterval(30)
        let book = Book(
            id: "book-1",
            title: "Cloud Atlas",
            author: "David Mitchell",
            filePath: "/tmp/cloud-atlas.pdf",
            format: .pdf,
            contentHash: "abc123",
            syncState: Book.SyncState.synced.rawValue,
            remoteRecordName: "remote-book-1",
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            assetUpdatedAt: updatedAt
        )

        let record = CloudKitBookMapper.makeBookRecord(from: book)
        let synced = try CloudKitBookMapper.makeSyncedBookRecord(from: record)

        #expect(record.recordType == CloudKitBookMapper.bookRecordType)
        #expect(record.recordID.recordName == "remote-book-1")
        #expect(record[CloudKitBookMapper.BookField.bookID] as? String == "book-1")
        #expect(record[CloudKitBookMapper.BookField.contentHash] as? String == "abc123")
        #expect(record[CloudKitBookMapper.BookField.format] as? String == BookFormat.pdf.rawValue)
        #expect(synced.bookID == "book-1")
        #expect(synced.remoteRecordName == "remote-book-1")
        #expect(synced.title == "Cloud Atlas")
        #expect(synced.author == "David Mitchell")
        #expect(synced.contentHash == "abc123")
        #expect(synced.assetChecksum == "abc123")
        #expect(synced.updatedAt == updatedAt)
        #expect(synced.deletedAt == deletedAt)
        #expect(synced.format == .pdf)
    }

    @Test func mapsProgressToRecordAndBack() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_999)
        let progress = SyncedProgressRecord(
            bookID: "book-2",
            lastReadAnchor: "pdf:42",
            currentPage: 43,
            totalPages: 300,
            progressUpdatedAt: updatedAt
        )

        let record = CloudKitBookMapper.makeProgressRecord(from: progress)
        let restored = try CloudKitBookMapper.makeSyncedProgressRecord(from: record)

        #expect(record.recordType == CloudKitBookMapper.progressRecordType)
        #expect(record.recordID.recordName == "progress:book-2")
        #expect(restored == progress)
    }

    @Test func throwsWhenRequiredBookFieldIsMissing() {
        let record = CKRecord(
            recordType: CloudKitBookMapper.bookRecordType,
            recordID: CKRecord.ID(recordName: "broken-book")
        )
        record[CloudKitBookMapper.BookField.bookID] = "book-3"
        record[CloudKitBookMapper.BookField.contentHash] = "hash-3"
        record[CloudKitBookMapper.BookField.format] = BookFormat.pdf.rawValue
        record[CloudKitBookMapper.BookField.updatedAt] = Date()

        #expect(throws: CloudKitBookMapperError.missingField(CloudKitBookMapper.BookField.title)) {
            _ = try CloudKitBookMapper.makeSyncedBookRecord(from: record)
        }
    }
}
