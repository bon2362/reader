import SwiftUI

private struct OpenedBookPayload: Identifiable {
    let book: Book
    let url: URL

    var id: String { book.id }
}

struct IPhoneLibraryView: View {
    @State var viewModel: IPhoneLibraryViewModel
    let libraryRepository: LibraryRepositoryProtocol
    let annotationRepository: AnnotationRepositoryProtocol
    let syncCoordinator: SyncCoordinator

    @State private var openedBook: OpenedBookPayload?

    var body: some View {
        NavigationStack {
            List(viewModel.books) { book in
                Button {
                    Task {
                        if let url = await viewModel.openURL(for: book) {
                            openedBook = OpenedBookPayload(book: book, url: url)
                        }
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(book.title)
                            if let author = book.author, !author.isEmpty {
                                Text(author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        statusLabel(for: viewModel.state(for: book))
                    }
                }
            }
            .navigationTitle("Library")
            .overlay {
                if viewModel.books.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "books.vertical",
                        description: Text("Импортируйте PDF на Mac и дождитесь синхронизации.")
                    )
                }
            }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $openedBook, content: { payload in
                IPhonePDFReaderView(
                    book: payload.book,
                    localURL: payload.url,
                    libraryRepository: libraryRepository,
                    annotationRepository: annotationRepository,
                    syncCoordinator: syncCoordinator
                )
            })
        }
    }

    @ViewBuilder
    private func statusLabel(for state: IPhoneLibraryViewModel.Availability) -> some View {
        switch state {
        case .cloudOnly:
            Label("Cloud", systemImage: "icloud")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .downloading:
            ProgressView()
        case .ready:
            Label("Ready", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed:
            Label("Error", systemImage: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
