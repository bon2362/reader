import Foundation
import PDFKit
import Testing
@testable import Reader

@MainActor
@Suite("PDFReaderStore")
struct PDFReaderStoreTests {

    @Test func loadsOutlineAndSearchResultsForTextPDF() async throws {
        let db = try DatabaseManager.inMemory()
        let library = LibraryRepository(database: db)
        let annotations = AnnotationRepository(database: db)
        let url = try TestPDFFactory.makeTextPDF(
            text: "Hello PDF world",
            title: "Outline PDF",
            author: "Tester"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let book = Book(
            title: "Outline PDF",
            author: "Tester",
            filePath: url.path,
            lastCFI: "pdf:0",
            totalPages: 1,
            currentPage: 1,
            format: .pdf
        )
        try await library.insert(book)

        let store = try PDFReaderStore(
            book: book,
            resolvedURL: url,
            libraryRepository: library,
            tocStore: TOCStore(),
            searchStore: SearchStore(),
            highlightsStore: HighlightsStore(repository: annotations),
            textNotesStore: TextNotesStore(repository: annotations),
            stickyNotesStore: StickyNotesStore(repository: annotations),
            annotationPanelStore: AnnotationPanelStore(
                highlightsStore: HighlightsStore(repository: annotations),
                textNotesStore: TextNotesStore(repository: annotations),
                stickyNotesStore: StickyNotesStore(repository: annotations),
                tocStore: TOCStore()
            )
        )
        store.start()
        let pdfView = PDFView()
        store.attachPDFView(pdfView)

        #expect(store.tocStore.entries.isEmpty)

        store.searchStore.updateQuery("world")
        try await Task.sleep(nanoseconds: SearchStore.debounceNanos + 150_000_000)

        #expect(store.searchStore.results.count == 1)
        #expect(store.searchStore.results[0].excerpt.contains("world"))
    }

    @Test func reportsUnavailableSearchForImageOnlyPDF() async throws {
        let db = try DatabaseManager.inMemory()
        let library = LibraryRepository(database: db)
        let annotations = AnnotationRepository(database: db)
        let url = try TestPDFFactory.makeImageOnlyPDF(title: "Scanned")
        defer { try? FileManager.default.removeItem(at: url) }

        let book = Book(
            title: "Scanned",
            filePath: url.path,
            lastCFI: "pdf:0",
            totalPages: 1,
            currentPage: 1,
            format: .pdf
        )
        try await library.insert(book)

        let store = try PDFReaderStore(
            book: book,
            resolvedURL: url,
            libraryRepository: library,
            tocStore: TOCStore(),
            searchStore: SearchStore(),
            highlightsStore: HighlightsStore(repository: annotations),
            textNotesStore: TextNotesStore(repository: annotations),
            stickyNotesStore: StickyNotesStore(repository: annotations),
            annotationPanelStore: AnnotationPanelStore(
                highlightsStore: HighlightsStore(repository: annotations),
                textNotesStore: TextNotesStore(repository: annotations),
                stickyNotesStore: StickyNotesStore(repository: annotations),
                tocStore: TOCStore()
            )
        )
        store.start()

        #expect(store.isImageOnly == true)

        store.searchStore.updateQuery("anything")
        try await Task.sleep(nanoseconds: SearchStore.debounceNanos + 150_000_000)

        #expect(store.searchStore.results.isEmpty)
        #expect(store.searchStore.emptyMessage == "В этом PDF нет текстового слоя")
    }

    @Test func keepsDescendantOutlineEntriesWhenParentHasNoDestination() throws {
        let url = try TestPDFFactory.makeTextPDF(
            text: "Hello PDF world",
            title: "Outline PDF",
            author: "Tester"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0) else {
            Issue.record("Failed to load PDF document")
            return
        }

        let root = PDFOutline()
        let section = PDFOutline()
        section.label = "Раздел"
        let chapter = PDFOutline()
        chapter.label = "Глава 1"
        chapter.destination = PDFDestination(page: page, at: .zero)

        section.insertChild(chapter, at: 0)
        root.insertChild(section, at: 0)
        document.outlineRoot = root

        let entries = PDFReaderStore.makeTOCEntries(document: document)

        #expect(entries.count == 1)
        #expect(entries[0].label == "Глава 1")
        #expect(entries[0].href == PDFAnchor.encodePage(0))
        #expect(entries[0].level == 1)
    }
}
