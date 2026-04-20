import Testing
import Foundation
@testable import Reader

@Suite("StickyNotesStore")
@MainActor
struct StickyNotesStoreTests {

    private func setup() throws -> (StickyNotesStore, AnnotationRepository, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let store = StickyNotesStore(repository: ann)
        let book = Book(title: "Test", filePath: "/tmp/b.epub")
        return (store, ann, lib, book)
    }

    @Test func createAtInsertsAndExpands() async throws {
        let (store, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)

        await store.createAt(spineIndex: 2)

        let stored = try await ann.fetchPageNotes(bookId: book.id)
        #expect(stored.count == 1)
        #expect(stored.first?.spineIndex == 2)
        #expect(stored.first?.body == "")
        #expect(store.notes.count == 1)
        #expect(store.expandedId == store.notes.first?.id)
    }

    @Test func createAtNoOpWithoutBook() async throws {
        let (store, _, _, _) = try setup()
        await store.createAt(spineIndex: 1)
        #expect(store.notes.isEmpty)
    }

    @Test func loadForBookHydrates() async throws {
        let (store, ann, lib, book) = try setup()
        try await lib.insert(book)
        let n1 = PageNote(bookId: book.id, spineIndex: 0, body: "a")
        let n2 = PageNote(bookId: book.id, spineIndex: 1, body: "b")
        try await ann.insertPageNote(n1)
        try await ann.insertPageNote(n2)

        await store.loadForBook(bookId: book.id)
        #expect(store.notes.count == 2)
    }

    @Test func updateBodyPersists() async throws {
        let (store, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        await store.createAt(spineIndex: 0)
        let id = store.notes[0].id

        await store.updateBody(id: id, body: "written")

        let stored = try await ann.fetchPageNotes(bookId: book.id)
        #expect(stored.first?.body == "written")
        #expect(store.notes[0].body == "written")
    }

    @Test func deleteRemoves() async throws {
        let (store, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        await store.createAt(spineIndex: 0)
        let id = store.notes[0].id

        await store.delete(id: id)

        let stored = try await ann.fetchPageNotes(bookId: book.id)
        #expect(stored.isEmpty)
        #expect(store.notes.isEmpty)
        #expect(store.expandedId == nil)
    }

    @Test func notesForSpineFilters() async throws {
        let (store, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        await store.createAt(spineIndex: 0)
        await store.createAt(spineIndex: 1)
        await store.createAt(spineIndex: 1)

        #expect(store.notesForSpine(0).count == 1)
        #expect(store.notesForSpine(1).count == 2)
        #expect(store.notesForSpine(5).isEmpty)
    }

    @Test func toggleExpandToggles() throws {
        let (store, _, _, _) = try setup()
        store.toggleExpand(id: "a")
        #expect(store.expandedId == "a")
        store.toggleExpand(id: "a")
        #expect(store.expandedId == nil)
    }

    @Test func resetClears() async throws {
        let (store, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        await store.createAt(spineIndex: 0)
        store.reset()
        #expect(store.notes.isEmpty)
        #expect(store.expandedId == nil)
    }

    @Test func readerStoreAddsForCurrentSpine() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let book = Book(title: "t", filePath: "/tmp/x.epub")
        try await lib.insert(book)
        await store.stickyNotesStore.loadForBook(bookId: book.id)
        store.currentSpineIndex = 3

        store.addStickyNoteForCurrentPage()
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(store.stickyNotesStore.notes.count == 1)
        #expect(store.stickyNotesStore.notes.first?.spineIndex == 3)
    }
}
