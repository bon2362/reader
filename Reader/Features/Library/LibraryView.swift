import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Bindable var store: LibraryStore
    let onOpenBook: (Book, URL) -> Void
    let onOpenTest: (Book, URL) -> Void

    @State private var showImporter = false
    @State private var pendingDeletionBook: Book?

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
                                isSelected: store.selectedBookID == book.id,
                                onSelect: { store.selectBook(id: book.id) },
                                onOpen: {
                                    store.selectBook(id: book.id)
                                    openBook(book)
                                },
                                onOpenTest: { openBookTest(book) },
                                onDelete: { requestDeletion(of: book) }
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
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    requestDeletionOfSelectedBook()
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
                .disabled(selectedBook == nil)
            }
        }
        .onDeleteCommand(perform: requestDeletionOfSelectedBook)
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
        .confirmationDialog(
            "Удалить книгу?",
            isPresented: .init(
                get: { pendingDeletionBook != nil },
                set: { if !$0 { pendingDeletionBook = nil } }
            ),
            presenting: pendingDeletionBook
        ) { book in
            Button("Удалить", role: .destructive) {
                pendingDeletionBook = nil
                Task { await store.deleteBook(id: book.id) }
            }
            Button("Отмена", role: .cancel) {
                pendingDeletionBook = nil
            }
        } message: { book in
            Text("Книга \"\(book.title)\" будет удалена из библиотеки вместе с локальным файлом.")
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

    private var selectedBook: Book? {
        guard let selectedBookID = store.selectedBookID else {
            return nil
        }
        return store.books.first(where: { $0.id == selectedBookID })
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

    private func requestDeletion(of book: Book) {
        store.selectBook(id: book.id)
        pendingDeletionBook = book
    }

    private func requestDeletionOfSelectedBook() {
        guard let selectedBook else {
            return
        }
        pendingDeletionBook = selectedBook
    }

    private func openBook(_ book: Book) {
        Task {
            let latestBook = await store.latestBook(id: book.id) ?? book
            guard let url = store.resolveBookURL(latestBook) else {
                store.errorMessage = "Файл книги не найден"
                return
            }
            onOpenBook(latestBook, url)
        }
    }

    private func openBookTest(_ book: Book) {
        Task {
            let latestBook = await store.latestBook(id: book.id) ?? book
            guard let url = store.resolveBookURL(latestBook) else {
                store.errorMessage = "Файл книги не найден"
                return
            }
            onOpenTest(latestBook, url)
        }
    }
}
