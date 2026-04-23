import CryptoKit
import Foundation

struct AnnotationExportSummary: Equatable, Sendable {
    var exportedCount: Int
    var skippedCount: Int
    var failedCount: Int
    var results: [AnnotationBookExportResult]
}

struct AnnotationBookExportResult: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case exported(fileURL: URL)
        case skipped(reason: String)
        case failed(message: String)
    }

    var bookId: String
    var title: String
    var status: Status
}

struct AnnotationExportService: Sendable {
    private let libraryRepository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private let encoder: MarkdownAnnotationEncoder
    private let locationFormatter = AnnotationLocationFormatter()

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol,
        encoder: MarkdownAnnotationEncoder = MarkdownAnnotationEncoder()
    ) {
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
        self.encoder = encoder
    }

    func exportAll(to directoryURL: URL) async -> AnnotationExportSummary {
        let fileManager = FileManager.default
        var results: [AnnotationBookExportResult] = []
        let books: [Book]

        do {
            books = try await libraryRepository.fetchAll()
        } catch {
            return AnnotationExportSummary(
                exportedCount: 0,
                skippedCount: 0,
                failedCount: 1,
                results: [
                    AnnotationBookExportResult(
                        bookId: "",
                        title: "Library",
                        status: .failed(message: error.localizedDescription)
                    )
                ]
            )
        }

        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            return AnnotationExportSummary(
                exportedCount: 0,
                skippedCount: 0,
                failedCount: books.isEmpty ? 1 : books.count,
                results: books.map {
                    AnnotationBookExportResult(
                        bookId: $0.id,
                        title: $0.title,
                        status: .failed(message: error.localizedDescription)
                    )
                }
            )
        }

        for book in books {
            do {
                let highlights = try await annotationRepository.fetchHighlights(bookId: book.id)
                let textNotes = try await annotationRepository.fetchTextNotes(bookId: book.id)
                let stickyNotes = try await annotationRepository.fetchPageNotes(bookId: book.id)

                guard highlights.isEmpty == false || textNotes.isEmpty == false || stickyNotes.isEmpty == false else {
                    results.append(
                        AnnotationBookExportResult(
                            bookId: book.id,
                            title: book.title,
                            status: .skipped(reason: "No annotations")
                        )
                    )
                    continue
                }

                let document = try makeExchangeDocument(
                    book: book,
                    highlights: highlights,
                    textNotes: textNotes,
                    stickyNotes: stickyNotes
                )
                let markdown = try encoder.encode(document)
                let fileURL = fileURL(for: book, directoryURL: directoryURL)
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)

                results.append(
                    AnnotationBookExportResult(
                        bookId: book.id,
                        title: book.title,
                        status: .exported(fileURL: fileURL)
                    )
                )
            } catch {
                results.append(
                    AnnotationBookExportResult(
                        bookId: book.id,
                        title: book.title,
                        status: .failed(message: error.localizedDescription)
                    )
                )
            }
        }

        return AnnotationExportSummary(
            exportedCount: results.filter {
                if case .exported = $0.status { return true }
                return false
            }.count,
            skippedCount: results.filter {
                if case .skipped = $0.status { return true }
                return false
            }.count,
            failedCount: results.filter {
                if case .failed = $0.status { return true }
                return false
            }.count,
            results: results
        )
    }

    private func makeExchangeDocument(
        book: Book,
        highlights: [Highlight],
        textNotes: [TextNote],
        stickyNotes: [PageNote]
    ) throws -> AnnotationExchangeDocument {
        let contentHash = try contentHash(for: book)
        let highlightsById = Dictionary(uniqueKeysWithValues: highlights.map { ($0.id, $0) })

        return AnnotationExchangeDocument(
            exportedAt: Date(),
            book: AnnotationExchangeBook(
                id: book.id,
                title: book.title,
                author: book.author,
                format: book.format,
                contentHash: contentHash
            ),
            items: highlights.map(makeHighlightItem)
                + textNotes.map { makeTextNoteItem($0, highlightsById: highlightsById) }
                + stickyNotes.map { makeStickyNoteItem($0, book: book) }
        )
    }

    private func makeHighlightItem(_ highlight: Highlight) -> AnnotationExchangeItem {
        let isPDFAnchor = highlight.cfiStart.hasPrefix("pdf:")
        return AnnotationExchangeItem(
            exchangeId: highlight.exchangeId ?? highlight.id,
            type: .highlight,
            anchor: AnnotationExchangeAnchor(
                scheme: isPDFAnchor ? .pdfAnchor : .cfi,
                value: isPDFAnchor ? highlight.cfiStart : "\(highlight.cfiStart)||\(highlight.cfiEnd)"
            ),
            createdAt: highlight.createdAt,
            updatedAt: highlight.updatedAt,
            selectedText: highlight.selectedText,
            color: AnnotationExchangeHighlightColor(highlight.color)
        )
    }

    private func makeTextNoteItem(
        _ note: TextNote,
        highlightsById: [String: Highlight]
    ) -> AnnotationExchangeItem {
        AnnotationExchangeItem(
            exchangeId: note.exchangeId ?? note.id,
            type: .textNote,
            anchor: AnnotationExchangeAnchor(
                scheme: note.cfiAnchor.hasPrefix("pdf:") ? .pdfAnchor : .cfi,
                value: note.cfiAnchor
            ),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            selectedText: note.selectedText ?? note.highlightId.flatMap { highlightsById[$0]?.selectedText },
            body: note.body
        )
    }

    private func makeStickyNoteItem(_ note: PageNote, book: Book) -> AnnotationExchangeItem {
        AnnotationExchangeItem(
            exchangeId: note.exchangeId ?? note.id,
            type: .stickyNote,
            anchor: AnnotationExchangeAnchor(
                scheme: .page,
                value: String(note.spineIndex)
            ),
            createdAt: note.createdAt,
            updatedAt: note.updatedAt,
            body: note.body,
            pageLabel: locationFormatter.exportLabel(
                for: note,
                format: book.format,
                chapterPageCounts: book.chapterPageCounts
            )
        )
    }

    private func contentHash(for book: Book) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: book.filePath))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func fileURL(for book: Book, directoryURL: URL) -> URL {
        let slug = slugify(book.title)
        let suffix = String(book.id.prefix(8))
        return directoryURL.appendingPathComponent("\(slug)--\(suffix).md")
    }

    private func slugify(_ title: String) -> String {
        let lowercase = title.lowercased()
        let parts = lowercase.components(separatedBy: CharacterSet.alphanumerics.inverted)
        let slug = parts.filter { !$0.isEmpty }.joined(separator: "-")
        return slug.isEmpty ? "book" : slug
    }
}

private extension AnnotationExchangeHighlightColor {
    init(_ color: HighlightColor) {
        switch color {
        case .yellow: self = .yellow
        case .red: self = .red
        case .green: self = .green
        case .blue: self = .blue
        case .purple: self = .purple
        }
    }
}
