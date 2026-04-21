import CloudKit
import Foundation

enum CloudKitBookMapperError: Error, Equatable {
    case missingField(String)
    case invalidField(String)
}

enum CloudKitBookMapper {
    static let bookRecordType = "Book"
    static let progressRecordType = "ReadingProgress"

    enum BookField {
        static let bookID = "bookID"
        static let contentHash = "contentHash"
        static let title = "title"
        static let author = "author"
        static let format = "format"
        static let fileAsset = "fileAsset"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
    }

    enum ProgressField {
        static let bookID = "bookID"
        static let lastReadAnchor = "lastReadAnchor"
        static let currentPage = "currentPage"
        static let totalPages = "totalPages"
        static let progressUpdatedAt = "progressUpdatedAt"
    }

    static func makeBookRecord(from book: Book, assetURL: URL? = nil) -> CKRecord {
        let record = CKRecord(
            recordType: bookRecordType,
            recordID: CKRecord.ID(recordName: book.remoteRecordName ?? book.id)
        )
        record[BookField.bookID] = book.id as CKRecordValue
        record[BookField.contentHash] = book.contentHash as CKRecordValue
        record[BookField.title] = book.title as CKRecordValue
        if let author = book.author {
            record[BookField.author] = author as CKRecordValue
        }
        record[BookField.format] = book.format.rawValue as CKRecordValue
        record[BookField.updatedAt] = book.updatedAt as CKRecordValue
        if let deletedAt = book.deletedAt {
            record[BookField.deletedAt] = deletedAt as CKRecordValue
        }
        if let assetURL {
            record[BookField.fileAsset] = CKAsset(fileURL: assetURL)
        }
        return record
    }

    static func makeProgressRecord(
        from progress: SyncedProgressRecord,
        remoteRecordName: String? = nil
    ) -> CKRecord {
        let record = CKRecord(
            recordType: progressRecordType,
            recordID: CKRecord.ID(recordName: remoteRecordName ?? "progress:\(progress.bookID)")
        )
        record[ProgressField.bookID] = progress.bookID as CKRecordValue
        record[ProgressField.lastReadAnchor] = progress.lastReadAnchor as CKRecordValue
        record[ProgressField.currentPage] = progress.currentPage as CKRecordValue
        record[ProgressField.totalPages] = progress.totalPages as CKRecordValue
        record[ProgressField.progressUpdatedAt] = progress.progressUpdatedAt as CKRecordValue
        return record
    }

    static func makeSyncedBookRecord(from record: CKRecord) throws -> SyncedBookRecord {
        let rawFormat: String = try requiredString(BookField.format, in: record)
        guard let format = BookFormat(rawValue: rawFormat) else {
            throw CloudKitBookMapperError.invalidField(BookField.format)
        }

        return SyncedBookRecord(
            bookID: try requiredString(BookField.bookID, in: record),
            contentHash: try requiredString(BookField.contentHash, in: record),
            title: try requiredString(BookField.title, in: record),
            author: optionalString(BookField.author, in: record),
            format: format,
            remoteRecordName: record.recordID.recordName,
            updatedAt: try requiredDate(BookField.updatedAt, in: record),
            deletedAt: optionalDate(BookField.deletedAt, in: record),
            assetChecksum: optionalString(BookField.contentHash, in: record) ?? ""
        )
    }

    static func makeSyncedProgressRecord(from record: CKRecord) throws -> SyncedProgressRecord {
        SyncedProgressRecord(
            bookID: try requiredString(ProgressField.bookID, in: record),
            lastReadAnchor: try requiredString(ProgressField.lastReadAnchor, in: record),
            currentPage: try requiredInt(ProgressField.currentPage, in: record),
            totalPages: try requiredInt(ProgressField.totalPages, in: record),
            progressUpdatedAt: try requiredDate(ProgressField.progressUpdatedAt, in: record)
        )
    }

    private static func requiredString(_ key: String, in record: CKRecord) throws -> String {
        guard let value = record[key] as? String, !value.isEmpty else {
            throw CloudKitBookMapperError.missingField(key)
        }
        return value
    }

    private static func optionalString(_ key: String, in record: CKRecord) -> String? {
        record[key] as? String
    }

    private static func requiredDate(_ key: String, in record: CKRecord) throws -> Date {
        guard let value = record[key] as? Date else {
            throw CloudKitBookMapperError.missingField(key)
        }
        return value
    }

    private static func optionalDate(_ key: String, in record: CKRecord) -> Date? {
        record[key] as? Date
    }

    private static func requiredInt(_ key: String, in record: CKRecord) throws -> Int {
        if let value = record[key] as? Int {
            return value
        }
        if let value = record[key] as? NSNumber {
            return value.intValue
        }
        throw CloudKitBookMapperError.missingField(key)
    }
}
