import CryptoKit
import Foundation

struct AnnotationImportPreviewSummary: Equatable, Sendable {
    var createCount: Int
    var updateCount: Int
    var skipCount: Int
    var invalidCount: Int
    var files: [AnnotationImportPreviewFileResult]
}

struct AnnotationImportPreviewFileResult: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case ready(bookId: String)
        case unmatchedBook
        case invalid(reason: String)
    }

    var sourceURL: URL
    var status: Status
    var createCount: Int
    var updateCount: Int
    var skipCount: Int
}

struct AnnotationImportPreviewService: Sendable {
    private let libraryRepository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private let decoder: MarkdownAnnotationDecoder

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol,
        decoder: MarkdownAnnotationDecoder = MarkdownAnnotationDecoder()
    ) {
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
        self.decoder = decoder
    }

    func preview(urls: [URL]) async -> AnnotationImportPreviewSummary {
        let books = (try? await libraryRepository.fetchAll()) ?? []
        let booksByHash: [String: Book] = Dictionary(uniqueKeysWithValues: books.compactMap { book in
            guard let hash = try? contentHash(for: book) else { return nil }
            return (hash, book)
        })

        var files: [AnnotationImportPreviewFileResult] = []
        var createCount = 0
        var updateCount = 0
        var skipCount = 0
        var invalidCount = 0

        for url in urls {
            do {
                let markdown = try String(contentsOf: url, encoding: .utf8)
                let document = try decoder.decode(markdown)

                guard let book = booksByHash[document.book.contentHash] else {
                    let skippedItems = document.items.count
                    files.append(
                        AnnotationImportPreviewFileResult(
                            sourceURL: url,
                            status: .unmatchedBook,
                            createCount: 0,
                            updateCount: 0,
                            skipCount: skippedItems
                        )
                    )
                    skipCount += skippedItems
                    continue
                }

                let counters = try await classifyItems(document.items, for: book)
                files.append(
                    AnnotationImportPreviewFileResult(
                        sourceURL: url,
                        status: .ready(bookId: book.id),
                        createCount: counters.createCount,
                        updateCount: counters.updateCount,
                        skipCount: counters.skipCount
                    )
                )
                createCount += counters.createCount
                updateCount += counters.updateCount
                skipCount += counters.skipCount
            } catch {
                files.append(
                    AnnotationImportPreviewFileResult(
                        sourceURL: url,
                        status: .invalid(reason: String(describing: error)),
                        createCount: 0,
                        updateCount: 0,
                        skipCount: 0
                    )
                )
                invalidCount += 1
            }
        }

        return AnnotationImportPreviewSummary(
            createCount: createCount,
            updateCount: updateCount,
            skipCount: skipCount,
            invalidCount: invalidCount,
            files: files
        )
    }

    private func classifyItems(
        _ items: [AnnotationExchangeItem],
        for book: Book
    ) async throws -> (createCount: Int, updateCount: Int, skipCount: Int) {
        var createCount = 0
        var updateCount = 0
        var skipCount = 0

        for item in items {
            switch item.type {
            case .highlight:
                if let existing = try await annotationRepository.fetchHighlight(bookId: book.id, exchangeId: item.exchangeId) {
                    if item.updatedAt > existing.updatedAt {
                        updateCount += 1
                    } else {
                        skipCount += 1
                    }
                } else {
                    createCount += 1
                }
            case .textNote:
                if let existing = try await annotationRepository.fetchTextNote(bookId: book.id, exchangeId: item.exchangeId) {
                    if item.updatedAt > existing.updatedAt {
                        updateCount += 1
                    } else {
                        skipCount += 1
                    }
                } else {
                    createCount += 1
                }
            case .stickyNote:
                if let existing = try await annotationRepository.fetchPageNote(bookId: book.id, exchangeId: item.exchangeId) {
                    if item.updatedAt > existing.updatedAt {
                        updateCount += 1
                    } else {
                        skipCount += 1
                    }
                } else {
                    createCount += 1
                }
            }
        }

        return (createCount, updateCount, skipCount)
    }

    private func contentHash(for book: Book) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: book.filePath))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
