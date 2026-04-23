import Testing
import Foundation
import CryptoKit
import ZIPFoundation
@testable import Reader

@Suite("LibraryStore")
@MainActor
struct LibraryStoreTests {

    private func makeStore() throws -> (LibraryStore, LibraryRepository, AnnotationRepository) {
        let db = try DatabaseManager.inMemory()
        let repo = LibraryRepository(database: db)
        let annotationRepository = AnnotationRepository(database: db)
        return (
            LibraryStore(
                database: db,
                repository: repo,
                annotationRepository: annotationRepository
            ),
            repo,
            annotationRepository
        )
    }

    @Test func loadBooksEmpty() async throws {
        let (store, _, _) = try makeStore()
        await store.loadBooks()
        #expect(store.books.isEmpty)
        #expect(store.isLoading == false)
    }

    @Test func loadBooksReturnsInserted() async throws {
        let (store, repo, _) = try makeStore()
        try await repo.insert(Book(title: "A", filePath: "/a"))
        try await repo.insert(Book(title: "B", filePath: "/b"))

        await store.loadBooks()
        #expect(store.books.count == 2)
    }

    @Test func deleteBookRemovesFromList() async throws {
        let (store, repo, _) = try makeStore()
        let book = Book(title: "X", filePath: "/x")
        try await repo.insert(book)
        await store.loadBooks()

        await store.deleteBook(id: book.id)
        #expect(store.books.isEmpty)
    }

    @Test func resolveBookURLReturnsNilWhenMissing() throws {
        let (store, _, _) = try makeStore()
        let book = Book(title: "T", filePath: "/definitely/not/exist/\(UUID().uuidString).epub")
        #expect(store.resolveBookURL(book) == nil)
    }

    @Test func resolveBookURLReturnsURLWhenExists() throws {
        let (store, _, _) = try makeStore()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).txt")
        try Data().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let book = Book(title: "T", filePath: tmp.path)
        #expect(store.resolveBookURL(book) != nil)
    }

    @Test func latestBookReturnsFreshCopyFromRepository() async throws {
        let (store, repo, _) = try makeStore()
        let original = Book(title: "Original", filePath: "/a", currentPage: 1, format: .pdf)
        try await repo.insert(original)
        try await repo.updateReadingProgress(id: original.id, lastCFI: "pdf:7", currentPage: 8, totalPages: 19)

        let latest = await store.latestBook(id: original.id)

        #expect(latest?.lastCFI == "pdf:7")
        #expect(latest?.currentPage == 8)
    }

    @Test func selectBookStoresSelectedId() throws {
        let (store, _, _) = try makeStore()

        store.selectBook(id: "book-123")

        #expect(store.selectedBookID == "book-123")
    }

    @Test func clearSelectionResetsSelectedId() throws {
        let (store, _, _) = try makeStore()

        store.selectBook(id: "book-123")
        store.clearSelection()

        #expect(store.selectedBookID == nil)
    }

    @Test func displayedBooksFiltersByTitleAndAuthor() throws {
        let (store, _, _) = try makeStore()
        store.books = [
            Book(title: "Swift Concurrency", author: "Alice Appleseed", filePath: "/a"),
            Book(title: "Combine Essentials", author: "Bob Reader", filePath: "/b"),
            Book(title: "Server Side Swift", author: "Charlie", filePath: "/c")
        ]

        store.searchText = "swift"
        #expect(store.displayedBooks.map(\.title) == ["Swift Concurrency", "Server Side Swift"])

        store.searchText = "reader"
        #expect(store.displayedBooks.map(\.title) == ["Combine Essentials"])
    }

    @Test func displayedBooksReturnsAllForBlankSearch() throws {
        let (store, _, _) = try makeStore()
        store.books = [
            Book(title: "One", filePath: "/one"),
            Book(title: "Two", filePath: "/two")
        ]

        store.searchText = "   "

        #expect(store.displayedBooks.map(\.title) == ["One", "Two"])
    }

    @Test func highlightedSegmentsMarkCaseInsensitiveMatches() throws {
        let segments = LibraryStore.highlightedSegments(in: "Authoring Authority", query: "auth")

        #expect(segments == [
            LibrarySearchTextSegment(text: "Auth", isHighlighted: true),
            LibrarySearchTextSegment(text: "oring ", isHighlighted: false),
            LibrarySearchTextSegment(text: "Auth", isHighlighted: true),
            LibrarySearchTextSegment(text: "ority", isHighlighted: false)
        ])
    }

    @Test func importBookFromMinimalEPUB() async throws {
        let (store, _, _) = try makeStore()

        let url = try EPUBTestFactory.makeMinimalEPUB(title: "Imported", author: "Auth")
        defer { try? FileManager.default.removeItem(at: url) }

        await store.importBook(from: url)

        #expect(store.books.count == 1)
        #expect(store.books[0].title == "Imported")
        #expect(store.books[0].author == "Auth")
        #expect(store.errorMessage == nil)

        if let id = store.books.first?.id {
            try? FileAccess.deleteBookFiles(bookId: id)
        }
    }

    @Test func importBooksImportsMultipleSupportedBooks() async throws {
        let (store, _, _) = try makeStore()

        let first = try EPUBTestFactory.makeMinimalEPUB(title: "First", author: "One")
        let second = try EPUBTestFactory.makeMinimalEPUB(title: "Second", author: "Two")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        await store.importBooks(from: [first, second])

        #expect(store.books.count == 2)
        #expect(Set(store.books.map(\.title)) == ["First", "Second"])
        #expect(store.libraryImportFeedback?.title == "Книги импортированы")
        #expect(store.libraryImportFeedback?.message == "Добавлено книг: 2")

        for id in store.books.map(\.id) {
            try? FileAccess.deleteBookFiles(bookId: id)
        }
    }

    @Test func importBooksReportsPartialFailures() async throws {
        let (store, _, _) = try makeStore()

        let valid = try EPUBTestFactory.makeMinimalEPUB(title: "Imported", author: "Author")
        let invalid = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-book-\(UUID().uuidString).txt")
        try Data("plain text".utf8).write(to: invalid)
        defer {
            try? FileManager.default.removeItem(at: valid)
            try? FileManager.default.removeItem(at: invalid)
        }

        await store.importBooks(from: [valid, invalid])

        #expect(store.books.count == 1)
        #expect(store.books.first?.title == "Imported")
        #expect(store.errorMessage == nil)
        #expect(store.libraryImportFeedback?.title == "Импорт завершён частично")
        #expect(store.libraryImportFeedback?.message.contains("Добавлено книг: 1") == true)
        #expect(store.libraryImportFeedback?.message.contains(invalid.lastPathComponent) == true)

        if let id = store.books.first?.id {
            try? FileAccess.deleteBookFiles(bookId: id)
        }
    }

    @Test func loadBooksRepairsBrokenPDFMetadata() async throws {
        let (store, repo, _) = try makeStore()
        let url = try TestPDFFactory.makeTextPDF(
            text: "Hello PDF world",
            title: "<E7E0EAE0F0E8FF2031393937>",
            author: "<C2E8F2>",
            filename: "Закария 1997"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let book = Book(
            title: "<E7E0EAE0F0E8FF2031393937>",
            author: "<C2E8F2>",
            filePath: url.path,
            format: .pdf
        )
        try await repo.insert(book)

        await store.loadBooks()
        let repaired = try await repo.fetch(id: book.id)

        #expect(store.books.first?.title == "Закария 1997")
        #expect(store.books.first?.author == nil)
        #expect(repaired?.title == "Закария 1997")
        #expect(repaired?.author == nil)
    }

    @Test func deleteBookClearsSelectionForDeletedBook() async throws {
        let (store, repo, _) = try makeStore()
        let book = Book(title: "X", filePath: "/x")
        try await repo.insert(book)
        await store.loadBooks()
        store.selectBook(id: book.id)

        await store.deleteBook(id: book.id)

        #expect(store.selectedBookID == nil)
    }

    @Test func loadBooksClearsSelectionWhenSelectedBookMissing() async throws {
        let (store, repo, _) = try makeStore()
        let keptBook = Book(title: "Kept", filePath: "/kept")
        try await repo.insert(keptBook)
        store.selectBook(id: "missing-book")

        await store.loadBooks()

        #expect(store.selectedBookID == nil)
    }

    @Test func exportAllAnnotationsShowsSuccessFeedback() async throws {
        let (store, repo, annotationRepository) = try makeStore()
        let bookURL = FileManager.default.temporaryDirectory.appendingPathComponent("library-export-\(UUID().uuidString).epub")
        let exportDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try Data("book".utf8).write(to: bookURL)
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: bookURL)
            try? FileManager.default.removeItem(at: exportDirectory)
        }

        let book = Book(title: "Export Book", filePath: bookURL.path, format: .epub)
        try await repo.insert(book)
        try await annotationRepository.insertHighlight(
            Highlight(
                bookId: book.id,
                cfiStart: "epubcfi(/6/2)",
                cfiEnd: "epubcfi(/6/4)",
                color: .yellow,
                selectedText: "Quote"
            )
        )

        await store.exportAllAnnotations(to: exportDirectory)

        #expect(store.isExportingAnnotations == false)
        #expect(store.errorMessage == nil)
        #expect(store.exportFeedback?.title == "Экспорт завершён")
        #expect(store.exportFeedback?.message.contains("Экспортировано книг: 1") == true)
    }

    @Test func prepareAnnotationImportPreviewStoresPreviewAndAllowsApply() async throws {
        let (store, repo, _) = try makeStore()
        let bookFile = try makeBookFile(contents: "library-import-preview-book")
        let book = Book(title: "Import Preview", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await repo.insert(book)
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                title: book.title,
                author: book.author,
                contentHash: try sha256Hex(of: bookFile),
                items: sampleImportItems
            )
        )
        defer {
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        await store.prepareAnnotationImportPreview(urls: [markdownURL])

        #expect(store.isImportingAnnotations == false)
        #expect(store.importPreview?.createCount == 3)
        #expect(store.importPreview?.updateCount == 0)
        #expect(store.importPreview?.skipCount == 0)
        #expect(store.canApplyPreparedImport == true)
    }

    @Test func applyPreparedAnnotationImportImportsAnnotationsAndClearsPreview() async throws {
        let (store, repo, annotationRepository) = try makeStore()
        let bookFile = try makeBookFile(contents: "library-import-apply-book")
        let book = Book(title: "Import Apply", author: "Jane Doe", filePath: bookFile.path, format: .epub)
        try await repo.insert(book)
        let markdownURL = try makeMarkdownFile(
            markdown: sampleMarkdown(
                title: book.title,
                author: book.author,
                contentHash: try sha256Hex(of: bookFile),
                items: sampleImportItems
            )
        )
        defer {
            try? FileManager.default.removeItem(at: markdownURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: bookFile)
        }

        await store.prepareAnnotationImportPreview(urls: [markdownURL])
        await store.applyPreparedAnnotationImport()

        #expect(store.isImportingAnnotations == false)
        #expect(store.importPreview == nil)
        #expect(store.canApplyPreparedImport == false)
        #expect(store.errorMessage == nil)
        #expect(store.importFeedback?.title == "Импорт завершён")
        #expect(store.importFeedback?.message.contains("Импортировано книг: 1") == true)
        #expect(try await annotationRepository.fetchHighlights(bookId: book.id).count == 1)
        #expect(try await annotationRepository.fetchTextNotes(bookId: book.id).count == 1)
        #expect(try await annotationRepository.fetchPageNotes(bookId: book.id).count == 1)
    }

    private func sampleMarkdown(
        title: String,
        author: String?,
        contentHash: String,
        items: String
    ) -> String {
        """
        ---
        format: "reader-annotations/v1"
        exportedAt: "2025-04-22T12:30:00Z"
        book:
          id: "book-1"
          title: "\(title)"
          author: "\(author ?? "")"
          format: "epub"
          contentHash: "\(contentHash)"
        ---

        # Annotations

        \(items)
        """
    }

    private var sampleImportItems: String {
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

        > Selected

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
        pageLabel: "Стр. 17"
        -->

        **Location**

        > Стр. 17

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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("library-store-\(UUID().uuidString).epub")
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
