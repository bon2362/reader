import SwiftUI

struct PDFReaderView: View {
    @Bindable var readerStore: ReaderStore
    let book: Book
    let resolvedURL: URL

    var body: some View {
        Group {
            if let store = readerStore.pdfStore {
                PDFReaderContentView(readerStore: readerStore, store: store)
            } else {
                ProgressView("Открываем PDF…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: book.id) {
            readerStore.openPDFBook(book, resolvedURL: resolvedURL)
        }
    }
}

private struct PDFReaderContentView: View {
    @Bindable var readerStore: ReaderStore
    @Bindable var store: PDFReaderStore

    var body: some View {
        VStack(spacing: 0) {
            ChapterHeaderBar(chapterTitle: readerStore.tocStore.currentEntry?.label ?? readerStore.currentBook?.title)

            GeometryReader { geo in
                ZStack {
                    NativePDFView(
                        document: store.document,
                        onViewReady: { pdfView in store.attachPDFView(pdfView) },
                        onDisplayReady: { pdfView in store.handleDisplayReady(in: pdfView) },
                        onPageChanged: { pdfView in store.handlePageChange(in: pdfView) },
                        onSelectionChanged: { pdfView in store.handleSelectionChange(in: pdfView) },
                        onHistoryChanged: { pdfView in store.handleHistoryChange(in: pdfView) },
                        onNoteAnnotationTap: { id, point in
                            store.handleNoteAnnotationTap(id: id, at: point)
                        }
                    )

                    HStack(spacing: 0) {
                        EdgeClickArea(onTap: { store.prevPage() })
                            .frame(width: 80)
                        Spacer()
                        EdgeClickArea(onTap: { store.nextPage() })
                            .frame(width: 80)
                    }

                    StickyNotesOverlayView(
                        notes: readerStore.stickyNotesStore.notesForPage(
                            spineIndex: store.currentPageIndex,
                            pageInChapter: 0
                        ),
                        expandedId: readerStore.stickyNotesStore.expandedId,
                        onToggle: { id in readerStore.stickyNotesStore.toggleExpand(id: id) },
                        onUpdate: { id, body in
                            Task { await readerStore.stickyNotesStore.updateBody(id: id, body: body) }
                        },
                        onDelete: { id in
                            Task { await readerStore.stickyNotesStore.delete(id: id) }
                        }
                    )

                    TextNotePopoverOverlay(
                        tappedId: readerStore.textNotesStore.tappedNoteId,
                        point: readerStore.textNotesStore.tappedNotePoint,
                        notes: readerStore.textNotesStore.notes,
                        onEdit: { id in readerStore.textNotesStore.beginEdit(noteId: id) },
                        onDelete: { id in
                            Task {
                                await readerStore.textNotesStore.deleteNote(id: id)
                            }
                        },
                        onDismiss: { readerStore.textNotesStore.dismissTappedNote() }
                    )

                    VStack {
                        Spacer()
                        PageIndicator(
                            currentPage: store.currentPageNumber,
                            totalPages: store.totalPages,
                            isReady: true
                        )
                        .padding(.bottom, 14)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: readerStore.highlightsStore.pendingSelection)
                .onChange(of: readerStore.textNotesStore.notes) { _, _ in
                    store.syncNoteAnnotations()
                }
            }
        }
    }
}

private struct EdgeClickArea: View {
    let onTap: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}
