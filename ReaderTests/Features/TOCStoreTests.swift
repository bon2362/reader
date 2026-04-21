import Testing
import Foundation
@testable import Reader

@Suite("TOCStore")
@MainActor
struct TOCStoreTests {

    private func sampleEntries() -> [TOCEntry] {
        [
            TOCEntry(id: "ch1", label: "Chapter 1", href: "OEBPS/chap1.xhtml", level: 0),
            TOCEntry(id: "ch1s1", label: "Section 1.1", href: "OEBPS/chap1.xhtml#s1", level: 1),
            TOCEntry(id: "ch2", label: "Chapter 2", href: "OEBPS/chap2.xhtml", level: 0),
            TOCEntry(id: "ch3", label: "Chapter 3", href: "OEBPS/chap3.xhtml", level: 0),
        ]
    }

    @Test func setEntriesSelectsFirstWhenEmpty() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        #expect(s.currentEntryId == "ch1")
    }

    @Test func setEntriesKeepsCurrentIfSet() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.currentEntryId = "ch2"
        s.setEntries(sampleEntries())
        #expect(s.currentEntryId == "ch2")
    }

    @Test func setEntriesResetsCurrentWhenPreviousEntryMissing() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.currentEntryId = "ch2"
        s.setEntries([
            TOCEntry(id: "pdf-1", label: "PDF Chapter", href: "pdf:3", level: 0)
        ])
        #expect(s.currentEntryId == "pdf-1")
    }

    @Test func updateCurrentSectionMatchesByHref() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.updateCurrentSection(href: "OEBPS/chap2.xhtml")
        #expect(s.currentEntryId == "ch2")
    }

    @Test func updateCurrentSectionPrefersDeepestLevel() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.updateCurrentSection(href: "OEBPS/chap1.xhtml")
        // Both ch1 (level 0) and ch1s1 (level 1) share prefix; deepest wins
        #expect(s.currentEntryId == "ch1s1")
    }

    @Test func updateCurrentSectionIgnoresEmpty() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.currentEntryId = "ch2"
        s.updateCurrentSection(href: nil)
        s.updateCurrentSection(href: "")
        #expect(s.currentEntryId == "ch2")
    }

    @Test func updateCurrentSectionKeepsLastWhenNoMatch() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.currentEntryId = "ch2"
        s.updateCurrentSection(href: "other.xhtml")
        #expect(s.currentEntryId == "ch2")
    }

    @Test func currentEntryReturnsMatchedEntry() {
        let s = TOCStore()
        s.setEntries(sampleEntries())
        s.currentEntryId = "ch3"
        #expect(s.currentEntry?.label == "Chapter 3")
    }

    @Test func toggleVisibilityFlipsFlag() {
        let s = TOCStore()
        #expect(s.isVisible == false)
        s.toggleVisibility()
        #expect(s.isVisible == true)
        s.toggleVisibility()
        #expect(s.isVisible == false)
    }

    @Test func readerStoreRoutesTOCFromBridge() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        bridge.simulateTOCLoaded(sampleEntries())
        #expect(store.tocStore.entries.count == 4)
        #expect(store.tocStore.currentEntryId == "ch1")
    }

    @Test func readerStorePageChangedUpdatesTOC() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        bridge.simulateTOCLoaded(sampleEntries())
        bridge.simulatePageChanged(cfi: "cfi", spineIndex: 1, currentPage: 1, totalPages: 10, sectionHref: "OEBPS/chap2.xhtml")

        #expect(store.currentSectionHref == "OEBPS/chap2.xhtml")
        #expect(store.tocStore.currentEntryId == "ch2")
    }

    @Test func navigateToTOCEntryCallsBridgeGoToCFI() async throws {
        let db = try DatabaseManager.inMemory()
        let lib = LibraryRepository(database: db)
        let ann = AnnotationRepository(database: db)
        let bridge = MockEPUBBridge()
        let store = ReaderStore(libraryRepository: lib, annotationRepository: ann, bridge: bridge)

        let entry = TOCEntry(id: "ch2", label: "Chapter 2", href: "OEBPS/chap2.xhtml", level: 0)
        store.navigateToTOCEntry(entry)

        #expect(bridge.goToCFICalls == ["OEBPS/chap2.xhtml"])
        #expect(store.tocStore.currentEntryId == "ch2")
    }
}
