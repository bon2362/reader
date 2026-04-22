import CryptoKit
import Foundation
import Testing
@testable import Reader

@Suite("Annotation Import Preview Service")
struct AnnotationImportPreviewServiceTests {

    @Test func previewsValidFileWithCreateCounts() async throws {
        let (service, markdownURL, _) = try await makePreviewSetup()
        defer { try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent()) }

        let summary = await service.preview(urls: [markdownURL])

        #expect(summary.createCount == 3)
        #expect(summary.updateCount == 0)
        #expect(summary.skipCount == 0)
        #expect(summary.invalidCount == 0)
        #expect(summary.files.count == 1)
        #expect({
            if case .ready = summary.files[0].status { return true }
            return false
        }())
    }

    @Test func marksFileAsUnmatchedWhenBookHashIsMissing() async throws {
        let database = try DatabaseManager.inMemory()
        let service = AnnotationImportPreviewService(
            libraryRepository: LibraryRepository(database: database),
            annotationRepository: AnnotationRepository(database: database)
        )
        let markdownURL = try makeMarkdownFile(markdown: sampleMarkdown(contentHash: "missing-hash"))
        defer { try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent()) }

        let summary = await service.preview(urls: [markdownURL])

        #expect(summary.createCount == 0)
        #expect(summary.updateCount == 0)
        #expect(summary.skipCount == 1)
        #expect(summary.invalidCount == 0)
        #expect(summary.files.first?.status == .unmatchedBook)
    }

    @Test func marksMalformedAndUnsupportedFilesAsInvalid() async throws {
        let database = try DatabaseManager.inMemory()
        let service = AnnotationImportPreviewService(
            libraryRepository: LibraryRepository(database: database),
            annotationRepository: AnnotationRepository(database: database)
        )
        let malformedURL = try makeMarkdownFile(markdown: "not markdown front matter")
        let unsupportedURL = try makeMarkdownFile(
            markdown: sampleMarkdown(format: "reader-annotations/v2", contentHash: "unsupported-hash")
        )
        defer {
            try? FileManager.default.removeItem(at: malformedURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: unsupportedURL.deletingLastPathComponent())
        }

        let summary = await service.preview(urls: [malformedURL, unsupportedURL])

        #expect(summary.invalidCount == 2)
        #expect(summary.files.allSatisfy {
            if case .invalid = $0.status { return true }
            return false
        })
    }

    @Test func recognizesExistingRecordsAsUpdateOrSkip() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationImportPreviewService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let bookFile = try makeBookFile(contents: "preview-book")
        let book = Book(title: "Preview Book", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await libraryRepository.insert(book)
        let hash = try sha256Hex(of: bookFile)
        let olderExisting = Highlight(
            bookId: book.id,
            cfiStart: "old-start",
            cfiEnd: "old-end",
            color: .yellow,
            selectedText: "Old",
            exchangeId: "existing-update",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newerExisting = Highlight(
            bookId: book.id,
            cfiStart: "new-start",
            cfiEnd: "new-end",
            color: .yellow,
            selectedText: "New",
            exchangeId: "existing-skip",
            createdAt: Date(timeIntervalSince1970: 1_745_320_400),
            updatedAt: Date(timeIntervalSince1970: 1_745_324_400)
        )
        try await annotationRepository.insertHighlight(olderExisting)
        try await annotationRepository.insertHighlight(newerExisting)
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                contentHash: hash,
                items: """
                ## Highlights

                ### Highlight
                <!--
                id: "existing-update"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "start||end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T12:00:00Z"
                color: "yellow"
                selectedText: "Update me"
                -->

                > Update me

                ### Highlight
                <!--
                id: "existing-skip"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "start||end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T11:00:00Z"
                color: "yellow"
                selectedText: "Skip me"
                -->

                > Skip me

                ### Highlight
                <!--
                id: "brand-new"
                type: "highlight"
                anchor:
                  scheme: "cfi"
                  value: "start||end"
                createdAt: "2025-04-22T11:00:00Z"
                updatedAt: "2025-04-22T12:00:00Z"
                color: "yellow"
                selectedText: "Create me"
                -->

                > Create me
                """
            )
        )
        defer {
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        let summary = await service.preview(urls: [markdownURL])

        #expect(summary.createCount == 1)
        #expect(summary.updateCount == 1)
        #expect(summary.skipCount == 1)
        #expect(summary.invalidCount == 0)
    }

    private func makePreviewSetup() async throws -> (AnnotationImportPreviewService, URL, URL) {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationImportPreviewService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let bookFile = try makeBookFile(contents: "preview-book")
        let book = Book(title: "Preview Book", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await libraryRepository.insert(book)
        let hash = try sha256Hex(of: bookFile)
        let markdownURL = try makeMarkdownFile(markdown: sampleMarkdown(contentHash: hash, items: sampleAllItems))
        return (service, markdownURL, bookFile)
    }

    private func sampleMarkdown(
        format: String = "reader-annotations/v1",
        contentHash: String,
        items: String = """
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
        """
    ) -> String {
        """
        ---
        format: "\(format)"
        exportedAt: "2025-04-22T12:30:00Z"
        book:
          id: "book-1"
          title: "Preview Book"
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
