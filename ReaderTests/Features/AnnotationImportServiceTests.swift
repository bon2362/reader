import CryptoKit
import Foundation
import Testing
@testable import Reader

@Suite("Annotation Import Service")
struct AnnotationImportServiceTests {

    @Test func importsNewAnnotationsForMatchedBook() async throws {
        let (database, libraryRepository, annotationRepository, service) = try makeDependencies()
        let bookFile = try makeBookFile(contents: "import-book")
        let book = Book(title: "Import Book", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await libraryRepository.insert(book)
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(contentHash: try sha256Hex(of: bookFile), items: sampleAllItems)
        )
        defer {
            _ = database
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        let summary = await service.apply(urls: [markdownURL])

        #expect(summary.importedBookCount == 1)
        #expect(summary.failedBookCount == 0)
        #expect(summary.createCount == 3)
        #expect(summary.updateCount == 0)
        #expect(summary.skipCount == 0)

        let highlights = try await annotationRepository.fetchHighlights(bookId: book.id)
        let textNotes = try await annotationRepository.fetchTextNotes(bookId: book.id)
        let stickyNotes = try await annotationRepository.fetchPageNotes(bookId: book.id)

        #expect(highlights.count == 1)
        #expect(textNotes.count == 1)
        #expect(stickyNotes.count == 1)
        #expect(highlights.first?.exchangeId == "highlight-1")
        #expect(textNotes.first?.exchangeId == "text-note-1")
        #expect(textNotes.first?.selectedText == "Selected")
        #expect(stickyNotes.first?.exchangeId == "sticky-note-1")
        #expect(stickyNotes.first?.pageInChapter == 3)
    }

    @Test func reimportDoesNotCreateDuplicates() async throws {
        let (_, libraryRepository, annotationRepository, service) = try makeDependencies()
        let bookFile = try makeBookFile(contents: "reimport-book")
        let book = Book(title: "Reimport Book", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await libraryRepository.insert(book)
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(contentHash: try sha256Hex(of: bookFile), items: sampleAllItems)
        )
        defer {
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        _ = await service.apply(urls: [markdownURL])
        let summary = await service.apply(urls: [markdownURL])

        #expect(summary.importedBookCount == 1)
        #expect(summary.createCount == 0)
        #expect(summary.updateCount == 0)
        #expect(summary.skipCount == 3)
        #expect(try await annotationRepository.fetchHighlights(bookId: book.id).count == 1)
        #expect(try await annotationRepository.fetchTextNotes(bookId: book.id).count == 1)
        #expect(try await annotationRepository.fetchPageNotes(bookId: book.id).count == 1)
    }

    @Test func localNewerRecordWinsOverOlderImport() async throws {
        let (_, libraryRepository, annotationRepository, service) = try makeDependencies()
        let bookFile = try makeBookFile(contents: "newer-local-book")
        let book = Book(title: "Newer Local", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await libraryRepository.insert(book)
        try await annotationRepository.insertHighlight(
            Highlight(
                bookId: book.id,
                cfiStart: "local-start",
                cfiEnd: "local-end",
                color: .green,
                selectedText: "Keep local",
                exchangeId: "shared-highlight",
                createdAt: Date(timeIntervalSince1970: 1_745_320_400),
                updatedAt: Date(timeIntervalSince1970: 1_745_328_000)
            )
        )
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                contentHash: try sha256Hex(of: bookFile),
                items: """
                ## Highlights

                ### Highlight
                <!--
                id: "shared-highlight"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "remote-start||remote-end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T12:00:00Z"
                color: "yellow"
                selectedText: "Remote text"
                -->

                > Remote text
                """
            )
        )
        defer {
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        let summary = await service.apply(urls: [markdownURL])
        let highlight = try #require(try await annotationRepository.fetchHighlights(bookId: book.id).first)

        #expect(summary.createCount == 0)
        #expect(summary.updateCount == 0)
        #expect(summary.skipCount == 1)
        #expect(highlight.cfiStart == "local-start")
        #expect(highlight.color == .green)
        #expect(highlight.selectedText == "Keep local")
    }

    @Test func failureForOneBookRollsBackOnlyThatBook() async throws {
        let (_, libraryRepository, annotationRepository, service) = try makeDependencies()
        let goodBookFile = try makeBookFile(contents: "good-book")
        let badBookFile = try makeBookFile(contents: "bad-book")
        let goodBook = Book(title: "Good Import", author: "Jane Doe", filePath: goodBookFile.path, format: .epub)
        let badBook = Book(title: "Bad Import", author: "Jane Doe", filePath: badBookFile.path, format: .epub)
        try await libraryRepository.insert(goodBook)
        try await libraryRepository.insert(badBook)

        let goodMarkdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                contentHash: try sha256Hex(of: goodBookFile),
                items: """
                ## Highlights

                ### Highlight
                <!--
                id: "good-highlight"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "good-start||good-end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T12:00:00Z"
                color: "yellow"
                selectedText: "Good"
                -->

                > Good
                """
            )
        )
        let badMarkdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                contentHash: try sha256Hex(of: badBookFile),
                items: """
                ## Highlights

                ### Highlight
                <!--
                id: "bad-highlight-1"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "valid-start||valid-end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T12:00:00Z"
                color: "yellow"
                selectedText: "Will rollback"
                -->

                > Will rollback

                ### Highlight
                <!--
                id: "bad-highlight-2"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "broken-anchor"
                createdAt: "2025-04-22T11:10:00Z"
                updatedAt: "2025-04-22T12:10:00Z"
                color: "yellow"
                selectedText: "Break transaction"
                -->

                > Break transaction
                """
            )
        )
        defer {
            try? FileManager.default.removeItem(at: goodMarkdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: badMarkdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: goodBookFile)
            try? FileManager.default.removeItem(at: badBookFile)
        }

        let summary = await service.apply(urls: [goodMarkdownURL, badMarkdownURL])

        #expect(summary.importedBookCount == 1)
        #expect(summary.failedBookCount == 1)
        #expect(summary.createCount == 1)
        #expect(summary.results.contains {
            if case .failed = $0.status { return $0.bookId == badBook.id }
            return false
        })
        #expect(try await annotationRepository.fetchHighlights(bookId: goodBook.id).count == 1)
        #expect(try await annotationRepository.fetchHighlights(bookId: badBook.id).isEmpty)
    }

    private func makeDependencies() throws -> (DatabaseManager, LibraryRepository, AnnotationRepository, AnnotationImportService) {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationImportService(database: database, libraryRepository: libraryRepository)
        return (database, libraryRepository, annotationRepository, service)
    }

    private func sampleMarkdown(
        format: String = "reader-annotations/v1",
        contentHash: String,
        items: String
    ) -> String {
        """
        ---
        format: "\(format)"
        exportedAt: "2025-04-22T12:30:00Z"
        book:
          id: "book-1"
          title: "Import Book"
          author: "Jane Doe"
          format: "epub"
          contentHash: "\(contentHash)"
        ---

        # Annotations

        \(items)
        """
    }

    private var sampleAllItems: String {
        """
        ## Highlights

        ### Highlight
        <!--
        id: "highlight-1"
        type: "highlight"
        anchor:
          scheme: "cfi"
          value: "start||end"
        createdAt: "2025-04-22T11:00:00Z"
        updatedAt: "2025-04-22T12:00:00Z"
        color: "yellow"
        selectedText: "Important quote"
        -->

        > Important quote

        ## Text Notes

        ### Text Note
        <!--
        id: "text-note-1"
        type: "text_note"
        anchor:
          scheme: "cfi"
          value: "note-anchor"
        createdAt: "2025-04-22T11:10:00Z"
        updatedAt: "2025-04-22T12:10:00Z"
        selectedText: "Selected"
        -->

        **Selected text**

        Selected

        **Note**

        Body

        ## Sticky Notes

        ### Sticky Note
        <!--
        id: "sticky-note-1"
        type: "sticky_note"
        anchor:
          scheme: "page"
          value: "17"
        createdAt: "2025-04-22T11:20:00Z"
        updatedAt: "2025-04-22T12:20:00Z"
        pageLabel: "Chapter 2 · Page 4"
        -->

        **Location**

        Chapter 2 · Page 4

        **Note**

        Remember this section.
        """
    }

    private func makeMarkdownFile(markdown: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("annotations.md")
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeBookFile(contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("epub")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
