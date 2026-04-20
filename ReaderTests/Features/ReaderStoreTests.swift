import Testing
import Foundation
@testable import Reader

@Suite("ReaderStore")
@MainActor
struct ReaderStoreTests {

    private func makeSetup() throws -> (ReaderStore, MockEPUBBridge, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)
        let book = Book(title: "Test", filePath: "/tmp/test.epub")
        return (store, bridge, lib, book)
    }

    @Test func openBookLoadsURLViaBridge() async throws {
        let (store, bridge, lib, book) = try makeSetup()
        try await lib.insert(book)

        let url = URL(fileURLWithPath: "/tmp/test.epub")
        store.openBook(book, resolvedURL: url)

        #expect(bridge.loadBookCalls.count == 1)
        #expect(bridge.loadBookCalls[0] == url)
        #expect(store.currentBook?.id == book.id)
    }

    @Test func openBookRestoresLastCFI() async throws {
        let (store, bridge, lib, _) = try makeSetup()
        let book = Book(title: "T", filePath: "/x", lastCFI: "epubcfi(/6/4)")
        try await lib.insert(book)

        store.openBook(book, resolvedURL: URL(fileURLWithPath: "/x"))

        #expect(bridge.goToCFICalls == ["epubcfi(/6/4)"])
    }

    @Test func openBookSkipsGoToCFIWhenNoSavedPosition() async throws {
        let (store, bridge, lib, book) = try makeSetup()
        try await lib.insert(book)

        store.openBook(book, resolvedURL: URL(fileURLWithPath: "/x"))

        #expect(bridge.goToCFICalls.isEmpty)
    }

    @Test func nextPageDelegatesToBridge() async throws {
        let (store, bridge, _, _) = try makeSetup()
        store.nextPage()
        #expect(bridge.nextPageCallCount == 1)
    }

    @Test func prevPageDelegatesToBridge() async throws {
        let (store, bridge, _, _) = try makeSetup()
        store.prevPage()
        #expect(bridge.prevPageCallCount == 1)
    }

    @Test func pageChangedUpdatesStoreState() async throws {
        let (store, bridge, _, _) = try makeSetup()
        bridge.simulatePageChanged(cfi: "cfi1", spineIndex: 3, currentPage: 47, totalPages: 312)

        #expect(store.currentCFI == "cfi1")
        #expect(store.currentSpineIndex == 3)
        #expect(store.currentPage == 47)
        #expect(store.totalPages == 312)
    }

    @Test func pageChangedPersistsProgress() async throws {
        let (store, bridge, lib, book) = try makeSetup()
        try await lib.insert(book)
        store.openBook(book, resolvedURL: URL(fileURLWithPath: "/x"))

        bridge.simulatePageChanged(cfi: "cfi-new", spineIndex: 2, currentPage: 50, totalPages: 200)

        // Task.detached persists — wait briefly
        try await Task.sleep(nanoseconds: 200_000_000)

        let reloaded = try await lib.fetch(id: book.id)
        #expect(reloaded?.lastCFI == "cfi-new")
        #expect(reloaded?.currentPage == 50)
        #expect(reloaded?.totalPages == 200)
    }

    @Test func resetAutoHideToolbarShowsToolbar() async throws {
        let (store, _, _, _) = try makeSetup()
        store.showToolbar = false
        store.resetAutoHideToolbar()
        #expect(store.showToolbar == true)
    }

    @Test func initialToolbarVisible() async throws {
        let (store, _, _, _) = try makeSetup()
        #expect(store.showToolbar == true)
    }

    @Test func bindBridgeAfterInit() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann)
        let bridge = MockEPUBBridge()

        store.bindBridge(bridge)
        store.nextPage()

        #expect(bridge.nextPageCallCount == 1)
    }

    @Test func bridgeDelegateIsSetOnBind() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann)
        let bridge = MockEPUBBridge()

        store.bindBridge(bridge)
        bridge.simulatePageChanged(cfi: "x", spineIndex: 0, currentPage: 1, totalPages: 10)

        #expect(store.currentCFI == "x")
    }
}
