import Testing
import Foundation
@testable import Reader

@Suite("TextNotesStore")
@MainActor
struct TextNotesStoreTests {

    private func setup() throws -> (TextNotesStore, MockEPUBBridge, AnnotationRepository, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let store = TextNotesStore(repository: ann)
        let bridge = MockEPUBBridge()
        store.bindBridge(bridge)
        let book = Book(title: "Test", filePath: "/tmp/b.epub")
        return (store, bridge, ann, lib, book)
    }

    @Test func beginNoteOpensEditorWithSelection() throws {
        let (store, _, _, _, _) = try setup()
        let sel = SelectionInfo(cfiStart: "cs", cfiEnd: "ce", text: "quoted")
        store.beginNote(for: sel)
        #expect(store.isEditorPresented == true)
        #expect(store.draftSelection == sel)
        #expect(store.draftEditingNote == nil)
    }

    @Test func addNoteInsertsAndSyncsBridge() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        bridge.setAnnotationsCalls.removeAll()

        let sel = SelectionInfo(cfiStart: "cfi-s", cfiEnd: "cfi-e", text: "q")
        store.beginNote(for: sel)
        await store.addNote(body: "My note")

        let stored = try await ann.fetchTextNotes(bookId: book.id)
        #expect(stored.count == 1)
        #expect(stored.first?.body == "My note")
        #expect(stored.first?.cfiAnchor == "cfi-s")
        #expect(store.notes.count == 1)
        #expect(store.isEditorPresented == false)
        #expect(bridge.setAnnotationsCalls.last?.count == 1)
        #expect(bridge.setAnnotationsCalls.last?.first?.type == "note")
    }

    @Test func addNoteIgnoresBlankBody() async throws {
        let (store, _, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        let sel = SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x")
        store.beginNote(for: sel)
        await store.addNote(body: "   \n  ")
        let stored = try await ann.fetchTextNotes(bookId: book.id)
        #expect(stored.isEmpty)
    }

    @Test func loadForBookHydratesAndSyncs() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        let n = TextNote(bookId: book.id, cfiAnchor: "anchor", body: "hi")
        try await ann.insertTextNote(n)

        await store.loadForBook(bookId: book.id)

        #expect(store.notes.count == 1)
        #expect(bridge.setAnnotationsCalls.last?.count == 1)
        #expect(bridge.setAnnotationsCalls.last?.first?.cfi == "anchor")
    }

    @Test func updateNotePersistsBody() async throws {
        let (store, _, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        store.beginNote(for: SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x"))
        await store.addNote(body: "v1")

        let id = store.notes[0].id
        store.beginEdit(noteId: id)
        await store.updateNote(body: "v2")

        let stored = try await ann.fetchTextNotes(bookId: book.id)
        #expect(stored.first?.body == "v2")
        #expect(store.isEditorPresented == false)
    }

    @Test func deleteNoteRemovesAndSyncs() async throws {
        let (store, bridge, ann, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        store.beginNote(for: SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x"))
        await store.addNote(body: "bye")
        let id = store.notes[0].id
        store.toggleExpand(id: id)
        bridge.setAnnotationsCalls.removeAll()

        await store.deleteNote(id: id)

        let stored = try await ann.fetchTextNotes(bookId: book.id)
        #expect(stored.isEmpty)
        #expect(store.notes.isEmpty)
        #expect(store.expandedNoteId == nil)
        #expect(bridge.setAnnotationsCalls.last?.isEmpty == true)
    }

    @Test func toggleExpandToggles() throws {
        let (store, _, _, _, _) = try setup()
        store.toggleExpand(id: "a")
        #expect(store.expandedNoteId == "a")
        store.toggleExpand(id: "a")
        #expect(store.expandedNoteId == nil)
        store.toggleExpand(id: "b")
        #expect(store.expandedNoteId == "b")
    }

    @Test func handlePositionsFiltersToKnownNotes() async throws {
        let (store, _, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        store.beginNote(for: SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x"))
        await store.addNote(body: "n")
        let id = store.notes[0].id

        let positions: [AnnotationPosition] = [
            AnnotationPosition(id: id, x: 10, y: 20, type: "note"),
            AnnotationPosition(id: "stranger", x: 10, y: 40, type: "note"),
            AnnotationPosition(id: id, x: 10, y: 50, type: "highlight")
        ]
        store.handlePositions(positions)

        #expect(store.positions.count == 1)
        #expect(store.positions.first?.id == id)
        #expect(store.positions.first?.y == 20)
    }

    @Test func cancelEditorResetsDraft() throws {
        let (store, _, _, _, _) = try setup()
        store.beginNote(for: SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x"))
        store.cancelEditor()
        #expect(store.isEditorPresented == false)
        #expect(store.draftSelection == nil)
    }

    @Test func resetClearsEverything() async throws {
        let (store, _, _, lib, book) = try setup()
        try await lib.insert(book)
        await store.loadForBook(bookId: book.id)
        store.beginNote(for: SelectionInfo(cfiStart: "s", cfiEnd: "e", text: "x"))
        await store.addNote(body: "hi")
        store.toggleExpand(id: store.notes[0].id)
        store.reset()
        #expect(store.notes.isEmpty)
        #expect(store.positions.isEmpty)
        #expect(store.expandedNoteId == nil)
        #expect(store.isEditorPresented == false)
    }

    @Test func readerStoreRoutesAnnotationPositions() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let book = Book(title: "t", filePath: "/tmp/x.epub")
        try await lib.insert(book)
        await store.textNotesStore.loadForBook(bookId: book.id)
        store.textNotesStore.beginNote(for: SelectionInfo(cfiStart: "cs", cfiEnd: "ce", text: "x"))
        await store.textNotesStore.addNote(body: "hi")
        let id = store.textNotesStore.notes[0].id

        bridge.simulateAnnotationPositions([AnnotationPosition(id: id, x: 0, y: 100, type: "note")])
        #expect(store.textNotesStore.positions.count == 1)
    }

    @Test func readerStoreSyncsAnnotationsOnPageChanged() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let book = Book(title: "t", filePath: "/tmp/x.epub")
        try await lib.insert(book)
        await store.textNotesStore.loadForBook(bookId: book.id)
        store.textNotesStore.beginNote(for: SelectionInfo(cfiStart: "cs", cfiEnd: "ce", text: "x"))
        await store.textNotesStore.addNote(body: "hi")
        bridge.setAnnotationsCalls.removeAll()

        bridge.simulatePageChanged(cfi: "c", spineIndex: 0, currentPage: 1, totalPages: 10)
        #expect(bridge.setAnnotationsCalls.count == 1)
        #expect(bridge.setAnnotationsCalls[0].first?.type == "note")
    }
}
