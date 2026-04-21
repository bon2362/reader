import CloudKit
import Foundation

enum CloudKitHighlightMapperError: Error, Equatable {
    case missingField(String)
    case invalidField(String)
}

enum CloudKitHighlightMapper {
    static let recordType = "Highlight"

    enum Field {
        static let highlightID = "highlightID"
        static let bookID = "bookID"
        static let anchor = "anchor"
        static let color = "color"
        static let selectedText = "selectedText"
        static let updatedAt = "updatedAt"
        static let deletedAt = "deletedAt"
    }

    static func makeRecord(from highlight: Highlight) -> CKRecord {
        let record = CKRecord(
            recordType: recordType,
            recordID: CKRecord.ID(recordName: highlight.remoteRecordName ?? highlight.id)
        )
        record[Field.highlightID] = highlight.id as CKRecordValue
        record[Field.bookID] = highlight.bookId as CKRecordValue
        record[Field.anchor] = highlight.cfiStart as CKRecordValue
        record[Field.color] = highlight.color.rawValue as CKRecordValue
        record[Field.selectedText] = highlight.selectedText as CKRecordValue
        record[Field.updatedAt] = highlight.updatedAt as CKRecordValue
        if let deletedAt = highlight.deletedAt {
            record[Field.deletedAt] = deletedAt as CKRecordValue
        }
        return record
    }

    static func makeSyncedHighlightRecord(from record: CKRecord) throws -> SyncedHighlightRecord {
        let rawColor = try requiredString(Field.color, in: record)
        guard let color = HighlightColor(rawValue: rawColor) else {
            throw CloudKitHighlightMapperError.invalidField(Field.color)
        }

        return SyncedHighlightRecord(
            highlightID: try requiredString(Field.highlightID, in: record),
            bookID: try requiredString(Field.bookID, in: record),
            anchor: try requiredString(Field.anchor, in: record),
            color: color,
            selectedText: optionalString(Field.selectedText, in: record) ?? "",
            remoteRecordName: record.recordID.recordName,
            updatedAt: try requiredDate(Field.updatedAt, in: record),
            deletedAt: optionalDate(Field.deletedAt, in: record)
        )
    }

    private static func requiredString(_ key: String, in record: CKRecord) throws -> String {
        guard let value = record[key] as? String, !value.isEmpty else {
            throw CloudKitHighlightMapperError.missingField(key)
        }
        return value
    }

    private static func optionalString(_ key: String, in record: CKRecord) -> String? {
        record[key] as? String
    }

    private static func requiredDate(_ key: String, in record: CKRecord) throws -> Date {
        guard let value = record[key] as? Date else {
            throw CloudKitHighlightMapperError.missingField(key)
        }
        return value
    }

    private static func optionalDate(_ key: String, in record: CKRecord) -> Date? {
        record[key] as? Date
    }
}
