import SwiftUI

struct IPhoneEPUBReaderView: View {
    // Store создаётся в init — до первого рендера, чтобы makeUIView
    // успел вызвать attachWebView до того, как .task запустит load().
    @State private var store: IPhoneEPUBReaderStore
    @State private var loadError: String?

    init(openedBook: IPhoneOpenedBook, libraryRepository: LibraryRepositoryProtocol) {
        _store = State(initialValue: IPhoneEPUBReaderStore(
            book: openedBook.book,
            resolvedURL: openedBook.url,
            libraryRepository: libraryRepository
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(UIColor.systemBackground).ignoresSafeArea()
            IPhoneEPUBWebView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if store.isLoading {
                ProgressView("Загрузка...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
            } else if let error = loadError {
                ContentUnavailableView(
                    "Не удалось открыть книгу",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                pageControls
            }
        }
        .navigationTitle(store.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load()
            if let msg = store.errorMessage {
                loadError = msg
            }
        }
    }

    @ViewBuilder
    private var pageControls: some View {
        HStack {
            Button {
                store.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            .disabled(!store.canGoToPreviousPage)

            Spacer()

            VStack(spacing: 2) {
                Text(store.chapterTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(store.pageInChapter + 1) / \(store.totalInChapter)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                store.goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
            .disabled(!store.canGoToNextPage)
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}
