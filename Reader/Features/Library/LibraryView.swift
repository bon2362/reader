import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable var store: LibraryStore
    let onOpenBook: (Book, URL) -> Void
    let onOpenTest: (Book, URL) -> Void

    @State private var showImporter = false

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        Group {
            if store.books.isEmpty && !store.isLoading {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(store.books) { book in
                            BookCardView(
                                book: book,
                                onOpen: { openBook(book) },
                                onOpenTest: { openBookTest(book) },
                                onDelete: { Task { await store.deleteBook(id: book.id) } }
                            )
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Библиотека")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImporter = true
                } label: {
                    Label("Импорт", systemImage: "plus")
                }
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "epub") ?? .item,
                UTType.pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .alert(
            "Ошибка",
            isPresented: .init(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .task { await store.loadBooks() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Нет книг", systemImage: "books.vertical")
        } description: {
            Text("Нажмите + чтобы добавить EPUB или PDF файл")
        } actions: {
            Button("Импорт EPUB/PDF") { showImporter = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            Task {
                await store.importBook(from: url)
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
        case .failure(let error):
            store.errorMessage = error.localizedDescription
        }
    }

    private func openBook(_ book: Book) {
        guard let url = store.resolveBookURL(book) else {
            store.errorMessage = "Файл книги не найден"
            return
        }
        onOpenBook(book, url)
    }

    private func openBookTest(_ book: Book) {
        guard let url = store.resolveBookURL(book) else {
            store.errorMessage = "Файл книги не найден"
            return
        }
        onOpenTest(book, url)
    }
}
