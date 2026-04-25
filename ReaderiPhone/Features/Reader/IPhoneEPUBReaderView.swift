import SwiftUI

struct IPhoneEPUBReaderView: View {
    @State private var store: IPhoneEPUBReaderStore?
    @State private var loadError: String?

    private let openedBook: IPhoneOpenedBook
    private let libraryRepository: LibraryRepositoryProtocol

    init(openedBook: IPhoneOpenedBook, libraryRepository: LibraryRepositoryProtocol) {
        self.openedBook = openedBook
        self.libraryRepository = libraryRepository
    }

    var body: some View {
        Group {
            if let store {
                readerBody(store: store)
            } else if let error = loadError {
                ContentUnavailableView(
                    "Не удалось открыть книгу",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ProgressView("Загрузка...")
            }
        }
        .navigationTitle(openedBook.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let s = IPhoneEPUBReaderStore(
                book: openedBook.book,
                resolvedURL: openedBook.url,
                libraryRepository: libraryRepository
            )
            store = s
            await s.load()
            if let msg = s.errorMessage {
                loadError = msg
                store = nil
            }
        }
    }

    @ViewBuilder
    private func readerBody(store: IPhoneEPUBReaderStore) -> some View {
        VStack(spacing: 0) {
            IPhoneEPUBWebView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            pageControls(store: store)
        }
    }

    @ViewBuilder
    private func pageControls(store: IPhoneEPUBReaderStore) -> some View {
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
