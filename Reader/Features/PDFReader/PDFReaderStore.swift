import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class PDFReaderStore {
    var currentPageIndex: Int = 0
    var currentPageNumber: Int = 1
    var totalPages: Int
    var isImageOnly: Bool
    var canGoBackFromLink: Bool = false
    var notePositions: [AnnotationPosition] = []

    let book: Book
    let document: PDFDocument
    let tocStore: TOCStore
    let searchStore: SearchStore
    let highlightsStore: HighlightsStore
    let textNotesStore: TextNotesStore
    let stickyNotesStore: StickyNotesStore
    let annotationPanelStore: AnnotationPanelStore

    private let libraryRepository: LibraryRepositoryProtocol
    private weak var pdfView: PDFView?
    private var started = false
    private var awaitingInitialDisplay = true
    private let onStateChange: @MainActor (PDFReaderStore) -> Void

    init(
        book: Book,
        resolvedURL: URL,
        libraryRepository: LibraryRepositoryProtocol,
        tocStore: TOCStore,
        searchStore: SearchStore,
        highlightsStore: HighlightsStore,
        textNotesStore: TextNotesStore,
        stickyNotesStore: StickyNotesStore,
        annotationPanelStore: AnnotationPanelStore,
        onStateChange: @escaping @MainActor (PDFReaderStore) -> Void = { _ in }
    ) throws {
        self.book = book
        self.document = try PDFBookLoader.loadDocument(from: resolvedURL)
        self.totalPages = document.pageCount
        self.isImageOnly = PDFBookLoader.isImageOnly(document)
        self.libraryRepository = libraryRepository
        self.tocStore = tocStore
        self.searchStore = searchStore
        self.highlightsStore = highlightsStore
        self.textNotesStore = textNotesStore
        self.stickyNotesStore = stickyNotesStore
        self.annotationPanelStore = annotationPanelStore
        self.onStateChange = onStateChange

        tocStore.setEntries(Self.makeTOCEntries(document: document))
        searchStore.bindHandlers(
            search: { [weak self] query in self?.runSearch(query) },
            select: { [weak self] result in self?.selectSearchResult(result) }
        )
    }

    func start() {
        guard !started else { return }
        started = true

        highlightsStore.reset()
        textNotesStore.reset()
        stickyNotesStore.reset()
        highlightsStore.bindExternalRenderer(
            render: { [weak self] highlight in
                guard let self, let pdfView = self.pdfView else { return }
                PDFHighlightRenderer.apply(highlight: highlight, in: pdfView)
            },
            remove: { [weak self] id in
                guard let self, let pdfView = self.pdfView else { return }
                PDFHighlightRenderer.remove(highlightID: id, in: pdfView)
            }
        )

        Task { [highlightsStore, bookId = book.id] in
            await highlightsStore.loadAndRender(bookId: bookId)
        }
        Task { [weak self, textNotesStore, bookId = book.id] in
            await textNotesStore.loadForBook(bookId: bookId)
            self?.syncNoteAnnotations()
        }
        Task { [stickyNotesStore, bookId = book.id] in
            await stickyNotesStore.loadForBook(bookId: bookId)
        }
    }

    func attachPDFView(_ pdfView: PDFView) {
        self.pdfView = pdfView
        if pdfView.document !== document {
            pdfView.document = document
        }
        syncNoteAnnotations(notify: false)
        for highlight in highlightsStore.highlights {
            PDFHighlightRenderer.apply(highlight: highlight, in: pdfView)
        }
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
        guard !awaitingInitialDisplay else { return }
        guard let page = pdfView.currentPage else { return }
        let pageIndex = document.index(for: page)
        guard isValidPageIndex(pageIndex) else { return }
        applyPageState(pageIndex: pageIndex, in: pdfView, shouldPersistProgress: true)
    }

    func handleHistoryChange(in pdfView: PDFView) {
        canGoBackFromLink = pdfView.canGoBack
        onStateChange(self)
    }

    func handleNoteAnnotationTap(id: String, at point: CGPoint) {
        textNotesStore.onNoteTapped(id: id, at: overlayPoint(from: point))
        onStateChange(self)
    }

    func handleSelectionChange(in pdfView: PDFView) {
        guard !isImageOnly,
              let selection = pdfView.currentSelection,
              let page = selection.pages.first else {
            highlightsStore.onSelectionCleared()
            return
        }

        let pageIndex = document.index(for: page)
        guard let anchor = makeAnchor(for: selection, on: page, pageIndex: pageIndex) else {
            highlightsStore.onSelectionCleared()
            return
        }

        let selectedText = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !selectedText.isEmpty else {
            highlightsStore.onSelectionCleared()
            return
        }

        let rect = overlayRect(from: pdfView.convert(selection.bounds(for: page), from: page))
        if let existing = highlightsStore.highlights.first(where: { $0.cfiStart == anchor.stringValue }) {
            highlightsStore.onHighlightTapped(id: existing.id)
            highlightsStore.updateSelectionRect(rect)
            return
        }
        highlightsStore.onTextSelected(
            cfiStart: anchor.stringValue,
            cfiEnd: anchor.stringValue,
            text: selectedText
        )
        highlightsStore.updateSelectionRect(rect)
    }

    func nextPage() {
        pdfView?.goToNextPage(nil)
    }

    func prevPage() {
        pdfView?.goToPreviousPage(nil)
    }

    func goToPageNumber(_ pageNumber: Int) {
        goToPage(pageNumber - 1)
    }

    func addStickyNoteForCurrentPage() {
        let pageIndex = currentPageIndex
        Task { [stickyNotesStore] in
            await stickyNotesStore.createAt(spineIndex: pageIndex, pageInChapter: 0)
        }
    }

    func navigateToTOCEntry(_ entry: TOCEntry) {
        guard let anchor = PDFAnchor.parse(entry.href) else { return }
        goToPage(anchor.pageIndex)
    }

    func navigateToAnnotation(_ item: AnnotationListItem) {
        if let cfi = item.cfi,
           let anchor = PDFAnchor.parse(cfi) {
            goToAnchor(anchor, flashSelection: true)
            return
        }
        if let page = item.spineIndex {
            goToPage(page)
        }
    }

    func goBack() {
        guard let pdfView else { return }
        pdfView.goBack(nil)
        canGoBackFromLink = pdfView.canGoBack
        handlePageChange(in: pdfView)
    }

    func selectSearchResult(_ result: SearchResult) {
        guard let anchor = PDFAnchor.parse(result.cfi) else { return }
        goToAnchor(anchor, flashSelection: true)
    }

    func refreshVisibleAnnotations(notify: Bool = true) {
        guard let pdfView else {
            notePositions = []
            if notify {
                onStateChange(self)
            }
            return
        }

        notePositions = textNotesStore.notes.compactMap { note in
            guard let anchor = PDFAnchor.parse(note.cfiAnchor),
                  anchor.pageIndex == currentPageIndex,
                  let range = anchor.range,
                  let page = document.page(at: anchor.pageIndex),
                  let selection = page.selection(for: range) else {
                return nil
            }
            let rect = pdfView.convert(selection.bounds(for: page), from: page)
            return AnnotationPosition(id: note.id, x: rect.maxX, y: rect.midY, type: "note")
        }
        if notify {
            onStateChange(self)
        }
    }

    func syncNoteAnnotations(notify: Bool = true) {
        guard let pdfView else {
            refreshVisibleAnnotations(notify: notify)
            return
        }
        PDFTextNoteRenderer.sync(notes: textNotesStore.notes, in: pdfView)
        refreshVisibleAnnotations(notify: notify)
    }

    private func restorePosition(in pdfView: PDFView) {
        goToPage(restoredPageIndex(), in: pdfView, persistProgress: false, alignToTop: true)
    }

    private func restoredPageIndex() -> Int {
        let fallbackIndex = max(0, (book.currentPage ?? 1) - 1)
        let parsedIndex = PDFAnchor.parse(book.lastCFI ?? "")?.pageIndex ?? fallbackIndex
        return max(0, min(parsedIndex, max(document.pageCount - 1, 0)))
    }

    private func applyPageState(pageIndex: Int, in pdfView: PDFView, shouldPersistProgress: Bool) {
        currentPageIndex = pageIndex
        currentPageNumber = currentPageIndex + 1
        tocStore.updateCurrentPDFPage(currentPageIndex)
        canGoBackFromLink = pdfView.canGoBack
        refreshVisibleAnnotations(notify: false)
        if shouldPersistProgress {
            persistProgress()
        }
        onStateChange(self)
    }

    private func isValidPageIndex(_ index: Int) -> Bool {
        index != NSNotFound && index >= 0 && index < document.pageCount
    }

    private func overlayRect(from pdfViewRect: CGRect) -> CGRect {
        guard let pdfView else { return pdfViewRect }
        return CGRect(
            x: pdfViewRect.origin.x,
            y: pdfView.bounds.height - pdfViewRect.maxY,
            width: pdfViewRect.width,
            height: pdfViewRect.height
        )
    }

    private func overlayPoint(from pdfViewPoint: CGPoint) -> CGPoint {
        guard let pdfView else { return pdfViewPoint }
        return CGPoint(
            x: pdfViewPoint.x,
            y: pdfView.bounds.height - pdfViewPoint.y
        )
    }

    private func persistProgress() {
        let currentAnchor = PDFAnchor.encodePage(currentPageIndex)
        Task.detached { [libraryRepository, bookId = book.id, currentPageNumber, totalPages] in
            try? await libraryRepository.updateReadingProgress(
                id: bookId,
                lastCFI: currentAnchor,
                currentPage: currentPageNumber,
                totalPages: totalPages
            )
        }
    }

    private func runSearch(_ query: String) {
        guard !isImageOnly else {
            searchStore.showUnavailableMessage("В этом PDF нет текстового слоя")
            return
        }

        let matches = document.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])
        let results = matches.compactMap { selection -> SearchResult? in
            guard let page = selection.pages.first else { return nil }
            let pageIndex = document.index(for: page)
            guard let anchor = makeAnchor(for: selection, on: page, pageIndex: pageIndex) else { return nil }
            let excerpt = (selection.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let pageLabel = pageIndex + 1
            return SearchResult(cfi: anchor.stringValue, excerpt: "Стр. \(pageLabel): \(excerpt)")
        }
        searchStore.handleResults(results)
    }

    private func goToPage(
        _ pageIndex: Int,
        persistProgress: Bool = true,
        alignToTop: Bool = false
    ) {
        guard let pdfView else { return }
        goToPage(pageIndex, in: pdfView, persistProgress: persistProgress, alignToTop: alignToTop)
    }

    private func goToPage(
        _ pageIndex: Int,
        in pdfView: PDFView,
        persistProgress: Bool,
        alignToTop: Bool
    ) {
        guard let page = document.page(at: max(0, min(pageIndex, document.pageCount - 1))) else {
            return
        }

        if alignToTop {
            let bounds = page.bounds(for: pdfView.displayBox)
            let destination = PDFDestination(
                page: page,
                at: CGPoint(x: bounds.minX, y: bounds.maxY)
            )
            pdfView.go(to: destination)
        } else {
            pdfView.go(to: page)
        }

        applyPageState(pageIndex: document.index(for: page), in: pdfView, shouldPersistProgress: persistProgress)
    }

    private func goToAnchor(_ anchor: PDFAnchor, flashSelection: Bool) {
        guard let pdfView,
              let page = document.page(at: anchor.pageIndex) else {
            return
        }
        pdfView.go(to: page)
        applyPageState(pageIndex: anchor.pageIndex, in: pdfView, shouldPersistProgress: true)

        guard flashSelection,
              let range = anchor.range,
              let selection = page.selection(for: range) else {
            return
        }

        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.highlightedSelections = [selection]
        Task { @MainActor [weak pdfView] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            pdfView?.highlightedSelections = []
        }
    }

    private func makeAnchor(for selection: PDFSelection, on page: PDFPage, pageIndex: Int) -> PDFAnchor? {
        guard let pageText = page.string,
              let rawSelectedText = selection.string,
              !rawSelectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let nsText = pageText as NSString
        let targetBounds = selection.bounds(for: page)
        let candidates = selectionQueries(from: rawSelectedText)

        var bestRange: NSRange?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for query in candidates {
            for range in allRanges(of: query, in: nsText) {
                guard let candidateSelection = page.selection(for: range) else { continue }
                let bounds = candidateSelection.bounds(for: page)
                let distance = hypot(bounds.midX - targetBounds.midX, bounds.midY - targetBounds.midY)
                if distance < bestDistance {
                    bestDistance = distance
                    bestRange = range
                }
            }
            if bestRange != nil {
                break
            }
        }

        guard let bestRange else { return nil }
        return PDFAnchor(
            pageIndex: pageIndex,
            charStart: bestRange.location,
            charEnd: bestRange.location + bestRange.length
        )
    }

    private func selectionQueries(from rawSelectedText: String) -> [String] {
        var queries: [String] = []
        let raw = rawSelectedText
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWhitespace = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        for query in [raw, trimmed, normalizedWhitespace] {
            guard !query.isEmpty, !queries.contains(query) else { continue }
            queries.append(query)
        }
        return queries
    }

    private func allRanges(of needle: String, in haystack: NSString) -> [NSRange] {
        guard !needle.isEmpty else { return [] }
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: haystack.length)

        while true {
            let found = haystack.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else { break }
            result.append(found)
            let nextLocation = found.location + max(found.length, 1)
            guard nextLocation < haystack.length else { break }
            searchRange = NSRange(location: nextLocation, length: haystack.length - nextLocation)
        }

        return result
    }

    static func makeTOCEntries(document: PDFDocument) -> [TOCEntry] {
        guard let root = document.outlineRoot else { return [] }
        var entries: [TOCEntry] = []

        func walk(_ outline: PDFOutline, level: Int) {
            for index in 0..<outline.numberOfChildren {
                guard let child = outline.child(at: index) else {
                    continue
                }
                if let pageIndex = tocPageIndex(for: child, document: document) {
                    let title = (child.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    entries.append(TOCEntry(
                        id: "pdf-toc-\(entries.count)-\(pageIndex)",
                        label: title.isEmpty ? "Стр. \(pageIndex + 1)" : title,
                        href: PDFAnchor.encodePage(pageIndex),
                        level: level
                    ))
                }
                walk(child, level: level + 1)
            }
        }

        walk(root, level: 0)
        return entries
    }

    private static func tocPageIndex(for outline: PDFOutline, document: PDFDocument) -> Int? {
        guard let page = outline.destination?.page else { return nil }
        return document.index(for: page)
    }
}
