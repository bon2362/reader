import Foundation

protocol ProgressSyncing: Sendable {
    func publishStableProgress(bookID: String, lastReadAnchor: String, currentPage: Int, totalPages: Int) async
}

protocol HighlightSyncing: Sendable {
    func publishHighlightChange(id: String) async
    func publishHighlightDeletion(id: String) async
}

actor SyncCoordinator: ProgressSyncing, HighlightSyncing {
    private let libraryRepository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private let syncService: SyncServiceProtocol
    private let logger: SyncDiagnosticsLogging
    private let clock: SyncClock

    private var activeBookIDs: Set<String> = []
    private var pendingRemoteProgress: [String: SyncedProgressRecord] = [:]

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol,
        syncService: SyncServiceProtocol,
        logger: SyncDiagnosticsLogging = SyncDiagnosticsLogger(),
        clock: SyncClock = SystemSyncClock()
    ) {
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
        self.syncService = syncService
        self.logger = logger
        self.clock = clock
    }

    func syncOnLaunch() async {
        await pushLocalChanges()
        await pullRemoteChanges()
    }

    func enqueueBookUpload(bookID: String) async {
        guard let book = try? await libraryRepository.fetch(id: bookID) else { return }
        await upload(book: book)
    }

    func beginReading(bookID: String) {
        activeBookIDs.insert(bookID)
    }

    func endReading(bookID: String) {
        activeBookIDs.remove(bookID)
    }

    func pendingRemoteProgress(for bookID: String) -> SyncedProgressRecord? {
        pendingRemoteProgress[bookID]
    }

    func clearPendingRemoteProgress(for bookID: String) {
        pendingRemoteProgress.removeValue(forKey: bookID)
    }

    func hydrateAssetIfNeeded(for book: Book) async -> URL? {
        if !book.filePath.isEmpty {
            let localURL = URL(fileURLWithPath: book.filePath)
            if FileManager.default.fileExists(atPath: localURL.path) {
                return localURL
            }
        }

        guard let recordName = book.remoteRecordName else { return nil }
        do {
            logger.log(.hydration, "download asset for \(book.id)")
            guard let remoteURL = try await syncService.downloadBookAsset(recordName: recordName) else {
                return nil
            }
            let localURL = try FileAccess.copyPDFToSandbox(from: remoteURL, bookId: book.id)
            var updatedBook = book
            updatedBook.filePath = localURL.path
            updatedBook.assetUpdatedAt = clock.now()
            try await libraryRepository.update(updatedBook)
            return localURL
        } catch {
            logger.log(.error, "asset hydration failed for \(book.id): \(error.localizedDescription)")
            return nil
        }
    }

    func publishStableProgress(
        bookID: String,
        lastReadAnchor: String,
        currentPage: Int,
        totalPages: Int
    ) async {
        let progress = SyncedProgressRecord(
            bookID: bookID,
            lastReadAnchor: lastReadAnchor,
            currentPage: currentPage,
            totalPages: totalPages,
            progressUpdatedAt: clock.now()
        )
        do {
            logger.log(.upload, "progress \(bookID) page \(currentPage)")
            _ = try await syncService.saveProgress(progress)
        } catch {
            logger.log(.error, "progress upload failed for \(bookID): \(error.localizedDescription)")
        }
    }

    func publishHighlightChange(id: String) async {
        guard let highlight = try? await annotationRepository.fetchHighlight(id: id, includeDeleted: true) else { return }
        do {
            logger.log(.upload, "highlight upsert \(id)")
            let synced = try await syncService.saveHighlight(highlight)
            try await annotationRepository.markHighlightSynced(
                id: id,
                remoteRecordName: synced.remoteRecordName,
                updatedAt: synced.updatedAt,
                deletedAt: synced.deletedAt
            )
        } catch {
            logger.log(.error, "highlight upload failed for \(id): \(error.localizedDescription)")
        }
    }

    func publishHighlightDeletion(id: String) async {
        await publishHighlightChange(id: id)
    }

    private func pushLocalChanges() async {
        let books = (try? await libraryRepository.fetchBooksPendingSync()) ?? []
        for book in books {
            await upload(book: book)
        }

        let highlights = (try? await annotationRepository.fetchHighlightsPendingSync()) ?? []
        for highlight in highlights {
            await publishHighlightChange(id: highlight.id)
        }
    }

    private func pullRemoteChanges() async {
        do {
            logger.log(.pull, "fetch books")
            let remoteBooks = try await syncService.fetchBooks()
            for remoteBook in remoteBooks {
                if remoteBook.deletedAt != nil {
                    try await libraryRepository.applyRemoteBookTombstone(remoteBook)
                } else {
                    try await libraryRepository.applyRemoteBookUpsert(remoteBook)
                }
            }

            logger.log(.pull, "fetch progress")
            let remoteProgress = try await syncService.fetchProgressRecords()
            for progress in remoteProgress {
                let localBook = try await libraryRepository.fetch(id: progress.bookID)
                let localUpdatedAt = localBook?.progressUpdatedAt ?? .distantPast
                guard progress.progressUpdatedAt > localUpdatedAt else { continue }
                if activeBookIDs.contains(progress.bookID) {
                    pendingRemoteProgress[progress.bookID] = progress
                    logger.log(.conflict, "pending remote progress for active book \(progress.bookID)")
                } else {
                    try await libraryRepository.updateProgressFromSync(progress)
                }
            }

            logger.log(.pull, "fetch highlights")
            let remoteHighlights = try await syncService.fetchHighlights()
            for highlight in remoteHighlights {
                if highlight.deletedAt != nil {
                    try await annotationRepository.applyRemoteHighlightTombstone(highlight)
                } else {
                    try await annotationRepository.applyRemoteHighlightUpsert(highlight)
                }
            }
        } catch {
            logger.log(.error, "pull failed: \(error.localizedDescription)")
        }
    }

    private func upload(book: Book) async {
        do {
            let assetURL = (!book.filePath.isEmpty && FileManager.default.fileExists(atPath: book.filePath))
                ? URL(fileURLWithPath: book.filePath)
                : nil
            logger.log(.upload, "book \(book.id)")
            let synced = try await syncService.saveBook(book, assetURL: assetURL)
            try await libraryRepository.markBookSynced(
                id: book.id,
                remoteRecordName: synced.remoteRecordName,
                updatedAt: synced.updatedAt,
                assetUpdatedAt: assetURL == nil ? book.assetUpdatedAt : clock.now(),
                deletedAt: synced.deletedAt
            )
        } catch {
            logger.log(.error, "book upload failed for \(book.id): \(error.localizedDescription)")
        }
    }
}
