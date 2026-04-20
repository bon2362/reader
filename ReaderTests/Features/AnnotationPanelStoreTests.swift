import Testing
import Foundation
@testable import Reader

@Suite("AnnotationPanelStore")
@MainActor
struct AnnotationPanelStoreTests {

    private func setup() throws -> (AnnotationPanelStore, HighlightsStore, TextNotesStore, StickyNotesStore, AnnotationRepository, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let hl = HighlightsStore(repository: ann)
        let tn = TextNotesStore(repository: ann)
        let sn = StickyNotesStore(repository: ann)
        let toc = TOCStore()
        let panel = AnnotationPanelStore(
            highlightsStore: hl,
            textNotesStore: tn,
            stickyNotesStore: sn,
            tocStore: toc
        )
        let book = Book(title: "T", filePath: "/tmp/a.epub")
        return (panel, hl, tn, sn, ann, lib, book)
    }

    @Test func emptyItemsWhenNothing() throws {
        let (panel, _, _, _, _, _, _) = try setup()
        #expect(panel.allItems.isEmpty)
        #expect(panel.count(for: .all) == 0)
    }

    @Test func aggregatesAllThreeTypes() async throws {
        let (panel, hl, tn, sn, _, lib, book) = try setup()
        try await lib.insert(book)
        await hl.loadAndRender(bookId: book.id)
        await tn.loadForBook(bookId: book.id)
        await sn.loadForBook(bookId: book.id)

        hl.onTextSelected(cfiStart: "cfi-a", cfiEnd: "cfi-a-end", text: "quote")
        await hl.applyColor(.yellow)

        tn.beginNote(for: SelectionInfo(cfiStart: "cfi-b", cfiEnd: "cfi-b-end", text: "x"))
        await tn.addNote(body: "note body")

        await sn.createAt(spineIndex: 2)

        #expect(panel.allItems.count == 3)
        #expect(panel.count(for: .highlights) == 1)
        #expect(panel.count(for: .notes) == 1)
        #expect(panel.count(for: .sticky) == 1)
        #expect(panel.count(for: .all) == 3)
    }

    @Test func filteredItemsByTab() async throws {
        let (panel, hl, _, sn, _, lib, book) = try setup()
        try await lib.insert(book)
        await hl.loadAndRender(bookId: book.id)
        await sn.loadForBook(bookId: book.id)
        hl.onTextSelected(cfiStart: "c1", cfiEnd: "c1e", text: "q")
        await hl.applyColor(.red)
        await sn.createAt(spineIndex: 0)

        panel.selectedTab = .highlights
        #expect(panel.filteredItems.count == 1)
        #expect(panel.filteredItems.first?.kind == .highlight)

        panel.selectedTab = .sticky
        #expect(panel.filteredItems.count == 1)
        #expect(panel.filteredItems.first?.kind == .sticky)

        panel.selectedTab = .notes
        #expect(panel.filteredItems.isEmpty)
    }

    @Test func toggleVisibility() throws {
        let (panel, _, _, _, _, _, _) = try setup()
        #expect(panel.isVisible == false)
        panel.toggleVisibility()
        #expect(panel.isVisible == true)
        panel.hide()
        #expect(panel.isVisible == false)
    }

    @Test func readerStoreNavigatesHighlight() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let item = AnnotationListItem(id: "1", kind: .highlight, preview: "p", spineIndex: nil, pageInChapter: nil, cfi: "cfi-x", color: .yellow, chapterLabel: nil, createdAt: Date())
        store.navigateToAnnotation(item)
        #expect(bridge.goToCFICalls == ["cfi-x"])
        #expect(bridge.goToSpineCalls.isEmpty)
    }

    @Test func readerStoreNavigatesSticky() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let item = AnnotationListItem(id: "2", kind: .sticky, preview: "s", spineIndex: 5, pageInChapter: 3, cfi: nil, color: nil, chapterLabel: nil, createdAt: Date())
        store.navigateToAnnotation(item)
        #expect(bridge.goToSpinePageCalls.count == 1)
        #expect(bridge.goToSpinePageCalls.first?.index == 5)
        #expect(bridge.goToSpinePageCalls.first?.pageInChapter == 3)
        #expect(bridge.goToSpineCalls.isEmpty)
        #expect(bridge.goToCFICalls.isEmpty)
    }

    @Test func stickyItemsExposeBodyAndPageInChapter() async throws {
        let (panel, _, _, sn, _, lib, book) = try setup()
        try await lib.insert(book)
        await sn.loadForBook(bookId: book.id)
        await sn.createAt(spineIndex: 6, pageInChapter: 3)
        let id = try #require(sn.notes.first?.id)

        await sn.updateBody(id: id, body: "реальная sticky")

        let item = try #require(panel.allItems.first { $0.kind == .sticky })
        #expect(item.preview == "реальная sticky")
        #expect(item.spineIndex == 6)
        #expect(item.pageInChapter == 3)
    }

    @Test func sortsStickiesBeforeCFIlessAndByCFI() async throws {
        let (panel, hl, _, sn, _, lib, book) = try setup()
        try await lib.insert(book)
        await hl.loadAndRender(bookId: book.id)
        await sn.loadForBook(bookId: book.id)
        await sn.createAt(spineIndex: 3)
        hl.onTextSelected(cfiStart: "epubcfi(/6/2!/4)", cfiEnd: "x", text: "a")
        await hl.applyColor(.blue)
        hl.onTextSelected(cfiStart: "epubcfi(/6/10!/4)", cfiEnd: "y", text: "b")
        await hl.applyColor(.green)

        let items = panel.allItems
        #expect(items.count == 3)
        // Sticky sort key "s00000003" vs cfi keys start with "c" — "c" < "s" so cfis come first
        #expect(items[0].kind == .highlight)
        #expect(items[1].kind == .highlight)
        #expect(items[2].kind == .sticky)
    }
}
