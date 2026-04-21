import CloudKit
import Foundation

struct CloudKitSyncService: SyncServiceProtocol {
    private let database: CKDatabase

    init(containerIdentifier: String = "iCloud.com.koshkin.reader") {
        self.database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
    }

    init(container: CKContainer) {
        self.database = container.privateCloudDatabase
    }

    func fetchBooks() async throws -> [SyncedBookRecord] {
        let records = try await fetchRecords(recordType: CloudKitBookMapper.bookRecordType)
        return try records.map(CloudKitBookMapper.makeSyncedBookRecord(from:))
    }

    func saveBook(_ book: Book, assetURL: URL?) async throws -> SyncedBookRecord {
        let record = CloudKitBookMapper.makeBookRecord(from: book, assetURL: assetURL)
        let saved = try await save(record: record)
        return try CloudKitBookMapper.makeSyncedBookRecord(from: saved)
    }

    func fetchProgressRecords() async throws -> [SyncedProgressRecord] {
        let records = try await fetchRecords(recordType: CloudKitBookMapper.progressRecordType)
        return try records.map(CloudKitBookMapper.makeSyncedProgressRecord(from:))
    }

    func saveProgress(_ progress: SyncedProgressRecord) async throws -> SyncedProgressRecord {
        let record = CloudKitBookMapper.makeProgressRecord(from: progress)
        let saved = try await save(record: record)
        return try CloudKitBookMapper.makeSyncedProgressRecord(from: saved)
    }

    func fetchHighlights() async throws -> [SyncedHighlightRecord] {
        let records = try await fetchRecords(recordType: CloudKitHighlightMapper.recordType)
        return try records.map(CloudKitHighlightMapper.makeSyncedHighlightRecord(from:))
    }

    func saveHighlight(_ highlight: Highlight) async throws -> SyncedHighlightRecord {
        let record = CloudKitHighlightMapper.makeRecord(from: highlight)
        let saved = try await save(record: record)
        return try CloudKitHighlightMapper.makeSyncedHighlightRecord(from: saved)
    }

    func downloadBookAsset(recordName: String) async throws -> URL? {
        let record = try await fetchRecord(recordName: recordName)
        return (record[CloudKitBookMapper.BookField.fileAsset] as? CKAsset)?.fileURL
    }

    private func fetchRecords(recordType: String) async throws -> [CKRecord] {
        try await withCheckedThrowingContinuation { continuation in
            let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
            database.fetch(withQuery: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: CKQueryOperation.maximumResults) { result in
                switch result {
                case .success(let payload):
                    let records = payload.matchResults.compactMap { _, result in try? result.get() }
                    continuation.resume(returning: records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func save(record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let savedRecord {
                    continuation.resume(returning: savedRecord)
                } else {
                    continuation.resume(throwing: error ?? CKError(.internalError))
                }
            }
        }
    }

    private func fetchRecord(recordName: String) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: CKRecord.ID(recordName: recordName)) { record, error in
                if let record {
                    continuation.resume(returning: record)
                } else {
                    continuation.resume(throwing: error ?? CKError(.unknownItem))
                }
            }
        }
    }
}
