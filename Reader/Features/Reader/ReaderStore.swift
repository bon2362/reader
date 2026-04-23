import Foundation
import Observation

struct AnnotationExportFeedback: Equatable {
    var title: String
    var message: String
}

@MainActor
@Observable
final class ReaderStore {
    // MARK: - Reading state

    var currentBook: Book?
    var currentCFI: String?
    var currentPage: Int = 0
    var totalPages: Int = 0
    var currentSpineIndex: Int = 0
    var currentPageInChapter: Int = 0
    var totalChapters: Int = 0
    var isPageCountReady: Bool = false
    var currentSectionHref: String?
    var showToolbar: Bool = true
    var errorMessage: String?
    var canGoBackFromLink: Bool = false
    var pdfStore: PDFReaderStore?
    var isExportingAnnotations: Bool = false
    var exportFeedback: AnnotationExportFeedback?

    let tocStore: TOCStore
    let searchStore: SearchStore
    let highlightsStore: HighlightsStore
    let textNotesStore: TextNotesStore
    let stickyNotesStore: StickyNotesStore
    let annotationPanelStore: AnnotationPanelStore

    // MARK: - Collaborators

    private var bridge: EPUBBridgeProtocol?
    private let libraryRepository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private var hideToolbarTask: Task<Void, Never>?
    private let annotationLocationFormatter = AnnotationLocationFormatter()

    // MARK: - Init

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol,
        bridge: EPUBBridgeProtocol? = nil,
        tocStore: TOCStore = TOCStore(),
        searchStore: SearchStore = SearchStore(),
        highlightsStore: HighlightsStore? = nil,
        textNotesStore: TextNotesStore? = nil,
        stickyNotesStore: StickyNotesStore? = nil
    ) {
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
        self.tocStore = tocStore
        self.searchStore = searchStore
        self.highlightsStore = highlightsStore ?? HighlightsStore(repository: annotationRepository)
        self.textNotesStore = textNotesStore ?? TextNotesStore(repository: annotationRepository)
        let stickies = stickyNotesStore ?? StickyNotesStore(repository: annotationRepository)
        self.stickyNotesStore = stickies
        self.annotationPanelStore = AnnotationPanelStore(
            highlightsStore: self.highlightsStore,
            textNotesStore: self.textNotesStore,
            stickyNotesStore: stickies,
            tocStore: self.tocStore
        )
        if let bridge {
            bindBridge(bridge)
        }
    }

    // MARK: - Bridge binding

    func bindBridge(_ bridge: EPUBBridgeProtocol) {
        self.bridge = bridge
        bridge.delegate = self
        searchStore.bindBridge(bridge)
        highlightsStore.bindBridge(bridge)
        textNotesStore.bindBridge(bridge)
    }

    // MARK: - Public API

    func openBook(_ book: Book, resolvedURL: URL) {
        guard book.format == .epub else {
            openPDFBook(book, resolvedURL: resolvedURL)
            return
        }

        pdfStore = nil
        currentBook = book
        currentCFI = book.lastCFI
        currentPage = book.currentPage ?? 0
        totalPages = book.totalPages ?? 0
        currentPageInChapter = 0
        annotationPanelStore.updateChapterPageCounts(book.chapterPageCounts ?? [])
        highlightsStore.reset()
        textNotesStore.reset()
        stickyNotesStore.reset()
        isPageCountReady = false
        canGoBackFromLink = false
        // Seed bridge with cached page counts AND saved position before loading;
        // the bridge consumes both inside its async parse Task.
        bridge?.setCachedChapterPageCounts(book.chapterPageCounts ?? [])
        bridge?.setPendingInitialCFI(book.lastCFI)
        bridge?.loadBook(url: resolvedURL)

        let id = book.id
        Task { [highlightsStore] in await highlightsStore.loadAndRender(bookId: id) }
        Task { [textNotesStore] in await textNotesStore.loadForBook(bookId: id) }
        Task { [stickyNotesStore] in await stickyNotesStore.loadForBook(bookId: id) }
    }

    func openPDFBook(_ book: Book, resolvedURL: URL) {
        do {
            let store = try PDFReaderStore(
                book: book,
                resolvedURL: resolvedURL,
                libraryRepository: libraryRepository,
                tocStore: tocStore,
                searchStore: searchStore,
                highlightsStore: highlightsStore,
                textNotesStore: textNotesStore,
                stickyNotesStore: stickyNotesStore,
                annotationPanelStore: annotationPanelStore,
                onStateChange: { [weak self] pdfStore in
                    guard let self else { return }
                    self.currentCFI = PDFAnchor.encodePage(pdfStore.currentPageIndex)
                    self.currentPage = pdfStore.currentPageNumber
                    self.totalPages = pdfStore.totalPages
                    self.currentSpineIndex = pdfStore.currentPageIndex
                    self.currentPageInChapter = 0
                    self.totalChapters = self.tocStore.entries.count
                    self.isPageCountReady = true
                    self.canGoBackFromLink = pdfStore.canGoBackFromLink
                }
            )
            pdfStore = store
            currentBook = book
            currentCFI = book.lastCFI
            currentPage = book.currentPage ?? 1
            totalPages = book.totalPages ?? 0
            currentSpineIndex = max(0, (book.currentPage ?? 1) - 1)
            currentPageInChapter = 0
            totalChapters = max(0, tocStore.entries.count)
            isPageCountReady = true
            canGoBackFromLink = store.canGoBackFromLink
            errorMessage = nil
            store.start()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addStickyNoteForCurrentPage() {
        if let pdfStore {
            pdfStore.addStickyNoteForCurrentPage()
            return
        }
        let spine = currentSpineIndex
        let page = bridge?.pageInCurrentChapter ?? currentPageInChapter
        Task { [stickyNotesStore] in await stickyNotesStore.createAt(spineIndex: spine, pageInChapter: page) }
    }

    func navigateToAnnotation(_ item: AnnotationListItem) {
        if let pdfStore {
            pdfStore.navigateToAnnotation(item)
            canGoBackFromLink = pdfStore.canGoBackFromLink
            return
        }
        if let cfi = item.cfi, !cfi.isEmpty {
            bridge?.goToCFI(cfi)
        } else if let spine = item.spineIndex, let page = item.pageInChapter {
            bridge?.goToSpine(index: spine, pageInChapter: page)
        } else if let spine = item.spineIndex {
            bridge?.goToSpine(index: spine)
        }
    }

    func nextPage() {
        if let pdfStore {
            pdfStore.nextPage()
            return
        }
        bridge?.nextPage()
    }

    func prevPage() {
        if let pdfStore {
            pdfStore.prevPage()
            return
        }
        bridge?.prevPage()
    }

    func goBackFromLink() {
        if let pdfStore {
            pdfStore.goBack()
            canGoBackFromLink = pdfStore.canGoBackFromLink
            return
        }
        bridge?.goBackFromLink()
    }

    func exportAnnotations(to directoryURL: URL) async {
        isExportingAnnotations = true
        defer { isExportingAnnotations = false }

        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let summary = await service.exportAll(to: directoryURL)

        if summary.exportedCount == 0, summary.failedCount > 0 {
            let failedTitles = summary.results.compactMap { result -> String? in
                if case .failed = result.status {
                    return result.title
                }
                return nil
            }
            errorMessage = failedTitles.isEmpty
                ? "Не удалось экспортировать заметки."
                : "Не удалось экспортировать заметки: \(failedTitles.joined(separator: ", "))"
            return
        }

        exportFeedback = AnnotationExportFeedback(
            title: "Экспорт завершён",
            message: makeExportFeedbackMessage(summary: summary, directoryURL: directoryURL)
        )
    }

    func stickyNoteLocationLabel(for note: PageNote) -> String {
        annotationLocationFormatter.overlayLabel(
            for: note,
            format: currentBook?.format ?? .epub,
            chapterPageCounts: currentBook?.chapterPageCounts
        )
    }

    func resetAutoHideToolbar() {
        showToolbar = true
        hideToolbarTask?.cancel()
        hideToolbarTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.showToolbar = false
        }
    }

    private func makeExportFeedbackMessage(
        summary: AnnotationExportSummary,
        directoryURL: URL
    ) -> String {
        var lines = ["Папка: \(directoryURL.path)"]
        lines.append("Экспортировано книг: \(summary.exportedCount)")

        if summary.skippedCount > 0 {
            lines.append("Пропущено без заметок: \(summary.skippedCount)")
        }

        if summary.failedCount > 0 {
            lines.append("Ошибок: \(summary.failedCount)")
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - EPUBBridgeDelegate

extension ReaderStore: EPUBBridgeDelegate {

    func bridgeDidReceivePong() {}

    func bridgeDidChangePage(cfi: String, spineIndex: Int, currentPage: Int, totalPages: Int, sectionHref: String?) {
        self.currentCFI = cfi
        self.currentSpineIndex = spineIndex
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.currentPageInChapter = bridge?.pageInCurrentChapter ?? 0
        self.currentSectionHref = sectionHref
        tocStore.updateCurrentSection(href: sectionHref)
        textNotesStore.syncAnnotationsToBridge()
        persistProgress(cfi: cfi, currentPage: currentPage, totalPages: totalPages)
    }

    func bridgeDidSelectText(cfiStart: String, cfiEnd: String, text: String) {
        highlightsStore.onTextSelected(cfiStart: cfiStart, cfiEnd: cfiEnd, text: text)
    }

    func bridgeDidUpdateSelectionRect(_ rect: CGRect?) {
        highlightsStore.updateSelectionRect(rect)
    }

    func bridgeDidClearSelection() {
        highlightsStore.onSelectionCleared()
    }

    func bridgeDidUpdateLinkBackAvailability(canGoBack: Bool) {
        canGoBackFromLink = canGoBack
    }

    func bridgeDidFailToLoadBook(message: String) {
        errorMessage = message
    }
    func bridgeDidTapPage(x: Double, y: Double) {}
    func bridgeDidReceiveSearchResults(_ results: [SearchResult]) {
        searchStore.handleResults(results)
    }
    func bridgeDidReceiveAnnotationPositions(_ positions: [AnnotationPosition]) {
        textNotesStore.handlePositions(positions)
    }
    func bridgeDidLoadTOC(_ entries: [TOCEntry]) {
        tocStore.setEntries(entries)
        tocStore.updateCurrentSection(href: currentSectionHref)
    }

    func bridgeDidTapHighlight(id: String) {
        highlightsStore.onHighlightTapped(id: id)
    }

    func bridgeDidLoadBook(chapterCount: Int) {
        totalChapters = chapterCount
    }

    func bridgeDidTapNote(id: String, x: Double, y: Double) {
        textNotesStore.onNoteTapped(id: id, at: CGPoint(x: x, y: y))
    }

    func bridgeDidFinishPageCountPreflight(counts: [Int]) {
        isPageCountReady = true
        annotationPanelStore.updateChapterPageCounts(counts)
        guard let book = currentBook, !counts.isEmpty else { return }
        let id = book.id
        Task.detached { [libraryRepository] in
            try? await libraryRepository.updateChapterPageCountsCache(id: id, counts: counts)
        }
    }

    func navigateToTOCEntry(_ entry: TOCEntry) {
        if let pdfStore {
            pdfStore.navigateToTOCEntry(entry)
            canGoBackFromLink = pdfStore.canGoBackFromLink
            return
        }
        bridge?.goToCFI(entry.href)
        tocStore.currentEntryId = entry.id
    }

    private func persistProgress(cfi: String, currentPage: Int, totalPages: Int) {
        guard let book = currentBook else { return }
        let id = book.id
        Task.detached { [libraryRepository] in
            try? await libraryRepository.updateReadingProgress(
                id: id, lastCFI: cfi, currentPage: currentPage, totalPages: totalPages
            )
        }
    }
}
