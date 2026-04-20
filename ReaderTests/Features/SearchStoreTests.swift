import Testing
import Foundation
@testable import Reader

@Suite("SearchStore")
@MainActor
struct SearchStoreTests {

    private func makeStore() -> (SearchStore, MockEPUBBridge) {
        let bridge = MockEPUBBridge()
        let store = SearchStore()
        store.bindBridge(bridge)
        return (store, bridge)
    }

    // Shorter sleep than the debounce default to keep tests snappy
    private static let waitAfterDebounce: UInt64 = 500_000_000

    @Test func showAndHideToggleVisibility() {
        let (store, _) = makeStore()
        #expect(store.isVisible == false)
        store.show()
        #expect(store.isVisible == true)
        store.hide()
        #expect(store.isVisible == false)
    }

    @Test func toggleVisibilityFlips() {
        let (store, _) = makeStore()
        store.toggleVisibility()
        #expect(store.isVisible == true)
        store.toggleVisibility()
        #expect(store.isVisible == false)
    }

    @Test func emptyQueryClearsResultsAndSkipsSearch() async throws {
        let (store, bridge) = makeStore()
        store.results = [SearchResult(cfi: "x", excerpt: "y")]
        store.updateQuery("   ")
        #expect(store.results.isEmpty)
        #expect(store.isSearching == false)
        try await Task.sleep(nanoseconds: SearchStoreTests.waitAfterDebounce)
        #expect(bridge.searchCalls.isEmpty)
    }

    @Test func nonEmptyQuerySetsSearchingImmediately() {
        let (store, _) = makeStore()
        store.updateQuery("hello")
        #expect(store.isSearching == true)
    }

    @Test func debouncedQueryDispatchesSearchOnce() async throws {
        let (store, bridge) = makeStore()
        store.updateQuery("he")
        store.updateQuery("hel")
        store.updateQuery("hello")
        try await Task.sleep(nanoseconds: SearchStoreTests.waitAfterDebounce)
        #expect(bridge.searchCalls == ["hello"])
    }

    @Test func handleResultsStoresResultsAndStopsSearching() {
        let (store, _) = makeStore()
        store.isSearching = true
        let r = [SearchResult(cfi: "c1", excerpt: "hello world")]
        store.handleResults(r)
        #expect(store.results.count == 1)
        #expect(store.results.first?.cfi == "c1")
        #expect(store.isSearching == false)
    }

    @Test func selectResultNavigatesViaBridge() {
        let (store, bridge) = makeStore()
        let r = SearchResult(cfi: "cfi-42", excerpt: "whatever")
        store.selectResult(r)
        #expect(bridge.goToCFICalls == ["cfi-42"])
    }

    @Test func hideCancelsDebounceAndResetsSearching() async throws {
        let (store, bridge) = makeStore()
        store.updateQuery("pending")
        #expect(store.isSearching == true)
        store.hide()
        #expect(store.isSearching == false)
        try await Task.sleep(nanoseconds: SearchStoreTests.waitAfterDebounce)
        #expect(bridge.searchCalls.isEmpty)
    }

    @Test func readerStoreRoutesSearchResultsToSearchStore() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let results = [SearchResult(cfi: "c", excerpt: "e")]
        bridge.simulateSearchResults(results)

        #expect(store.searchStore.results.count == 1)
    }

    @Test func readerStoreBindsBridgeToSearchStore() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        store.searchStore.selectResult(SearchResult(cfi: "z", excerpt: "w"))
        #expect(bridge.goToCFICalls == ["z"])
    }
}
