import Testing
import Foundation
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
            LibraryStore(repository: repo, annotationRepository: annotationRepository),
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
}
