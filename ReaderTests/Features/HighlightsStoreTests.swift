import Testing
import Foundation
@testable import Reader

@Suite("HighlightsStore")
@MainActor
struct HighlightsStoreTests {

    private func setup() throws -> (HighlightsStore, MockEPUBBridge, AnnotationRepository, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let store = HighlightsStore(repository: ann)
        let bridge = MockEPUBBridge()
        store.bindBridge(bridge)
        let book = Book(title: "Test", filePath: "/tmp/b.epub")
        return (store, bridge, ann, lib, book)
    }

    @Test func textSelectionSetsPending() throws {
        let (store, _, _, _, _) = try setup()
        store.onTextSelected(cfiStart: "s", cfiEnd: "e", text: "hello")
        #expect(store.pendingSelection?.text == "hello")
    }

    @Test func textSelectionIgnoredWhenBlank() throws {
        let (store, _, _, _, _) = try setup()
        store.onTextSelected(cfiStart: "s", cfiEnd: "e", text: "   ")
        #expect(store.pendingSelection == nil)
    }

    @Test func applyColorInsertsAndRenders() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadAndRender(bookId: book.id)

        store.onTextSelected(cfiStart: "cfi-s", cfiEnd: "cfi-e", text: "quoted")
        await store.applyColor(.yellow)

        let stored = try await ann.fetchHighlights(bookId: book.id)
        #expect(stored.count == 1)
        #expect(stored.first?.color == .yellow)
        #expect(stored.first?.selectedText == "quoted")
        #expect(bridge.highlightCalls.count == 1)
        #expect(bridge.highlightCalls[0].cfiStart == "cfi-s")
        #expect(store.pendingSelection == nil)
        #expect(store.highlights.count == 1)
    }

    @Test func applyColorNoOpWithoutSelection() async throws {
        let (store, bridge, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadAndRender(bookId: book.id)

        await store.applyColor(.red)
        #expect(bridge.highlightCalls.isEmpty)
        #expect(store.highlights.isEmpty)
    }

    @Test func loadAndRenderHydratesFromDB() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        let h = Highlight(bookId: book.id, cfiStart: "cs", cfiEnd: "ce", color: .blue, selectedText: "t")
        try await ann.insertHighlight(h)

        await store.loadAndRender(bookId: book.id)

        #expect(store.highlights.count == 1)
        #expect(bridge.highlightCalls.count == 1)
        #expect(bridge.highlightCalls[0].id == h.id)
        #expect(bridge.highlightCalls[0].color == .blue)
    }

    @Test func highlightTappedSetsActive() async throws {
        let (store, _, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadAndRender(bookId: book.id)

        store.onTextSelected(cfiStart: "s", cfiEnd: "e", text: "x")
        store.onHighlightTapped(id: "hid")

        #expect(store.activeHighlightId == "hid")
        #expect(store.pendingSelection == nil)
    }

    @Test func changeActiveColorUpdatesDBAndRerenders() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadAndRender(bookId: book.id)

        store.onTextSelected(cfiStart: "cs", cfiEnd: "ce", text: "x")
        await store.applyColor(.yellow)
        let id = store.highlights[0].id
        store.onHighlightTapped(id: id)

        bridge.removeHighlightCalls.removeAll()
        bridge.highlightCalls.removeAll()

        await store.changeActiveColor(.green)

        let stored = try await ann.fetchHighlights(bookId: book.id)
        #expect(stored.first?.color == .green)
        #expect(bridge.removeHighlightCalls == [id])
        #expect(bridge.highlightCalls.count == 1)
        #expect(bridge.highlightCalls[0].color == .green)
    }

    @Test func deleteActiveRemovesFromDBAndBridge() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadAndRender(bookId: book.id)

        store.onTextSelected(cfiStart: "cs", cfiEnd: "ce", text: "x")
        await store.applyColor(.red)
        let id = store.highlights[0].id
        store.onHighlightTapped(id: id)

        await store.deleteActive()

        let stored = try await ann.fetchHighlights(bookId: book.id)
        #expect(stored.isEmpty)
        #expect(store.highlights.isEmpty)
        #expect(bridge.removeHighlightCalls == [id])
        #expect(store.activeHighlightId == nil)
    }

    @Test func resetClearsState() throws {
        let (store, _, _, _, _) = try setup()
        store.onTextSelected(cfiStart: "s", cfiEnd: "e", text: "x")
        store.activeHighlightId = "y"
        store.highlights = [Highlight(bookId: "b", cfiStart: "s", cfiEnd: "e", color: .yellow)]
        store.reset()
        #expect(store.highlights.isEmpty)
        #expect(store.pendingSelection == nil)
        #expect(store.activeHighlightId == nil)
    }

    @Test func readerStoreRoutesTextSelection() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        bridge.simulateTextSelected(cfiStart: "s", cfiEnd: "e", text: "hi")
        #expect(store.highlightsStore.pendingSelection?.text == "hi")
    }

    @Test func readerStoreRoutesHighlightTap() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        bridge.simulateHighlightTapped(id: "ID-1")
        #expect(store.highlightsStore.activeHighlightId == "ID-1")
    }
}
