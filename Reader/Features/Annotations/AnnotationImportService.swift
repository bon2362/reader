import CryptoKit
import Foundation
import GRDB

enum AnnotationImportError: Error, Equatable, LocalizedError {
    case invalidAnchor(String)
    case missingRequiredField(String)

    var errorDescription: String? {
        switch self {
        case let .invalidAnchor(message):
            return message
        case let .missingRequiredField(field):
            return "Missing required field: \(field)"
        }
    }
}

struct AnnotationImportSummary: Equatable, Sendable {
    var importedBookCount: Int
    var failedBookCount: Int
    var unmatchedBookCount: Int
    var invalidFileCount: Int
    var createCount: Int
    var updateCount: Int
    var skipCount: Int
    var results: [AnnotationImportBookResult]
}

struct AnnotationImportBookResult: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case imported
        case failed(message: String)
        case unmatchedBook
        case invalid(reason: String)
    }

    var sourceURLs: [URL]
    var bookId: String?
    var title: String
    var status: Status
    var createCount: Int
    var updateCount: Int
    var skipCount: Int
}

struct AnnotationImportService {
    private let writer: any DatabaseWriter
    private let libraryRepository: LibraryRepositoryProtocol
    private let decoder: MarkdownAnnotationDecoder

    init(
        database: DatabaseManager,
        libraryRepository: LibraryRepositoryProtocol,
        decoder: MarkdownAnnotationDecoder = MarkdownAnnotationDecoder()
    ) {
        self.writer = database.writer
        self.libraryRepository = libraryRepository
        self.decoder = decoder
    }

    func apply(urls: [URL]) async -> AnnotationImportSummary {
        let books: [Book]

        do {
            books = try await libraryRepository.fetchAll()
        } catch {
            return AnnotationImportSummary(
                importedBookCount: 0,
                failedBookCount: 1,
                unmatchedBookCount: 0,
                invalidFileCount: 0,
                createCount: 0,
                updateCount: 0,
                skipCount: 0,
                results: [
                    AnnotationImportBookResult(
                        sourceURLs: [],
                        bookId: nil,
                        title: "Library",
                        status: .failed(message: error.localizedDescription),
                        createCount: 0,
                        updateCount: 0,
                        skipCount: 0
                    )
                ]
            )
        }

        let booksByHash: [String: Book] = Dictionary(uniqueKeysWithValues: books.compactMap { book in
            guard let hash = try? contentHash(for: book) else { return nil }
            return (hash, book)
        })

        var groupedDocuments: [String: GroupedImport] = [:]
        var results: [AnnotationImportBookResult] = []

        for url in urls {
            do {
                let markdown = try String(contentsOf: url, encoding: .utf8)
                let document = try decoder.decode(markdown)

                guard let book = booksByHash[document.book.contentHash] else {
                    results.append(
                        AnnotationImportBookResult(
                            sourceURLs: [url],
                            bookId: nil,
                            title: document.book.title,
                            status: .unmatchedBook,
                            createCount: 0,
                            updateCount: 0,
                            skipCount: document.items.count
                        )
                    )
                    continue
                }

                groupedDocuments[book.id, default: GroupedImport(book: book)]
                    .append(document: document, sourceURL: url)
            } catch {
                results.append(
                    AnnotationImportBookResult(
                        sourceURLs: [url],
                        bookId: nil,
                        title: url.lastPathComponent,
                        status: .invalid(reason: String(describing: error)),
                        createCount: 0,
                        updateCount: 0,
                        skipCount: 0
                    )
                )
            }
        }

        for groupedImport in groupedDocuments.values.sorted(by: { $0.book.title < $1.book.title }) {
            do {
                let counters = try await apply(groupedImport.documents, to: groupedImport.book)
                results.append(
                    AnnotationImportBookResult(
                        sourceURLs: groupedImport.sourceURLs,
                        bookId: groupedImport.book.id,
                        title: groupedImport.book.title,
                        status: .imported,
                        createCount: counters.createCount,
                        updateCount: counters.updateCount,
                        skipCount: counters.skipCount
                    )
                )
            } catch {
                results.append(
                    AnnotationImportBookResult(
                        sourceURLs: groupedImport.sourceURLs,
                        bookId: groupedImport.book.id,
                        title: groupedImport.book.title,
                        status: .failed(message: String(describing: error)),
                        createCount: 0,
                        updateCount: 0,
                        skipCount: 0
                    )
                )
            }
        }

        return AnnotationImportSummary(
            importedBookCount: results.filter {
                if case .imported = $0.status { return true }
                return false
            }.count,
            failedBookCount: results.filter {
                if case .failed = $0.status { return true }
                return false
            }.count,
            unmatchedBookCount: results.filter {
                if case .unmatchedBook = $0.status { return true }
                return false
            }.count,
            invalidFileCount: results.filter {
                if case .invalid = $0.status { return true }
                return false
            }.count,
            createCount: results.reduce(0) { $0 + $1.createCount },
            updateCount: results.reduce(0) { $0 + $1.updateCount },
            skipCount: results.reduce(0) { $0 + $1.skipCount },
            results: results
        )
    }

    private func apply(
        _ documents: [AnnotationExchangeDocument],
        to book: Book
    ) async throws -> (createCount: Int, updateCount: Int, skipCount: Int) {
        try await writer.write { db in
            var createCount = 0
            var updateCount = 0
            var skipCount = 0

            for document in documents {
                for item in document.items {
                    switch try apply(item, to: book, db: db) {
                    case .create:
                        createCount += 1
                    case .update:
                        updateCount += 1
                    case .skip:
                        skipCount += 1
                    }
                }
            }

            return (createCount, updateCount, skipCount)
        }
    }

    private func apply(_ item: AnnotationExchangeItem, to book: Book, db: Database) throws -> ApplyOperation {
        switch item.type {
        case .highlight:
            return try applyHighlight(item, to: book, db: db)
        case .textNote:
            return try applyTextNote(item, to: book, db: db)
        case .stickyNote:
            return try applyPageNote(item, to: book, db: db)
        }
    }

    private func applyHighlight(_ item: AnnotationExchangeItem, to book: Book, db: Database) throws -> ApplyOperation {
        let anchor = try decodeHighlightAnchor(item.anchor)
        let color = try requireColor(item.color)

        if var existing = try Highlight
            .filter(Highlight.Columns.bookId == book.id)
            .filter(Highlight.Columns.exchangeId == item.exchangeId)
            .fetchOne(db) {
            guard item.updatedAt > existing.updatedAt else {
                return .skip
            }

            existing.cfiStart = anchor.start
            existing.cfiEnd = anchor.end
            existing.color = color
            existing.selectedText = item.selectedText ?? existing.selectedText
            existing.exchangeId = item.exchangeId
            existing.createdAt = item.createdAt
            existing.updatedAt = item.updatedAt
            try existing.update(db)
            return .update
        }

        let highlight = Highlight(
            bookId: book.id,
            cfiStart: anchor.start,
            cfiEnd: anchor.end,
            color: color,
            selectedText: item.selectedText ?? "",
            exchangeId: item.exchangeId,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        try highlight.insert(db)
        return .create
    }

    private func applyTextNote(_ item: AnnotationExchangeItem, to book: Book, db: Database) throws -> ApplyOperation {
        let anchorValue = try decodeTextAnchor(item.anchor)

        if var existing = try TextNote
            .filter(TextNote.Columns.bookId == book.id)
            .filter(TextNote.Columns.exchangeId == item.exchangeId)
            .fetchOne(db) {
            guard item.updatedAt > existing.updatedAt else {
                return .skip
            }

            existing.highlightId = nil
            existing.cfiAnchor = anchorValue
            existing.selectedText = item.selectedText
            existing.body = item.body ?? ""
            existing.exchangeId = item.exchangeId
            existing.createdAt = item.createdAt
            existing.updatedAt = item.updatedAt
            try existing.update(db)
            return .update
        }

        let note = TextNote(
            bookId: book.id,
            highlightId: nil,
            cfiAnchor: anchorValue,
            selectedText: item.selectedText,
            body: item.body ?? "",
            exchangeId: item.exchangeId,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        try note.insert(db)
        return .create
    }

    private func applyPageNote(_ item: AnnotationExchangeItem, to book: Book, db: Database) throws -> ApplyOperation {
        let spineIndex = try decodePageAnchor(item.anchor)
        let pageInChapter = decodePageInChapter(item.pageLabel, format: book.format)

        if var existing = try PageNote
            .filter(PageNote.Columns.bookId == book.id)
            .filter(PageNote.Columns.exchangeId == item.exchangeId)
            .fetchOne(db) {
            guard item.updatedAt > existing.updatedAt else {
                return .skip
            }

            existing.spineIndex = spineIndex
            existing.pageInChapter = pageInChapter
            existing.body = item.body ?? ""
            existing.exchangeId = item.exchangeId
            existing.createdAt = item.createdAt
            existing.updatedAt = item.updatedAt
            try existing.update(db)
            return .update
        }

        let note = PageNote(
            bookId: book.id,
            spineIndex: spineIndex,
            pageInChapter: pageInChapter,
            body: item.body ?? "",
            exchangeId: item.exchangeId,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt
        )
        try note.insert(db)
        return .create
    }

    private func decodeHighlightAnchor(_ anchor: AnnotationExchangeAnchor) throws -> (start: String, end: String) {
        switch anchor.scheme {
        case .cfi:
            let parts = anchor.value.components(separatedBy: "||")
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else {
                throw AnnotationImportError.invalidAnchor("Highlight anchor must contain cfiStart||cfiEnd")
            }
            return (parts[0], parts[1])
        case .pdfAnchor:
            guard anchor.value.isEmpty == false else {
                throw AnnotationImportError.invalidAnchor("PDF highlight anchor must not be empty")
            }
            return (anchor.value, anchor.value)
        case .page:
            throw AnnotationImportError.invalidAnchor("Highlight does not support page anchor")
        }
    }

    private func decodeTextAnchor(_ anchor: AnnotationExchangeAnchor) throws -> String {
        switch anchor.scheme {
        case .cfi, .pdfAnchor:
            guard anchor.value.isEmpty == false else {
                throw AnnotationImportError.invalidAnchor("Text note anchor must not be empty")
            }
            return anchor.value
        case .page:
            throw AnnotationImportError.invalidAnchor("Text note does not support page anchor")
        }
    }

    private func decodePageAnchor(_ anchor: AnnotationExchangeAnchor) throws -> Int {
        guard anchor.scheme == .page else {
            throw AnnotationImportError.invalidAnchor("Sticky note must use page anchor")
        }
        guard let value = Int(anchor.value) else {
            throw AnnotationImportError.invalidAnchor("Sticky note page anchor must be an integer")
        }
        return value
    }

    private func decodePageInChapter(_ pageLabel: String?, format: BookFormat) -> Int {
        guard format == .epub, let pageLabel else { return 0 }
        guard let range = pageLabel.range(of: #"Page\s+(\d+)"#, options: .regularExpression) else {
            return 0
        }
        let digits = pageLabel[range].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        guard let pageNumber = Int(digits), pageNumber > 0 else {
            return 0
        }
        return pageNumber - 1
    }

    private func requireColor(_ color: AnnotationExchangeHighlightColor?) throws -> HighlightColor {
        guard let color else {
            throw AnnotationImportError.missingRequiredField("color")
        }

        switch color {
        case .yellow: return .yellow
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }

    private func contentHash(for book: Book) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: book.filePath))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private enum ApplyOperation {
    case create
    case update
    case skip
}

private struct GroupedImport {
    let book: Book
    var documents: [AnnotationExchangeDocument]
    var sourceURLs: [URL]

    init(book: Book) {
        self.book = book
        self.documents = []
        self.sourceURLs = []
    }

    mutating func append(document: AnnotationExchangeDocument, sourceURL: URL) {
        documents.append(document)
        sourceURLs.append(sourceURL)
    }
}
