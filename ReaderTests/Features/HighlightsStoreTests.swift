import Testing
import Foundation
@testable import Reader

@Suite("HighlightsStore")
@MainActor
struct HighlightsStoreTests {

    private struct FailingAnnotationRepository: AnnotationRepositoryProtocol {
        enum Failure: Error {
            case expected
        }

        func fetchHighlights(bookId: String) async throws -> [Highlight] { throw Failure.expected }
        func fetchHighlight(bookId: String, exchangeId: String) async throws -> Highlight? { throw Failure.expected }
        func insertHighlight(_ h: Highlight) async throws { throw Failure.expected }
        func updateHighlight(_ h: Highlight) async throws { throw Failure.expected }
        func deleteHighlight(id: String) async throws { throw Failure.expected }
        func fetchTextNotes(bookId: String) async throws -> [TextNote] { throw Failure.expected }
        func fetchTextNote(bookId: String, exchangeId: String) async throws -> TextNote? { throw Failure.expected }
        func insertTextNote(_ n: TextNote) async throws { throw Failure.expected }
        func updateTextNote(_ n: TextNote) async throws { throw Failure.expected }
        func deleteTextNote(id: String) async throws { throw Failure.expected }
        func fetchPageNotes(bookId: String) async throws -> [PageNote] { throw Failure.expected }
        func fetchPageNote(bookId: String, exchangeId: String) async throws -> PageNote? { throw Failure.expected }
        func insertPageNote(_ n: PageNote) async throws { throw Failure.expected }
        func updatePageNote(_ n: PageNote) async throws { throw Failure.expected }
        func deletePageNote(id: String) async throws { throw Failure.expected }
    }

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

    @Test func externalRendererPathLoadsAndRendersHighlights() async throws {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let book = Book(title: "PDF", filePath: "/tmp/test.pdf", format: .pdf)
        try await lib.insert(book)

        let existing = Highlight(bookId: book.id, cfiStart: "pdf:1|0-5", cfiEnd: "pdf:1|0-5", color: .green, selectedText: "quote")
        try await ann.insertHighlight(existing)

        let store = HighlightsStore(repository: ann)
        var renderedIDs: [String] = []
        store.bindExternalRenderer(
            render: { highlight in
                renderedIDs.append(highlight.id)
            },
            remove: { _ in }
        )

        await store.loadAndRender(bookId: book.id)

        #expect(store.highlights.count == 1)
        #expect(renderedIDs == [existing.id])
    }

    @Test func failurePathsSetAndClearErrorMessage() async {
        let store = HighlightsStore(repository: FailingAnnotationRepository())

        await store.loadAndRender(bookId: "book-1")
        #expect(store.errorMessage == "Не удалось загрузить хайлайты")

        store.dismissError()
        #expect(store.errorMessage == nil)

        store.onTextSelected(cfiStart: "a", cfiEnd: "b", text: "quote")
        await store.applyColor(.yellow)
        #expect(store.errorMessage == "Не удалось сохранить хайлайт")

        store.dismissError()
        #expect(store.errorMessage == nil)
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
