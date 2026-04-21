import Testing
import Foundation
import ZIPFoundation
@testable import Reader

@Suite("LibraryStore")
@MainActor
struct LibraryStoreTests {

    private func makeStore() throws -> (LibraryStore, LibraryRepository) {
        let db = try DatabaseManager.inMemory()
        let repo = LibraryRepository(database: db)
        return (LibraryStore(repository: repo), repo)
    }

    @Test func loadBooksEmpty() async throws {
        let (store, _) = try makeStore()
        await store.loadBooks()
        #expect(store.books.isEmpty)
        #expect(store.isLoading == false)
    }

    @Test func loadBooksReturnsInserted() async throws {
        let (store, repo) = try makeStore()
        try await repo.insert(Book(title: "A", filePath: "/a"))
        try await repo.insert(Book(title: "B", filePath: "/b"))

        await store.loadBooks()
        #expect(store.books.count == 2)
    }

    @Test func deleteBookRemovesFromList() async throws {
        let (store, repo) = try makeStore()
        let book = Book(title: "X", filePath: "/x")
        try await repo.insert(book)
        await store.loadBooks()

        await store.deleteBook(id: book.id)
        #expect(store.books.isEmpty)
    }

    @Test func resolveBookURLReturnsNilWhenMissing() throws {
        let (store, _) = try makeStore()
        let book = Book(title: "T", filePath: "/definitely/not/exist/\(UUID().uuidString).epub")
        #expect(store.resolveBookURL(book) == nil)
    }

    @Test func resolveBookURLReturnsURLWhenExists() throws {
        let (store, _) = try makeStore()
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).txt")
        try Data().write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let book = Book(title: "T", filePath: tmp.path)
        #expect(store.resolveBookURL(book) != nil)
    }

    @Test func latestBookReturnsFreshCopyFromRepository() async throws {
        let (store, repo) = try makeStore()
        let original = Book(title: "Original", filePath: "/a", currentPage: 1, format: .pdf)
        try await repo.insert(original)
        try await repo.updateReadingProgress(id: original.id, lastCFI: "pdf:7", currentPage: 8, totalPages: 19)

        let latest = await store.latestBook(id: original.id)

        #expect(latest?.lastCFI == "pdf:7")
        #expect(latest?.currentPage == 8)
    }

    @Test func importBookFromMinimalEPUB() async throws {
        let (store, _) = try makeStore()

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
        let (store, repo) = try makeStore()
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
}
