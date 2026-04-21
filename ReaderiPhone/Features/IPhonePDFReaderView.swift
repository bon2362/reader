import PDFKit
import SwiftUI

struct IPhonePDFReaderView: View {
    let book: Book
    let localURL: URL
    let libraryRepository: LibraryRepositoryProtocol
    let annotationRepository: AnnotationRepositoryProtocol
    let syncCoordinator: SyncCoordinator

    @Environment(\.dismiss) private var dismiss
    @State private var document: PDFDocument?
    @State private var pdfView: PDFView?
    @State private var currentPage = 1
    @State private var totalPages = 0
    @State private var selectedText = ""
    @State private var pendingAnchor: PDFAnchor?
    @State private var highlightsStore: HighlightsStore?

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    IPhonePDFKitView(
                        document: document,
                        onReady: { view in
                            pdfView = view
                            restorePosition(in: view)
                            bindHighlights(to: view)
                        },
                        onPageChanged: { view in
                            handlePageChange(in: view)
                        },
                        onSelectionChanged: { view in
                            handleSelectionChange(in: view)
                        }
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(book.title)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !selectedText.isEmpty {
                        Button("Highlight") {
                            Task { await highlightsStore?.applyColor(.yellow) }
                        }
                    }
                    if (highlightsStore?.activeHighlight) != nil {
                        Button("Delete", role: .destructive) {
                            Task { await highlightsStore?.deleteActive() }
                        }
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Text("\(currentPage) / \(max(totalPages, 1))")
                        .font(.caption)
                }
            }
            .task {
                document = PDFDocument(url: localURL)
                totalPages = document?.pageCount ?? 0
                await syncCoordinator.beginReading(bookID: book.id)
            }
            .onDisappear {
                Task {
                    await syncCoordinator.endReading(bookID: book.id)
                }
            }
        }
    }

    private func bindHighlights(to view: PDFView) {
        guard highlightsStore == nil else { return }
        let store = HighlightsStore(repository: annotationRepository, syncCoordinator: syncCoordinator)
        store.bindExternalRenderer(
            render: { highlight in
                PDFHighlightRenderer.apply(highlight: highlight, in: view)
            },
            remove: { id in
                PDFHighlightRenderer.remove(highlightID: id, in: view)
            }
        )
        highlightsStore = store
        Task {
            await store.loadAndRender(bookId: book.id)
        }
    }

    private func restorePosition(in view: PDFView) {
        guard let document else { return }
        let fallbackIndex = max(0, (book.currentPage ?? 1) - 1)
        let parsedIndex = PDFAnchor.parse(book.lastCFI ?? "")?.pageIndex ?? fallbackIndex
        let targetIndex = max(0, min(parsedIndex, max(document.pageCount - 1, 0)))
        if let page = document.page(at: targetIndex) {
            view.go(to: page)
            currentPage = targetIndex + 1
        }
    }

    private func handlePageChange(in view: PDFView) {
        guard let document, let page = view.currentPage else { return }
        let pageIndex = document.index(for: page)
        currentPage = pageIndex + 1
        totalPages = document.pageCount
        let anchor = PDFAnchor.encodePage(pageIndex)
        Task {
            try? await libraryRepository.updateReadingProgress(
                id: book.id,
                lastCFI: anchor,
                currentPage: currentPage,
                totalPages: totalPages
            )
            await syncCoordinator.publishStableProgress(
                bookID: book.id,
                lastReadAnchor: anchor,
                currentPage: currentPage,
                totalPages: totalPages
            )
        }
    }

    private func handleSelectionChange(in view: PDFView) {
        guard let document,
              let selection = view.currentSelection,
              let page = selection.pages.first,
              let anchor = makeAnchor(for: selection, on: page, pageIndex: document.index(for: page)) else {
            selectedText = ""
            pendingAnchor = nil
            highlightsStore?.onSelectionCleared()
            return
        }

        let text = selection.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else {
            selectedText = ""
            pendingAnchor = nil
            highlightsStore?.onSelectionCleared()
            return
        }

        selectedText = text
        pendingAnchor = anchor
        highlightsStore?.onTextSelected(cfiStart: anchor.stringValue, cfiEnd: anchor.stringValue, text: text)
    }

    private func makeAnchor(for selection: PDFSelection, on page: PDFPage, pageIndex: Int) -> PDFAnchor? {
        guard let pageText = page.string,
              let rawSelectedText = selection.string,
              !rawSelectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return PDFAnchor(pageIndex: pageIndex)
        }

        let normalizedPageText = pageText as NSString
        let normalizedSelection = rawSelectedText.trimmingCharacters(in: .whitespacesAndNewlines) as NSString
        let range = normalizedPageText.range(of: normalizedSelection as String)
        guard range.location != NSNotFound else {
            return PDFAnchor(pageIndex: pageIndex)
        }
        return PDFAnchor(pageIndex: pageIndex, charStart: range.location, charEnd: range.location + range.length)
    }
}
