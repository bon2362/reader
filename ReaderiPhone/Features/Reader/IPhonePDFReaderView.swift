import PDFKit
import SwiftUI

struct IPhonePDFReaderView: View {
    @State private var store: IPhonePDFReaderStore?
    @State private var loadError: String?

    private let openedBook: IPhoneOpenedBook
    private let libraryRepository: LibraryRepositoryProtocol
    private let onClose: (() -> Void)?

    init(
        openedBook: IPhoneOpenedBook,
        libraryRepository: LibraryRepositoryProtocol,
        onClose: (() -> Void)? = nil
    ) {
        self.openedBook = openedBook
        self.libraryRepository = libraryRepository
        self.onClose = onClose
    }

    var body: some View {
        Group {
            if let store {
                ZStack(alignment: .bottom) {
                    IPhonePDFKitView(
                        document: store.document,
                        onReady: { pdfView in
                            store.attachPDFView(pdfView)
                        },
                        onDisplayReady: { pdfView in
                            store.handleDisplayReady(in: pdfView)
                        },
                        onPageChanged: { pdfView in
                            store.handlePageChange(in: pdfView)
                        },
                        onSelectionChanged: { pdfView in
                            store.handleSelectionChange(in: pdfView)
                        },
                        onHighlightTapped: { id in
                            store.handleHighlightTap(id: id)
                        }
                    )

                    pageControls(store: store)
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 8) {
                        if let onClose {
                            HStack {
                                Button(action: onClose) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .safeAreaPadding(.top)
                        }

                        if let errorMessage = store.currentErrorMessage {
                            Button {
                                store.dismissError()
                            } label: {
                                Label(errorMessage, systemImage: "xmark.circle.fill")
                                    .font(.footnote)
                                    .labelStyle(.titleAndIcon)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    highlightControls(store: store)
                }
            } else if let loadError {
                ContentUnavailableView(
                    "Reader Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Opening PDF")
            }
        }
        .background(Color(uiColor: .systemBackground))
        .ignoresSafeArea()
        .navigationTitle(openedBook.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard store == nil, loadError == nil else { return }

            do {
                store = try IPhonePDFReaderStore(
                    book: openedBook.book,
                    resolvedURL: openedBook.url,
                    libraryRepository: libraryRepository,
                    annotationRepository: openedBook.annotationRepository
                )
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func pageControls(store: IPhonePDFReaderStore) -> some View {
        HStack(spacing: 16) {
            Button {
                store.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.canGoToPreviousPage == false)

            Text("\(store.currentPageNumber) / \(max(store.totalPages, 1))")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)

            Button {
                store.goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.canGoToNextPage == false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.bottom, 88)
    }

    @ViewBuilder
    private func highlightControls(store: IPhonePDFReaderStore) -> some View {
        if store.highlightsStore.pendingSelection != nil {
            IPhoneHighlightColorPicker(
                onPick: { color in
                    Task { await store.applyHighlightColor(color) }
                },
                onDismiss: {
                    store.dismissHighlightUI()
                }
            )
            .padding(.bottom, 20)
        } else if let activeHighlight = store.highlightsStore.activeHighlight {
            IPhoneHighlightColorPicker(
                onPick: { color in
                    Task { await store.changeActiveHighlightColor(color) }
                },
                onDismiss: {
                    store.dismissHighlightUI()
                },
                activeColor: activeHighlight.color,
                showDelete: true,
                onDelete: {
                    Task { await store.deleteActiveHighlight() }
                }
            )
            .padding(.bottom, 20)
        }
    }
}
