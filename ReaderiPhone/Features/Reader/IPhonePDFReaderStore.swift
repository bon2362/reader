import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class IPhonePDFReaderStore {
    let book: Book
    let document: PDFDocument
    let highlightsStore: HighlightsStore

    var currentPageIndex = 0
    var currentPageNumber = 1
    var totalPages: Int
    var errorMessage: String?

    private let libraryRepository: LibraryRepositoryProtocol
    private weak var pdfView: PDFView?
    private var awaitingInitialDisplay = true
    private var started = false

    init(
        book: Book,
        resolvedURL: URL,
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol
    ) throws {
        self.book = book
        self.document = try PDFBookLoader.loadDocument(from: resolvedURL)
        self.totalPages = document.pageCount
        self.libraryRepository = libraryRepository
        self.highlightsStore = HighlightsStore(repository: annotationRepository)
    }

    var canGoToPreviousPage: Bool {
        currentPageIndex > 0
    }

    var canGoToNextPage: Bool {
        currentPageIndex < max(totalPages - 1, 0)
    }

    var currentErrorMessage: String? {
        errorMessage ?? highlightsStore.errorMessage
    }

    func attachPDFView(_ pdfView: PDFView) {
        self.pdfView = pdfView
        if pdfView.document !== document {
            pdfView.document = document
        }
        highlightsStore.bindExternalRenderer(
            render: { highlight in
                PDFHighlightRenderer.apply(highlight: highlight, in: pdfView)
            },
            remove: { id in
                PDFHighlightRenderer.remove(highlightID: id, in: pdfView)
            }
        )
        for highlight in highlightsStore.highlights {
            PDFHighlightRenderer.apply(highlight: highlight, in: pdfView)
        }
        startIfNeeded()
    }

    func handleDisplayReady(in pdfView: PDFView) {
        if self.pdfView == nil {
            self.pdfView = pdfView
        }

        guard awaitingInitialDisplay,
              self.pdfView === pdfView else {
            return
        }

        restorePosition(in: pdfView)
        awaitingInitialDisplay = false
    }

    func handlePageChange(in pdfView: PDFView) {
        guard !awaitingInitialDisplay,
              let page = pdfView.currentPage else {
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else { return }

        applyPageState(pageIndex: pageIndex, shouldPersistProgress: true)
    }

    func goToPreviousPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func goToNextPage() {
        pdfView?.goToNextPage(nil)
    }

    func handleSelectionChange(in pdfView: PDFView) {
        guard let selection = pdfView.currentSelection,
              let page = selection.pages.first else {
            highlightsStore.onSelectionCleared()
            return
        }

        let pageIndex = document.index(for: page)
        guard pageIndex != NSNotFound else {
            highlightsStore.onSelectionCleared()
            return
        }

        let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard text.isEmpty == false else {
            highlightsStore.onSelectionCleared()
            return
        }

        let anchor = makeAnchor(for: selection, on: page, pageIndex: pageIndex)
        highlightsStore.onTextSelected(
            cfiStart: anchor.stringValue,
            cfiEnd: anchor.stringValue,
            text: text
        )
        highlightsStore.updateSelectionRect(pdfView.convert(selection.bounds(for: page), from: page))
    }

    func handleHighlightTap(id: String) {
        highlightsStore.onHighlightTapped(id: id)
    }

    func applyHighlightColor(_ color: HighlightColor) async {
        await highlightsStore.applyColor(color)
        pdfView?.clearSelection()
    }

    func changeActiveHighlightColor(_ color: HighlightColor) async {
        await highlightsStore.changeActiveColor(color)
    }

    func deleteActiveHighlight() async {
        await highlightsStore.deleteActive()
    }

    func dismissHighlightUI() {
        highlightsStore.cancelPendingSelection()
        highlightsStore.dismissActiveHighlight()
        pdfView?.clearSelection()
    }

    func dismissError() {
        errorMessage = nil
        highlightsStore.dismissError()
    }

    private func startIfNeeded() {
        guard started == false else { return }
        started = true

        Task {
            await highlightsStore.loadAndRender(bookId: book.id)
        }
    }

    private func restorePosition(in pdfView: PDFView) {
        let restoredIndex = PDFReadingProgress.restoredPageIndex(
            lastCFI: book.lastCFI,
            currentPage: book.currentPage,
            pageCount: document.pageCount
        )
        goToPage(restoredIndex, in: pdfView, persistProgress: false)
    }

    private func goToPage(_ pageIndex: Int, in pdfView: PDFView, persistProgress: Bool) {
        let clampedIndex = PDFReadingProgress.clampedPageIndex(pageIndex, pageCount: document.pageCount)
        guard let page = document.page(at: clampedIndex) else {
            errorMessage = "Не удалось открыть нужную страницу PDF."
            return
        }

        pdfView.go(to: page)
        applyPageState(pageIndex: clampedIndex, shouldPersistProgress: persistProgress)
    }

    private func applyPageState(pageIndex: Int, shouldPersistProgress: Bool) {
        currentPageIndex = PDFReadingProgress.clampedPageIndex(pageIndex, pageCount: document.pageCount)
        currentPageNumber = currentPageIndex + 1
        totalPages = document.pageCount
        errorMessage = nil

        guard shouldPersistProgress else { return }

        let anchor = PDFReadingProgress.pageAnchor(for: currentPageIndex, pageCount: totalPages)
        let currentPageNumber = self.currentPageNumber
        let totalPages = self.totalPages

        Task {
            do {
                try await libraryRepository.updateReadingProgress(
                    id: book.id,
                    lastCFI: anchor,
                    currentPage: currentPageNumber,
                    totalPages: totalPages
                )
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func makeAnchor(for selection: PDFSelection, on page: PDFPage, pageIndex: Int) -> PDFAnchor {
        PDFSelectionAnchorResolver.makeAnchor(for: selection, on: page, pageIndex: pageIndex)
            ?? PDFAnchor(pageIndex: pageIndex)
    }
}
